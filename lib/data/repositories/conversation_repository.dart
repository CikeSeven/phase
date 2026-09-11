import 'package:drift/drift.dart' hide Column;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../../core/utils/logger.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/attachment_storage.dart';
import '../models/chat_attachment.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

part 'conversation_repository.g.dart';

/// 会话与消息的仓库：对上层屏蔽 drift，异常统一转 [Failure]。
class ConversationRepository {
  ConversationRepository(this._db, {this.attachments});

  final AppDatabase _db;

  /// 删除会话时清理附件文件；测试可为 null（不清理）。
  final AttachmentStorage? attachments;

  Stream<List<Conversation>> watchConversations() {
    return _db.watchConversationRows().map(
      (rows) => rows.map(_toConversation).toList(),
    );
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _db
        .watchMessageRows(conversationId)
        .map((rows) => rows.map(_toChatMessage).toList());
  }

  /// 一次性读取某会话的全部消息（构造请求上下文用）。
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    try {
      final rows = await _db.getMessageRows(conversationId);
      return rows.map(_toChatMessage).toList();
    } on Exception catch (e, st) {
      AppLogger.error('读取消息失败', e, st);
      throw UnknownFailure('读取消息失败', cause: e);
    }
  }

  Future<Conversation> createConversation({String title = '新会话'}) async {
    try {
      final now = DateTime.now();
      final companion = ConversationsCompanion.insert(
        id: generateId(),
        title: title,
        createdAt: now,
        updatedAt: now,
      );
      await _db.insertConversation(companion);
      return Conversation(
        id: companion.id.value,
        title: title,
        pinned: false,
        createdAt: now,
        updatedAt: now,
      );
    } on Exception catch (e, st) {
      AppLogger.error('创建会话失败', e, st);
      throw UnknownFailure('创建会话失败', cause: e);
    }
  }

  Future<void> renameConversation(String id, String title) async {
    try {
      await _db.updateConversationFields(
        id,
        ConversationsCompanion(
          title: Value(title),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } on Exception catch (e, st) {
      AppLogger.error('重命名会话失败', e, st);
      throw UnknownFailure('重命名会话失败', cause: e);
    }
  }

  Future<void> setPinned(String id, {required bool pinned}) async {
    try {
      await _db.updateConversationFields(
        id,
        ConversationsCompanion(pinned: Value(pinned)),
      );
    } on Exception catch (e, st) {
      AppLogger.error('更新置顶状态失败', e, st);
      throw UnknownFailure('更新置顶状态失败', cause: e);
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      // 先收集附件路径，库删除成功后再尽力清理文件。
      final attachmentPaths = [
        for (final message in await getMessages(id))
          ...message.attachments.map((attachment) => attachment.path),
      ];
      await _db.deleteConversationCascade(id);
      await attachments?.deletePaths(attachmentPaths);
    } on Exception catch (e, st) {
      AppLogger.error('删除会话失败', e, st);
      throw UnknownFailure('删除会话失败', cause: e);
    }
  }

  /// 追加一条消息并刷新会话的 updatedAt。
  Future<ChatMessage> appendMessage({
    required String conversationId,
    required ChatRole role,
    required String content,
    ChatMessageStatus status = ChatMessageStatus.done,
    String? modelName,
    List<ChatAttachment> attachments = const [],
  }) async {
    try {
      final now = DateTime.now();
      final companion = MessagesCompanion.insert(
        id: generateId(),
        conversationId: conversationId,
        role: role,
        content: content,
        status: status,
        modelName: Value(modelName),
        attachmentsJson: Value(encodeChatAttachments(attachments)),
        createdAt: now,
      );
      await _db.insertMessage(companion);
      await _db.updateConversationFields(
        conversationId,
        ConversationsCompanion(updatedAt: Value(now)),
      );
      return ChatMessage(
        id: companion.id.value,
        role: role,
        content: content,
        status: status,
        modelName: modelName,
        attachments: attachments,
        createdAt: now,
      );
    } on Exception catch (e, st) {
      AppLogger.error('追加消息失败', e, st);
      throw UnknownFailure('追加消息失败', cause: e);
    }
  }

  /// 流式输出时增量更新内容与思考，结束时更新状态；thinkingDuration 仅在有值时写入。
  Future<void> updateMessageContent(
    String id, {
    required String content,
    required String? reasoning,
    required ChatMessageStatus status,
    Duration? thinkingDuration,
  }) async {
    try {
      await _db.updateMessageContent(
        id,
        content: content,
        reasoning: reasoning,
        status: status,
        thinkingDuration: thinkingDuration,
      );
    } on Exception catch (e, st) {
      AppLogger.error('更新消息失败', e, st);
      throw UnknownFailure('更新消息失败', cause: e);
    }
  }

  Conversation _toConversation(ConversationRow row) {
    return Conversation(
      id: row.id,
      title: row.title,
      pinned: row.pinned,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ChatMessage _toChatMessage(MessageRow row) {
    return ChatMessage(
      id: row.id,
      role: row.role,
      content: row.content,
      status: row.status,
      modelName: row.modelName,
      reasoning: row.reasoning,
      attachments: decodeChatAttachments(row.attachmentsJson),
      thinkingDuration: row.thinkingDurationMs == null
          ? null
          : Duration(milliseconds: row.thinkingDurationMs!),
      createdAt: row.createdAt,
    );
  }
}

@Riverpod(keepAlive: true)
ConversationRepository conversationRepository(Ref ref) {
  return ConversationRepository(
    ref.watch(appDatabaseProvider),
    attachments: ref.watch(attachmentStorageProvider).value,
  );
}
