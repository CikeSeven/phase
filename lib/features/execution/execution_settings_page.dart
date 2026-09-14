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
import '../chat/model_selection.dart';
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

  Future<void> _editApplicationPolicy(
    List<InstalledApplication> applications,
    ExecutionScope draft,
  ) async {
    final policy = await showApplicationPolicySheet(
      context,
      applications: applications,
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
    final selection = ref.watch(modelSelectionProvider).value;
    final endpoint = Uri.tryParse(selection?.profile.baseUrl ?? '');
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error is Failure ? error.userMessage : '读取执行设置失败'),
                TextButton(
                  onPressed: () => controller.load(),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
          data: (value) {
            final draft = _draft ?? value.scope;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                Text(
                  '授权文件或屏幕内容会发送给本次任务所选模型。',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Text('还需在助手的工具范围中启用对应工具；权限本身不会自动开放工具。'),
                Text(
                  selection == null
                      ? '尚未选择模型，请在聊天页选择后发送。'
                      : '当前模型：${selection.model}\n端点：${endpoint?.scheme}://${endpoint?.authority.split('@').last}',
                ),
                const SizedBox(height: AppSpacing.l),
                ListTile(
                  title: const Text('任务通知'),
                  subtitle: Text(
                    value.capabilities?.notificationsAllowed == true
                        ? '已允许'
                        : '未允许，设备任务无法启动',
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
                    value.capabilities?.accessibilityConnected == true
                        ? '已连接'
                        : '未连接，点击前往系统设置',
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
                const SizedBox(height: AppSpacing.l),
                ListTile(
                  title: const Text('截图观察与手势组合'),
                  subtitle: Text(
                    value.capabilities?.actions.contains(
                              ExecutionAction.captureScreen,
                            ) ==
                            true
                        ? '窗口截图可用，需模型支持图片与工具；手势可直接使用屏幕像素，也可按图片宽高换算，不要求先截图。'
                        : '截图需要 Android 14+ 和已连接的无障碍服务；手势与控件操作不依赖截图能力。',
                  ),
                ),
                Text('授权文件与目录', style: Theme.of(context).textTheme.titleMedium),
                const Text('勾选范围仅在保存后用于新任务；选择器授权不等于开放给模型。解除授权立即生效，不删除文件。'),
                Wrap(
                  spacing: AppSpacing.s,
                  children: [
                    for (final directory in [false, true])
                      OutlinedButton.icon(
                        onPressed: _busy
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
                for (final grant in value.grants)
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
                                              .where((uri) => uri != grant.uri)
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
                                final approved = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AppDialog(
                                    title: '解除文件授权？',
                                    content: const Text('后续任务将无法访问，不会删除外部文件。'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('取消'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('解除'),
                                      ),
                                    ],
                                  ),
                                );
                                if (approved == true) {
                                  await controller.release(grant.uri);
                                  if (mounted) {
                                    setState(
                                      () => _draft = ExecutionScope(
                                        appPolicy: draft.appPolicy,
                                        fileUris: draft.fileUris
                                            .where((uri) => uri != grant.uri)
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
                const SizedBox(height: AppSpacing.l),
                Text('应用操作', style: Theme.of(context).textTheme.titleMedium),
                const Text(
                  'AI 获取应用列表和执行动作均受同一名单校验；相月与其他第三方应用使用相同规则，可在名单中允许或禁止。',
                ),
                ListTile(
                  key: const ValueKey('edit-application-policy'),
                  title: const Text('应用名单'),
                  subtitle: Text(
                    draft.appPolicy.mode == AppListMode.blacklist
                        ? '黑名单 · 显式屏蔽 ${draft.appPolicy.blacklist.length} 个 · 放行 ${draft.appPolicy.allowedSystemApps.length} 个系统应用'
                        : '白名单 · 允许 ${draft.appPolicy.whitelist.length} 个应用',
                  ),
                  trailing: const Icon(Symbols.chevron_right),
                  onTap: _busy
                      ? null
                      : () => _editApplicationPolicy(value.applications, draft),
                ),
                const Text('名单收紧会立即限制运行中的任务，新增允许从下一次任务生效。'),
              ],
            );
          },
        ),
      ),
    );
  }
}
