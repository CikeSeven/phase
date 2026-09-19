import 'dart:convert';
import 'dart:io';

import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
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
        expect(h.conversationId(), isNull);
        expect(await repo.list(), isEmpty);
        final confirmations = <String>[];
        h.onConfirmation = (request) async {
          confirmations.add(request.summary);
          return ToolDecision.approved;
        };
        await h.controller().send('生成报告');
        final chat = (await chats.getThread(h.conversationId()!))!.conversation;
        final workspace = (await repo.get(chat.workspaceId!))!;
        expect(jsonEncode(requests.first), contains('shell'));
        expect(jsonEncode(requests.first), contains('/workspace'));
        expect((await h.latestRun()).configuration.workspace!.id, workspace.id);
        final records = await (await h.toolCalls()).getByRun(
          (await h.latestRun()).id,
        );
        expect(requests, hasLength(2));
        expect(records.single.status, ToolCallStatus.failed);
        expect(records.single.result, contains('公开输出'));
        expect(records.single.result, contains('诊断输出'));
        expect(records.single.result, contains('"exitCode":7'));
        expect(records.single.artifacts, hasLength(1));
        expect(jsonEncode(requests.last), contains('公开输出'));
        expect(confirmations.single, contains('会话工作区'));
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
