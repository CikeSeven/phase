import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import 'application_policy_sheet.dart';
import '../../../data/models/application_access_policy.dart';
import '../../../data/models/execution_scope.dart';
import 'execution_api.g.dart';
import 'execution_setup_controller.dart';

class ExecutionSettingsPage extends ConsumerStatefulWidget {
  const ExecutionSettingsPage({super.key});
  @override
  ConsumerState<ExecutionSettingsPage> createState() =>
      _ExecutionSettingsPageState();
}

class _ExecutionSettingsPageState extends ConsumerState<ExecutionSettingsPage>
    with WidgetsBindingObserver {
  ExecutionScope? _draft;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) {
        unawaited(ref.read(executionSetupControllerProvider.notifier).load());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) {
      unawaited(ref.read(executionSetupControllerProvider.notifier).load());
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is Failure ? error.userMessage : '执行设置操作失败，请重试',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editApplicationPolicy(ExecutionScope draft) async {
    final policy = await showApplicationPolicySheet(
      context,
      loadApplications: ref
          .read(executionSetupControllerProvider.notifier)
          .loadApplications,
      initialPolicy: draft.appPolicy,
      openPermissionSettings: () => ref
          .read(executionSetupControllerProvider.notifier)
          .openPermission(PermissionScreen.applications),
    );
    if (mounted && policy != null) {
      setState(
        () => _draft = ExecutionScope(
          appPolicy: policy,
          fileUris: draft.fileUris,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(executionSetupControllerProvider);
    final controller = ref.read(executionSetupControllerProvider.notifier);
    return PopScope(
      canPop: !_busy,
      child: AppScaffold(
        title: '执行与权限',
        bottomBar: FilledButton(
          key: const ValueKey('save-execution-scope'),
          onPressed: _busy || data.value == null
              ? null
              : () => _action(() async {
                  await controller.save(_draft ?? data.value!.scope);
                  if (context.mounted) Navigator.pop(context);
                }),
          child: const Text('保存执行设置'),
        ),
        body: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: _LoadError(
              error: error,
              fallback: '读取执行设置失败',
              onRetry: controller.load,
            ),
          ),
          data: (value) {
            final draft = _draft ?? value.scope;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                _PermissionTile(
                  title: '任务通知',
                  statusKey: const ValueKey('notifications-permission-status'),
                  granted: value.capabilities.whenData(
                    (capabilities) => capabilities.notificationsAllowed,
                  ),
                  onTap: _busy
                      ? null
                      : () => _action(
                          () => controller.openPermission(
                            PermissionScreen.notifications,
                          ),
                        ),
                ),
                _PermissionTile(
                  title: '无障碍服务',
                  statusKey: const ValueKey('accessibility-permission-status'),
                  granted: value.capabilities.whenData(
                    (capabilities) => capabilities.accessibilityConnected,
                  ),
                  onTap: _busy
                      ? null
                      : () => _action(
                          () => controller.openPermission(
                            PermissionScreen.accessibility,
                          ),
                        ),
                ),
                if (value.capabilities.error case final error?)
                  _LoadError(
                    key: const ValueKey('capabilities-error'),
                    error: error,
                    fallback: '读取权限状态失败',
                    onRetry: _busy ? null : controller.loadCapabilities,
                  ),
                const SizedBox(height: AppSpacing.l),
                ListTile(
                  key: const ValueKey('edit-application-policy'),
                  title: const Text('应用名单'),
                  subtitle: Text(
                    draft.appPolicy.mode == AppListMode.blacklist
                        ? '黑名单 · 屏蔽 ${draft.appPolicy.blacklist.length} 个 · 放行 ${draft.appPolicy.allowedSystemApps.length} 个系统应用'
                        : '白名单 · 允许 ${draft.appPolicy.whitelist.length} 个应用',
                  ),
                  trailing: const Icon(Symbols.chevron_right),
                  onTap: _busy
                      ? null
                      : () => _action(() => _editApplicationPolicy(draft)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.statusKey,
    required this.granted,
    required this.onTap,
  });

  final String title;
  final Key statusKey;
  final AsyncValue<bool> granted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = context.brandColors;
    final (label, icon, background, foreground) = granted.when(
      loading: () => (
        '读取中…',
        Symbols.hourglass_empty,
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
      error: (_, _) => (
        '读取失败',
        Symbols.error,
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      data: (allowed) => allowed
          ? (
              '已授权',
              Symbols.check_circle,
              brand.tealContainer,
              brand.onTealContainer,
            )
          : (
              '未授权',
              Symbols.error,
              colors.errorContainer,
              colors.onErrorContainer,
            ),
    );
    return ListTile(
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            key: statusKey,
            liveRegion: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: AppRadius.smallAll,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Icon(icon, size: 20, color: foreground, fill: 1),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      trailing: const Icon(Symbols.open_in_new),
      onTap: onTap,
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.error,
    required this.fallback,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final String fallback;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(error is Failure ? (error as Failure).userMessage : fallback),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}
