import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/conversation.dart';
import '../../data/repositories/conversation_repository.dart';
part 'conversation_providers.g.dart';

/// 会话列表流（置顶优先、按更新时间倒序）。
@riverpod
Stream<List<Conversation>> conversations(Ref ref) async* {
  final repository = await ref.watch(conversationRepositoryProvider.future);
  yield* repository.watchConversations();
}

/// 某会话的当前分支视图。
@riverpod
Stream<ConversationThread?> conversationThread(
  Ref ref,
  String conversationId,
) async* {
  final repository = await ref.watch(conversationRepositoryProvider.future);
  yield* repository.watchThread(conversationId);
}
