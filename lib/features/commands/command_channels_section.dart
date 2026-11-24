import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/app_elastic_switch.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/failure.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_icon_badge.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/app_section.dart';
import '../../data/models/tool_call_record.dart';
import 'command_channel_card.dart';
import 'command_channels_controller.dart';
import 'root_command_dialog.dart';
import '../../core/widgets/app_dialog.dart';
import 'root_command_driver.dart';

class CommandChannelsSection extends ConsumerStatefulWidget {
  const CommandChannelsSection({super.key});

  @override
  ConsumerState<CommandChannelsSection> createState() =>
      _CommandChannelsSectionState();
}

class _CommandChannelsSectionState
    extends ConsumerState<CommandChannelsSection> {
  bool _busy = false;

  Future<void> _operate(Future<void> Function() action) async {
    if (_busy ||
        ref.read(commandChannelsControllerProvider).value?.busy == true) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _perform(CommandChannelAction action) async {
    final status = ref
        .read(commandChannelsControllerProvider)
        .value
        ?.statuses
        .where((status) => status.channel == 'shizuku')
        .firstOrNull;
    if (!commandChannelActions(status?.state).contains(action)) return;
    final controller = ref.read(commandChannelsControllerProvider.notifier);
    await _operate(() async {
      switch (action) {
        case CommandChannelAction.open:
          await controller.open('shizuku');
        case CommandChannelAction.authorize:
          await controller.authorize('shizuku');
        case CommandChannelAction.initialize:
          await controller.initialize('shizuku');
        case CommandChannelAction.retry:
          await controller.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(commandChannelsControllerProvider);
    final shizuku = value.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error is Failure ? error.userMessage : '系统能力状态读取失败'),
          TextButton(
            onPressed: () => ref.invalidate(commandChannelsControllerProvider),
            child: const Text('重试'),
          ),
        ],
      ),
      data: (state) {
        final controller = ref.read(commandChannelsControllerProvider.notifier);
        final locked = state.busy || _busy;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.m,
          children: [
            CommandChannelCard(
              enabled: state.settings.enabled(ExecutionChannel.shizuku),
              locked: locked || state.settings.root,
              loading: _busy || state.busy,
              status: state.statuses
                  .where((status) => status.channel == 'shizuku')
                  .firstOrNull,
              onEnabled: (value) =>
                  _operate(() => controller.setShizukuEnabled(value)),
              onAction: _perform,
            ),
            if (state.error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  state.error!,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        );
      },
    );
    final state = value.value;
    return AppSection(
      title: 'Android 执行方式',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.m,
        children: [
          shizuku,
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: AppRadius.mediumAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppElasticSwitchTile(
                    secondary: const AppIconBadge(
                      icon: LucideIcons.terminal,
                      size: 40,
                      iconSize: 22,
                    ),
                    title: const Text('Root 模式'),
                    subtitle: const Text('通过 Root 运行 Android 命令和虚拟屏'),
                    value: state?.settings.root ?? false,
                    onChanged: state == null || state.busy || _busy
                        ? null
                        : (enabled) => _operate(
                            () => ref
                                .read(
                                  commandChannelsControllerProvider.notifier,
                                )
                                .setRootEnabled(enabled),
                          ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.m,
                      ),
                      child: TextButton(
                        onPressed: _busy || state?.busy == true
                            ? null
                            : () => showAppDialog<void>(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const RootCommandDialog(
                                  driver: RootCommandDriver(),
                                ),
                              ),
                        child: const Text('手动命令'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
