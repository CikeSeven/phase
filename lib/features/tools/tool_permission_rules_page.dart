import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/tool_permission.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/tool_source.dart';
import '../../../data/repositories/mcp_server_repository.dart';
import '../execution/shizuku_display_tool.dart';
import 'http_tool.dart';
import 'tool_permission_rules_controller.dart';
import 'tool_presentation.dart';

enum _RuleChoice { modeDefault, allow, ask, deny }

const _builtInTools = [
  'system_info',
  'read_file',
  'list_files',
  'grep',
  'find',
  'write_file',
  'edit_file',
  'shell',
  'install_packages',
  'read_skill',
  'prepare_skill',
  'read_history',
  'read_memory',
  'write_memory',
  'web_search',
  'web_fetch',
  'list_apps',
  'open_app',
  'inspect_ui',
  'capture_screen',
  'click_node',
  'scroll',
  'input_text',
  'perform_gestures',
  'wait_for_user',
  'submit_plan',
];

class ToolPermissionRulesPage extends ConsumerStatefulWidget {
  const ToolPermissionRulesPage({super.key});

  @override
  ConsumerState<ToolPermissionRulesPage> createState() =>
      _ToolPermissionRulesPageState();
}

class _ToolPermissionRulesPageState
    extends ConsumerState<ToolPermissionRulesPage> {
  bool _saving = false;

  Future<void> _save(ToolPermissionRule target, _RuleChoice choice) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final warning = target.sourceKind == ToolSourceKind.mcp
          ? '之后运行中，此版本 MCP 工具的所有参数调用都无需确认。'
          : switch (target.toolName) {
              'shell' => '之后运行中的完整命令无需确认；此规则不限制文件、网络或子进程访问。',
              'install_packages' => '之后运行中的依赖安装无需确认，包括软件包安装脚本。',
              'http_request' =>
                '之后运行中的 ${target.action} 请求无需确认，范围包含所有目标地址与请求内容。',
              _ => null,
            };
      if (choice == _RuleChoice.allow && warning != null) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AppDialog(
            title: '直接允许此工具',
            icon: LucideIcons.shieldAlert,
            description: warning,
            content: const SizedBox.shrink(),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('直接允许'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      await ref.read(toolPermissionRulesControllerProvider.notifier).setRule(
        target,
        switch (choice) {
          _RuleChoice.modeDefault => null,
          _RuleChoice.allow => ToolPolicy.allow,
          _RuleChoice.ask => ToolPolicy.ask,
          _RuleChoice.deny => ToolPolicy.deny,
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          buildAppSnackBar(
            content: Text(error is Failure ? error.userMessage : '工具规则保存失败'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(toolPermissionRulesControllerProvider);
    final servers = ref.watch(mcpServersProvider);
    ToolPermissionRule target(String name, {String? action}) =>
        ToolPermissionRule(
          sourceKind: ToolSourceKind.builtIn,
          sourceId: 'builtIn',
          toolName: name,
          action: action,
          policy: ToolPolicy.ask,
        );
    return PopScope(
      canPop: !_saving,
      child: AppScaffold(
        title: '工具规则',
        body: rules.when(
          loading: () => const Center(child: AppLoadingIndicator()),
          error: (error, _) => AppEmptyState(
            icon: LucideIcons.circleAlert,
            title: '无法读取工具规则',
            message: error is Failure ? error.userMessage : '读取失败，请重试',
            action: FilledButton.tonal(
              onPressed: () =>
                  ref.invalidate(toolPermissionRulesControllerProvider),
              child: const Text('重试'),
            ),
          ),
          data: (value) {
            final targets = <({String label, ToolPermissionRule rule})>[
              for (final name in _builtInTools)
                (label: ToolPresentation.toolLabel(name), rule: target(name)),
              for (final method in HttpRequestTool.methods)
                (
                  label: 'HTTP · $method',
                  rule: target('http_request', action: method),
                ),
              for (final action in ShizukuDisplayTool.actions)
                (
                  label:
                      '虚拟屏 · ${ToolPresentation.actionLabel('shizuku_display', action)}',
                  rule: target('shizuku_display', action: action),
                ),
              for (final entry in servers.value ?? const [])
                for (final tool in entry.tools)
                  (
                    label:
                        '${entry.profile.name} · ${tool.source.originalName}',
                    rule: ToolPermissionRule(
                      sourceKind: ToolSourceKind.mcp,
                      sourceId: entry.profile.id,
                      toolName: tool.source.originalName,
                      definitionRevision: tool.source.definitionRevision,
                      policy: ToolPolicy.ask,
                    ),
                  ),
            ];
            final keys = targets.map((target) => target.rule.key).toSet();
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                for (final target in targets)
                  _row(target.rule, target.label, value),
                if (servers.isLoading) const AppLoadingIndicator(),
                if (servers.hasError)
                  TextButton.icon(
                    onPressed: () => ref.invalidate(mcpServersProvider),
                    icon: const Icon(LucideIcons.refreshCw),
                    label: const Text('重新读取 MCP 工具'),
                  ),
                for (final rule in value)
                  if (!keys.contains(rule.key))
                    _row(
                      rule,
                      '${rule.toolName}${rule.action == null ? '' : ' · ${rule.action}'}（暂不可用）',
                      value,
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(
    ToolPermissionRule target,
    String label,
    List<ToolPermissionRule> rules,
  ) {
    final saved = rules.where((rule) => rule.key == target.key).firstOrNull;
    final stale =
        saved?.policy == ToolPolicy.allow &&
        saved?.definitionRevision != null &&
        saved?.definitionRevision != target.definitionRevision;
    final choice = saved == null || stale
        ? _RuleChoice.modeDefault
        : switch (saved.policy) {
            ToolPolicy.allow => _RuleChoice.allow,
            ToolPolicy.ask => _RuleChoice.ask,
            ToolPolicy.deny => _RuleChoice.deny,
          };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDropdown<_RuleChoice>(
            label: label,
            value: choice,
            options: const {
              _RuleChoice.modeDefault: '跟随模式',
              _RuleChoice.allow: '直接允许',
              _RuleChoice.ask: '每次确认',
              _RuleChoice.deny: '禁止执行',
            },
            onChanged: _saving ? null : (choice) => _save(target, choice),
          ),
          if (stale)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text('工具定义已更新，旧允许规则不再生效'),
            ),
        ],
      ),
    );
  }
}
