import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/workspace_repository.dart';
import '../tools/tool.dart';
import 'dependency_installer.dart';
import 'dependency_profiles.dart';
import 'process_driver.dart';

/// 模型侧的托管依赖安装：与设置页共用同一白名单与互斥，
/// 一次装齐全部依赖组；按设计约束作为独立工具调用并默认询问用户。
class InstallTool extends Tool {
  const InstallTool({
    this.workspace,
    this.repository,
    this.driver,
    this.installer,
  });
  final WorkspaceSnapshot? workspace;
  final WorkspaceRepository? repository;
  final ProcessDriver? driver;
  final DependencyInstaller? installer;
  @override
  String get name => 'install_packages';
  @override
  String get description =>
      '在 Ubuntu 环境一次安装完整开发依赖并记录版本：python3、pip、venv、'
      'nodejs、npm、git、ripgrep。安装经 apt 更新与自愈流程，可能耗时数分钟；'
      '已安装内容跨会话持久保留，重复安装是安全的。';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'additionalProperties': false,
  };
  @override
  Set<String> get requiredCapabilities => const {'linux_process'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      'Ubuntu ${workspace?.environmentRevision ?? "24.04 ARM64"} · ${workspace?.name ?? "会话工作区"}\n'
      '安装全部开发依赖：${DependencyProfile.completePackages}';

  @override
  String? validateArguments(Map<String, dynamic> arguments) =>
      arguments.isEmpty ? null : '该工具不需要参数';

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final binding = workspace;
    if (binding == null ||
        !binding.linuxAvailable ||
        repository == null ||
        driver == null) {
      return const ToolOutcome.failure(
        '请先在设置中安装 Ubuntu 环境',
        errorCode: 'environmentMissing',
      );
    }
    final tail = <String>[];
    try {
      final resolved = installer ?? DependencyInstaller(repository!, driver!);
      final records = await resolved.install(cancellation, (step, line) {
        tail.add(
          '${switch (step) {
            DependencyStep.repairing => '修复',
            DependencyStep.updating => '更新',
            DependencyStep.installing => '安装',
            DependencyStep.verifying => '验证',
          }}: $line',
        );
        if (tail.length > 5) tail.removeAt(0);
      });
      return ToolOutcome.success(
        jsonEncode({
          'profiles': [
            for (final profile in DependencyProfile.all)
              {
                'id': profile.id,
                'label': profile.label,
                'version': records[profile.id]?.version,
              },
          ],
          'outputTail': tail,
          'knownEffects': '已安装内容持久保留在环境中',
        }),
      );
    } on ToolCancelled {
      return const ToolOutcome.cancelled('安装已取消，已安装内容保留');
    } on WorkspaceFailure catch (error) {
      return ToolOutcome.failure(error.userMessage, errorCode: error.code);
    }
  }
}
