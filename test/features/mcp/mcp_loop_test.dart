import 'package:phase/data/models/chat_chunk.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/mcp_server_repository.dart';
import 'package:phase/features/mcp/mcp_client.dart';
import 'package:phase/features/mcp/mcp_connections.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/anthropic_messages/anthropic_messages_provider.dart';
import 'package:phase/providers/google_generative_ai/google_generative_ai_provider.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';
import 'package:phase/providers/openai_responses/openai_responses_provider.dart';

import '../tools/tool_loop_harness.dart';
import 'mcp_memory_transport.dart';
import 'mcp_model_fixtures.dart';

class _ModelTransport implements HttpClientAdapter {
  _ModelTransport(this.protocol);
  final ApiProtocol protocol;
  late String toolName;
  final payloads = <Map<String, dynamic>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    payloads.add(options.data as Map<String, dynamic>);
    return ResponseBody.fromString(
      payloads.length == 1
          ? mcpCallSse(protocol, toolName)
          : mcpAnswerSse(protocol),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AiProvider _provider(ProviderProfile profile, Dio dio) =>
    switch (profile.protocol) {
      ApiProtocol.openaiCompletions => OpenAiCompletionsProvider(
        profile: profile,
        apiKey: '',
        dio: dio,
      ),
      ApiProtocol.openaiResponses => OpenAiResponsesProvider(
        profile: profile,
        apiKey: '',
        dio: dio,
      ),
      ApiProtocol.anthropicMessages => AnthropicMessagesProvider(
        profile: profile,
        apiKey: '',
        dio: dio,
      ),
      ApiProtocol.googleGenerativeAi => GoogleGenerativeAiProvider(
        profile: profile,
        apiKey: '',
        dio: dio,
      ),
    };

void main() {
  for (final protocol in ApiProtocol.values) {
    for (final images in [true, false]) {
      test('${protocol.name} 图片 $images 真实适配器 SSE → MCP → 落库与最终回答（内存 HTTP）', () async {
        final transport = McpMemoryTransport();
        const png =
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=';
        (transport.result['content'] as List).add({
          'type': 'image',
          'mimeType': 'image/png',
          'data': images ? png : 'invalid-base64',
        });
        final model = _ModelTransport(protocol);
        final connections = McpConnections(
          createClient: (profile, bearer, headers) => McpHttpClient(
            profile,
            bearer: bearer,
            headers: headers,
            dio: Dio()..httpClientAdapter = transport,
          ),
        );
        addTearDown(connections.close);
        final h = await ToolLoopHarness.create(
          protocol: protocol,
          mcpConnections: connections,
          models: [
            ProfileModel(
              id: 'model-a',
              supportsTools: true,
              supportsImages: images,
            ),
          ],
          factory: (profile, _) =>
              _provider(profile, Dio()..httpClientAdapter = model),
        );
        final repository = await h.container.read(
          mcpServerRepositoryProvider.future,
        );
        final saved = await repository.save(transport.profile());
        final discover = await connections.create(
          saved,
          bearer: null,
          headers: {},
        );
        final tools = await discover.connect(RunCancellation());
        await repository.saveCatalog(saved, tools, discover.protocolVersion!);
        await connections.release(discover);
        model.toolName = tools.single.name;
        final assistants = await h.container.read(
          assistantRepositoryProvider.future,
        );
        final assistant = await assistants.ensureDefault();
        await assistants.save(
          assistant.copyWith(mcpToolNames: {model.toolName}),
        );
        var confirmed = 0;
        h.onConfirmation = (request) async {
          confirmed++;
          return ToolDecision.approved;
        };
        await h.controller().send('读取样本文档');
        expect(confirmed, 0);
        expect(transport.calls, 1);
        expect(model.payloads, hasLength(2));
        expect(jsonEncode(model.payloads.last), contains('月相记录'));
        final record = (await h.recordsByCall()).values.single;
        expect(record.status, ToolCallStatus.succeeded);
        expect(record.source?.originalName, 'read_sample');
        expect(
          record.source?.definitionRevision,
          tools.single.source.definitionRevision,
        );
        expect((await h.latestRun()).status, RunStatus.completed);
        expect((await h.branch()).last.text, '已读取月相记录');
        expect(transport.deletes, 2);
        final attachments = await (await h.conversations()).attachmentsFor(
          h.conversationId()!,
        );
        expect(attachments, hasLength(images ? 1 : 0));
        expect(
          jsonEncode(model.payloads.last),
          images ? contains(png) : isNot(contains('invalid-base64')),
        );
      });
    }
  }

  for (final change in ['disable', 'revoke', 'definition', 'allowLater']) {
    test('模型输出期间 $change 不能扩大旧运行或执行已失效定义', () async {
      final transport = McpMemoryTransport();
      final connections = McpConnections(
        createClient: (profile, bearer, headers) => McpHttpClient(
          profile,
          bearer: bearer,
          headers: headers,
          dio: Dio()..httpClientAdapter = transport,
        ),
      );
      addTearDown(connections.close);
      final h = await ToolLoopHarness.create(mcpConnections: connections);
      final repository = await h.container.read(
        mcpServerRepositoryProvider.future,
      );
      final saved = await repository.save(transport.profile());
      final client = await connections.create(saved, bearer: null, headers: {});
      final tools = await client.connect(RunCancellation());
      await repository.saveCatalog(saved, tools, client.protocolVersion!);
      await connections.release(client);
      final name = tools.single.name;
      final assistants = await h.container.read(
        assistantRepositoryProvider.future,
      );
      final assistant = await assistants.ensureDefault();
      await assistants.save(
        assistant.copyWith(mcpToolNames: change == 'allowLater' ? {} : {name}),
      );
      var confirmations = 0;
      h.onConfirmation = (_) async {
        confirmations++;
        return ToolDecision.approved;
      };
      Stream<ChatChunk> changedTurn() async* {
        switch (change) {
          case 'disable':
            await repository.save(saved.copyWith(enabled: false));
          case 'revoke':
            await assistants.save(assistant);
          case 'definition':
            transport.description = '定义发生了变化';
          case 'allowLater':
            await assistants.save(assistant.copyWith(mcpToolNames: {name}));
        }
        yield* toolTurn(callId: 'sample', toolName: name, arguments: '{}');
      }

      h.provider.turns.addAll([changedTurn(), textTurn('已处理')]);
      await h.controller().send('读取');
      expect(confirmations, 0);
      final record = (await h.recordsByCall()).values.single;
      expect(transport.calls, 0);
      expect(
        record.status,
        change == 'definition'
            ? ToolCallStatus.failed
            : ToolCallStatus.rejected,
      );
      expect(
        (await h.latestRun()).configuration.toolPolicies[name],
        change == 'allowLater' ? isNull : ToolPolicy.allow,
      );
    });
  }
  test('停止空闲 MCP 响应，保存工具取消与运行终态（内存 HTTP）', () async {
    final transport = McpMemoryTransport();
    final connections = McpConnections(
      createClient: (profile, bearer, headers) => McpHttpClient(
        profile,
        bearer: bearer,
        headers: headers,
        dio: Dio()..httpClientAdapter = transport,
      ),
    );
    addTearDown(connections.close);
    final h = await ToolLoopHarness.create(mcpConnections: connections);
    final repository = await h.container.read(
      mcpServerRepositoryProvider.future,
    );
    final profile = await repository.save(transport.profile());
    final discovery = await connections.create(
      profile,
      bearer: null,
      headers: {},
    );
    final tools = await discovery.connect(RunCancellation());
    await repository.saveCatalog(profile, tools, discovery.protocolVersion!);
    await connections.release(discovery);
    final name = tools.single.name;
    final assistants = await h.container.read(
      assistantRepositoryProvider.future,
    );
    final assistant = await assistants.ensureDefault();
    await assistants.save(assistant.copyWith(mcpToolNames: {name}));
    h.onConfirmation = (_) async => ToolDecision.approved;
    h.provider.turns.add(
      toolTurn(callId: 'sample', toolName: name, arguments: '{}'),
    );
    transport.hangCall = true;
    final sending = h.controller().send('读取样本');
    await transport.callStarted.future;
    h.controller().stop();
    await sending;
    expect(transport.calls, 1);
    expect((await h.latestRun()).status, RunStatus.stopped);
    final record = (await h.recordsByCall()).values.single;
    expect(record.status, ToolCallStatus.cancelled);
    expect(record.result, contains('可能已生效'));
    expect(h.provider.requests, hasLength(1));
  });
}
