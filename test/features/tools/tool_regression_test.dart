import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/tools/run_recovery_controller.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/anthropic_messages/anthropic_messages_provider.dart';
import 'package:phase/providers/google_generative_ai/google_generative_ai_provider.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';
import 'package:phase/providers/openai_responses/openai_responses_provider.dart';

import 'tool_loop_harness.dart';

String sse(Object event) => 'data: ${jsonEncode(event)}\n\n';
String completionText() =>
    '${sse({
      'choices': [
        {
          'delta': {'content': 'done'},
          'finish_reason': 'stop',
        },
      ],
    })}data: [DONE]\n\n';
String completionCall(String name) => sse({
  'choices': [
    {
      'delta': {
        'tool_calls': [
          {
            'index': 0,
            'id': 'call_1',
            'type': 'function',
            'function': {'name': name, 'arguments': '{}'},
          },
        ],
      },
    },
  ],
});
String anthropicText() =>
    '${sse({
      'type': 'content_block_delta',
      'index': 0,
      'delta': {'type': 'text_delta', 'text': 'done'},
    })}${sse({'type': 'message_stop'})}';
String googleText() => sse({
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          {'text': 'done'},
        ],
      },
      'finishReason': 'STOP',
    },
  ],
});

class Gateway {
  Gateway(this.server, this.bodies);
  final HttpServer server;
  final List<String> bodies;
  final requests = <Map<String, dynamic>>[];
  String get url => 'http://127.0.0.1:${server.port}/';
  static Future<Gateway> start(List<String> bodies) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final gateway = Gateway(server, bodies);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      gateway.requests.add(jsonDecode(body) as Map<String, dynamic>);
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(bodies[gateway.requests.length - 1]);
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    return gateway;
  }

  AiProvider factory(
    ProviderProfile profile,
    String key,
    ApiProtocol protocol,
  ) {
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    final configured = profile.copyWith(
      baseUrl: url,
      requiresKey: false,
      protocol: protocol,
    );
    return switch (protocol) {
      ApiProtocol.openaiCompletions => OpenAiCompletionsProvider(
        profile: configured,
        apiKey: '',
        dio: dio,
      ),
      ApiProtocol.anthropicMessages => AnthropicMessagesProvider(
        profile: configured,
        apiKey: '',
        dio: dio,
      ),
      ApiProtocol.googleGenerativeAi => GoogleGenerativeAiProvider(
        profile: configured,
        apiKey: '',
        dio: dio,
      ),
      ApiProtocol.openaiResponses => OpenAiResponsesProvider(
        profile: configured,
        apiKey: '',
        dio: dio,
      ),
    };
  }
}

void main() {
  final partialCalls = <ApiProtocol, String>{
    ApiProtocol.anthropicMessages: sse({
      'type': 'content_block_start',
      'index': 0,
      'content_block': {
        'type': 'tool_use',
        'id': 'call-0',
        'name': 'echo',
        'input': {},
      },
    }),
    ApiProtocol.googleGenerativeAi: sse({
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {
                'functionCall': {'name': 'echo', 'args': {}},
              },
            ],
          },
        },
      ],
    }),
    ApiProtocol.openaiResponses: sse({
      'type': 'response.output_item.done',
      'output_index': 0,
      'item': {
        'type': 'function_call',
        'id': 'fc-0',
        'call_id': 'call-0',
        'name': 'echo',
        'arguments': '{}',
      },
    }),
  };
  for (final entry in partialCalls.entries) {
    test('${entry.key.name} EOF 不能派发参数已经完整的工具调用', () async {
      final echo = RecordingTool(name: 'echo');
      final gateway = await Gateway.start([entry.value]);
      final h = await ToolLoopHarness.create(
        registry: ToolRegistry([echo]),
        factory: (p, k) => gateway.factory(p, k, entry.key),
      );
      await h.controller().send('review');
      expect(echo.executions, isEmpty);
      expect((await h.latestRun()).finishReason, RunFinishReason.modelError);
      expect(gateway.requests, hasLength(1));
    });
  }

  test('Responses 完整工具响应经执行、落库与真实请求回填', () async {
    final echo = RecordingTool(name: 'echo');
    final gateway = await Gateway.start([
      sse({
        'type': 'response.completed',
        'response': {
          'output': [
            {
              'type': 'function_call',
              'id': 'fc-0',
              'call_id': 'call-0',
              'name': 'echo',
              'arguments': '{}',
            },
          ],
        },
      }),
      sse({
        'type': 'response.completed',
        'response': {
          'output': [
            {
              'type': 'message',
              'id': 'msg-1',
              'content': [
                {'type': 'output_text', 'text': 'done'},
              ],
            },
          ],
        },
      }),
    ]);
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([echo]),
      factory: (p, k) => gateway.factory(p, k, ApiProtocol.openaiResponses),
    );
    await h.controller().send('review');
    final input = gateway.requests.last['input'] as List;
    expect(
      input.where((item) => item['type'] == 'function_call_output'),
      hasLength(1),
    );
    expect(input.where((item) => item['role'] == 'tool'), isEmpty);
    expect(echo.executions, hasLength(1));
    expect((await h.latestRun()).status, RunStatus.completed);
  });

  test('Responses incomplete 不执行已经出现的完整调用', () async {
    final echo = RecordingTool(name: 'echo');
    final gateway = await Gateway.start([
      sse({
        'type': 'response.incomplete',
        'response': {
          'output': [
            {
              'type': 'function_call',
              'id': 'fc-0',
              'call_id': 'call-0',
              'name': 'echo',
              'arguments': '{}',
            },
          ],
        },
      }),
    ]);
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([echo]),
      factory: (p, k) => gateway.factory(p, k, ApiProtocol.openaiResponses),
    );
    await h.controller().send('review');
    expect(echo.executions, isEmpty);
    expect((await h.latestRun()).finishReason, RunFinishReason.modelError);
  });

  test('HTTP 已返回头部并保持正文空闲时停止会关闭流，取消结果最终落库', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final ready = Completer<void>();
    server.listen((request) async {
      await request.drain<void>();
      request.response.write('first chunk');
      await request.response.flush();
      ready.complete();
    });
    final h = await ToolLoopHarness.create();
    h.onConfirmation = (_) async => ToolDecision.approved;
    h.provider.turns.add(
      toolTurn(
        callId: 'get',
        toolName: 'http_request',
        arguments: jsonEncode({'url': 'http://127.0.0.1:${server.port}/'}),
      ),
    );
    final sending = h.controller().send('read');
    await ready.future.timeout(const Duration(seconds: 3));
    h.controller().stop();
    await sending.timeout(const Duration(seconds: 2));
    expect((await h.recordsByCall())['get']!.status, ToolCallStatus.cancelled);
    expect((await h.latestRun()).status, RunStatus.stopped);
    expect(h.provider.requests, hasLength(1));
  });

  test('interrupted SSE must not execute a tool', () async {
    final echo = RecordingTool(name: 'echo');
    // Deliberately closes the HTTP body without finish_reason or [DONE].
    final gateway = await Gateway.start([
      completionCall('echo'),
      completionText(),
    ]);
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([echo]),
      factory: (p, k) => gateway.factory(p, k, ApiProtocol.openaiCompletions),
    );
    await h.controller().send('review');
    expect(echo.executions, isEmpty, reason: '工具响应没有协议终止事件，不能执行');
  });

  test('Completions tool results must all have tool_call_id', () async {
    final echo = RecordingTool(name: 'echo');
    final gateway = await Gateway.start([
      '${completionCall('echo')}${sse({
        'choices': [
          {'delta': {}, 'finish_reason': 'tool_calls'},
        ],
      })}data: [DONE]\n\n',
      completionText(),
    ]);
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([echo]),
      factory: (p, k) => gateway.factory(p, k, ApiProtocol.openaiCompletions),
    );
    await h.controller().send('review');
    final results = (gateway.requests[1]['messages'] as List)
        .where((m) => m['role'] == 'tool')
        .toList();
    expect(
      results.where((m) => m['tool_call_id'] == null),
      isEmpty,
      reason: '真实回填里多出没有 tool_call_id 的 role=tool 消息',
    );
    expect(results, hasLength(1));
  });

  test(
    'Anthropic must group all parallel results immediately after tool_use',
    () async {
      final echo = RecordingTool(name: 'echo');
      final calls = StringBuffer();
      for (var i = 0; i < 2; i++) {
        calls.write(
          sse({
            'type': 'content_block_start',
            'index': i,
            'content_block': {
              'type': 'tool_use',
              'id': 'call_$i',
              'name': 'echo',
              'input': {},
            },
          }),
        );
        calls.write(sse({'type': 'content_block_stop', 'index': i}));
      }
      calls.write(sse({'type': 'message_stop'}));
      final gateway = await Gateway.start([calls.toString(), anthropicText()]);
      final h = await ToolLoopHarness.create(
        registry: ToolRegistry([echo]),
        factory: (p, k) => gateway.factory(p, k, ApiProtocol.anthropicMessages),
      );
      await h.controller().send('review');
      final messages = gateway.requests[1]['messages'] as List;
      final use = messages.indexWhere((m) => m['role'] == 'assistant');
      final resultBlocks = (messages[use + 1]['content'] as List).where(
        (b) => b['type'] == 'tool_result',
      );
      expect(resultBlocks, hasLength(2));
    },
  );

  test(
    'Google must replay thoughtSignature on the Part, not FunctionCall',
    () async {
      final echo = RecordingTool(name: 'echo');
      final gateway = await Gateway.start([
        sse({
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {
                    'functionCall': {'name': 'echo', 'args': {}},
                    'thoughtSignature': 'fake-test-signature',
                  },
                ],
              },
              'finishReason': 'STOP',
            },
          ],
        }),
        googleText(),
      ]);
      final h = await ToolLoopHarness.create(
        registry: ToolRegistry([echo]),
        factory: (p, k) =>
            gateway.factory(p, k, ApiProtocol.googleGenerativeAi),
      );
      await h.controller().send('review');
      final model = (gateway.requests[1]['contents'] as List).singleWhere(
        (m) => m['role'] == 'model',
      );
      final callPart = (model['parts'] as List).singleWhere(
        (p) => p['functionCall'] != null,
      );
      expect(callPart['thoughtSignature'], 'fake-test-signature');
    },
  );

  test('stopping real idle HTTP tool must complete without server releasing response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final received = Completer<HttpRequest>();
    server.listen((request) async {
      await request.drain<void>();
      received.complete(request);
    });
    final h = await ToolLoopHarness.create();
    h.onConfirmation = (_) async => ToolDecision.approved;
    h.provider.turns.add(
      toolTurn(
        callId: 'call_1',
        toolName: 'http_request',
        arguments: jsonEncode({
          'url': 'http://127.0.0.1:${server.port}/',
          'method': 'POST',
          'body': 'fake-data',
        }),
      ),
    );
    var done = false;
    final sending = h.controller().send('review').then((_) {
      done = true;
    });
    final request = await received.future.timeout(const Duration(seconds: 3));
    h.controller().stop();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final stoppedPromptly = done;
    request.response.write('saved');
    await request.response.close();
    await sending;
    expect(stoppedPromptly, isTrue, reason: '停止后仍在等待真实 HTTP 响应，直到服务端主动关闭才结束');
    expect((await h.recordsByCall())['call_1']!.status, ToolCallStatus.unknown);
    expect((await h.latestRun()).status, RunStatus.awaitingResult);
  });

  test(
    'artifact persistence failure after file write must stop the run',
    () async {
      final h = await ToolLoopHarness.create(
        saveArtifact: (_) async {
          throw const UnknownFailure('injected artifact persistence failure');
        },
      );
      h.onConfirmation = (_) async => ToolDecision.approved;
      h.provider.turns.addAll([
        toolTurn(
          callId: 'call_1',
          toolName: 'write_file',
          arguments: '{"path":"summary.md","content":"fake summary"}',
        ),
        textTurn('done'),
      ]);
      await expectLater(h.controller().send('review'), throwsA(isA<Failure>()));
      expect(
        File('${h.artifactsDir(h.conversationId()!).path}/summary.md')
            .readAsStringSync(),
        'fake summary',
      );
      final record = (await h.recordsByCall())['call_1']!;
      expect(record.status, ToolCallStatus.unknown);
      final preview = await h.container
          .read(runRecoveryControllerProvider.notifier)
          .inspectWrite(record.id);
      expect(File(preview.localPath).readAsStringSync(), 'fake summary');
      expect(
        (await h.recordsByCall())['call_1']!.status,
        ToolCallStatus.unknown,
      );
      expect(h.provider.requests, hasLength(1));
      expect((await h.latestRun()).status, RunStatus.awaitingResult);
    },
  );

  test(
    'copied tool history must survive deleting source conversation',
    () async {
      final echo = RecordingTool(name: 'echo');
      final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
      h.provider.turns.addAll([
        toolTurn(callId: 'call_1', toolName: 'echo', arguments: '{}'),
        textTurn('done'),
      ]);
      await h.controller().send('review');
      final repository = await h.conversations();
      final original = h.conversationId()!;
      final copied = await repository.duplicateConversation(original);
      final thread = (await repository.getThread(copied.id))!;
      final ids = thread.messages
          .expand((m) => m.parts)
          .whereType<ToolCallPart>()
          .map((p) => p.toolCallId)
          .toList();
      await repository.deleteConversation(original);
      final records = await repository.toolCallsByIds(ids);
      expect(records, hasLength(1), reason: '副本保留了原会话的工具记录 ID，删除原会话后引用悬空');
    },
  );

  test(
    'starting a new conversation must not remove stop control for existing run',
    () async {
      final echo = RecordingTool(name: 'echo');
      final gate = Completer<void>();
      echo.executeAsync = (_, cancellation) async {
        await gate.future;
        return const ToolOutcome.success('done');
      };
      final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
      h.provider.turns.addAll([
        toolTurn(callId: 'call_1', toolName: 'echo', arguments: '{}'),
        textTurn('done'),
      ]);
      final sending = h.controller().send('review');
      await h.waitUntil(() => echo.executions.isNotEmpty);
      h.controller().startNewConversation();
      final controlStillActive = h.state().isGenerating;
      h.controller().stop();
      gate.complete();
      await sending;
      expect(
        controlStillActive,
        isTrue,
        reason: '切换视图不能把运行中的根任务标为空闲，否则 stop() 直接返回',
      );
    },
  );

  test('text plus pending tool must keep its tool card visible', () async {
    final echo = RecordingTool(name: 'echo', policy: ToolPolicy.ask);
    final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
    final gate = Completer<ToolDecision>();
    h.onConfirmation = (_) => gate.future;
    h.provider.turns.addAll([
      toolTurn(
        callId: 'call_1',
        toolName: 'echo',
        arguments: '{}',
        text: 'I will use the tool',
      ),
      textTurn('done'),
    ]);
    final sending = h.controller().send('review');
    await h.waitUntil(
      () async =>
          (await h.recordsByCall())['call_1']?.status ==
          ToolCallStatus.awaitingConfirmation,
    );
    final repository = await h.conversations();
    final thread = (await repository.getThread(h.conversationId()!))!;
    final visible = visibleMessages(thread, h.state());
    final shownCalls = visible
        .expand((m) => m.parts)
        .whereType<ToolCallPart>()
        .toList();
    gate.complete(ToolDecision.rejected);
    await sending;
    expect(
      shownCalls,
      hasLength(1),
      reason: '文本流已收口，旧 streamingParts 仍覆盖持久化工具引用',
    );
  });
}
