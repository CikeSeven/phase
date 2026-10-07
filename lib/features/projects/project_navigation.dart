import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/failure.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../chat/chat_controller.dart';

/// 会话 ID 更新会替换路由，实际离开页面后仍需恢复上一页选择。
class ProjectChatNavigation {
  final _closed = Completer<void>();
  Future<void> get closed => _closed.future;

  void finish() {
    if (!_closed.isCompleted) _closed.complete();
  }

  void fail(Object error, StackTrace stack) {
    if (!_closed.isCompleted) _closed.completeError(error, stack);
  }
}

Future<void> openProjectPage(
  BuildContext context,
  WidgetRef ref,
  String projectId,
) async {
  final previous = ref.read(activeConversationProvider);
  await context.push<void>('/projects/$projectId');
  if (!context.mounted) return;
  await _restoreChat(context, ref, previous);
}

Future<void> openProjectConversation(
  BuildContext context,
  WidgetRef ref,
  String projectId, {
  String? conversationId,
}) async {
  final previous = ref.read(activeConversationProvider);
  final navigation = ProjectChatNavigation();
  unawaited(
    context
        .push<void>(
          '/projects/$projectId/conversations/${conversationId ?? 'new'}',
          extra: navigation,
        )
        .then<void>((_) => navigation.finish(), onError: navigation.fail),
  );
  await navigation.closed;
  if (!context.mounted) return;
  await _restoreChat(context, ref, previous);
}

Future<void> _restoreChat(
  BuildContext context,
  WidgetRef ref,
  ActiveConversationState previous,
) async {
  if (ModalRoute.of(context)?.isCurrent != true) return;
  // 显式从侧栏选择普通聊天已完成导航，不覆盖用户的这次选择。
  if (ref.read(activeConversationProvider).projectId == null) return;
  try {
    await ref
        .read(chatControllerProvider.notifier)
        .restoreConversation(previous);
  } catch (error) {
    if (!context.mounted) return;
    ref
        .read(chatControllerProvider.notifier)
        .startNewConversation(projectId: previous.projectId);
    ScaffoldMessenger.of(context).showSnackBar(
      buildAppSnackBar(
        content: Text(error is Failure ? error.userMessage : '恢复会话失败，请重试'),
      ),
    );
  }
}
