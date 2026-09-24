import 'package:phase/data/models/permission_mode.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/memory_entry.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/memory_repository.dart';
import 'package:phase/data/repositories/plan_repository.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/providers/provider_factory.dart';

import '../../mcp/mcp_model_fixtures.dart';
import '../../tools/tool_loop_harness.dart';

void main() {
  for (final protocol in ApiProtocol.values) {
    test('${protocol.name} 真实适配器计划提交 → 批准新运行 → 基础档直接记忆写入 → 检索回填', () async {
      final gateway = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => gateway.close(force: true));
      final payloads = <Map<String, dynamic>>[];
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
            'submit_plan',
            arguments: {
              'title': '记录偏好',
              'steps': ['保存用户指定的偏好', '读取检查'],
            },
            callId: 'plan',
          ),
          2 => mcpCallSse(
            protocol,
            'write_memory',
            arguments: {'content': '喜欢月相记录', 'scope': 'assistant'},
            callId: 'write',
          ),
          3 => mcpCallSse(
            protocol,
            'read_memory',
            arguments: {'query': '月相'},
            callId: 'read',
          ),
          _ => mcpAnswerSse(protocol),
        });
        await request.response.close();
      });
      final h = await ToolLoopHarness.create(
        protocol: protocol,
        registry: ToolRegistry([]),
        factory: (profile, _) => buildAiProvider(
          profile.copyWith(
            baseUrl: 'http://127.0.0.1:${gateway.port}/v1',
            requiresKey: false,
          ),
          '',
        ),
      );
      final assistants = await h.container.read(
        assistantRepositoryProvider.future,
      );
      await assistants.save(
        (await assistants.ensureDefault()).copyWith(
          memoryScope: MemoryScope.assistant,
        ),
      );
      await h.controller().setPermissionMode(PermissionMode.plan);
      await h.controller().send('规划如何记录我的偏好');
      expect(payloads, hasLength(1));
      expect(jsonEncode(payloads.first), isNot(contains('write_memory')));
      final p = (await PlanRepository(
        h.database,
      ).watch(h.conversationId()!).first).single;
      var confirmations = 0;
      h.onConfirmation = (_) async {
        confirmations++;
        return ToolDecision.approved;
      };
      await h.controller().approvePlan(p);
      expect(payloads, hasLength(4));
      expect(confirmations, 0);
      expect(jsonEncode(payloads[1]), contains('批准并执行计划'));
      expect(jsonEncode(payloads[3]), contains('喜欢月相记录'));
      expect(
        (await MemoryRepository(h.database).watch().first).single.sourceRunId,
        (await h.latestRun()).id,
      );
      expect(
        (await h.recordsByCall()).values.every(
          (r) => r.status == ToolCallStatus.succeeded,
        ),
        isTrue,
      );
    });
  }
}
