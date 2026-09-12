import 'dart:async';
import 'dart:convert';

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
import '../models/model_selection.dart';
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

  /// 复制和删除会话时管理附件文件；纯数据测试可不注入。
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
    ModelSelection? modelSelectionOverride,
  }) async {
    return _guard('创建会话失败', () async {
      final now = DateTime.now();
      final conversation = Conversation(
        id: generateId(),
        title: title,
        assistantId: assistantId,
        modelSelectionOverride: modelSelectionOverride,
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

  Future<void> setModelSelection(String id, ModelSelection selection) {
    return _guard('保存会话模型失败', () async {
      final changed =
          await (_db.update(
            _db.conversations,
          )..where((t) => t.id.equals(id))).write(
            ConversationsCompanion(
              selectionJson: Value(jsonEncode(selection.toJson())),
            ),
          );
      if (changed == 0) throw const UnknownFailure('会话不存在或已删除');
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
      await attachments?.deletePaths([
        for (final row in rows) ...[
          row.localPath,
          if (row.extractedTextPath != null) row.extractedTextPath!,
        ],
      ]);
    });
  }

  /// 复制会话：新会话带同样的助手、模型覆盖与全部消息（含其他分支）。
  ///
  /// 副本拥有独立附件文件；消息父指针和所有分支中的附件引用一起重映射。
  Future<Conversation> duplicateConversation(String id) {
    return _guard('复制会话失败', () async {
      final source = await getThread(id);
      if (source == null) {
        throw const UnknownFailure('会话不存在或已删除');
      }
      final now = DateTime.now();
      final copy = Conversation(
        id: generateId(),
        title: '${source.conversation.title}（副本）',
        assistantId: source.conversation.assistantId,
        modelSelectionOverride: source.conversation.modelSelectionOverride,
        createdAt: now,
        updatedAt: now,
      );
      final attachmentRows = await (_db.select(
        _db.attachments,
      )..where((t) => t.conversationId.equals(id))).get();
      if (attachmentRows.isNotEmpty && attachments == null) {
        throw const UnknownFailure('复制会话需要附件存储');
      }
      final attachmentIds = <String, String>{};
      final copiedAttachments = <Attachment>[];
      try {
        for (final row in attachmentRows) {
          final newId = generateId();
          final copied = await attachments!.copy(
            attachmentFromRow(row),
            conversationId: copy.id,
            id: newId,
          );
          attachmentIds[row.id] = newId;
          copiedAttachments.add(copied);
        }
        await _db.transaction(() async {
          await _db.into(_db.conversations).insert(conversationCompanion(copy));

          // 旧消息 id → 新消息 id，用于重建父指针与当前分支指针。
          final idMap = {
            for (final message in source.messages) message.id: generateId(),
          };
          for (final message in source.messages) {
            await _db
                .into(_db.messages)
                .insert(
                  messageCompanion(
                    message.copyTo(
                      conversationId: copy.id,
                      id: idMap[message.id]!,
                      parentId: message.parentId == null
                          ? null
                          : idMap[message.parentId!],
                      parts: _copyMessageParts(message.parts, attachmentIds),
                    ),
                  ),
                );
          }

          final currentId = source.currentMessageId;
          await (_db.update(
            _db.conversations,
          )..where((t) => t.id.equals(copy.id))).write(
            ConversationsCompanion(
              currentMessageId: Value(
                currentId == null ? null : idMap[currentId],
              ),
            ),
          );

          for (final attachment in copiedAttachments) {
            await _db
                .into(_db.attachments)
                .insert(attachmentCompanion(attachment));
          }
        });
      } catch (_) {
        await attachments?.deletePaths([
          for (final attachment in copiedAttachments) ...[
            attachment.localPath,
            if (attachment.extractedTextPath != null)
              attachment.extractedTextPath!,
          ],
        ]);
        rethrow;
      }
      return copy;
    });
  }

  List<MessagePart> _copyMessageParts(
    List<MessagePart> parts,
    Map<String, String> attachmentIds,
  ) {
    return [
      for (final part in parts)
        switch (part) {
          ImagePart(:final attachmentId) => ImagePart(
            attachmentId:
                attachmentIds[attachmentId] ??
                (throw const UnknownFailure('复制会话的图片附件引用不存在')),
          ),
          DocumentPart(:final attachmentId) => DocumentPart(
            attachmentId:
                attachmentIds[attachmentId] ??
                (throw const UnknownFailure('复制会话的文档附件引用不存在')),
          ),
          _ => part,
        },
    ];
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

  Future<List<Attachment>> attachmentsFor(String conversationId) {
    return _guard('读取附件失败', () async {
      final rows = await (_db.select(
        _db.attachments,
      )..where((t) => t.conversationId.equals(conversationId))).get();
      return rows.map(attachmentFromRow).toList();
    });
  }

  /// 记录文档抽取结果：成功的文本路径或失败原因（二者互斥）。
  Future<void> updateAttachmentExtraction(
    String attachmentId, {
    String? extractedTextPath,
    String? error,
  }) {
    return _guard('保存附件抽取结果失败', () async {
      await (_db.update(
        _db.attachments,
      )..where((t) => t.id.equals(attachmentId))).write(
        AttachmentsCompanion(
          extractedTextPath: Value(extractedTextPath),
          extractionError: Value(extractedTextPath == null ? error : null),
        ),
      );
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
