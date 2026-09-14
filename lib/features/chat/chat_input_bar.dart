import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_control_style.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/frosted_surface.dart';
import '../../../data/models/attachment.dart';
import 'attachment_chips.dart';
import 'attachment_picker.dart';
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
      if (!generating) return;
      // 生成状态意味着 controller 已接收并落库，之前的草稿不能提前清掉。
      if (_pendingText != null && _controller.text == _pendingText) {
        _controller.clear();
      }
      _pendingText = null;
      if (_attachments.isNotEmpty) setState(() => _attachments = const []);
    });
    final selection = ref.watch(modelSelectionProvider);
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
        IconButton(
          key: const ValueKey('chat-attach'),
          tooltip: '附件',
          onPressed: _submitting ? null : _showAttachmentSheet,
          icon: const Icon(Symbols.attach_file),
        ),
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
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(
              Size.square(AppControlStyle.mediumHeight),
            ),
            shape: AppControlStyle.shape(active: isGenerating),
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
          borderColor: _focusNode.hasFocus ? theme.colorScheme.primary : null,
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
                      AppControlStyle.mediumHeight,
                      double.infinity,
                    )
                  : AppControlStyle.mediumHeight;
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
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('attach-camera'),
              leading: const Icon(Symbols.photo_camera),
              title: const Text('拍照'),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              key: const ValueKey('attach-gallery'),
              leading: const Icon(Symbols.photo_library),
              title: const Text('相册'),
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            ListTile(
              key: const ValueKey('attach-file'),
              leading: const Icon(Symbols.description),
              title: const Text('文件'),
              subtitle: const Text('文本类文件，内容随消息发送'),
              onTap: () => Navigator.of(context).pop('file'),
            ),
            const SizedBox(height: AppSpacing.s),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (source != 'file' && !_modelSupportsImages()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('当前模型未标记支持图片输入')));
      return;
    }
    try {
      final picker = await ref.read(attachmentPickerProvider.future);
      if (!mounted) return;
      final picked = switch (source) {
        'camera' => [?await picker.pickCameraImage()],
        'gallery' => await picker.pickImages(),
        _ => await picker.pickFiles(),
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
