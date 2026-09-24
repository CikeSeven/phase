import 'package:phase/data/models/chat_chunk.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/skill_repository.dart';
import 'package:phase/features/tools/tool.dart';

import '../tools/tool_loop_harness.dart';
import 'skill_test_support.dart';

void main() {
  for (final action in ['disable', 'removeScope', 'delete', 'update']) {
    test('模型输出期间 $action：保持来源、版本和实际终态', () async {
      final h = await ToolLoopHarness.create();
      final repository = await h.container.read(skillRepositoryProvider.future);
      final folder = Directory('${h.tempDir.path}/source');
      await folder.create();
      await File('${folder.path}/SKILL.md')
          .writeAsString('$sampleSkill\n旧版唯一标记');
      final package = await repository.packages.prepare(
        folder.path,
        zip: false,
        cancellation: RunCancellation(),
      );
      final skill = await repository.install(package, RunCancellation());
      final assistants = await h.container.read(
        assistantRepositoryProvider.future,
      );
      final assistant = (await assistants.ensureDefault()).copyWith(
        skillIds: {skill.id},
      );
      await assistants.save(assistant);
      var confirmations = 0;
      h.onConfirmation = (_) async {
        confirmations++;
        return ToolDecision.approved;
      };
      Stream<ChatChunk> changedTurn() async* {
        switch (action) {
          case 'disable':
            await repository.setEnabled(skill.id, false);
          case 'removeScope':
            await assistants.save(assistant.copyWith(skillIds: {}));
          case 'delete':
            await repository.delete(skill.id);
          case 'update':
            await File('${folder.path}/SKILL.md')
                .writeAsString('$sampleSkill\n新版唯一标记');
            final updated = await repository.packages.prepare(
              folder.path,
              zip: false,
              cancellation: RunCancellation(),
            );
            await repository.install(
              updated,
              RunCancellation(),
              replaceId: skill.id,
            );
            await repository.collectGarbage();
        }
        yield* toolTurn(
          callId: 'read',
          toolName: 'read_skill',
          arguments: jsonEncode({'skillId': skill.id}),
        );
      }

      h.provider.turns.addAll([changedTurn(), textTurn('按实际结果结束')]);
      await h.controller().send('读取 Skill');
      expect(confirmations, 0);
      final record = (await h.recordsByCall()).values.single;
      if (action == 'update') {
        expect(record.status, ToolCallStatus.succeeded);
        expect(record.result, contains('旧版唯一标记'));
        expect(record.result, isNot(contains('新版唯一标记')));
        expect(record.result, contains(skill.snapshot.revision));
        expect(await Directory(skill.snapshot.installedPath).exists(), isFalse);
      } else {
        expect(record.status, isNot(ToolCallStatus.succeeded));
        expect(record.result, isNot(contains('旧版唯一标记')));
      }
      final run = await h.latestRun();
      expect(run.status, RunStatus.completed);
      expect(await h.resultTextOf(record), isNotNull);
      if (action == 'delete') expect(await repository.get(skill.id), isNull);
    });
  }
}
