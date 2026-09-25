import '../models/workspace.dart';

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
import '../models/permission_mode.dart';
import '../models/message_part.dart';
import '../models/model_selection.dart';
import '../models/tool_call_record.dart';
import '../models/agent_run.dart';
import 'row_mappers.dart';
import 'workspace_repository.dart';

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
  ConversationRepository(
    this._db, {
    required this.workspaces,
    this.attachments,
  });

  final WorkspaceRepository workspaces;

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
    PrimaryEnvironment primaryEnvironment = PrimaryEnvironment.ubuntu,
    PermissionSelection permissions = const PermissionSelection(),
    String? assistantId,
    ModelSelection? modelSelectionOverride,
  }) async {
    return _guard('创建会话失败', () async {
      final now = DateTime.now();
      final workspace = await workspaces.create('会话工作区');
      final conversation = Conversation(
        id: generateId(),
        title: title,
        permissions: permissions,
        primaryEnvironment: primaryEnvironment,
        workspaceId: workspace.id,
        assistantId: assistantId,
        modelSelectionOverride: modelSelectionOverride,
        createdAt: now,
        updatedAt: now,
      );
      try {
        await _db
            .into(_db.conversations)
            .insert(conversationCompanion(conversation));
      } catch (_) {
        await workspaces.delete(workspace.id);
        rethrow;
      }
      return conversation;
    });
  }

  Future<void> updateConversation(Conversation conversation) {
    return _guard('更新会话失败', () async {
      await (_db.update(
        _db.conversations,
      )..where((t) => t.id.equals(conversation.id))).write(
        conversationCompanion(conversation.copyWith(updatedAt: DateTime.now()))
            .copyWith(primaryEnvironment: const Value.absent()),
      );
    });
  }

  Future<void> setPermissionMode(String id, PermissionMode mode) =>
      _guard('保存权限模式失败', () async {
        final changed =
            await (_db.update(
              _db.conversations,
            )..where((t) => t.id.equals(id))).write(
              ConversationsCompanion(
                permissionMode: Value(mode),
                lastExecutionMode: mode == PermissionMode.plan
                    ? const Value.absent()
                    : Value(mode),
              ),
            );
        if (changed == 0) throw const OperationFailure('会话已不存在');
      });

  Future<void> setAssistant(String id, String assistantId) =>
      _guard('保存会话助手失败', () async {
        final changed =
            await (_db.update(_db.conversations)..where((t) => t.id.equals(id)))
                .write(ConversationsCompanion(assistantId: Value(assistantId)));
        if (changed == 0) throw const OperationFailure('会话已不存在');
      });

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

  /// 文件清理完成后删除记录；失败保留会话与工作区标记，允许重试。
  Future<void> deleteConversation(String id) {
    return _guard('删除会话失败', () async {
      final thread = await getThread(id);
      if (thread == null) return;
      final runs = await (_db.select(
        _db.agentRuns,
      )..where((t) => t.conversationId.equals(id))).get();
      if (runs.any(
        (run) =>
            run.status == RunStatus.running ||
            run.status == RunStatus.awaitingConfirmation ||
            run.status == RunStatus.awaitingUser,
      )) {
        throw const OperationFailure('请先停止或处理此会话的任务，再删除会话');
      }
      final rows = await (_db.select(
        _db.attachments,
      )..where((t) => t.conversationId.equals(id))).get();
      Future<void> removeOwner() async {
        await attachments?.deleteConversationFiles(id, [
          for (final row in rows) ...[row.localPath, ?row.extractedTextPath],
        ]);
        await (_db.delete(
          _db.conversations,
        )..where((t) => t.id.equals(id))).go();
      }

      final workspaceId = thread.conversation.workspaceId;
      if (workspaceId == null) {
        await removeOwner();
      } else {
        await workspaces.delete(workspaceId, deleteOwner: removeOwner);
      }
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
      final runRows = await (_db.select(
        _db.agentRuns,
      )..where((t) => t.conversationId.equals(id))).get();
      if (runRows.any(
        (run) => const {
          RunStatus.running,
          RunStatus.awaitingConfirmation,
          RunStatus.awaitingUser,
        }.contains(run.status),
      )) {
        throw const OperationFailure('请先结束或处理此会话的任务，再复制会话');
      }
      final runIds = {for (final run in runRows) run.id: generateId()};
      final planRows = await (_db.select(
        _db.agentPlans,
      )..where((t) => t.conversationId.equals(id))).get();
      final planIds = {for (final row in planRows) row.id: generateId()};
      final callRows = await (_db.select(
        _db.toolCalls,
      )..where((t) => t.runId.isIn(runIds.keys))).get();
      final callIds = {for (final call in callRows) call.id: generateId()};
      final now = DateTime.now();
      final copy = Conversation(
        id: generateId(),
        title: '${source.conversation.title}（副本）',
        assistantId: source.conversation.assistantId,
        permissions: source.conversation.permissions,
        primaryEnvironment: source.conversation.primaryEnvironment,
        workspaceId: generateId(),
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
      final workspace = await workspaces.create('会话工作区', id: copy.workspaceId!);
      try {
        if (source.conversation.workspaceId case final sourceWorkspace?) {
          await workspaces.copyFiles(sourceWorkspace, workspace);
        }
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
                      parts: _copyMessageParts(
                        message.parts,
                        attachmentIds,
                        callIds,
                      ),
                    ),
                  ).copyWith(
                    runId: Value(
                      message.runId == null ? null : runIds[message.runId],
                    ),
                  ),
                );
          }

          String mappedMessage(String old) =>
              idMap[old] ?? (throw const OperationFailure('会话的运行消息引用不完整，无法复制'));
          for (final row in runRows) {
            final configuration = agentRunFromRow(row).configuration;
            final copiedConfiguration = configuration.toJson();
            if (configuration.planId != null) {
              copiedConfiguration['planId'] = planIds[configuration.planId];
            }
            if (configuration.workspace case final originalWorkspace?) {
              copiedConfiguration['workspace'] = {
                ...originalWorkspace.toJson(),
                'id': workspace.id,
                'name': workspace.name,
                'rootPath': workspace.rootPath,
              };
            }
            await _db
                .into(_db.agentRuns)
                .insert(
                  row
                      .toCompanion(false)
                      .copyWith(
                        id: Value(runIds[row.id]!),
                        conversationId: Value(copy.id),
                        configurationJson: Value(
                          jsonEncode(copiedConfiguration),
                        ),
                        inputMessageId: Value(
                          mappedMessage(row.inputMessageId),
                        ),
                        currentMessageId: Value(
                          row.currentMessageId == null
                              ? null
                              : mappedMessage(row.currentMessageId!),
                        ),
                        activeToolCallId: Value(
                          row.activeToolCallId == null
                              ? null
                              : callIds[row.activeToolCallId],
                        ),
                      ),
                );
          }
          final requests = await (_db.select(
            _db.modelRequests,
          )..where((t) => t.conversationId.equals(id))).get();
          for (final request in requests) {
            await _db
                .into(_db.modelRequests)
                .insert(
                  request
                      .toCompanion(false)
                      .copyWith(
                        id: Value(generateId()),
                        conversationId: Value(copy.id),
                        runId: Value(runIds[request.runId]),
                        assistantMessageId: Value(
                          idMap[request.assistantMessageId],
                        ),
                        summaryId: const Value(null),
                        summaryJobId: const Value(null),
                        originRequestId: Value(
                          request.originRequestId ?? request.id,
                        ),
                        isInherited: const Value(true),
                        contextJson: const Value('{}'),
                      ),
                );
          }
          final archives = await (_db.select(
            _db.usageArchives,
          )..where((t) => t.conversationId.equals(id))).get();
          for (final archive in archives) {
            await _db
                .into(_db.usageArchives)
                .insert(
                  archive
                      .toCompanion(false)
                      .copyWith(conversationId: Value(copy.id)),
                );
          }
          for (final row in planRows) {
            await _db
                .into(_db.agentPlans)
                .insert(
                  row
                      .toCompanion(false)
                      .copyWith(
                        id: Value(planIds[row.id]!),
                        conversationId: Value(copy.id),
                        sourceRunId: Value(runIds[row.sourceRunId]!),
                        sourceMessageId: Value(
                          mappedMessage(row.sourceMessageId),
                        ),
                        executionRunId: Value(
                          row.executionRunId == null
                              ? null
                              : runIds[row.executionRunId],
                        ),
                      ),
                );
          }
          // 摘要是分支派生缓存，副本按新的消息身份重新构建；长期记忆不复制。
          for (final row in callRows) {
            final record = toolCallFromRow(row);
            await _db
                .into(_db.toolCalls)
                .insert(
                  row
                      .toCompanion(false)
                      .copyWith(
                        id: Value(callIds[row.id]!),
                        runId: Value(runIds[row.runId]!),
                        assistantMessageId: Value(
                          mappedMessage(row.assistantMessageId),
                        ),
                        resultMessageId: Value(
                          row.resultMessageId == null
                              ? null
                              : mappedMessage(row.resultMessageId!),
                        ),
                        artifactsJson: Value(
                          jsonEncode([
                            for (final id in record.artifacts)
                              attachmentIds[id] ??
                                  (throw const OperationFailure(
                                    '工具产物引用不完整，无法复制',
                                  )),
                          ]),
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
      } catch (error, stack) {
        try {
          await workspaces.delete(
            workspace.id,
            deleteOwner: () async {
              await attachments?.deletePaths([
                for (final attachment in copiedAttachments) ...[
                  attachment.localPath,
                  ?attachment.extractedTextPath,
                ],
              ]);
            },
          );
        } on Failure catch (cleanup) {
          // A remote workspace must retain a reachable owner when cleanup fails.
          await _db
              .into(_db.conversations)
              .insertOnConflictUpdate(
                conversationCompanion(
                  copy.copyWith(title: '${copy.title}（复制未完成）'),
                ),
              );
          throw OperationFailure('${cleanup.userMessage}；未完成副本已保留，请重试删除');
        }
        Error.throwWithStackTrace(error, stack);
      }
      return copy;
    });
  }

  List<MessagePart> _copyMessageParts(
    List<MessagePart> parts,
    Map<String, String> attachmentIds,
    Map<String, String> callIds,
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
          ToolCallPart(:final toolCallId, :final providerData) => ToolCallPart(
            toolCallId:
                callIds[toolCallId] ??
                (throw const OperationFailure('工具调用引用不完整，无法复制')),
            providerData: providerData,
          ),
          ToolResultPart(:final toolCallId) => ToolResultPart(
            toolCallId:
                callIds[toolCallId] ??
                (throw const OperationFailure('工具结果引用不完整，无法复制')),
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
        if (message.runId case final runId?) {
          await (_db.update(
            _db.agentRuns,
          )..where((t) => t.id.equals(runId))).write(
            AgentRunsCompanion(
              currentMessageId: Value(message.id),
              activeToolCallId: const Value(null),
            ),
          );
        }
      });
      return message;
    });
  }

  /// 落库助手消息的最终内容（流式结束后调用一次）。
  Future<void> updateMessage({
    required String messageId,
    required List<MessagePart> parts,
    required MessageStatus status,
    int? thinkingDurationMs,
  }) {
    return _guard('更新消息失败', () async {
      await (_db.update(
        _db.messages,
      )..where((t) => t.id.equals(messageId))).write(
        MessagesCompanion(
          partsJson: Value(encodeMessageParts(parts)),
          status: Value(status),
          thinkingDurationMs: Value(thinkingDurationMs),
        ),
      );
    });
  }

  /// 响应收口与整轮调用原子保存；重启不依赖尚未派发调用的内存缓冲。
  Future<void> completeToolTurn({
    required String messageId,
    required String runId,
    required List<MessagePart> parts,
    required List<ToolCallRecord> calls,
    int? thinkingDurationMs,
  }) => _guard(
    '保存模型响应失败',
    () => _db.transaction(() async {
      await updateMessage(
        messageId: messageId,
        parts: parts,
        status: MessageStatus.completed,
        thinkingDurationMs: thinkingDurationMs,
      );
      for (final call in calls) {
        await _db.into(_db.toolCalls).insert(toolCallCompanion(call));
      }
      await (_db.update(_db.agentRuns)..where((t) => t.id.equals(runId))).write(
        AgentRunsCompanion(currentMessageId: Value(messageId)),
      );
    }),
  );

  /// 装配上下文用的工具记录：消息里的 ToolCallPart/ToolResultPart 只存记录 id，
  /// 参数与结果按 id 批量读回。缺失的 id 不出现在结果里。
  Future<Map<String, ToolCallRecord>> toolCallsByIds(Iterable<String> ids) {
    final wanted = ids.toSet();
    if (wanted.isEmpty) return Future.value(const {});
    return _guard('读取工具记录失败', () async {
      final rows = await (_db.select(
        _db.toolCalls,
      )..where((t) => t.id.isIn(wanted))).get();
      return {for (final row in rows) row.id: toolCallFromRow(row)};
    });
  }

  /// 工具结果与结果消息在同一事务提交（design 第五部分 §3.3）。
  ///
  /// 事务内完成：结果消息落库、记录回填 resultMessageId、会话当前位置前移，
  /// 避免「结果已记、消息缺失」或反过来的中间态。
  Future<ToolCallRecord> saveToolResult({
    required String toolCallId,
    required ChatMessage message,
  }) {
    return _guard('保存工具结果失败', () async {
      await _db.transaction(() async {
        await _db.into(_db.messages).insert(messageCompanion(message));
        final changed =
            await (_db.update(_db.toolCalls)
                  ..where((t) => t.id.equals(toolCallId)))
                .write(ToolCallsCompanion(resultMessageId: Value(message.id)));
        if (changed == 0) {
          throw const UnknownFailure('工具记录不存在');
        }
        await (_db.update(
          _db.conversations,
        )..where((t) => t.id.equals(message.conversationId))).write(
          ConversationsCompanion(
            currentMessageId: Value(message.id),
            updatedAt: Value(message.createdAt),
          ),
        );
        if (message.runId case final runId?) {
          await (_db.update(
            _db.agentRuns,
          )..where((t) => t.id.equals(runId))).write(
            AgentRunsCompanion(
              currentMessageId: Value(message.id),
              activeToolCallId: const Value(null),
            ),
          );
        }
      });
      final stored = await toolCallsByIds([toolCallId]);
      final record = stored[toolCallId];
      if (record == null) throw const UnknownFailure('工具记录不存在');
      return record;
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
        leftOuterJoin(
          _db.modelRequests,
          _db.modelRequests.assistantMessageId.equalsExp(_db.messages.id),
        ),
      ])
      ..where(_db.conversations.id.equals(conversationId))
      ..orderBy([OrderingTerm.asc(_db.messages.createdAt)]);
  }

  ConversationThread? _threadFromRows(List<TypedResult> rows) {
    if (rows.isEmpty) return null;
    return _buildThread(rows.first.readTable(_db.conversations), [
      for (final row in rows)
        if (row.readTableOrNull(_db.messages) case final message?)
          messageFromRow(message, row.readTableOrNull(_db.modelRequests)),
    ]);
  }

  ConversationThread _buildThread(
    ConversationRow row,
    List<ChatMessage> messages,
  ) {
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
      AppLogger.error('$message (${e.runtimeType})', null, st);
      throw StorageFailure(message, cause: e);
    }
  }
}

@Riverpod(keepAlive: true)
Future<ConversationRepository> conversationRepository(Ref ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final storage = await ref.watch(attachmentStorageProvider.future);
  return ConversationRepository(
    database,
    attachments: storage,
    workspaces: await ref.watch(workspaceRepositoryProvider.future),
  );
}
