import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/database_key.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/model_request_repository.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

const _tables = [
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
  'context_summaries',
  'agent_plans',
  'memory_entries',
];
const _usage =
    '{ "inputTokens": 20, "outputTokens": 8, "cachedInputTokens": 7 }';

void main() {
  for (final corruptReference in [false, true]) {
    test('本次 7 → 8 ${corruptReference ? '引用异常整体回滚' : '全部旧业务列与用量原样保留，重开和复制正常'}', () async {
      final directory = Directory.systemTemp.createTempSync(
        'phase_context_upgrade',
      );
      final path = '${directory.path}/phase.sqlite';
      final key = '0123456789abcdef' * 4;
      var db = openAppDatabase(path: path, hexKey: key, background: false);
      addTearDown(() async {
        await db.close();
        await directory.delete(recursive: true);
      });
      await db.assertEncryptionAvailable();
      final config = RunConfiguration(
        connection: const RunConnection(
          profileId: 'p',
          protocol: 'openaiCompletions',
          baseUrl: 'https://fixture.test',
          requiresKey: false,
        ),
        modelSelection: const ModelSelection(profileId: 'p', modelId: 'm'),
        systemPrompt: 'fixture',
      ).toJson();
      config.remove('contextPolicy');
      final insertions = <String, List<Object?>>{
        'INSERT INTO provider_profiles (id,name,protocol,base_url,created_at) VALUES (?,?,?,?,?)':
            ['p', 'fixture', 'openaiCompletions', 'https://fixture.test', 1],
        'INSERT INTO models (profile_id,model_id) VALUES (?,?)': ['p', 'm'],
        'INSERT INTO assistants (id,name,created_at) VALUES (?,?,?)': [
          'a',
          'fixture',
          1,
        ],
        'INSERT INTO runtime_environments (id,configuration_json) VALUES (?,?)':
            ['ubuntu', '{}'],
        'INSERT INTO workspaces (id,name,environment_id,created_at) VALUES (?,?,?,?)':
            ['w', 'fixture', 'ubuntu', 1],
        'INSERT INTO workspace_copies (workspace_id,relative_path,source_json) VALUES (?,?,?)':
            ['w', 'fixture.txt', '{}'],
        'INSERT INTO conversations (id,title,assistant_id,current_message_id,created_at,updated_at) VALUES (?,?,?,?,?,?)':
            ['c', 'fixture', 'a', 'message', 1, 1],
        'INSERT INTO messages (id,conversation_id,run_id,role,status,parts_json,created_at) VALUES (?,?,?,?,?,?,?)':
            [
              'message',
              'c',
              'run',
              'assistant',
              'completed',
              '[{"type":"text","text":"保留正文"}]',
              1,
            ],
        'INSERT INTO attachments (id,conversation_id,kind,name,mime_type,size,local_path,created_at) VALUES (?,?,?,?,?,?,?,?)':
            [
              'attachment',
              'c',
              'image',
              'fixture.png',
              'image/png',
              1,
              '/fixture/image.png',
              1,
            ],
        'INSERT INTO agent_runs (id,conversation_id,input_message_id,configuration_json,status,max_turns,created_at) VALUES (?,?,?,?,?,?,?)':
            ['run', 'c', 'message', jsonEncode(config), 'completed', 0, 1],
        'INSERT INTO tool_calls (id,run_id,assistant_message_id,tool_name,arguments_json,channel,default_policy,status,created_at) VALUES (?,?,?,?,?,?,?,?,?)':
            [
              'call',
              'run',
              'message',
              'read_file',
              '{"path":"fixture.txt"}',
              'app',
              'allow',
              'succeeded',
              1,
            ],
        'INSERT INTO mcp_servers (id,profile_json) VALUES (?,?)': ['mcp', '{}'],
        'INSERT INTO skill_installations (id,name,snapshot_json,installed_at) VALUES (?,?,?,?)':
            ['skill', 'fixture', '{}', 1],
        'INSERT INTO agent_plans (id,revision,conversation_id,source_run_id,source_message_id,title,steps_json,status,created_at) VALUES (?,?,?,?,?,?,?,?,?)':
            [
              'plan',
              1,
              'c',
              'run',
              'message',
              'fixture',
              '["保留计划"]',
              'draft',
              1,
            ],
        'INSERT INTO memory_entries (id,content,created_at,updated_at) VALUES (?,?,?,?)':
            ['memory', '保留记忆', 1, 1],
      };
      for (final entry in insertions.entries) {
        await db.customStatement(entry.key, entry.value);
      }
      // 仅构造本次已安装 E5 的真实表形态，不建设更早版本链。
      await db.customStatement('DROP TABLE model_requests');
      await db.customStatement('DROP TABLE usage_archives');
      await db.customStatement(
        'ALTER TABLE messages ADD COLUMN usage_json TEXT',
      );
      await db.customStatement(
        'ALTER TABLE agent_runs ADD COLUMN usage_json TEXT',
      );
      await db.customStatement('DROP TABLE context_summaries');
      await db.customStatement(
        'CREATE TABLE context_summaries (id TEXT NOT NULL PRIMARY KEY, conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, run_id TEXT NOT NULL, branch_end_id TEXT NOT NULL, covered_ids_json TEXT NOT NULL, fingerprint TEXT NOT NULL, source_model TEXT NOT NULL, version INTEGER NOT NULL, status TEXT NOT NULL, content TEXT NOT NULL, usage_json TEXT, created_at INTEGER NOT NULL)',
      );
      await db.customStatement(
        'INSERT INTO context_summaries VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          'summary',
          'c',
          'run',
          'message',
          '["message"]',
          'fixture',
          'p/m',
          1,
          'completed',
          '保留旧摘要',
          _usage,
          1,
        ],
      );
      await db.customStatement('UPDATE messages SET usage_json = ?', [_usage]);
      await db.customStatement('UPDATE agent_runs SET usage_json = ?', [
        _usage,
      ]);
      if (corruptReference) {
        await db.customStatement('PRAGMA foreign_keys = OFF');
        await db.customStatement("UPDATE tool_calls SET run_id = 'missing'");
      }
      final before = <String, List<Map<String, dynamic>>>{};
      for (final table in _tables) {
        before[table] =
            (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
                .map((r) => {...r.data}..remove('usage_json'))
                .toList();
      }
      await db.customStatement('PRAGMA user_version = 7');
      await db.close();
      db = openAppDatabase(path: path, hexKey: key, background: false);
      if (corruptReference) {
        await expectLater(
          db.assertEncryptionAvailable(),
          throwsA(isA<OperationFailure>()),
        );
        await db.close();
        final original = raw.sqlite3.open(path);
        try {
          original.execute(sqliteKeyPragma(key));
          expect(
            original.select('PRAGMA user_version').single['user_version'],
            7,
          );
          expect(
            original
                .select('SELECT usage_json FROM messages')
                .single['usage_json'],
            _usage,
          );
          expect(
            original.select(
              "SELECT name FROM sqlite_master WHERE name IN ('model_requests','usage_archives')",
            ),
            isEmpty,
          );
        } finally {
          original.close();
        }
        return;
      }
      for (var reopen = 0; reopen < 2; reopen++) {
        await db.assertEncryptionAvailable();
        for (final table in _tables) {
          final after =
              (await db
                      .customSelect('SELECT * FROM $table ORDER BY rowid')
                      .get())
                  .map((r) => {...r.data}..remove('checkpoint_json'))
                  .toList();
          expect(after, before[table], reason: '$table 原业务列不能改变');
        }
        expect(
          (await db.select(db.usageArchives).get()).map((a) => a.reportJson),
          [_usage, _usage, _usage],
        );
        expect(await ModelRequestRepository(db).list('c'), isEmpty);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
        await db.close();
        db = openAppDatabase(path: path, hexKey: key, background: false);
      }
      // 新结构允许手动摘要没有 runId；旧版摘要仅保留，不伪装为新检查点。
      await db.customStatement(
        "INSERT INTO context_summaries (id,conversation_id,run_id,branch_end_id,covered_ids_json,fingerprint,source_model,version,status,content,created_at) VALUES ('manual','c',NULL,'message','[]','fixture','p/m',2,'cancelled','',2)",
      );
      // 文件复制由既有专用用例覆盖，此处去除虚构附件，验证旧用量档案的归属。
      await db.delete(db.attachments).go();
      final conversations = ConversationRepository(
        db,
        workspaces: WorkspaceRepository(db, directory),
      );
      final copy = await conversations.duplicateConversation('c');
      await conversations.deleteConversation('c');
      expect(await ModelRequestRepository(db).list(copy.id), isEmpty);
      expect(
        (await db.select(db.usageArchives).get()).every(
          (a) => a.conversationId == copy.id && a.reportJson == _usage,
        ),
        isTrue,
      );
      expect(await db.select(db.usageArchives).get(), hasLength(3));
    });
  }
}
