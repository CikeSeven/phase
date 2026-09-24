import 'dart:convert';
import 'dart:io';

import 'package:phase/data/datasources/local/database_key.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/mcp_server_profile.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/skill_installation.dart';
import 'package:phase/data/models/token_usage.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

const schema8Key =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

/// 来自实际 schema 8 定义的假数据，不借助当前 schema 降版本伪造升级。
void createSchema8Fixture(String path) {
  final db = raw.sqlite3.open(path);
  try {
    db.execute(sqliteKeyPragma(schema8Key));
    db.execute(File('test/fixtures/database/schema8.sql').readAsStringSync());
    db.execute('PRAGMA foreign_keys = ON');
    void insert(String table, Map<String, Object?> fields) => db.execute(
      'INSERT INTO "$table" (${fields.keys.map((k) => '"$k"').join(',')}) VALUES (${fields.keys.map((_) => '?').join(',')})',
      fields.values.toList(),
    );
    const selection = ModelSelection(profileId: 'profile', modelId: 'fixture');
    final server = McpServerProfile(
      id: 'server',
      name: 'fixture MCP',
      endpoint: 'https://fixture.invalid/mcp',
      definitionRevision: 'fixture',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final tool = mcpToolSnapshot(server, {
      'name': 'read_sample',
      'description': 'fixture',
      'inputSchema': {'type': 'object'},
    });
    final skill = SkillSnapshot(
      id: 'skill',
      name: 'sample',
      description: 'fixture',
      revision: 'one',
      source: 'test',
      installedPath: '/fixture/skill',
      resources: {},
    );
    insert('provider_profiles', {
      'id': 'profile',
      'name': 'fixture profile',
      'protocol': 'openaiCompletions',
      'base_url': 'https://fixture.invalid',
      'default_model': 'fixture',
      'created_at': 1,
    });
    insert('models', {
      'profile_id': 'profile',
      'model_id': 'fixture',
      'supports_tools': 1,
    });
    insert('mcp_servers', {
      'id': 'server',
      'profile_json': jsonEncode(server.toJson()),
      'tools_json': jsonEncode([tool.toJson()]),
    });
    insert('skill_installations', {
      'id': 'skill',
      'name': 'sample',
      'snapshot_json': jsonEncode(skill.toJson()),
      'installed_at': 1,
    });
    insert('runtime_environments', {
      'id': 'default',
      'configuration_json': jsonEncode(
        const RuntimeEnvironment(
          phase: EnvironmentPhase.ready,
          rootPath: '/fixture',
          revision: 'one',
        ).toJson(),
      ),
    });
    insert('workspaces', {
      'id': 'workspace',
      'name': 'fixture workspace',
      'environment_id': 'default',
      'created_at': 1,
    });
    insert('workspace_copies', {
      'workspace_id': 'workspace',
      'relative_path': 'sample.txt',
      'source_json': '{"kind":"fixture"}',
    });
    insert('assistants', {
      'id': 'assistant-default',
      'name': 'fixture assistant',
      'system_prompt': '保留系统提示',
      'default_selection_json': jsonEncode(selection.toJson()),
      'created_at': 1,
      'skill_ids_json': '["skill"]',
      'memory_scope': 'assistant',
      'tool_policy_json': jsonEncode({
        'shell': 'allow',
        'app_operations': 'allow',
        tool.name: 'ask',
        'mcp_missing_catalog_tool': 'allow',
        'mcp_denied_tool': 'deny',
        'write_file': 'deny',
      }),
    });
    insert('assistants', {'id': 'empty', 'name': 'empty', 'created_at': 2});
    insert('conversations', {
      'id': 'c',
      'title': '保留会话',
      'assistant_id': 'assistant-default',
      'current_message_id': 'result',
      'workspace_id': 'workspace',
      'selection_json': jsonEncode(selection.toJson()),
      'pinned': 1,
      'created_at': 1,
      'updated_at': 2,
    });
    final config =
        RunConfiguration(
            connection: const RunConnection(
              profileId: 'profile',
              protocol: 'openaiCompletions',
              baseUrl: 'https://fixture.invalid',
              requiresKey: true,
            ),
            modelSelection: selection,
            systemPrompt: '保留运行提示',
            enabledTools: {tool.name, 'shell'},
            toolSnapshots: [tool],
            mcpServers: [server],
            skills: [skill],
          ).toJson()
          ..['mode'] = 'execute'
          ..remove('planExecutionMode');
    config['toolPolicies'] = {
      tool.name: 'ask',
      'shell': 'deny',
      'install_packages': 'allow',
    };
    for (final mode in ['execute', 'plan']) {
      insert('agent_runs', {
        'id': mode,
        'conversation_id': 'c',
        'assistant_id': 'assistant-default',
        'input_message_id': 'input',
        'current_message_id': 'result',
        'configuration_json': jsonEncode({...config, 'mode': mode}),
        'status': 'completed',
        'finish_reason': 'completed',
        'max_turns': 0,
        'created_at': 1,
        'finished_at': 2,
      });
    }
    insert('messages', {
      'id': 'input',
      'conversation_id': 'c',
      'role': 'user',
      'status': 'completed',
      'parts_json': '[{"type":"text","text":"用户消息"}]',
      'created_at': 1,
    });
    insert('messages', {
      'id': 'answer',
      'conversation_id': 'c',
      'parent_id': 'input',
      'run_id': 'execute',
      'role': 'assistant',
      'status': 'completed',
      'parts_json': '[{"type":"text","text":"模型正文"},{"type":"toolCall","toolCallId":"call"}]',
      'created_at': 2,
    });
    insert('messages', {
      'id': 'result',
      'conversation_id': 'c',
      'parent_id': 'answer',
      'run_id': 'execute',
      'role': 'tool',
      'status': 'completed',
      'parts_json':
          '[{"type":"toolResult","toolResultId":"call"}]',
      'created_at': 3,
    });
    insert('attachments', {
      'id': 'attachment',
      'conversation_id': 'c',
      'kind': 'artifact',
      'name': 'sample.txt',
      'mime_type': 'text/plain',
      'size': 7,
      'local_path': '/fixture/sample.txt',
      'created_at': 1,
    });
    insert('tool_calls', {
      'id': 'call',
      'run_id': 'execute',
      'assistant_message_id': 'answer',
      'result_message_id': 'result',
      'tool_name': tool.name,
      'source_json': jsonEncode(tool.source.toJson()),
      'arguments_json': '{}',
      'channel': 'app',
      'default_policy': 'ask',
      'status': 'succeeded',
      'decision': 'approved',
      'result': '返回结果',
      'artifacts_json': '["attachment"]',
      'created_at': 1,
      'started_at': 1,
      'finished_at': 2,
    });
    insert('context_summaries', {
      'id': 'summary',
      'conversation_id': 'c',
      'run_id': 'execute',
      'branch_end_id': 'result',
      'covered_ids_json': '["input","answer","result"]',
      'fingerprint': 'fixture',
      'source_model': 'fixture',
      'version': 2,
      'status': 'completed',
      'content': '保留摘要',
      'checkpoint_json': '{"adoption":"applied"}',
      'created_at': 3,
    });
    insert('model_requests', {
      'id': 'request',
      'conversation_id': 'c',
      'run_id': 'execute',
      'logical_turn': 1,
      'attempt_index': 1,
      'purpose': 'chat',
      'status': 'completed',
      'profile_id': 'profile',
      'protocol': 'openaiCompletions',
      'requested_model_id': 'fixture',
      'assistant_message_id': 'answer',
      'usage_json': jsonEncode(
        const TokenUsage(
          promptTokens: 100,
          cacheReadTokens: 80,
          outputTokens: 20,
        ).toJson(),
      ),
      'context_json': '{}',
      'created_at': 1,
      'started_at': 1,
      'finished_at': 2,
    });
    insert('usage_archives', {
      'conversation_id': 'c',
      'source_kind': 'message',
      'source_id': 'old',
      'report_json': '{"input":41}',
    });
    insert('agent_plans', {
      'id': 'plan',
      'revision': 1,
      'conversation_id': 'c',
      'source_run_id': 'plan',
      'source_message_id': 'answer',
      'title': '旧计划',
      'steps_json': '["读取资料"]',
      'status': 'draft',
      'created_at': 2,
    });
    insert('memory_entries', {
      'id': 'memory',
      'assistant_id': 'assistant-default',
      'source_message_id': 'input',
      'source_run_id': 'execute',
      'content': '长期偏好',
      'created_at': 1,
      'updated_at': 2,
    });
  } finally {
    db.close();
  }
}

raw.Database openSchemaFixture(String path) {
  final db = raw.sqlite3.open(path);
  db.execute(sqliteKeyPragma(schema8Key));
  return db;
}

Map<String, List<Map<String, Object?>>> schemaFixtureSnapshot(
  raw.Database db,
) => {
  for (final table in db.select(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  ))
    table['name'] as String: [
      for (final row in db.select(
        'SELECT * FROM "${table['name']}" ORDER BY rowid',
      ))
        Map<String, Object?>.from(row),
    ],
};
