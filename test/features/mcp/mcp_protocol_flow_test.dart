import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/tool_source.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/mcp_server_repository.dart';
import 'package:phase/features/mcp/mcp_client.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/providers/provider_factory.dart';

import '../tools/tool_loop_harness.dart';
import 'mcp_test_server.dart';
import 'mcp_model_fixtures.dart';

void main() {
  for (final protocol in ApiProtocol.values) {
    for (final images in [true, false]) {
      test('${protocol.name} 原始 SSE → MCP 确认/HTTP/保存/回填/最终回答，图片 $images', () async {
        final mcp = await McpTestServer.start();
        addTearDown(mcp.close);
        mcp.mode = 'sse';
        const png =
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=';
        mcp.result = {
          'content': [
            {'type': 'text', 'text': '样本文档：月相记录。'},
            {'type': 'image', 'mimeType': 'image/png', 'data': png},
          ],
          'structuredContent': {'title': '月相记录', 'pages': 2},
        };
        final gateway = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => gateway.close(force: true));
        final payloads = <Map<String, dynamic>>[];
        late String toolName;
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
          request.response.write(
            payloads.length == 1
                ? mcpCallSse(protocol, toolName)
                : mcpAnswerSse(protocol),
          );
          await request.response.close();
        });
        final h = await ToolLoopHarness.create(
          protocol: protocol,
          models: [
            ProfileModel(
              id: 'model-a',
              supportsTools: true,
              supportsImages: images,
            ),
          ],
          factory: (profile, _) => buildAiProvider(
            profile.copyWith(
              baseUrl: 'http://127.0.0.1:${gateway.port}/v1',
              requiresKey: false,
            ),
            '',
          ),
        );
        final repository = await h.container.read(
          mcpServerRepositoryProvider.future,
        );
        final saved = await repository.save(mcp.profile());
        final discovery = McpClient(saved, bearer: null);
        final tools = await discovery.connect(RunCancellation());
        await repository.saveCatalog(saved, tools, discovery.protocolVersion!);
        await discovery.close();
        toolName = tools.single.name;
        final assistants = await h.container.read(
          assistantRepositoryProvider.future,
        );
        final assistant = await assistants.ensureDefault();
        await assistants.save(
          assistant.copyWith(
            toolPolicy: assistant.toolPolicy.withPolicy(
              toolName,
              ToolPolicy.ask,
            ),
          ),
        );
        var confirmations = 0;
        h.onConfirmation = (request) async {
          confirmations++;
          expect(request.record.source?.originalName, 'read_sample');
          expect(request.summary, contains('样本文档'));
          return ToolDecision.approved;
        };
        await h
            .controller()
            .send('读取样本文档')
            .timeout(const Duration(seconds: 15));
        expect(confirmations, 1);
        expect(mcp.calls, 1);
        expect(payloads, hasLength(2));
        expect(jsonEncode(payloads.first), contains(toolName));
        final record = (await h.recordsByCall()).values.single;
        expect(record.status, ToolCallStatus.succeeded);
        expect(record.source?.kind, ToolSourceKind.mcp);
        expect(
          record.source?.definitionRevision,
          tools.single.source.definitionRevision,
        );
        expect(record.result, contains('月相记录'));
        expect(jsonEncode(payloads.last), contains('月相记录'));
        expect((await h.branch()).last.text, '已读取月相记录');
        final run = await h.latestRun();
        expect(run.status, RunStatus.completed);
        expect(run.configuration.mcpServers.single.endpoint, saved.endpoint);
        expect(
          run.configuration.toolSnapshots.any((t) => t.name == toolName),
          isTrue,
        );
        final artifacts = await (await h.conversations()).attachmentsFor(
          h.conversationId()!,
        );
        if (images) {
          expect(artifacts, hasLength(1));
          expect(record.artifacts, [artifacts.single.id]);
          final encoded = base64Encode(
            await File(artifacts.single.localPath).readAsBytes(),
          );
          expect(jsonEncode(payloads.last), contains(encoded));
          expect(
            jsonEncode(payloads.last),
            isNot(contains(artifacts.single.localPath)),
          );
        } else {
          expect(artifacts, isEmpty);
          expect(record.artifacts, isEmpty);
          expect(jsonEncode(payloads.last), isNot(contains(png)));
        }
        expect(mcp.closed, 2);
      });
    }
  }
  for (final mode in ['pending', 'idle']) {
    test('停止 MCP $mode 真实连接并保存取消终态', () async {
      final server = await McpTestServer.start();
      addTearDown(server.close);
      final h = await ToolLoopHarness.create();
      final repository = await h.container.read(
        mcpServerRepositoryProvider.future,
      );
      final profile = await repository.save(server.profile());
      final client = McpClient(profile, bearer: null);
      final tools = await client.connect(RunCancellation());
      await repository.saveCatalog(profile, tools, client.protocolVersion!);
      await client.close();
      final name = tools.single.name;
      final assistants = await h.container.read(
        assistantRepositoryProvider.future,
      );
      final assistant = await assistants.ensureDefault();
      await assistants.save(
        assistant.copyWith(
          toolPolicy: assistant.toolPolicy.withPolicy(name, ToolPolicy.ask),
        ),
      );
      h.onConfirmation = (_) async => ToolDecision.approved;
      h.provider.turns.add(
        toolTurn(callId: 'sample', toolName: name, arguments: '{}'),
      );
      server.mode = mode;
      final sending = h.controller().send('读取样本');
      await server.callArrived.future.timeout(const Duration(seconds: 5));
      h.controller().stop();
      await sending.timeout(const Duration(seconds: 3));
      final record = (await h.recordsByCall()).values.single;
      expect(record.status, ToolCallStatus.cancelled);
      expect(record.result, contains('可能已生效'));
      expect((await h.latestRun()).status, RunStatus.stopped);
      expect(server.calls, 1);
      expect(h.provider.requests, hasLength(1));
    });
  }
}
