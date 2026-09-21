import 'package:phase/data/models/agent_plan.dart';
import 'package:phase/data/models/memory_entry.dart';
import 'package:phase/data/repositories/memory_repository.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/skill_installation.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/mcp_server_profile.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/agent_run_repository.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/mcp_server_repository.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/data/repositories/skill_repository.dart';
import 'package:phase/data/repositories/tool_call_repository.dart';

import '../../../support/fake_secure_storage.dart';

/// 本次装机的 v6 → v7 增量例外。只使用假配置、假密钥和临时加密库。
void main() {
  test('E5 覆盖升级保留十三张旧表、工作区、Skills、MCP 和凭据，重开不重复建表', () async {
    final directory = Directory.systemTemp.createTempSync('phase_e5_upgrade');
    final path = '${directory.path}/phase.sqlite';
    const key =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    var db = openAppDatabase(path: path, hexKey: key, background: false);
    addTearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
    });
    final fakeKeys = FakeSecureStorage();
    final keys = SecureKeyStorage(fakeKeys);
    final profile = await ProviderProfileRepository(db, keys).createProfile(
      name: '测试模型配置',
      baseUrl: 'https://model.example.test/v1',
      models: const [ProfileModel(id: 'fixture-model')],
      defaultModel: 'fixture-model',
    );
    await keys.write(profile.id, 'fixture-model-key');
    final mcp = McpServerRepository(db, keys);
    final server = await mcp.save(
      McpServerProfile(
        id: 'fixture-server',
        name: '测试 MCP',
        endpoint: 'https://mcp.example.test/mcp',
        definitionRevision: 'fixture-revision',
        requiresBearer: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      bearer: 'fixture-mcp-key',
      headers: {'X-Fixture': 'fixture-header'},
    );
    final tool = mcpToolSnapshot(server, {
      'name': 'read_sample',
      'description': '样本文档',
      'inputSchema': {'type': 'object', 'properties': <String, dynamic>{}},
    });
    await mcp.saveCatalog(server, [tool], '2025-06-18');
    final skillFile = File('${directory.path}/installed-skill/SKILL.md');
    await skillFile.parent.create(recursive: true);
    await skillFile.writeAsString('fixture skill original');
    final skill = SkillSnapshot(
      id: 'fixture-skill',
      name: '样本 Skill',
      description: '固定版本指导',
      revision: 'fixture-revision',
      source: '本地测试',
      installedPath: skillFile.parent.path,
      resources: {},
    );
    await db
        .into(db.skillInstallations)
        .insert(
          SkillInstallationsCompanion.insert(
            id: skill.id,
            name: skill.name,
            snapshotJson: jsonEncode(skill.toJson()),
            installedAt: DateTime(2026),
          ),
        );
    final assistants = AssistantRepository(db);
    final assistant = (await assistants.ensureDefault()).copyWith(
      systemPrompt: '保留系统提示词',
      skillIds: {skill.id},
      defaultModelSelection: ModelSelection(
        profileId: profile.id,
        modelId: 'fixture-model',
      ),
      toolPolicy: (await assistants.ensureDefault()).toolPolicy.withPolicy(
        tool.name,
        ToolPolicy.ask,
      ),
    );
    await assistants.save(assistant);
    final conversations = ConversationRepository(
      db,
      workspaces: WorkspaceRepository(db, directory),
    );
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
    await conversations.saveAttachment(
      Attachment(
        id: 'artifact',
        conversationId: conversation.id,
        kind: AttachmentKind.artifact,
        name: 'sample.txt',
        mimeType: 'text/plain',
        size: 6,
        localPath: '/fixture/sample.txt',
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
        finishReason: RunFinishReason.completed,
        createdAt: DateTime(2026),
        configuration: RunConfiguration(
          connection: RunConnection(
            profileId: profile.id,
            protocol: 'openaiCompletions',
            baseUrl: profile.baseUrl,
            requiresKey: true,
          ),
          modelSelection: ModelSelection(
            profileId: profile.id,
            modelId: 'fixture-model',
          ),
          systemPrompt: assistant.systemPrompt,
          enabledTools: {tool.name},
          toolSnapshots: [tool],
          mcpServers: [server],
          skills: [skill],
        ),
      ),
    );
    await conversations.appendMessage(
      ChatMessage(
        id: 'answer',
        parentId: 'input',
        runId: 'run',
        conversationId: conversation.id,
        role: ChatRole.assistant,
        parts: const [
          ReasoningPart(publicText: '公开思考样本'),
          TextPart(text: '结果'),
          ToolCallPart(toolCallId: 'call'),
        ],
        createdAt: DateTime(2026),
      ),
    );
    await ToolCallRepository(db).create(
      ToolCallRecord(
        id: 'call',
        runId: 'run',
        assistantMessageId: 'answer',
        toolName: tool.name,
        source: tool.source,
        arguments: const {},
        channel: ExecutionChannel.app,
        defaultPolicy: ToolPolicy.ask,
        status: ToolCallStatus.succeeded,
        result: '升级前的实际结果',
        artifacts: const ['artifact'],
        createdAt: DateTime(2026),
      ),
    );

    final workspaces = WorkspaceRepository(db, directory);
    await workspaces.saveEnvironment(
      const RuntimeEnvironment(
        phase: EnvironmentPhase.ready,
        rootPath: '/fixture',
        revision: 'fixture',
      ),
    );
    await workspaces.recordCopy(conversation.workspaceId!, 'sample.txt', {
      'kind': 'fixture',
    });

    // 从当前初版结构去掉本批唯一的新增字段，构造本次已安装 E4 的 schema 6。
    final run =
        (await db
                .customSelect('SELECT configuration_json FROM agent_runs')
                .getSingle())
            .read<String>('configuration_json');
    final config = jsonDecode(run) as Map<String, dynamic>;
    for (final key in [
      'mode',
      'contextWindow',
      'planId',
      'planRevision',
      'approvedPlan',
      'memoryScope',
    ]) {
      config.remove(key);
    }
    await db.customStatement('UPDATE agent_runs SET configuration_json = ?', [
      jsonEncode(config),
    ]);
    await db.customStatement('DROP TABLE context_summaries');
    await db.customStatement('DROP TABLE agent_plans');
    await db.customStatement('DROP TABLE memory_entries');
    await db.customStatement('ALTER TABLE assistants DROP COLUMN memory_scope');
    await db.customStatement('PRAGMA user_version = 6');
    const tables = [
      'provider_profiles',
      'models',
      'assistants',
      'conversations',
      'messages',
      'attachments',
      'agent_runs',
      'tool_calls',
      'mcp_servers',
      'skill_installations',
      'runtime_environments',
      'workspaces',
      'workspace_copies',
    ];
    final before = <String, List<Map<String, dynamic>>>{};
    for (final table in tables) {
      before[table] =
          (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
              .map((r) => r.data)
              .toList();
      expect(before[table], isNotEmpty, reason: '$table 必须有待保留的真实样本行');
    }
    final secretsBefore = Map.of(fakeKeys.values);
    await db.close();

    for (var reopen = 0; reopen < 2; reopen++) {
      db = openAppDatabase(path: path, hexKey: key, background: false);
      await db.assertEncryptionAvailable();
      for (final table in tables) {
        final after =
            (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
                .map((row) {
                  final values = {...row.data};
                  if (table == 'assistants') values.remove('memory_scope');
                  return values;
                })
                .toList();
        expect(after, before[table], reason: '$table 的所有旧列必须保持');
      }
      final restored = (await AssistantRepository(db).getById(assistant.id))!;
      expect(restored.skillIds, {skill.id});
      expect(restored.memoryScope, MemoryScope.disabled);
      expect(
        (await AgentRunRepository(db).getById('run'))!.configuration.mode,
        AgentMode.execute,
      );
      expect(restored.toolPolicy.policies[tool.name], ToolPolicy.ask);
      expect(
        (await AgentRunRepository(db).getById('run'))!
            .configuration
            .skills
            .single
            .toJson(),
        skill.toJson(),
      );
      expect(
        (await McpServerRepository(db, keys).get(server.id))!
            .tools
            .single
            .source
            .definitionRevision,
        tool.source.definitionRevision,
      );
      expect(
        (await SkillRepository(
          db,
          Directory('${directory.path}/skills'),
        ).list()).single.snapshot.toJson(),
        skill.toJson(),
      );
      expect(
        (await ConversationRepository(
          db,
          workspaces: WorkspaceRepository(db, directory),
        ).getThread(conversation.id))!.conversation.workspaceId,
        conversation.workspaceId,
      );
      expect(await db.select(db.contextSummaries).get(), isEmpty);
      expect(await db.select(db.agentPlans).get(), isEmpty);
      expect(await db.select(db.memoryEntries).get(), isEmpty);
      expect(await skillFile.readAsString(), 'fixture skill original');
      expect(fakeKeys.values, secretsBefore);
      expect(await keys.read(profile.id), 'fixture-model-key');
      expect(await keys.readMcp(server.credentialRef!), 'fixture-mcp-key');
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        7,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      if (reopen == 0) await db.close();
      if (reopen == 1) {
        final memories = MemoryRepository(db);
        final entry = await memories.add(
          content: '升级后的记忆',
          assistantId: assistant.id,
          sourceMessageId: 'input',
          sourceRunId: 'run',
        );
        expect(
          (await memories.search(
            '升级',
            assistantId: assistant.id,
            scope: MemoryScope.assistant,
          )).single.id,
          entry.id,
        );
        await memories.delete(entry.id);
        await AssistantRepository(db)
            .save(restored.copyWith(memoryScope: MemoryScope.assistant));
        expect(
          (await AssistantRepository(db).getById(assistant.id))!.memoryScope,
          MemoryScope.assistant,
        );
      }
    }
  });
}
