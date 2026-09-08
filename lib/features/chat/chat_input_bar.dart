import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/frosted_surface.dart';
import 'chat_controller.dart';
import 'model_selection.dart';

/// 底部输入栏（DESIGN.md §5.3）。
///
/// 结构：附件按钮（占位）+ 多行 TextField（最多 5 行）+ 发送/停止双态按钮。
class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({super.key});

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _controller = TextEditingController();
  bool _canSend = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating = ref.watch(
      chatControllerProvider.select((s) => s.isGenerating),
    );
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.m,
        ),
        child: FrostedSurface(
          borderRadius: AppRadius.fullAll,
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Symbols.add),
                  tooltip: '附件',
                  // TODO(multimodal): 接入图片/文件选择前保持禁用，布局位置保留。
                  onPressed: null,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      hintText: '输入消息…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: AppSpacing.m,
                      ),
                    ),
                    onChanged: (value) {
                      final canSend = value.trim().isNotEmpty;
                      if (canSend != _canSend) {
                        setState(() => _canSend = canSend);
                      }
                    },
                  ),
                ),
                IconButton.filled(
                  icon: Icon(isGenerating ? Symbols.stop : Symbols.send),
                  tooltip: isGenerating ? '停止生成' : '发送',
                  onPressed: isGenerating
                      ? () => ref.read(chatControllerProvider.notifier).stop()
                      : _canSend
                      ? _send
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      return;
    }
    // 配置缺失时先引导，不产生任何消息（ChatController.send 内有同样防御）。
    final selection = await ref.read(modelSelectionProvider.future);
    if (selection == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('请先在设置中配置服务商与模型'),
              action: SnackBarAction(
                label: '去配置',
                onPressed: () => context.push('/settings/providers'),
              ),
            ),
          );
      }
      return;
    }
    _controller.clear();
    setState(() => _canSend = false);
    try {
      await ref.read(chatControllerProvider.notifier).send(text);
    } on Failure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    }
  }
}
