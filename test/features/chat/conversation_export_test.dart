import 'dart:convert';
import 'dart:io';

import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/agent_run_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/tool_call_repository.dart';
import 'package:phase/features/chat/conversation_export.dart';

import '../../support/test_database.dart';

/// 会话导出：Markdown 按分支顺序，JSON 含消息 parts 与工具记录。
void main() {
  late AppDatabase database;
  late Directory directory;
  late ConversationRepository conversations;
  late ToolCallRepository toolCalls;
  late AgentRunRepository runs;
  late ConversationExporter exporter;

  setUp(() {
    final created = createTestDatabase(name: 'export');
    database = created.database;
    directory = created.directory;
    conversations = ConversationRepository(
      database,
      workspaces: WorkspaceRepository(database, directory),
    );
    toolCalls = ToolCallRepository(database);
    runs = AgentRunRepository(database);
    exporter = ConversationExporter(
      conversations: conversations,
      directory: Directory(p.join(directory.path, 'exports')),
    );
  });

  tearDown(() async {
    await database.close();
    directory.deleteSync(recursive: true);
  });

  /// 一条带附件、思考与工具调用的会话。
  Future<String> seedConversation() async {
    final conversation = await conversations.createConversation(title: '旅行计划');
    final photo = Attachment(
      id: 'attach-photo',
      conversationId: conversation.id,
      kind: AttachmentKind.image,
      name: '照片.png',
      mimeType: 'image/png',
      size: 2048,
      localPath: p.join(directory.path, 'photo.png'),
      createdAt: DateTime(2026, 9, 12, 9),
    );
    final artifact = Attachment(
      id: 'attach-summary',
      conversationId: conversation.id,
      kind: AttachmentKind.artifact,
      name: 'summary.md',
      mimeType: 'text/markdown',
      size: 12,
      localPath: p.join(
        directory.path,
        'artifacts',
        conversation.id,
        'summary.md',
      ),
      createdAt: DateTime(2026, 9, 12, 9, 5),
    );
    await conversations.saveAttachment(photo);
    await conversations.saveAttachment(artifact);

    // 运行先落库：工具记录外键指向它。
    await runs.create(
      AgentRun(
        id: 'run-1',
        conversationId: conversation.id,
        inputMessageId: 'msg-user',
        configuration: const RunConfiguration(
          connection: RunConnection(
            profileId: 'profile-1',
            protocol: 'openaiCompletions',
            baseUrl: 'https://example.com/v1',
            requiresKey: true,
          ),
          modelSelection: ModelSelection(
            profileId: 'profile-1',
            modelId: 'model-a',
          ),
          systemPrompt: '',
        ),
        createdAt: DateTime(2026, 9, 12, 9),
      ),
    );

    final record = await toolCalls.create(
      ToolCallRecord(
        id: 'tool-1',
        runId: 'run-1',
        assistantMessageId: 'msg-assistant',
        providerCallId: 'call_1',
        toolName: 'write_file',
        arguments: const {'path': 'summary.md', 'content': '# 摘要\n第一条'},
        providerData: const {'thoughtSignature': 'opaque-signature'},
        target: '写入文件「summary.md」（10 字，新文件）',
        channel: ExecutionChannel.app,
        defaultPolicy: ToolPolicy.ask,
        status: ToolCallStatus.succeeded,
        decision: ToolDecision.approved,
        confirmationRequestedAt: DateTime(2026, 9, 12, 9, 1),
        confirmationExpiresAt: DateTime(2026, 9, 12, 9, 2),
        decidedAt: DateTime(2026, 9, 12, 9, 1, 30),
        result: '已创建「summary.md」（10 字）',
        artifacts: [artifact.id],
        createdAt: DateTime(2026, 9, 12, 9, 1),
        startedAt: DateTime(2026, 9, 12, 9, 1, 31),
        finishedAt: DateTime(2026, 9, 12, 9, 1, 32),
      ),
    );

    await conversations.appendMessage(
      ChatMessage(
        id: 'msg-user',
        conversationId: conversation.id,
        role: ChatRole.user,
        parts: [
          ImagePart(attachmentId: photo.id),
          const TextPart(text: '把要点写成摘要'),
        ],
        createdAt: DateTime(2026, 9, 12, 9),
      ),
    );
    await conversations.appendMessage(
      ChatMessage(
        id: 'msg-assistant',
        conversationId: conversation.id,
        parentId: 'msg-user',
        runId: 'run-1',
        role: ChatRole.assistant,
        modelLabel: 'model-a',
        parts: [
          const ReasoningPart(
            publicText: '先整理要点',
            providerData: {'thoughtSignature': 'opaque-signature'},
          ),
          const TextPart(text: '我把要点写进了 summary.md'),
          ToolCallPart(toolCallId: record.id),
        ],
        createdAt: DateTime(2026, 9, 12, 9, 1),
      ),
    );
    await conversations.appendMessage(
      ChatMessage(
        id: 'msg-tool',
        conversationId: conversation.id,
        parentId: 'msg-assistant',
        runId: 'run-1',
        role: ChatRole.tool,
        parts: [
          ToolResultPart(toolCallId: record.id),
          TextPart(text: record.result!),
        ],
        createdAt: DateTime(2026, 9, 12, 9, 2),
      ),
    );
    return conversation.id;
  }

  test('Markdown 导出含标题、时间、正文、思考、附件名与工具调用结果', () async {
    final conversationId = await seedConversation();
    final result = await exporter.export(
      conversationId,
      ConversationExportFormat.markdown,
    );

    expect(result.formatLabel, 'Markdown');
    expect(result.messageCount, 3);
    expect(result.toolCallCount, 1);
    final file = File(result.path);
    expect(file.existsSync(), isTrue);
    expect(p.extension(result.path), '.md');
    expect(p.basename(result.path), startsWith('旅行计划-'));
    final markdown = file.readAsStringSync();

    expect(markdown, contains('# 旅行计划'));
    expect(markdown, contains('- 会话 ID：`$conversationId`'));
    expect(markdown, contains('- 创建时间：'));
    expect(markdown, contains('- 最后更新：'));
    expect(markdown, contains('- 导出时间：'));
    // 分支里的工具结果消息不重复成段，只计入总数。
    expect(markdown, contains('- 消息数：3（当前分支 2 条）'));
    expect(markdown, contains('- 工具调用：1 次'));
    expect(markdown, contains('## 用户'));
    // 消息与工具记录的时间按本地时间写出。
    expect(markdown, contains('> 2026-09-12 09:00:00'));
    expect(markdown, contains('- 创建时间：2026-09-12 09:01:00'));
    expect(markdown, contains('把要点写成摘要'));
    expect(markdown, contains('- 照片.png（图片）'));
    expect(markdown, contains('## 助手 · model-a'));
    expect(markdown, contains('### 思考'));
    expect(markdown, contains('先整理要点'));
    expect(markdown, contains('我把要点写进了 summary.md'));

    // 工具调用记录：工具名、参数、状态、决定、结果与产物名。
    expect(markdown, contains('### 工具调用：写入文件（write_file）'));
    expect(markdown, contains('- 记录 ID：`tool-1`'));
    expect(markdown, contains('- 状态：已完成'));
    expect(markdown, contains('- 决定：允许一次'));
    expect(markdown, contains('- 执行通道：应用内'));
    expect(markdown, contains('"path": "summary.md"'));
    expect(markdown, contains('"content": "# 摘要\\n第一条"'));
    expect(markdown, contains('已创建「summary.md」（10 字）'));
    expect(markdown, contains('- summary.md'));

    // 工具结果消息不重复成段：结果只随调用记录出现一次。
    expect('已创建「summary.md」（10 字）'.allMatches(markdown).length, 1);
    // 协议回传状态与密钥都不进导出。
    expect(markdown, isNot(contains('opaque-signature')));
    expect(markdown, isNot(contains('apiKey')));
  });

  test('JSON 导出含会话、消息 parts 与完整工具记录', () async {
    final conversationId = await seedConversation();
    final result = await exporter.export(
      conversationId,
      ConversationExportFormat.json,
    );

    expect(result.formatLabel, 'JSON');
    expect(p.extension(result.path), '.json');
    final decoded = jsonDecode(
      File(result.path).readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(decoded['format'], 'xiangyue.conversation.export');
    expect(decoded['version'], 1);

    final conversation = decoded['conversation'] as Map<String, dynamic>;
    expect(conversation['id'], conversationId);
    expect(conversation['title'], '旅行计划');
    expect(conversation['currentMessageId'], 'msg-tool');
    expect(conversation['branchMessageIds'], [
      'msg-user',
      'msg-assistant',
      'msg-tool',
    ]);

    final messages = (decoded['messages'] as List).cast<Map<String, dynamic>>();
    expect(messages.map((message) => message['id']), [
      'msg-user',
      'msg-assistant',
      'msg-tool',
    ]);
    final assistant = messages[1];
    expect(assistant['role'], 'assistant');
    expect(assistant['modelLabel'], 'model-a');
    final parts = (assistant['parts'] as List).cast<Map<String, dynamic>>();
    expect(parts.map((part) => part['type']), [
      'reasoning',
      'text',
      'toolCall',
    ]);
    expect(parts.first['publicText'], '先整理要点');
    expect(parts.last['toolCallId'], 'tool-1');
    // 协议状态不随导出的 parts 出去。
    expect(jsonEncode(decoded), isNot(contains('opaque-signature')));

    final records = (decoded['toolCalls'] as List).cast<Map<String, dynamic>>();
    final record = records.single;
    expect(record['id'], 'tool-1');
    expect(record['toolName'], 'write_file');
    expect(record['arguments'], {'path': 'summary.md', 'content': '# 摘要\n第一条'});
    expect(record['status'], 'succeeded');
    expect(record['decision'], 'approved');
    expect(record['result'], '已创建「summary.md」（10 字）');
    expect(record['errorCode'], isNull);
    expect(record['artifactIds'], ['attach-summary']);
    expect(record['artifactNames'], ['summary.md']);
    expect(record['channel'], 'app');
    expect(record['providerCallId'], 'call_1');

    final attachments = (decoded['attachments'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      attachments.map((attachment) => attachment['name']),
      containsAll(['照片.png', 'summary.md']),
    );
    // 附件只导出元数据，不导出磁盘路径。
    expect(jsonEncode(decoded), isNot(contains(directory.path)));
  });

  test('导出不存在的会话报失败，不写出空文件', () async {
    await expectLater(
      exporter.export('missing', ConversationExportFormat.markdown),
      throwsA(isA<Failure>()),
    );
    expect(Directory(p.join(directory.path, 'exports')).existsSync(), isFalse);
  });

  test('标题里的路径字符在文件名里被替换，扩展名区分两种格式', () async {
    final conversation = await conversations.createConversation(
      title: 'a/b:c*d?e"f<g>h|i',
    );
    final markdown = await exporter.export(
      conversation.id,
      ConversationExportFormat.markdown,
    );
    final json = await exporter.export(
      conversation.id,
      ConversationExportFormat.json,
    );
    expect(p.basename(markdown.path), startsWith('a_b_c_d_e_f_g_h_i-'));
    expect(p.basename(markdown.path), endsWith('.md'));
    expect(p.basename(json.path), endsWith('.json'));
    expect(markdown.path, isNot(json.path));
    // 标题原文保留在文件内容里，只影响文件名。
    expect(
      File(json.path).readAsStringSync(),
      contains('"title": "a/b:c*d?e\\"f<g>h|i"'),
    );
  });
}
