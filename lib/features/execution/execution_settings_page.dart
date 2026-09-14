import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_scaffold.dart';
import 'application_policy_sheet.dart';
import '../../../data/models/application_access_policy.dart';
import '../../../core/widgets/app_dialog.dart';
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
                ListTile(
                  title: const Text('任务通知'),
                  subtitle: Text(
                    value.capabilities.when(
                      loading: () => '读取中…',
                      error: (_, _) => '读取失败',
                      data: (capabilities) =>
                          capabilities.notificationsAllowed ? '已允许' : '未允许',
                    ),
                  ),
                  trailing: const Icon(Symbols.open_in_new),
                  onTap: _busy
                      ? null
                      : () => _action(
                          () => controller.openPermission(
                            PermissionScreen.notifications,
                          ),
                        ),
                ),
                ListTile(
                  title: const Text('无障碍服务'),
                  subtitle: Text(
                    value.capabilities.when(
                      loading: () => '读取中…',
                      error: (_, _) => '读取失败',
                      data: (capabilities) =>
                          capabilities.accessibilityConnected ? '已连接' : '未连接',
                    ),
                  ),
                  trailing: const Icon(Symbols.open_in_new),
                  onTap: _busy
                      ? null
                      : () => _action(
                          () => controller.openPermission(
                            PermissionScreen.accessibility,
                          ),
                        ),
                ),
                ListTile(
                  title: const Text('截图观察'),
                  subtitle: Text(
                    value.capabilities.when(
                      loading: () => '读取中…',
                      error: (_, _) => '读取失败',
                      data: (capabilities) =>
                          capabilities.actions.contains(
                            ExecutionAction.captureScreen,
                          )
                          ? '可用 · 需模型支持图片与工具'
                          : '需要 Android 14+ 和无障碍服务',
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
                Text('授权文件与目录', style: Theme.of(context).textTheme.titleMedium),
                Wrap(
                  spacing: AppSpacing.s,
                  children: [
                    for (final directory in [false, true])
                      OutlinedButton.icon(
                        onPressed: _busy || value.grants.isLoading
                            ? null
                            : () => _action(() async {
                                final grant = await controller.chooseFile(
                                  directory,
                                );
                                if (grant != null && mounted) {
                                  setState(
                                    () => _draft = ExecutionScope(
                                      appPolicy: draft.appPolicy,
                                      fileUris: {
                                        ...draft.fileUris,
                                        grant.uri,
                                      }.toList(),
                                    ),
                                  );
                                }
                              }),
                        icon: Icon(
                          directory ? Symbols.folder_open : Symbols.description,
                        ),
                        label: Text(directory ? '选择目录' : '选择文件'),
                      ),
                  ],
                ),
                value.grants.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.m),
                    child: LinearProgressIndicator(
                      key: ValueKey('file-grants-loading'),
                      semanticsLabel: '读取文件授权',
                    ),
                  ),
                  error: (error, _) => _LoadError(
                    key: const ValueKey('file-grants-error'),
                    error: error,
                    fallback: '读取文件授权失败',
                    onRetry: _busy ? null : controller.loadGrants,
                  ),
                  data: (grants) => grants.isEmpty
                      ? const Text('暂无文件授权')
                      : Column(
                          children: [
                            for (final grant in grants)
                              Row(
                                children: [
                                  Expanded(
                                    child: CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(grant.name),
                                      subtitle: Text(
                                        '${grant.directory ? '目录' : '文件'} · ${grant.writable ? '可写' : '只读'}',
                                      ),
                                      value: draft.fileUris.contains(grant.uri),
                                      onChanged: _busy
                                          ? null
                                          : (checked) => setState(
                                              () => _draft = ExecutionScope(
                                                appPolicy: draft.appPolicy,
                                                fileUris: checked == true
                                                    ? {
                                                        ...draft.fileUris,
                                                        grant.uri,
                                                      }.toList()
                                                    : draft.fileUris
                                                          .where(
                                                            (uri) =>
                                                                uri !=
                                                                grant.uri,
                                                          )
                                                          .toList(),
                                              ),
                                            ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '解除授权',
                                    onPressed: _busy
                                        ? null
                                        : () => _action(() async {
                                            final approved =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (context) =>
                                                      AppDialog(
                                                        title: '解除文件授权？',
                                                        content: const Text(
                                                          '后续任务将无法访问，不会删除外部文件。',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              '取消',
                                                            ),
                                                          ),
                                                          FilledButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              '解除',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                            if (approved == true) {
                                              await controller.release(
                                                grant.uri,
                                              );
                                              if (mounted) {
                                                setState(
                                                  () => _draft = ExecutionScope(
                                                    appPolicy: draft.appPolicy,
                                                    fileUris: draft.fileUris
                                                        .where(
                                                          (uri) =>
                                                              uri != grant.uri,
                                                        )
                                                        .toList(),
                                                  ),
                                                );
                                              }
                                            }
                                          }),
                                    icon: const Icon(Symbols.link_off),
                                  ),
                                ],
                              ),
                          ],
                        ),
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
