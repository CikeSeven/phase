import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../data/models/tool_call_record.dart';
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
  ExecutionChannel? _activeChannel;

  Future<void> _operate(
    ExecutionChannel channel,
    Future<void> Function() action,
  ) async {
    if (_activeChannel != null ||
        ref.read(commandChannelsControllerProvider).value?.busy == true) {
      return;
    }
    setState(() => _activeChannel = channel);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _activeChannel = null);
    }
  }

  Future<void> _perform(
    ExecutionChannel channel,
    CommandChannelAction action,
  ) async {
    final status = ref
        .read(commandChannelsControllerProvider)
        .value
        ?.statuses
        .where((status) => status.channel == channel.name)
        .firstOrNull;
    if (!commandChannelActions(channel, status?.state).contains(action)) return;
    final controller = ref.read(commandChannelsControllerProvider.notifier);
    await _operate(channel, () async {
      switch (action) {
        case CommandChannelAction.open:
          await controller.open(channel.name);
        case CommandChannelAction.authorize:
          await controller.authorize(channel.name);
        case CommandChannelAction.initialize:
          await controller.initialize(channel.name);
        case CommandChannelAction.copySetup:
          await _copyTermuxSetup();
        case CommandChannelAction.retry:
          await controller.refresh();
      }
    });
  }

  Future<void> _copyTermuxSetup() async {
    var message = '已复制，请在 Termux 中执行';
    try {
      await Clipboard.setData(const ClipboardData(text: _termuxSetup));
    } on PlatformException {
      message = '复制外部调用设置失败，请重试';
    } on MissingPluginException {
      message = '此设备不支持复制外部调用设置';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(commandChannelsControllerProvider);
    return value.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error is Failure ? error.userMessage : '命令通道状态读取失败'),
          TextButton(
            onPressed: () => ref.invalidate(commandChannelsControllerProvider),
            child: const Text('重试'),
          ),
        ],
      ),
      data: (state) {
        final controller = ref.read(commandChannelsControllerProvider.notifier);
        final locked = state.busy || _activeChannel != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.m,
          children: [
            for (final channel in [
              ExecutionChannel.shizuku,
              ExecutionChannel.termux,
            ])
              CommandChannelCard(
                key: ValueKey(channel),
                channel: channel,
                enabled:
                    channel == ExecutionChannel.shizuku &&
                    state.settings.shizuku,
                locked: locked,
                loading:
                    _activeChannel == channel ||
                    state.busy && _activeChannel == null,
                status: state.statuses
                    .where((status) => status.channel == channel.name)
                    .firstOrNull,
                onEnabled: channel == ExecutionChannel.shizuku
                    ? (value) => _operate(
                        channel,
                        () => controller.setShizukuEnabled(value),
                      )
                    : null,
                onAction: (action) => _perform(channel, action),
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

const _termuxSetup =
    "mkdir -p ~/.termux; touch ~/.termux/termux.properties; sed -i '/^[[:space:]#]*allow-external-apps[[:space:]]*=/d' ~/.termux/termux.properties; printf '\\nallow-external-apps=true\\n' >> ~/.termux/termux.properties; termux-reload-settings";
