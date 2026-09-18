import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/assistant.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/features/workspace/workspace_controller.dart';
import 'package:phase/providers/provider_factory.dart';

import '../mcp/mcp_model_fixtures.dart';
import '../tools/tool_loop_harness.dart';
import 'local_process_driver.dart';

void main() {
  for (final protocol in ApiProtocol.values) {
    test(
      '${protocol.name}: real process stdout/stderr, nonzero exit, artifact, saved result and next model turn',
      () async {
        final gateway = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => gateway.close(force: true));
        final requests = <Map<String, dynamic>>[];
        gateway.listen((request) async {
          requests.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>,
          );
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          request.response.write(
            requests.length == 1
                ? mcpCallSse(
                    protocol,
                    'shell',
                    arguments: {
                      'command': 'mkdir -p /workspace/output; printf "月相记录" > /workspace/output/report.txt; printf "公开输出"; printf "诊断输出" >&2; exit 7',
                    },
                  )
                : mcpAnswerSse(protocol),
          );
          await request.response.close();
        });
        final processes = LocalProcessDriver();
        addTearDown(processes.dispose);
        final h = await ToolLoopHarness.create(
          protocol: protocol,
          processes: processes,
          factory: (profile, _) => buildAiProvider(
            profile.copyWith(
              baseUrl: 'http://127.0.0.1:${gateway.port}/v1',
              requiresKey: false,
            ),
            '',
          ),
        );
        final repo = await h.container.read(workspaceRepositoryProvider.future);
        final workspace = await repo.create('论文');
        await repo.saveEnvironment(
          const RuntimeEnvironment(
            phase: EnvironmentPhase.ready,
            rootPath: '/fixture/environment',
            revision: '24.04-fixture',
          ),
        );
        final chats = await h.container.read(
          conversationRepositoryProvider.future,
        );
        final assistants = await h.container.read(
          assistantRepositoryProvider.future,
        );
        final assistant = await assistants.ensureDefault();
        await assistants.save(
          assistant.copyWith(
            toolPolicy: const ToolPolicyConfig(
              policies: {'shell': ToolPolicy.ask},
            ),
          ),
        );
        final chat = await chats.createConversation(assistantId: assistant.id);
        await repo.bind(chat.id, workspace.id);
        await h.controller().openConversation(chat.id);
        final confirmations = <String>[];
        h.onConfirmation = (request) async {
          confirmations.add(request.summary);
          return ToolDecision.approved;
        };
        await h.controller().send('生成报告');
        final records = await (await h.toolCalls()).getByRun(
          (await h.latestRun()).id,
        );
        expect(requests, hasLength(2));
        expect(records.single.status, ToolCallStatus.failed);
        expect(records.single.result, contains('公开输出'));
        expect(records.single.result, contains('诊断输出'));
        expect(records.single.result, contains('"exitCode":7'));
        expect(records.single.artifacts, hasLength(3));
        expect(jsonEncode(requests.last), contains('公开输出'));
        expect(confirmations.single, contains('论文'));
        expect(confirmations.single, contains('exit 7'));
        expect(processes.active, isEmpty);
        expect(
          await File('${workspace.rootPath}/output/report.txt').readAsString(),
          '月相记录',
        );
        final attachments = await chats.attachmentsFor(chat.id);
        expect(attachments.any((a) => a.name == 'report.txt'), isTrue);
      },
    );
  }
}
