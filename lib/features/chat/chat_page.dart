import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_top_bar.dart';
import 'chat_controller.dart';
import 'chat_empty_state.dart';
import 'chat_input_bar.dart';
import 'chat_transcript.dart';
import 'conversation_drawer.dart';
import 'model_picker_sheet.dart';
import 'model_selection.dart';

/// 聊天页的玻璃顶栏、阅读区、输入栏与会话侧栏。
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _drawerOpen = false;

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _onDrawerChanged(bool isOpen) {
    // 侧栏收起时框架会把焦点按历史恢复到输入框（键盘误弹），开关时都主动释放。
    FocusManager.instance.primaryFocus?.unfocus();
    if (_drawerOpen != isOpen) {
      setState(() => _drawerOpen = isOpen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationId = ref.watch(
      chatControllerProvider.select((state) => state.conversationId),
    );
    final selection = ref.watch(modelSelectionProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final titleStyle = theme.textTheme.titleSmall;
    final modelStyle = theme.textTheme.bodySmall;
    final toolbarHeight = math.max(
      64.0,
      scaler.scale(titleStyle?.fontSize ?? 14) * (titleStyle?.height ?? 1.4) +
          scaler.scale(modelStyle?.fontSize ?? 12) *
              (modelStyle?.height ?? 1.45) +
          AppSpacing.l,
    );
    final modelLabel = selection.hasError
        ? '模型加载失败'
        : selection.when(
            data: (value) => value?.model ?? '未配置模型',
            loading: () => '正在读取模型…',
            error: (_, _) => '模型加载失败',
          );
    final profileLabel = selection.value?.profile.name;

    return PopScope<void>(
      canPop: !_drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _scaffoldKey.currentState?.closeDrawer();
      },
      child: AppBackground(
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: colors.surface.withValues(alpha: 0),
          drawerEnableOpenDragGesture: true,
          drawerEdgeDragWidth: MediaQuery.sizeOf(context).width,
          onDrawerChanged: _onDrawerChanged,
          appBar: AppTopBar(
            toolbarHeight: toolbarHeight,
            automaticallyImplyLeading: false,
            leading: IconButton(
              tooltip: '打开会话列表',
              onPressed: _openDrawer,
              icon: const Icon(Symbols.menu),
            ),
            title: Tooltip(
              message: '选择模型',
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: const ValueKey('chat-model-picker'),
                  borderRadius: AppRadius.smallAll,
                  onTap: () => showModelPickerSheet(context),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text('相月', style: titleStyle),
                              if (profileLabel != null) ...[
                                const SizedBox(width: AppSpacing.s),
                                Expanded(
                                  child: Text(
                                    profileLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: modelStyle?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  modelLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: modelStyle?.copyWith(
                                    color: selection.hasError
                                        ? colors.error
                                        : colors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                Symbols.expand_more,
                                size: 20,
                                color: colors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: '新会话',
                onPressed: () => ref
                    .read(chatControllerProvider.notifier)
                    .startNewConversation(),
                icon: const Icon(Symbols.edit_square),
              ),
            ],
          ),
          drawer: ConversationDrawer(
            width: math.min(MediaQuery.sizeOf(context).width * 0.88, 400),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final composerHeight = math.min(
                  constraints.maxHeight,
                  math.max(
                    scaler.scale(16) * 1.5 +
                        96 +
                        MediaQuery.paddingOf(context).bottom,
                    constraints.maxHeight * 0.5,
                  ),
                );
                return Column(
                  children: [
                    Expanded(
                      child: conversationId == null
                          ? const ChatEmptyState()
                          : _ConversationMessages(
                              key: ValueKey(conversationId),
                              conversationId: conversationId,
                            ),
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 840,
                          maxHeight: composerHeight,
                        ),
                        child: const ChatInputBar(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationMessages extends ConsumerWidget {
  const _ConversationMessages({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(chatMessagesProvider(conversationId))
        .when(
          data: (messages) => messages.isEmpty
              ? const ChatEmptyState()
              : ChatTranscript(
                  key: ValueKey(conversationId),
                  conversationId: conversationId,
                  messages: messages,
                ),
          loading: () => const Center(
            child: CircularProgressIndicator(semanticsLabel: '正在读取会话'),
          ),
          error: (error, _) => AppEmptyState(
            icon: Symbols.error,
            title: '暂时无法读取消息',
            message: error is Failure ? error.userMessage : '加载消息失败，请重试',
            action: FilledButton.tonal(
              onPressed: () =>
                  ref.invalidate(chatMessagesProvider(conversationId)),
              child: const Text('重试'),
            ),
          ),
        );
  }
}
