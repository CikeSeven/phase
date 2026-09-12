import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../../core/utils/logger.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/attachment_storage.dart';
import '../models/attachment.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/message_part.dart';
import 'row_mappers.dart';

part 'conversation_repository.g.dart';

/// 一个会话的当前分支视图：完整消息树 + 当前分支 + 分支末尾指针。
class ConversationThread {
  const ConversationThread({
    required this.conversation,
    required this.messages,
    required this.branch,
    this.currentMessageId,
  });

  final Conversation conversation;

  /// 会话内全部消息（含其他分支），按创建时间排序。
  final List<ChatMessage> messages;

  /// 沿 [currentMessageId] 的父链取出的当前分支，按时间正序。
  final List<ChatMessage> branch;

  final String? currentMessageId;

  /// 当前分支末尾的消息；空会话为 null。
  ChatMessage? get lastMessage => branch.isEmpty ? null : branch.last;
}

/// 会话、消息与附件的读写；事务边界按 design 第五部分 §3.3。
class ConversationRepository {
  ConversationRepository(this._db, {this.attachments});

  final AppDatabase _db;

  /// 删除会话时清理附件文件；测试可注入 null（不清理文件）。
  final AttachmentStorage? attachments;

  // --- 会话 ---

  Stream<List<Conversation>> watchConversations() {
    final query = _db.select(_db.conversations)
      ..orderBy([
        (t) => OrderingTerm.desc(t.pinned),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    return query.watch().map((rows) => rows.map(conversationFromRow).toList());
  }

  /// 会话内容；会话不存在时为 null，供界面区分"空会话"与"已删除"。
  Stream<ConversationThread?> watchThread(String conversationId) {
    return _threadQuery(conversationId).watch().map(_threadFromRows);
  }

  /// 发送前读取最新分支，不依赖界面订阅是否已收到更新。
  Future<ConversationThread?> getThread(String conversationId) {
    return _guard('读取会话失败', () async {
      return _threadFromRows(await _threadQuery(conversationId).get());
    });
  }

  Future<Conversation> createConversation({
    String title = '新会话',
    String? assistantId,
  }) async {
    return _guard('创建会话失败', () async {
      final now = DateTime.now();
      final conversation = Conversation(
        id: generateId(),
        title: title,
        assistantId: assistantId,
        createdAt: now,
        updatedAt: now,
      );
      await _db
          .into(_db.conversations)
          .insert(conversationCompanion(conversation));
      return conversation;
    });
  }

  Future<void> updateConversation(Conversation conversation) {
    return _guard('更新会话失败', () async {
      await (_db.update(
        _db.conversations,
      )..where((t) => t.id.equals(conversation.id))).write(
        conversationCompanion(conversation.copyWith(updatedAt: DateTime.now())),
      );
    });
  }

  Future<void> renameConversation(String id, String title) {
    return _guard('重命名会话失败', () async {
      await (_db.update(
        _db.conversations,
      )..where((t) => t.id.equals(id))).write(
        ConversationsCompanion(
          title: Value(title),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> setPinned(String id, {required bool pinned}) {
    return _guard('更新置顶状态失败', () async {
      await (_db.update(_db.conversations)..where((t) => t.id.equals(id)))
          .write(ConversationsCompanion(pinned: Value(pinned)));
    });
  }

  /// 删除会话：消息、附件记录、运行与工具记录由外键级联删除，
  /// 附件文件在库删除成功后尽力清理。
  Future<void> deleteConversation(String id) {
    return _guard('删除会话失败', () async {
      final rows = await (_db.select(
        _db.attachments,
      )..where((t) => t.conversationId.equals(id))).get();
      await (_db.delete(_db.conversations)..where((t) => t.id.equals(id))).go();
      await attachments?.deletePaths(rows.map((row) => row.localPath));
    });
  }

  // --- 消息 ---

  /// 写入一条消息并更新会话当前位置（发送、回答落库共用）。
  ///
  /// 同一事务内完成消息写入、会话 currentMessageId 与 updatedAt。
  Future<ChatMessage> appendMessage(
    ChatMessage message, {
    bool updateTitle = false,
  }) {
    return _guard('写入消息失败', () async {
      await _db.transaction(() async {
        await _db.into(_db.messages).insert(messageCompanion(message));
        await (_db.update(
          _db.conversations,
        )..where((t) => t.id.equals(message.conversationId))).write(
          ConversationsCompanion(
            currentMessageId: Value(message.id),
            updatedAt: Value(message.createdAt),
            title: updateTitle
                ? Value(_titleFromMessage(message))
                : const Value.absent(),
          ),
        );
      });
      return message;
    });
  }

  /// 落库助手消息的最终内容（流式结束后调用一次）。
  Future<void> updateMessage({
    required String messageId,
    required List<MessagePart> parts,
    required MessageStatus status,
    TokenUsage? usage,
    int? thinkingDurationMs,
  }) {
    return _guard('更新消息失败', () async {
      await (_db.update(
        _db.messages,
      )..where((t) => t.id.equals(messageId))).write(
        MessagesCompanion(
          partsJson: Value(encodeMessageParts(parts)),
          status: Value(status),
          usageJson: Value(usage == null ? null : encodeUsageJson(usage)),
          thinkingDurationMs: Value(thinkingDurationMs),
        ),
      );
    });
  }

  /// 把当前分支指针移到指定消息（分支切换与重新生成的落点）。
  Future<void> setCurrentMessage(String conversationId, String messageId) {
    return _guard('切换分支失败', () async {
      await (_db.update(
        _db.conversations,
      )..where((t) => t.id.equals(conversationId))).write(
        ConversationsCompanion(
          currentMessageId: Value(messageId),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  // --- 附件 ---

  Future<void> saveAttachment(Attachment attachment) {
    return _guard('保存附件失败', () async {
      await _db
          .into(_db.attachments)
          .insertOnConflictUpdate(attachmentCompanion(attachment));
    });
  }

  /// 更新附件的文本抽取结果（S2 的 PDF/DOCX 抽取落库）。
  Future<void> updateAttachmentExtraction(
    String attachmentId, {
    required String extractedTextPath,
  }) {
    return _guard('保存附件文本失败', () async {
      await (_db.update(
        _db.attachments,
      )..where((t) => t.id.equals(attachmentId))).write(
        AttachmentsCompanion(extractedTextPath: Value(extractedTextPath)),
      );
    });
  }

  Future<List<Attachment>> attachmentsFor(String conversationId) {
    return _guard('读取附件失败', () async {
      final rows = await (_db.select(
        _db.attachments,
      )..where((t) => t.conversationId.equals(conversationId))).get();
      return rows.map(attachmentFromRow).toList();
    });
  }

  // --- 内部 ---

  Selectable<TypedResult> _threadQuery(String conversationId) {
    // 联表订阅跟踪两张表；left join 保留尚无消息的会话。
    return _db.select(_db.conversations).join([
        leftOuterJoin(
          _db.messages,
          _db.messages.conversationId.equalsExp(_db.conversations.id),
        ),
      ])
      ..where(_db.conversations.id.equals(conversationId))
      ..orderBy([OrderingTerm.asc(_db.messages.createdAt)]);
  }

  ConversationThread? _threadFromRows(List<TypedResult> rows) {
    if (rows.isEmpty) return null;
    return _buildThread(
      rows.first.readTable(_db.conversations),
      rows.map((row) => row.readTableOrNull(_db.messages)).nonNulls.toList(),
    );
  }

  ConversationThread _buildThread(
    ConversationRow row,
    List<MessageRow> messageRows,
  ) {
    final messages = messageRows.map(messageFromRow).toList();
    final byId = {for (final message in messages) message.id: message};

    final branch = <ChatMessage>[];
    String? cursor = row.currentMessageId;
    final seen = <String>{};
    while (cursor != null && seen.add(cursor)) {
      final message = byId[cursor];
      if (message == null) break;
      branch.insert(0, message);
      cursor = message.parentId;
    }

    return ConversationThread(
      conversation: conversationFromRow(row),
      messages: messages,
      branch: branch,
      currentMessageId: row.currentMessageId,
    );
  }

  String _titleFromMessage(ChatMessage message) {
    final text = message.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '新会话';
    final runes = text.runes.toList();
    return runes.length <= 30
        ? text
        : '${String.fromCharCodes(runes.take(30))}…';
  }

  Future<T> _guard<T>(String message, Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on Exception catch (e, st) {
      AppLogger.error(message, e, st);
      throw UnknownFailure(message, cause: e);
    }
  }
}

@Riverpod(keepAlive: true)
Future<ConversationRepository> conversationRepository(Ref ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final storage = await ref.watch(attachmentStorageProvider.future);
  return ConversationRepository(database, attachments: storage);
}
