import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/reasoning_effort.dart';
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
  double _composerExtent = 0;

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
    final titleStyle = theme.textTheme.titleMedium;
    final modelStyle = theme.textTheme.bodyMedium;
    final toolbarHeight = math.max(
      64.0,
      // 结尾只加标题列自身之外的垂直余量（padding xs*2）。
      scaler.scale(titleStyle?.fontSize ?? 16) * (titleStyle?.height ?? 1.4) +
          scaler.scale(modelStyle?.fontSize ?? 14) *
              (modelStyle?.height ?? 1.45) +
          AppSpacing.s,
    );
    final modelLabel = selection.hasError
        ? '模型加载失败'
        : selection.when(
            data: (value) => value?.model ?? '未配置模型',
            loading: () => '正在读取模型…',
            error: (_, _) => '模型加载失败',
          );
    final current = selection.value;

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
            // 模型名用满标题槽：两侧留白收窄，长 id 在真实边界截断。
            titleSpacing: 0,
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
                          Row(children: [Text('相月', style: titleStyle)]),
                          const SizedBox(height: AppSpacing.xs),
                          // 行占满可用宽度：长模型名在真实边界截断；Flexible
                          // 松散适配让短名称的下拉箭头仍然紧贴文字。
                          Row(
                            children: [
                              Flexible(
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
                              // 推理开启时跟在模型名右侧，关闭或不支持不显示。
                              if (current?.supportsReasoning == true &&
                                  current!.effort != ReasoningEffort.off) ...[
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  current.effort.label,
                                  key: const ValueKey('chat-reasoning-effort'),
                                  maxLines: 1,
                                  style: modelStyle?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
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
                // 消息区占满全高，输入栏悬浮其上；内容按实测输入栏高度留白，
                // 可以滚到磨砂底后面透出。
                return Stack(
                  children: [
                    Positioned.fill(
                      child: conversationId == null
                          ? ChatEmptyState(bottomPadding: _composerExtent)
                          : _ConversationMessages(
                              key: ValueKey(conversationId),
                              conversationId: conversationId,
                              bottomPadding: _composerExtent,
                            ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 840,
                            maxHeight: composerHeight,
                          ),
                          child: _ReportSize(
                            onChanged: (height) {
                              if (mounted && _composerExtent != height) {
                                setState(() => _composerExtent = height);
                              }
                            },
                            child: const ChatInputBar(),
                          ),
                        ),
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
  const _ConversationMessages({
    required this.conversationId,
    required this.bottomPadding,
    super.key,
  });

  final String conversationId;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thread = ref.watch(conversationThreadProvider(conversationId));
    final state = ref.watch(chatControllerProvider);
    return thread.when(
      data: (value) {
        final messages = value == null
            ? const <ChatMessage>[]
            : visibleMessages(value, state);
        if (messages.isEmpty) {
          return ChatEmptyState(bottomPadding: bottomPadding);
        }
        return ChatTranscript(
          key: ValueKey(conversationId),
          conversationId: conversationId,
          messages: messages,
          attachments: state.attachments,
          bottomPadding: bottomPadding,
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(semanticsLabel: '正在读取会话'),
      ),
      error: (error, _) => AppEmptyState(
        icon: Symbols.error,
        title: '暂时无法读取消息',
        message: error is Failure ? error.userMessage : '加载消息失败，请重试',
        action: FilledButton.tonal(
          onPressed: () =>
              ref.invalidate(conversationThreadProvider(conversationId)),
          child: const Text('重试'),
        ),
      ),
    );
  }
}

/// 把子节点高度变化回传给父级的轻量代理，用于悬浮输入栏的实测高度。
class _ReportSize extends SingleChildRenderObjectWidget {
  const _ReportSize({required this.onChanged, required super.child});

  final ValueChanged<double> onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportSize(onChanged);
}

class _RenderReportSize extends RenderProxyBox {
  _RenderReportSize(this.onChanged);

  final ValueChanged<double> onChanged;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size.height) return;
    _reported = size.height;
    final height = size.height;
    // 布局阶段不能触发 setState，推迟到帧末回调。
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(height));
  }
}
