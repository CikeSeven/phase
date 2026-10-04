import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import 'command_channel_card.dart';
import 'command_channels_controller.dart';

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
    return value.when(
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
              enabled: state.settings.shizuku,
              locked: locked,
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
  }
}
