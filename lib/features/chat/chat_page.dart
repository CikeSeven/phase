import 'package:go_router/go_router.dart';

import 'dart:async';
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
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/reasoning_effort.dart';
import '../assistants/assistant_picker_sheet.dart';
import 'chat_controller.dart';
import 'chat_empty_state.dart';
import 'chat_input_bar.dart';
import 'chat_run_banner.dart';
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
  /// 顶栏默认高度；两行紧凑排布的最小行高。
  static const _defaultToolbarHeight = 64.0;
  static const _compactRowHeight = 24.0;

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
      activeConversationProvider.select((active) => active.conversationId),
    );
    final workspaceId = conversationId == null
        ? null
        : ref
              .watch(conversationThreadProvider(conversationId))
              .value
              ?.conversation
              .workspaceId;
    final selection = ref.watch(modelSelectionProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final titleStyle = theme.textTheme.titleMedium;
    final modelStyle = theme.textTheme.labelMedium;
    // 顶栏保持默认高度：两行紧凑排布，只有大字号时按文字实际高度略微增高。
    final contentHeight =
        scaler.scale(titleStyle?.fontSize ?? 16) * (titleStyle?.height ?? 1.4) +
        scaler.scale(modelStyle?.fontSize ?? 12) *
            (modelStyle?.height ?? 1.45) +
        AppSpacing.xs * 2;
    final toolbarHeight = math.max(_defaultToolbarHeight, contentHeight);
    // 已经有值就不再退回加载态：重新解析期间标题不闪。
    final modelLabel = selection.hasError
        ? '模型加载失败'
        : selection.value?.model ?? (selection.isLoading ? '正在读取模型…' : '未配置模型');
    final current = selection.value;
    final assistantName =
        ref
            .watch(
              currentAssistantProvider(ref.watch(activeConversationProvider)),
            )
            ?.name ??
        '相月';

    return PopScope<void>(
      canPop: !_drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_drawerOpen) return;
        // 根页面的返回拦截仍按本地历史逐层关闭菜单、侧栏。
        if (ModalRoute.of(context)?.willHandlePopInternally ?? false) {
          Navigator.of(context).pop();
        } else {
          _scaffoldKey.currentState?.closeDrawer();
        }
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
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 助手名一行：点击切换助手。
                Tooltip(
                  message: '切换助手',
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      key: const ValueKey('chat-assistant-picker'),
                      borderRadius: AppRadius.smallAll,
                      onTap: () => showAssistantPickerSheet(context),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: _compactRowHeight,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                assistantName,
                                key: const ValueKey('chat-assistant-name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Icon(
                              Symbols.expand_more,
                              size: 18,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 模型一行：点击选择模型。
                Tooltip(
                  message: '选择模型',
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      key: const ValueKey('chat-model-picker'),
                      borderRadius: AppRadius.smallAll,
                      onTap: () => showModelPickerSheet(context),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: _compactRowHeight,
                        ),
                        child: Row(
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
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (conversationId != null)
                IconButton(
                  tooltip: '计划与上下文',
                  icon: const Icon(Symbols.account_tree),
                  onPressed: () =>
                      context.push('/conversations/$conversationId/context'),
                ),

              if (workspaceId != null)
                IconButton(
                  tooltip: '会话工作区',
                  icon: const Icon(Symbols.folder_open),
                  onPressed: () =>
                      context.push('/settings/workspaces/$workspaceId'),
                ),
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
            child: Column(
              children: [
                const ChatRunBanner(),
                Expanded(
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
              ],
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

  /// 重新生成最后一条回答；失败按统一文案提示，不改动已有回答。
  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(chatControllerProvider.notifier).regenerate();
    } on Failure catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

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
          isGenerating: state.isGenerating,
          onRegenerate: () => _regenerate(context, ref),
          bottomPadding: bottomPadding,
        );
      },
      loading: () =>
          const Center(child: AppLoadingIndicator(semanticsLabel: '正在读取会话')),
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
