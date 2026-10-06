import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/database_key.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_permission.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/agent_run_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/tool_call_repository.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

const _key = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  for (final background in [false, true]) {
    test('12 → 14 增加审计列与任务表，保留工具和运行，重复重开 $background', () async {
      final directory = Directory.systemTemp.createTempSync(
        'phase_permission_schema',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = '${directory.path}/phase.sqlite';
      var db = openAppDatabase(path: path, hexKey: _key, background: false);
      final conversation = await ConversationRepository(
        db,
        workspaces: WorkspaceRepository(db, directory),
      ).createConversation(title: 'preserved');
      await AgentRunRepository(db).create(
        AgentRun(
          id: 'run',
          conversationId: conversation.id,
          inputMessageId: 'input',
          createdAt: DateTime(2026),
          status: RunStatus.completed,
          configuration: const RunConfiguration(
            connection: RunConnection(
              profileId: 'p',
              protocol: 'openaiCompletions',
              baseUrl: 'https://example.com',
              requiresKey: false,
            ),
            modelSelection: ModelSelection(profileId: 'p', modelId: 'm'),
            systemPrompt: 'preserved',
          ),
        ),
      );
      await ToolCallRepository(db).create(
        ToolCallRecord(
          id: 'call',
          runId: 'run',
          assistantMessageId: 'message',
          toolName: 'http_request',
          arguments: const {'url': 'https://example.com'},
          channel: ExecutionChannel.app,
          defaultPolicy: ToolPolicy.allow,
          status: ToolCallStatus.succeeded,
          result: 'preserved result',
          createdAt: DateTime(2026),
        ),
      );
      await db.close();

      // Remove the post-12 structures to reconstruct the supported upgrade boundary.
      final fixture = raw.sqlite3.open(path)..execute(sqliteKeyPragma(_key));
      fixture.execute('ALTER TABLE tool_calls DROP COLUMN permission_json');
      fixture.execute('DROP TABLE command_tasks');
      fixture.execute('PRAGMA user_version = 12');
      final old = fixture.select('SELECT * FROM tool_calls').single;
      final before = Map<String, Object?>.from(old);
      fixture.close();
      for (var reopen = 0; reopen < 2; reopen++) {
        db = openAppDatabase(path: path, hexKey: _key, background: background);
        try {
          final rows = await db.select(db.toolCalls).get();
          expect(rows, hasLength(1));
          expect(rows.single.permissionJson, isNull);
          final row =
              (await db.customSelect('SELECT * FROM tool_calls').getSingle())
                  .data
                ..remove('permission_json');
          expect(row, before);
          expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .data
                .values
                .single,
            14,
          );
          expect(
            (await db.customSelect('PRAGMA quick_check').getSingle())
                .data
                .values
                .single,
            'ok',
          );
          expect(
            await db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
          expect(
            (await AgentRunRepository(db).getById('run'))!
                .configuration
                .systemPrompt,
            'preserved',
          );
          expect(
            (await db.select(db.conversations).get()).single.title,
            'preserved',
          );
        } finally {
          await db.close();
        }
      }
      db = openAppDatabase(path: path, hexKey: _key, background: background);
      try {
        final tools = ToolCallRepository(db);
        await tools.create(
          ToolCallRecord(
            id: 'new',
            runId: 'run',
            assistantMessageId: 'message',
            toolName: 'http_request',
            arguments: const {},
            channel: ExecutionChannel.app,
            defaultPolicy: ToolPolicy.ask,
            createdAt: DateTime.now(),
          ),
        );
        final permission = ToolPermissionDecision(
          policy: ToolPolicy.ask,
          request: ToolPermissionRequest(
            action: 'POST',
            effects: {ToolEffect.networkRequest},
          ),
          reason: 'fixture',
        );
        await tools.recordPermission('new', permission);
        expect(
          (await tools.getById('new')).permission!.toJson(),
          permission.toJson(),
        );
        await tools.requestConfirmation('new');
        expect(
          (await tools.recordDecision(
            'new',
            ToolDecision.approvedForRun,
          )).decision,
          ToolDecision.approvedForRun,
        );
      } finally {
        await db.close();
      }
    });
  }
}
