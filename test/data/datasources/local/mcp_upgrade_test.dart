import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/agent_run_repository.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/mcp_server_repository.dart';
import 'package:phase/data/repositories/tool_call_repository.dart';

import '../../../support/fake_secure_storage.dart';

/// 用户授权的 schema 3 → 4 覆盖安装例外；样本只使用假数据与假密钥。
void main() {
  test('MCP 增量升级保留既有会话、助手、运行与工具结果，重开不会重复建表', () async {
    final directory = Directory.systemTemp.createTempSync('phase_mcp_upgrade');
    final path = '${directory.path}/phase.sqlite';
    const key =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    var db = openAppDatabase(path: path, hexKey: key, background: false);
    addTearDown(() async {
      await db.close();
      directory.deleteSync(recursive: true);
    });
    final assistant = await AssistantRepository(db).ensureDefault();
    final conversations = ConversationRepository(db);
    final conversation = await conversations.createConversation(
      title: '升级前样本',
      assistantId: assistant.id,
    );
    await conversations.appendMessage(
      ChatMessage(
        id: 'input',
        conversationId: conversation.id,
        role: ChatRole.user,
        parts: const [TextPart(text: '保留这条样本消息')],
        createdAt: DateTime(2026),
      ),
    );
    await AgentRunRepository(db).create(
      AgentRun(
        id: 'run',
        conversationId: conversation.id,
        inputMessageId: 'input',
        assistantId: assistant.id,
        status: RunStatus.completed,
        configuration: const RunConfiguration(
          connection: RunConnection(
            profileId: 'p',
            protocol: 'openaiCompletions',
            baseUrl: 'https://example.test/v1',
            requiresKey: false,
          ),
          modelSelection: ModelSelection(profileId: 'p', modelId: 'model'),
          systemPrompt: '',
        ),
        createdAt: DateTime(2026),
      ),
    );
    await ToolCallRepository(db).create(
      ToolCallRecord(
        id: 'call',
        runId: 'run',
        assistantMessageId: 'answer',
        toolName: 'read_file',
        arguments: const {'reference': 'sample.txt'},
        channel: ExecutionChannel.app,
        defaultPolicy: ToolPolicy.allow,
        status: ToolCallStatus.succeeded,
        result: '升级前的实际结果',
        createdAt: DateTime(2026),
      ),
    );
    // 构造安装前 v3 的真实表结构，避免接触手机数据或凭据。
    await db.customStatement('DROP TABLE mcp_servers');
    await db.customStatement('ALTER TABLE tool_calls DROP COLUMN source_json');
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    for (var reopen = 0; reopen < 2; reopen++) {
      db = openAppDatabase(path: path, hexKey: key, background: false);
      await db.assertEncryptionAvailable();
      final thread = (await ConversationRepository(db)
          .getThread(conversation.id))!;
      expect(thread.conversation.title, '升级前样本');
      expect(thread.messages.single.text, '保留这条样本消息');
      expect(
        (await AssistantRepository(db).getById(assistant.id))!.name,
        assistant.name,
      );
      expect(
        (await AgentRunRepository(db).getById('run'))!.status,
        RunStatus.completed,
      );
      final record = await ToolCallRepository(db).getById('call');
      expect(record.result, '升级前的实际结果');
      expect(record.status, ToolCallStatus.succeeded);
      expect(record.source, isNull);
      expect(
        await McpServerRepository(
          db,
          SecureKeyStorage(FakeSecureStorage()),
        ).list(),
        isEmpty,
      );
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        4,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      if (reopen == 0) await db.close();
    }
  });
}
