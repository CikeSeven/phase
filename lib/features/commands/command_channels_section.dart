import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../data/models/tool_call_record.dart';
import 'command_channels_controller.dart';

class CommandChannelsSection extends ConsumerWidget {
  const CommandChannelsSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final channel in [
              ExecutionChannel.shizuku,
              ExecutionChannel.termux,
            ]) ...[
              const SizedBox(height: 16),
              AppSection(
                title: channel == ExecutionChannel.shizuku
                    ? 'Shizuku'
                    : 'Termux',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用命令与文件传输'),
                      subtitle: Text(
                        state.statuses
                                .where((s) => s.channel == channel.name)
                                .firstOrNull
                                ?.message ??
                            '状态不可用',
                      ),
                      value: state.settings.enabled(channel),
                      onChanged: state.busy
                          ? null
                          : (value) => controller.enable(channel, value),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () => controller.open(channel.name),
                          child: Text(
                            state.statuses
                                        .where((s) => s.channel == channel.name)
                                        .firstOrNull
                                        ?.state ==
                                    'notInstalled'
                                ? '下载'
                                : '打开应用',
                          ),
                        ),
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () => controller.authorize(channel.name),
                          child: const Text('授权'),
                        ),
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () => controller.initialize(channel.name),
                          child: Text(
                            channel == ExecutionChannel.termux ? '初始化' : '连接',
                          ),
                        ),
                        if (channel == ExecutionChannel.termux)
                          TextButton(
                            onPressed: state.busy
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      const ClipboardData(text: _termuxSetup),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('已复制，请在 Termux 中执行'),
                                        ),
                                      );
                                    }
                                  },
                            child: const Text('复制外部调用设置'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: state.busy ? null : controller.refresh,
                child: const Text('刷新状态'),
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
