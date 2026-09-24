import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/models/permission_mode.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/agent_run_repository.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/model_request_repository.dart';
import 'package:phase/data/repositories/plan_repository.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/data/repositories/workspace_repository.dart';

import '../../../support/fake_secure_storage.dart';
import '../../../support/schema8_fixture.dart';

void main() {
  for (final background in [false, true]) {
    test('真实 schema 8 → 9 保留全部表、运行快照与凭据，重复重开 $background', () async {
      final directory = Directory.systemTemp.createTempSync(
        'phase_permission_upgrade',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = '${directory.path}/phase.sqlite';
      createSchema8Fixture(path);
      final old = openSchemaFixture(path);
      final before = schemaFixtureSnapshot(old);
      old.close();
      final keys = FakeSecureStorage({
        'database_key': schema8Key,
        'provider_profile': 'fixture-secret',
        'mcp_secret': 'fixture-mcp-secret',
      });
      final secrets = Map.of(keys.values);
      final artifact = File('${directory.path}/sample.txt')
        ..writeAsStringSync('用户文件保持');
      for (var i = 0; i < 2; i++) {
        final db = await openDeviceDatabase(
          directory: directory,
          keyStore: keys,
          background: background,
        );
        try {
          final raw = openSchemaFixture(path);
          final after = schemaFixtureSnapshot(raw);
          expect(raw.select('PRAGMA user_version').single.values.single, 9);
          expect(
            raw.select('PRAGMA integrity_check').single.values.single,
            'ok',
          );
          expect(raw.select('PRAGMA foreign_key_check'), isEmpty);
          raw.close();
          expect(after.keys, before.keys);
          for (final table in before.keys) {
            final expected = before[table]!
                .map((r) => Map<String, Object?>.from(r))
                .toList();
            for (final row in expected) {
              if (table == 'assistants') {
                final policies = jsonDecode(
                  row.remove('tool_policy_json')! as String,
                ) as Map<String, dynamic>;
                row['mcp_tool_names_json'] = jsonEncode(
                  policies.entries
                      .where(
                        (e) => e.key.startsWith('mcp_') && e.value != 'deny',
                      )
                      .map((e) => e.key)
                      .toList()
                    ..sort(),
                );
              } else if (table == 'conversations') {
                row['permission_mode'] = 'basic';
                row['last_execution_mode'] = 'basic';
              } else if (table == 'agent_runs') {
                final config = jsonDecode(
                  row['configuration_json']! as String,
                ) as Map<String, dynamic>;
                config['mode'] = config['mode'] == 'plan' ? 'plan' : 'basic';
                config['planExecutionMode'] = 'basic';
                row['configuration_json'] = jsonEncode(config);
              }
            }
            expect(after[table], expected, reason: '$table 必须完整保留，除明确授权的字段转换');
          }
          final repo = ConversationRepository(
            db,
            workspaces: WorkspaceRepository(db, directory),
          );
          final conversations = await repo.watchConversations().first;
          expect(conversations.single.title, '保留会话');
          expect(conversations.single.permissions, const PermissionSelection());
          expect((await repo.getThread('c'))!.branch.length, 3);
          expect(
            (await AssistantRepository(db).getById('assistant-default'))!
                .skillIds,
            {'skill'},
          );
          expect(
            (await AgentRunRepository(db).getById('execute'))!
                .configuration
                .mode,
            PermissionMode.basic,
          );
          expect(
            (await AgentRunRepository(db).getById('plan'))!.configuration.mode,
            PermissionMode.plan,
          );
          expect(
            (await AgentRunRepository(db).getById('plan'))!
                .configuration
                .planExecutionMode,
            PermissionMode.basic,
          );
          expect(
            (await AgentRunRepository(db).getById('execute'))!
                .configuration
                .toolPolicies['shell'],
            ToolPolicy.deny,
          );
          expect((await PlanRepository(db).latest('plan')).revision, 1);
          expect(
            (await ModelRequestRepository(db).list('c'))
                .single
                .usage!
                .cacheReadTokens,
            80,
          );
          expect(
            (await ProviderProfileRepository(
              db,
              SecureKeyStorage(keys),
            ).watchProfiles().first).single.name,
            'fixture profile',
          );
          expect(keys.values, secrets);
          expect(artifact.readAsStringSync(), '用户文件保持');
          if (i == 1) {
            await repo.setPermissionMode('c', PermissionMode.fullAccess);
            expect(
              (await repo.getThread('c'))!.conversation.permissions.mode,
              PermissionMode.fullAccess,
            );
            final a = (await AssistantRepository(db)
                .getById('assistant-default'))!;
            await AssistantRepository(db).save(a.copyWith(name: '更新后的助手'));
            expect(
              (await AssistantRepository(db).getById(a.id))!.name,
              '更新后的助手',
            );
          }
        } finally {
          await db.close();
        }
      }
    });
  }

  for (final failure in ['assistant', 'run', 'foreignKey']) {
    test('8 → 9 的 $failure 异常整体回滚，原版本和全部内容保留，可重试', () async {
      final dir = Directory.systemTemp.createTempSync('phase_upgrade_rollback');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/phase.sqlite';
      createSchema8Fixture(path);
      final original = openSchemaFixture(path);
      final sql = switch (failure) {
        'assistant' => "UPDATE assistants SET tool_policy_json = '{private malformed' WHERE id = 'empty'",
        'run' => "UPDATE agent_runs SET configuration_json = '{private malformed' WHERE id = 'plan'",
        _ => "UPDATE attachments SET conversation_id='missing' WHERE id='attachment'",
      };
      final good = schemaFixtureSnapshot(original);
      original.execute(sql);
      final before = schemaFixtureSnapshot(original);
      final schemaBefore = original
          .select(
            "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY name",
          )
          .map((r) => r.values.single)
          .toList();
      original.close();
      await expectLater(
        openDeviceDatabase(
          directory: dir,
          keyStore: FakeSecureStorage({'database_key': schema8Key}),
          background: false,
        ),
        throwsA(isA<OperationFailure>()),
      );
      final after = openSchemaFixture(path);
      expect(schemaFixtureSnapshot(after), before);
      expect(after.select('PRAGMA user_version').single.values.single, 8);
      expect(
        after
            .select(
              "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY name",
            )
            .map((r) => r.values.single)
            .toList(),
        schemaBefore,
      );
      if (failure == 'assistant') {
        after.execute('UPDATE assistants SET tool_policy_json=? WHERE id=?', [
          good['assistants']!.last['tool_policy_json'],
          'empty',
        ]);
      } else if (failure == 'run') {
        after.execute('UPDATE agent_runs SET configuration_json=? WHERE id=?', [
          good['agent_runs']!.last['configuration_json'],
          'plan',
        ]);
      } else {
        after.execute(
          "UPDATE attachments SET conversation_id='c' WHERE id='attachment'",
        );
      }
      after.close();
      final db = await openDeviceDatabase(
        directory: dir,
        keyStore: FakeSecureStorage({'database_key': schema8Key}),
        background: false,
      );
      await db.close();
    });
  }
}
