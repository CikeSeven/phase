import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/skill_repository.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/providers/provider_factory.dart';

import '../mcp/mcp_model_fixtures.dart';
import '../tools/tool_loop_harness.dart';
import 'skill_test_support.dart';

void main() {
  for (final protocol in ApiProtocol.values) {
    test('${protocol.name} 真实适配器 → 按需读取指导 → 文件读取 → 确认写入 → 回填与落库', () async {
      final gateway = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => gateway.close(force: true));
      final payloads = <Map<String, dynamic>>[];
      late String skillId;
      gateway.listen((request) async {
        payloads.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(switch (payloads.length) {
          1 => mcpCallSse(
            protocol,
            'read_skill',
            arguments: {'skillId': skillId},
            callId: 'skill',
          ),
          2 => mcpCallSse(
            protocol,
            'read_file',
            arguments: {'reference': 'sample.txt'},
            callId: 'document',
          ),
          3 => mcpCallSse(
            protocol,
            'write_file',
            arguments: {'path': 'summary.md', 'content': '# 摘要\n月相记录：初七上弦。'},
            callId: 'summary',
          ),
          _ => mcpAnswerSse(protocol),
        });
        await request.response.close();
      });
      final h = await ToolLoopHarness.create(
        protocol: protocol,
        factory: (profile, _) => buildAiProvider(
          profile.copyWith(
            baseUrl: 'http://127.0.0.1:${gateway.port}/v1',
            requiresKey: false,
          ),
          '',
        ),
      );
      final repository = await h.container.read(skillRepositoryProvider.future);
      final source = Directory('${h.tempDir.path}/document-skill');
      await source.create();
      await File('${source.path}/SKILL.md').writeAsString(sampleSkill);
      final prepared = await repository.packages.prepare(
        source.path,
        zip: false,
        cancellation: RunCancellation(),
      );
      final skill = await repository.install(prepared, RunCancellation());
      skillId = skill.id;
      final assistants = await h.container.read(
        assistantRepositoryProvider.future,
      );
      final assistant = await assistants.ensureDefault();
      await assistants.save(assistant.copyWith(skillIds: {skill.id}));
      final attachment =
          await (await h.container.read(attachmentStorageProvider.future)).save(
            name: 'sample.txt',
            mimeType: 'text/plain',
            kind: AttachmentKind.text,
            bytes: utf8.encode('月相记录：初七上弦。'),
          );
      final confirmations = <String>[];
      h.onConfirmation = (request) async {
        confirmations.add(request.record.toolName);
        return ToolDecision.approved;
      };
      await h.controller().send('按照整理文档 Skill 生成摘要', attachments: [attachment]);
      expect(payloads, hasLength(4));
      expect(jsonEncode(payloads.first), contains(skill.id));
      expect(jsonEncode(payloads.first), isNot(contains('读取文档中的实际内容')));
      expect(jsonEncode(payloads[1]), contains('读取文档中的实际内容'));
      expect(jsonEncode(payloads[1]), contains(skill.snapshot.revision));
      expect(jsonEncode(payloads[2]), contains('初七上弦'));
      expect(confirmations, ['read_skill', 'write_file']);
      final records = await (await h.toolCalls()).getByRun(
        (await h.latestRun()).id,
      );
      expect(records, hasLength(3));
      expect(
        records.every((r) => r.status == ToolCallStatus.succeeded),
        isTrue,
      );
      final read = records.firstWhere((r) => r.toolName == 'read_skill');
      expect(await h.resultTextOf(read), contains(skill.snapshot.revision));
      expect(
        await File('${h.artifactsDir(h.conversationId()!).path}/summary.md')
            .readAsString(),
        '# 摘要\n月相记录：初七上弦。',
      );
      expect((await h.latestRun()).status, RunStatus.completed);
      expect((await h.latestRun()).configuration.skills.single.id, skill.id);
      expect((await h.branch()).last.text, '已读取月相记录');
    });
  }
}
