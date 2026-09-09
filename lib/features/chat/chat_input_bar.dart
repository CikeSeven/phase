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

/// 文本与动作分层的输入栏；由页面 Scaffold 处理键盘位移。
class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({super.key});

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _controller = TextEditingController();
  bool _canSend = false;
  bool _submitting = false;
  String? _pendingText;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onDraftChanged);
  }

  void _onDraftChanged() {
    final canSend = _controller.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating = ref.watch(
      chatControllerProvider.select((state) => state.isGenerating),
    );
    ref.listen(chatControllerProvider.select((state) => state.isGenerating), (
      _,
      generating,
    ) {
      if (!generating || _pendingText == null) return;
      // 生成状态意味着 controller 已接收并落库，之前的草稿不能提前清掉。
      if (_controller.text == _pendingText) _controller.clear();
      _pendingText = null;
    });
    final selection = ref.watch(modelSelectionProvider);
    final theme = Theme.of(context);
    final needsConfiguration =
        selection.hasError || (!selection.isLoading && selection.value == null);
    final field = TextField(
      key: const ValueKey('chat-message-input'),
      controller: _controller,
      minLines: 1,
      maxLines: 5,
      textInputAction: TextInputAction.newline,
      style: theme.textTheme.bodyLarge,
      decoration: const InputDecoration(
        hintText: '输入消息…',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.m,
        ),
      ),
    );
    final actions = Row(
      children: [
        if (needsConfiguration)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/settings/providers'),
                icon: Icon(
                  selection.hasError ? Symbols.error : Symbols.tune,
                  size: 18,
                ),
                label: Text(
                  selection.hasError ? '检查配置' : '配置模型',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: AppSpacing.s),
        IconButton.filled(
          icon: Icon(isGenerating ? Symbols.stop : Symbols.arrow_upward),
          tooltip: isGenerating ? '停止生成' : '发送',
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.mediumAll,
            ),
          ),
          onPressed: isGenerating
              ? () => ref.read(chatControllerProvider.notifier).stop()
              : _canSend && !_submitting
              ? _send
              : null,
        ),
      ],
    );

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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            0,
            AppSpacing.m,
            AppSpacing.s,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              final actionHeight = needsConfiguration
                  ? (scaler.scale(14) * 1.25 + AppSpacing.xl).clamp(
                      48.0,
                      double.infinity,
                    )
                  : 48.0;
              final minimumHeight =
                  scaler.scale(16) * 1.5 + AppSpacing.xl + actionHeight;
              return SingleChildScrollView(
                primary: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight.clamp(
                      minimumHeight,
                      double.infinity,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: field),
                      actions,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (_submitting ||
        text.trim().isEmpty ||
        ref.read(chatControllerProvider).isGenerating) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final selection = await ref.read(modelSelectionProvider.future);
      if (!mounted) return;
      if (selection == null) {
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
        return;
      }
      if (ref.read(chatControllerProvider).isGenerating) return;
      _pendingText = text;
      await ref.read(chatControllerProvider.notifier).send(text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                error is Failure ? error.userMessage : '发送失败，请稍后重试',
              ),
            ),
          );
      }
    } finally {
      _pendingText = null;
      if (mounted) setState(() => _submitting = false);
    }
  }
}
