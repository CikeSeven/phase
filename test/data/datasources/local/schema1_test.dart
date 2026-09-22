import 'package:phase/data/models/model_request_record.dart';
import 'package:phase/data/repositories/model_request_repository.dart';
import 'package:phase/data/models/token_usage.dart';

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

/// schema 1 的建表、约束、父子链与加密行为。
void main() {
  late Directory tempDir;
  late AppDatabase db;

  const hexKey =
      'a1b2c3d4e5f60718293a4b5c6d7e8f90'
      'a1b2c3d4e5f60718293a4b5c6d7e8f90';

  String dbPath() => p.join(tempDir.path, 'phase.sqlite');

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('phase_schema1');
    db = openAppDatabase(path: dbPath(), hexKey: hexKey);
    await db.assertEncryptionAvailable();
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  Future<String> insertConversation({String title = '新会话'}) async {
    final now = DateTime.now();
    await db
        .into(db.conversations)
        .insert(
          ConversationsCompanion.insert(
            id: 'conv_1',
            title: title,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return 'conv_1';
  }

  Future<void> insertProvider(String id, {String name = '服务商'}) {
    return db
        .into(db.providerProfiles)
        .insert(
          ProviderProfilesCompanion.insert(
            id: id,
            name: name,
            protocol: 'openaiCompletions',
            baseUrl: 'https://example.com/v1',
            createdAt: DateTime.now(),
          ),
        );
  }

  test('数据库文件用口令加密，明文读不出内容', () async {
    await insertConversation(title: '加密会话标题');
    await db.close();

    // 直接以明文打开同一文件：内容不可读，且不含明文标记。
    final plain = raw.sqlite3.open(dbPath());
    addTearDown(plain.close);
    expect(
      () => plain.select('SELECT title FROM conversations;'),
      throwsA(anything),
    );

    final bytes = File(dbPath()).readAsBytesSync();
    expect(
      String.fromCharCodes(bytes).contains('加密会话标题'),
      isFalse,
      reason: '加密库里不应出现明文业务数据',
    );
  });

  test('删除人工核验机制时收口已有挂起状态，保留会话和实际响应', () async {
    await insertConversation(title: '保留原会话');
    final now = DateTime.now();
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: 'input',
            conversationId: 'conv_1',
            role: ChatRole.user,
            status: MessageStatus.completed,
            createdAt: now,
          ),
        );
    await db
        .into(db.agentRuns)
        .insert(
          AgentRunsCompanion.insert(
            id: 'run',
            conversationId: 'conv_1',
            inputMessageId: 'input',
            configurationJson: '{}',
            status: RunStatus.running,
            maxTurns: 30,
            createdAt: now,
          ),
        );
    await db
        .into(db.toolCalls)
        .insert(
          ToolCallsCompanion.insert(
            id: 'call',
            runId: 'run',
            assistantMessageId: 'input',
            toolName: 'read_file',
            argumentsJson: '{"path":"notes.txt"}',
            channel: ExecutionChannel.app,
            defaultPolicy: ToolPolicy.allow,
            status: ToolCallStatus.executing,
            result: const Value('{"actionAccepted":true,"reason":"请核验"}'),
            createdAt: now,
          ),
        );
    await db.customStatement(
      "UPDATE tool_calls SET status = 'unknown' WHERE id = 'call'",
    );
    await db.customStatement(
      "UPDATE agent_runs SET status = 'awaitingResult' WHERE id = 'run'",
    );
    await db.close();
    db = openAppDatabase(path: dbPath(), hexKey: hexKey);
    final call = await db.select(db.toolCalls).getSingle();
    final run = await db.select(db.agentRuns).getSingle();
    expect(call.status, ToolCallStatus.failed);
    expect(jsonDecode(call.result!)['actionAccepted'], isTrue);
    expect(call.result, isNot(contains('核验')));
    expect(run.status, RunStatus.failed);
    expect(run.finishedAt, isNotNull);
    expect((await db.select(db.conversations).getSingle()).title, '保留原会话');
    expect(await db.select(db.messages).get(), hasLength(1));
  });

  test('服务商删除级联清理其模型', () async {
    await insertProvider('p1');
    await db
        .into(db.models)
        .insert(
          ModelsCompanion.insert(
            profileId: 'p1',
            modelId: 'm1',
            supportsReasoning: const Value(true),
          ),
        );
    expect(await db.select(db.models).get(), hasLength(1));

    await (db.delete(
      db.providerProfiles,
    )..where((t) => t.id.equals('p1'))).go();
    expect(await db.select(db.models).get(), isEmpty);
  });

  test('删除会话级联清理消息、附件与运行', () async {
    await insertConversation();
    final now = DateTime.now();
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: 'msg_1',
            conversationId: 'conv_1',
            role: ChatRole.user,
            status: MessageStatus.completed,
            partsJson: Value(encodeMessageParts(const [TextPart(text: '你好')])),
            createdAt: now,
          ),
        );
    await db
        .into(db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            id: 'att_1',
            conversationId: 'conv_1',
            kind: 'image',
            name: 'photo.jpg',
            mimeType: 'image/jpeg',
            size: 1024,
            localPath: '/tmp/photo.jpg',
            createdAt: now,
          ),
        );
    await db
        .into(db.agentRuns)
        .insert(
          AgentRunsCompanion.insert(
            id: 'run_1',
            conversationId: 'conv_1',
            inputMessageId: 'msg_1',
            configurationJson: '{}',
            status: RunStatus.running,
            maxTurns: 30,
            createdAt: now,
          ),
        );
    await db
        .into(db.toolCalls)
        .insert(
          ToolCallsCompanion.insert(
            id: 'call_1',
            runId: 'run_1',
            assistantMessageId: 'msg_1',
            toolName: 'read_file',
            argumentsJson: '{}',
            channel: ExecutionChannel.app,
            defaultPolicy: ToolPolicy.ask,
            status: ToolCallStatus.prepared,
            createdAt: now,
          ),
        );

    await (db.delete(
      db.conversations,
    )..where((t) => t.id.equals('conv_1'))).go();

    expect(await db.select(db.messages).get(), isEmpty);
    expect(await db.select(db.attachments).get(), isEmpty);
    expect(await db.select(db.agentRuns).get(), isEmpty);
    expect(await db.select(db.toolCalls).get(), isEmpty);
  });

  test('消息父链可按 parentId 还原当前分支', () async {
    await insertConversation();
    final now = DateTime.now();
    for (final (index, parentId) in [null, 'msg_1', 'msg_2'].indexed) {
      await db
          .into(db.messages)
          .insert(
            MessagesCompanion.insert(
              id: 'msg_${index + 1}',
              conversationId: 'conv_1',
              parentId: Value(parentId),
              role: index.isEven ? ChatRole.user : ChatRole.assistant,
              status: MessageStatus.completed,
              partsJson: Value(
                encodeMessageParts([TextPart(text: '第 ${index + 1} 条')]),
              ),
              createdAt: now.add(Duration(seconds: index)),
            ),
          );
    }

    final rows = await (db.select(
      db.messages,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
    expect(rows.map((row) => row.parentId), [null, 'msg_1', 'msg_2']);

    // 沿父指针回溯最后一条消息的整条链。
    final byId = {for (final row in rows) row.id: row};
    final branch = <String>[];
    String? cursor = rows.last.id;
    while (cursor != null) {
      branch.insert(0, cursor);
      cursor = byId[cursor]?.parentId;
    }
    expect(branch, ['msg_1', 'msg_2', 'msg_3']);
  });

  test('Parts 与用量经数据库往返不丢失', () async {
    await insertConversation();
    final now = DateTime.now();
    final parts = const [
      ReasoningPart(publicText: '先读文档', providerData: {'signature': 'sig'}),
      TextPart(text: '好的'),
      ToolCallPart(toolCallId: 'call_1'),
      ProviderPart(
        protocol: 'anthropicMessages',
        modelId: 'claude-x',
        data: {'type': 'server_tool_use'},
      ),
    ];
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: 'msg_parts',
            conversationId: 'conv_1',
            role: ChatRole.assistant,
            status: MessageStatus.completed,
            partsJson: Value(encodeMessageParts(parts)),
            createdAt: now,
          ),
        );

    final row = await (db.select(
      db.messages,
    )..where((t) => t.id.equals('msg_parts'))).getSingle();
    final decoded = decodeMessageParts(jsonDecode(row.partsJson));

    expect(decoded, hasLength(4));
    expect((decoded[0] as ReasoningPart).providerData, {'signature': 'sig'});
    expect((decoded[1] as TextPart).text, '好的');
    expect((decoded[2] as ToolCallPart).toolCallId, 'call_1');
    expect(decoded[3], isA<ProviderPart>());

    final requests = ModelRequestRepository(db);
    await requests.prepare(
      ModelRequestRecord(
        id: 'usage',
        conversationId: 'conv_1',
        profileId: 'fixture',
        protocol: 'openaiCompletions',
        requestedModelId: 'test',
        assistantMessageId: row.id,
        createdAt: now,
      ),
    );
    await requests.start('usage');
    await requests.settle(
      'usage',
      status: ModelRequestStatus.completed,
      usage: const TokenUsage(promptTokens: 12, outputTokens: 34),
      revision: 1,
    );
    final usage = (await requests.list('conv_1')).single.usage!;
    expect(usage.promptTokens, 12);
    expect(usage.outputTokens, 34);
  });

  test('未定义的内容块类型明确报错，不静默丢正文', () {
    expect(
      () => decodeMessageParts([
        {'type': 'unknownBlock', 'value': 'x'},
      ]),
      throwsA(isA<FormatException>()),
    );
  });
}
