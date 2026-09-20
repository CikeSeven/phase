import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../tools/tool.dart';
import 'dependency_profiles.dart';
import 'process_api.g.dart';
import 'process_driver.dart';

/// 托管 apt 安装：修复、更新、一次装齐全部依赖组，再逐组验证并记录版本。
/// 失败或取消保留已知状态；不替换 rootfs，因此可与模型运行并发。
class DependencyInstaller {
  DependencyInstaller(this.repository, this.driver);
  final WorkspaceRepository repository;
  final ProcessDriver driver;
  static const outputLimitBytes = 8 * 1024 * 1024;
  // apt otherwise suppresses transfer progress when stdout is a pipe. Keep
  // native CR-delimited progress without allocating a PTY or mixing streams.
  static const _apt =
      'apt-get -q=0 -o APT::Color=0 -o Dpkg::Use-Pty=0 '
      '-o DPkg::Lock::Timeout=60 -o Acquire::Retries=2 '
      '-o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30';

  /// 每个步骤在 guest 内执行的完整 shell 命令；测试覆写此方法注入假命令。
  /// 验证步按组单独执行，此时传入单元素列表。
  String commandFor(DependencyStep step, List<DependencyProfile> profiles) =>
      switch (step) {
        // 自愈步：失败只降级为警告，后续 apt 仍是权威判定。
        DependencyStep.repairing => 'dpkg --configure -a',
        DependencyStep.updating =>
          '$_apt -o APT::Update::Error-Mode=any update',
        DependencyStep.installing =>
          '$_apt install -y --no-install-recommends '
              'ca-certificates ${profiles.expand((p) => p.packages).join(' ')}',
        DependencyStep.verifying =>
          profiles.map((profile) => profile.verifyCommand).join(' && '),
      };

  /// 一次安装全部依赖组；返回按组记录的安装结果。
  Future<Map<String, InstalledDependency>> install(
    RunCancellation cancellation,
    void Function(DependencyStep step, String line) onOutput,
  ) async {
    final profiles = DependencyProfile.all;
    repository.beginDependencyChange();
    final owner = 'deps-${generateId()}';
    // The host only accepts guest workspaces under managed paths; staging
    // holds a scratch directory for the duration of the run.
    final scratch = Directory(
      p.join(repository.root.path, 'staging', 'deps-${generateId()}'),
    );
    final stops = driver.stops.listen((id) {
      if (id == owner) cancellation.cancel();
    });
    try {
      cancellation.throwIfCancelled();
      final env = await repository.environment();
      if (!env.ready || env.rootPath == null) {
        throw const WorkspaceFailure('environmentMissing', '请先安装 Ubuntu 环境');
      }
      await scratch.create(recursive: true);
      await driver.beginTask(owner, '安装开发依赖');
      for (final step in DependencyStep.values.take(3)) {
        cancellation.throwIfCancelled();
        await _run(
          owner,
          env.rootPath!,
          scratch.path,
          step,
          profiles,
          cancellation,
          onOutput,
        );
      }
      // 版本按组提取，每组一个独立验证进程；时间统一为本轮完成时刻。
      final installedAt = DateTime.now();
      var latest = await repository.environment();
      if (!latest.ready || latest.rootPath != env.rootPath) {
        throw const WorkspaceFailure(
          'environmentChanged',
          '环境已变化，本次安装结果未记录，可重试',
        );
      }
      for (final profile in profiles) {
        cancellation.throwIfCancelled();
        final version = await _run(
          owner,
          env.rootPath!,
          scratch.path,
          DependencyStep.verifying,
          [profile],
          cancellation,
          onOutput,
        );
        latest = latest.withDependencies(
          profile.id,
          InstalledDependency(
            installedAt: installedAt,
            version: _firstLine(version),
          ),
        );
      }
      cancellation.throwIfCancelled();
      await repository.saveEnvironment(latest);
      return latest.installedDependencies;
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
    List<DependencyProfile> profiles,
    RunCancellation cancellation,
    void Function(DependencyStep, String) onOutput,
  ) async {
    final stdout = StringBuffer();
    cancellation.throwIfCancelled();
    onOutput(
      step,
      step == DependencyStep.verifying
          ? '正在验证 ${profiles.single.label}'
          : step.description,
    );
    void line(bool stderr, String text) {
      if (text.trim().isEmpty) return;
      onOutput(step, text.trimRight());
      if (!stderr && step == DependencyStep.verifying) stdout.write('$text\n');
    }

    final pending = [StringBuffer(), StringBuffer()];
    void feed(bool stderr, String text) {
      final buffer = pending[stderr ? 1 : 0]..write(text);
      var body = buffer.toString();
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
        line(stderr, text);
      }
      buffer
        ..clear()
        ..write(body);
    }

    final decoders = [
      for (final stderr in [false, true])
        const Utf8Decoder(allowMalformed: true)
            .startChunkedConversion(_OutputSink((text) => feed(stderr, text))),
    ];

    cancellation.throwIfCancelled();
    final process = await driver.start(
      LinuxProcessSpec(
        ownerId: owner,
        processId: generateId(),
        rootfs: rootfs,
        workspace: workspace,
        executable: '/bin/sh',
        argv: ['-c', commandFor(step, profiles)],
        cwd: '/workspace',
        environment: {'DEBIAN_FRONTEND': 'noninteractive'},
        outputLimitBytes: DependencyInstaller.outputLimitBytes,
      ),
      (stderr, bytes) async => decoders[stderr ? 1 : 0].add(bytes),
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
    for (var index = 0; index < decoders.length; index++) {
      decoders[index].close();
      line(index == 1, pending[index].toString());
    }
    cancellation.throwIfCancelled();
    if (event.cancelled) throw const ToolCancelled();
    final failed =
        event.exitCode != 0 ||
        event.signal != null ||
        event.error != null ||
        event.timedOut ||
        event.outputLimitExceeded;
    if (step == DependencyStep.repairing) {
      if (failed) {
        AppLogger.error(
          'dpkg 修复未成功 exit=${event.exitCode} signal=${event.signal} '
          'timedOut=${event.timedOut}',
        );
        line(false, '警告：dpkg 修复未完全成功，继续尝试安装');
      }
      return '';
    }
    if (failed) {
      if (event.timedOut) {
        throw const WorkspaceFailure('aptTimeout', '安装超时，可重试；已安装内容保留');
      }
      AppLogger.error(
        '依赖安装步骤失败 step=${step.name} exit=${event.exitCode} '
        'signal=${event.signal} outputLimit=${event.outputLimitExceeded}',
      );
      throw switch (step) {
        DependencyStep.updating => const WorkspaceFailure(
          'aptUpdate',
          '软件源更新失败，请检查网络后重试',
        ),
        DependencyStep.installing => const WorkspaceFailure(
          'aptInstall',
          '依赖安装失败，可重试；已安装内容保留',
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

class _OutputSink implements Sink<String> {
  _OutputSink(this.onText);
  final void Function(String) onText;
  @override
  void add(String data) => onText(data);
  @override
  void close() {}
}
