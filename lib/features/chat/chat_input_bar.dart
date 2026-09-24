import 'permission_mode_menu.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_control_style.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/attachment.dart';
import 'attachment_chips.dart';
import 'attachment_picker.dart';
import 'attachment_source_sheet.dart';
import 'chat_controller.dart';
import 'chat_input_surface.dart';
import 'chat_send_button.dart';
import 'model_selection.dart';
import 'context/context_usage_indicator.dart';

/// 文本与动作分层的输入栏；由页面 Scaffold 处理键盘位移。
class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({super.key});

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _canSend = false;
  bool _submitting = false;
  String? _pendingText;
  List<Attachment> _attachments = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onDraftChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  void _onDraftChanged() {
    final canSend =
        _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
      if (_pendingText != null && _controller.text == _pendingText) {
        _controller.clear();
      }
      _pendingText = null;
      if (_attachments.isNotEmpty) setState(() => _attachments = const []);
    });
    final savingMode = ref.watch(
      chatControllerProvider.select((s) => s.savingPermissionMode),
    );
    final permissions = ref.watch(conversationPermissionsProvider);
    final modeReady =
        !permissions.isLoading && !permissions.hasError && !savingMode;
    final selection = ref.watch(modelSelectionProvider);
    final conversationId = ref.watch(
      activeConversationProvider.select((s) => s.conversationId),
    );
    final theme = Theme.of(context);
    final needsConfiguration =
        selection.hasError || (!selection.isLoading && selection.value == null);
    final field = TextField(
      key: const ValueKey('chat-message-input'),
      controller: _controller,
      focusNode: _focusNode,
      minLines: 1,
      maxLines: 5,
      textInputAction: TextInputAction.newline,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: '输入消息…',
        // 更透的玻璃上加强提示文字，避免背后内容降低对比度。
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.m,
        ),
      ),
    );
    final attachment = IconButton(
      key: const ValueKey('chat-attach'),
      tooltip: '附件',
      onPressed: _submitting ? null : _showAttachmentSheet,
      icon: const Icon(Symbols.attach_file),
    );
    final mode = needsConfiguration
        ? Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/settings/providers'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
              ),
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
          )
        : PermissionModeMenu(submitting: _submitting);
    final usage = conversationId == null
        ? null
        : ContextUsageIndicator(
            key: ValueKey(conversationId),
            conversationId: conversationId,
          );
    final send = ChatSendButton(
      isGenerating: isGenerating,
      onPressed: isGenerating
          ? () => ref.read(chatControllerProvider.notifier).stop()
          : _canSend && !_submitting && modeReady
          ? _send
          : null,
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
        child: ChatInputSurface(
          focused: _focusNode.hasFocus,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              // 大字窄屏将模式和圆环移到单独一行，不挤压发送与附件触区。
              final stacked =
                  usage != null &&
                  constraints.maxWidth <
                      scaler.scale(14) * 4 + scaler.scale(40) + 160;
              final actions = stacked
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [attachment, const Spacer(), send]),
                        Row(
                          children: [
                            Expanded(child: mode),
                            usage,
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        attachment,
                        Expanded(child: mode),
                        ?usage,
                        const SizedBox(width: AppSpacing.s),
                        send,
                      ],
                    );
              final actionHeight = needsConfiguration
                  ? (scaler.scale(14) * 1.25 + AppSpacing.xl).clamp(
                      AppControlStyle.mediumHeight,
                      double.infinity,
                    )
                  : AppControlStyle.mediumHeight;
              final minimumHeight =
                  scaler.scale(16) * 1.5 +
                  AppSpacing.xl +
                  actionHeight +
                  (stacked ? scaler.scale(40) + AppSpacing.s : 0);
              return SingleChildScrollView(
                // 极短可用高度时优先保留底部操作，输入内容仍可向上滚动。
                reverse: true,
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
                      if (_attachments.isNotEmpty)
                        AttachmentChips(
                          attachments: _attachments,
                          onRemove: (attachment) => setState(() {
                            _attachments = [
                              for (final entry in _attachments)
                                if (entry.id != attachment.id) entry,
                            ];
                            _onDraftChanged();
                          }),
                        ),
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
        (text.trim().isEmpty && _attachments.isEmpty) ||
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
      await ref
          .read(chatControllerProvider.notifier)
          .send(text, attachments: _attachments);
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

  /// 附件来源面板：拍照 / 相册 / 文件。
  Future<void> _showAttachmentSheet() async {
    FocusScope.of(context).unfocus();
    final source = await showAttachmentSourceSheet(context);
    if (source == null || !mounted) return;
    if (source != AttachmentSource.file && !_modelSupportsImages()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('当前模型未标记支持图片输入')));
      return;
    }
    try {
      final picker = await ref.read(attachmentPickerProvider.future);
      if (!mounted) return;
      final picked = switch (source) {
        AttachmentSource.camera => [?await picker.pickCameraImage()],
        AttachmentSource.gallery => await picker.pickImages(),
        AttachmentSource.file => await picker.pickFiles(),
      };
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _attachments = [..._attachments, ...picked];
        _onDraftChanged();
      });
    } on Failure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    }
  }

  bool _modelSupportsImages() {
    return ref.read(modelSelectionProvider).value?.supportsImages ?? true;
  }
}
