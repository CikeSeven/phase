import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../tools/tool.dart';
import 'dependency_profiles.dart';
import 'process_api.g.dart';
import 'process_driver.dart';

/// 托管 apt 安装：修复、更新、安装、验证四步，结果写入环境记录。
/// 失败或取消保留已知状态；不替换 rootfs，因此可与模型运行并发。
class DependencyInstaller {
  DependencyInstaller(this.repository, this.driver);
  final WorkspaceRepository repository;
  final ProcessDriver driver;
  static const timeoutMs = 30 * 60 * 1000;
  static const outputLimitBytes = 8 * 1024 * 1024;

  /// 每个步骤在 guest 内执行的完整 shell 命令；测试覆写此方法注入假命令。
  String commandFor(
    DependencyStep step,
    DependencyProfile profile,
  ) => switch (step) {
    // 自愈步：失败只降级为警告，后续 apt 仍是权威判定。
    DependencyStep.repairing => 'dpkg --configure -a',
    DependencyStep.updating =>
      'apt-get -o DPkg::Lock::Timeout=60 -o Acquire::Retries=2 '
          '-o APT::Update::Error-Mode=any update',
    DependencyStep.installing =>
      'apt-get -o DPkg::Lock::Timeout=60 install -y --no-install-recommends '
          'ca-certificates ${profile.packages.join(' ')}',
    DependencyStep.verifying => profile.verifyCommand,
  };

  Future<InstalledDependency> install(
    DependencyProfile profile,
    RunCancellation cancellation,
    void Function(DependencyStep step, String line) onOutput,
  ) async {
    final env = await repository.environment();
    if (!env.ready || env.rootPath == null) {
      throw const WorkspaceFailure('environmentMissing', '请先安装 Ubuntu 环境');
    }
    repository.beginDependencyChange();
    final owner = 'deps-${profile.id}-${generateId()}';
    // The host only accepts guest workspaces under managed paths; staging
    // holds a scratch directory for the duration of the run.
    final scratch = Directory(
      p.join(repository.root.path, 'staging', 'deps-${generateId()}'),
    );
    final stops = driver.stops.listen((id) {
      if (id == owner) cancellation.cancel();
    });
    try {
      await scratch.create(recursive: true);
      await driver.beginTask(owner, '安装${profile.label}');
      var version = '';
      for (final step in DependencyStep.values) {
        cancellation.throwIfCancelled();
        final result = await _run(
          owner,
          env.rootPath!,
          scratch.path,
          step,
          profile,
          cancellation,
          onOutput,
        );
        if (step == DependencyStep.verifying) version = result;
      }
      final latest = await repository.environment();
      if (!latest.ready || latest.rootPath != env.rootPath) {
        throw const WorkspaceFailure(
          'environmentChanged',
          '环境已变化，本次安装结果未记录，可重试',
        );
      }
      final record = InstalledDependency(
        installedAt: DateTime.now(),
        version: _firstLine(version),
      );
      await repository.saveEnvironment(
        latest.withDependencies(profile.id, record),
      );
      return record;
    } finally {
      try {
        await driver.endTask(owner);
        if (await scratch.exists()) await scratch.delete(recursive: true);
      } finally {
        await stops.cancel();
        repository.endDependencyChange();
      }
    }
  }

  /// 运行一步并返回该步 stdout 全文（用于验证步取版本）。
  Future<String> _run(
    String owner,
    String rootfs,
    String workspace,
    DependencyStep step,
    DependencyProfile profile,
    RunCancellation cancellation,
    void Function(DependencyStep, String) onOutput,
  ) async {
    final stdout = StringBuffer();
    final pending = StringBuffer();
    Future<void> line(bool stderr, String text) async {
      if (text.isEmpty) return;
      onOutput(step, text);
      if (!stderr && step == DependencyStep.verifying) stdout.write('$text\n');
    }

    Future<void> feed(bool stderr, List<int> bytes) async {
      pending.write(String.fromCharCodes(bytes));
      var body = pending.toString();
      // apt 进度条以 \r 刷新；两种分隔都按整行切。
      while (true) {
        final newline = body.indexOf('\n');
        final carriage = body.indexOf('\r');
        var index = -1;
        if (newline >= 0 && (carriage < 0 || newline < carriage)) {
          index = newline;
        } else if (carriage >= 0) {
          index = carriage;
        }
        if (index < 0) break;
        final text = body.substring(0, index);
        body = body.substring(index + 1);
        if (text.isEmpty) continue;
        await line(stderr, text);
      }
      pending
        ..clear()
        ..write(body);
    }

    final process = await driver.start(
      LinuxProcessSpec(
        ownerId: owner,
        processId: generateId(),
        rootfs: rootfs,
        workspace: workspace,
        executable: '/bin/sh',
        argv: ['-c', commandFor(step, profile)],
        cwd: '/workspace',
        environment: {},
        timeoutMs: DependencyInstaller.timeoutMs,
        outputLimitBytes: DependencyInstaller.outputLimitBytes,
      ),
      (stderr, bytes) => feed(stderr, bytes),
    );
    try {
      await process.closeInput();
    } catch (_) {
      if (cancellation.isCancelled) {
        await process.cancel();
      } else {
        rethrow;
      }
    }
    final event = await waitForProcess(process, cancellation);
    await line(false, pending.toString());
    if (event.cancelled) throw const ToolCancelled();
    final failed =
        event.exitCode != 0 ||
        event.signal != null ||
        event.error != null ||
        event.timedOut ||
        event.outputLimitExceeded;
    if (step == DependencyStep.repairing) {
      if (failed) {
        await line(false, '警告：dpkg 修复未完全成功，继续尝试安装');
      }
      return '';
    }
    if (failed) {
      if (event.timedOut) {
        throw const WorkspaceFailure('aptTimeout', '安装超时，可重试；已安装内容保留');
      }
      throw switch (step) {
        DependencyStep.updating => const WorkspaceFailure(
          'aptUpdate',
          '软件源更新失败，请检查网络后重试',
        ),
        DependencyStep.installing => WorkspaceFailure(
          'aptInstall',
          '${profile.label} 安装失败，可重试；已安装内容保留',
        ),
        _ => const WorkspaceFailure('verifyFailed', '已安装但验证未通过，未记录版本，可重试'),
      };
    }
    return stdout.toString();
  }

  static String? _firstLine(String text) {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
