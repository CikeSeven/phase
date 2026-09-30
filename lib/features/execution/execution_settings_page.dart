import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snack_bar.dart';
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
          buildAppSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(executionSetupControllerProvider);
    final controller = ref.read(executionSetupControllerProvider.notifier);
    return PopScope(
      canPop: !_busy,
      child: AppScaffold(
        title: '执行与权限',
        body: data.when(
          loading: () => const Center(child: AppLoadingIndicator()),
          error: (error, _) => Center(
            child: _LoadError(
              error: error,
              fallback: '读取执行设置失败',
              onRetry: controller.load,
            ),
          ),
          data: (value) => ListView(
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
              const SizedBox(height: AppSpacing.s),
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
            ],
          ),
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
    return AppListTile(
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
