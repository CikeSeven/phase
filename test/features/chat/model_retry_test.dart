import 'package:phase/data/models/token_usage.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/core/error/provider_error.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/model_retry.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/providers/anthropic_messages/anthropic_messages_provider.dart';
import 'package:phase/providers/google_generative_ai/google_generative_ai_provider.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';
import 'package:phase/providers/openai_responses/openai_responses_provider.dart';

import '../tools/tool_loop_harness.dart';

String _sse(Object value) => 'data: ${jsonEncode(value)}\n\n';

String _text(ApiProtocol protocol, String text, {bool complete = false}) =>
    switch (protocol) {
      ApiProtocol.openaiCompletions =>
        _sse({
              'choices': [
                {
                  'delta': {'content': text},
                  if (complete) 'finish_reason': 'stop',
                },
              ],
            }) +
            (complete ? 'data: [DONE]\n\n' : ''),
      ApiProtocol.openaiResponses =>
        complete
            ? _sse({
                'type': 'response.completed',
                'response': {
                  'output': [
                    {
                      'type': 'message',
                      'id': 'm1',
                      'content': [
                        {'type': 'output_text', 'text': text},
                      ],
                    },
                  ],
                },
              })
            : _sse({
                'type': 'response.output_text.delta',
                'item_id': 'm1',
                'output_index': 1,
                'content_index': 0,
                'delta': text,
              }),
      ApiProtocol.anthropicMessages =>
        _sse({
              'type': 'content_block_delta',
              'index': 1,
              'delta': {'type': 'text_delta', 'text': text},
            }) +
            (complete ? _sse({'type': 'message_stop'}) : ''),
      ApiProtocol.googleGenerativeAi => _sse({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': text},
              ],
            },
            if (complete) 'finishReason': 'STOP',
          },
        ],
      }),
    };

String _thinking(ApiProtocol protocol) => switch (protocol) {
  ApiProtocol.openaiCompletions => _sse({
    'choices': [
      {
        'delta': {'reasoning_content': 'failed-thinking'},
      },
    ],
  }),
  ApiProtocol.openaiResponses => _sse({
    'type': 'response.reasoning_summary_text.delta',
    'item_id': 'r1',
    'output_index': 0,
    'summary_index': 0,
    'delta': 'failed-thinking',
  }),
  ApiProtocol.anthropicMessages => _sse({
    'type': 'content_block_delta',
    'index': 0,
    'delta': {'type': 'thinking_delta', 'thinking': 'failed-thinking'},
  }),
  ApiProtocol.googleGenerativeAi => _sse({
    'candidates': [
      {
        'content': {
          'role': 'model',
          'parts': [
            {'text': 'failed-thinking', 'thought': true},
          ],
        },
      },
    ],
  }),
};

String _error(ApiProtocol protocol) => switch (protocol) {
  ApiProtocol.openaiCompletions => _sse({
    'error': {'code': 'server_error', 'message': 'private-fixture-error'},
  }),
  ApiProtocol.openaiResponses => _sse({
    'type': 'response.failed',
    'response': {
      'error': {'code': 'server_error', 'message': 'private-fixture-error'},
    },
  }),
  ApiProtocol.anthropicMessages => _sse({
    'type': 'error',
    'error': {'type': 'overloaded_error', 'message': 'private-fixture-error'},
  }),
  ApiProtocol.googleGenerativeAi => _sse({
    'error': {
      'code': 503,
      'status': 'UNAVAILABLE',
      'message': 'private-fixture-error',
    },
  }),
};

String _call(String id, {bool complete = true}) =>
    _sse({
      'choices': [
        {
          'delta': {
            'tool_calls': [
              {
                'index': 0,
                'id': id,
                'type': 'function',
                'function': {'name': 'write_file', 'arguments': '{}'},
              },
            ],
          },
          if (complete) 'finish_reason': 'tool_calls',
        },
      ],
    }) +
    (complete ? 'data: [DONE]\n\n' : '');

class _Gateway implements HttpClientAdapter {
  _Gateway(this.respond);
  final Future<ResponseBody> Function(RequestOptions, int) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options, requests.length);
  }

  @override
  void close({bool force = false}) {}
}

Future<ToolLoopHarness> _harness(
  _Gateway gateway, {
  ApiProtocol protocol = ApiProtocol.openaiCompletions,
  ToolRegistry? registry,
  ModelRetryPolicy retryPolicy = const ModelRetryPolicy(
    baseDelay: Duration.zero,
  ),
}) async {
  final dio = Dio()..httpClientAdapter = gateway;
  addTearDown(() => dio.close(force: true));
  return ToolLoopHarness.create(
    registry: registry,
    protocol: protocol,
    retryPolicy: retryPolicy,
    factory: (profile, key) => switch (protocol) {
      ApiProtocol.openaiCompletions => OpenAiCompletionsProvider(
        profile: profile,
        apiKey: key,
        dio: dio,
      ),
      ApiProtocol.openaiResponses => OpenAiResponsesProvider(
        profile: profile,
        apiKey: key,
        dio: dio,
      ),
      ApiProtocol.anthropicMessages => AnthropicMessagesProvider(
        profile: profile,
        apiKey: key,
        dio: dio,
      ),
      ApiProtocol.googleGenerativeAi => GoogleGenerativeAiProvider(
        profile: profile,
        apiKey: key,
        dio: dio,
      ),
    },
  );
}

void main() {
  for (final protocol in ApiProtocol.values) {
    test('${protocol.name} HTTP 503 重试同一请求，不增加逻辑轮次', () async {
      final gateway = _Gateway(
        (_, attempt) async => ResponseBody.fromString(
          attempt == 1
              ? '{"error":{"message":"fixture"}}'
              : _text(protocol, 'success', complete: true),
          attempt == 1 ? 503 : 200,
        ),
      );
      final h = await _harness(gateway, protocol: protocol);
      await h.controller().send('test');
      expect(gateway.requests, hasLength(2));
      expect(gateway.requests[1].data, gateway.requests[0].data);
      final run = await h.latestRun();
      expect(run.status, RunStatus.completed);
      expect(run.turnCount, 1);
      expect(run.modelAttemptCount, 2);
    });

    test('${protocol.name} 思考和正文之后的 SSE 错误可恢复，失败尝试不拼接或进入上下文', () async {
      final gateway = _Gateway(
        (_, attempt) async => ResponseBody.fromString(
          attempt == 1
              ? '${_thinking(protocol)}${_text(protocol, 'failed-text')}${_error(protocol)}'
              : _text(protocol, 'success', complete: true),
          200,
        ),
      );
      final h = await _harness(gateway, protocol: protocol);
      await h.controller().send('test');
      expect(gateway.requests, hasLength(2));
      expect(gateway.requests[1].data, gateway.requests[0].data);
      final thread = (await (await h.conversations()).getThread(
        h.conversationId()!,
      ))!;
      final attempts = thread.messages
          .where((m) => m.role == ChatRole.assistant)
          .toList();
      expect(attempts, hasLength(2));
      expect(attempts.first.status, MessageStatus.failed);
      expect(attempts.first.text, contains('failed-text'));
      expect(
        attempts.first.parts.whereType<ReasoningPart>().single.publicText,
        'failed-thinking',
      );
      expect(attempts.first.text, isNot(contains('private-fixture-error')));
      expect(attempts.first.parentId, attempts.last.parentId);
      expect(thread.branch.last.text, 'success');
      expect(visibleMessages(thread, h.state()).last.text, 'success');
      expect(thread.branch.last.parts.whereType<ReasoningPart>(), isEmpty);
      expect((await h.latestRun()).status, RunStatus.completed);
    });
  }

  for (final (status, code) in [
    (401, 'invalid_api_key'),
    (400, 'invalid_request_error'),
    (429, 'insufficient_quota'),
  ]) {
    test('HTTP $status/$code 不重试', () async {
      final gateway = _Gateway(
        (_, _) async => ResponseBody.fromString(
          jsonEncode({
            'error': {
              'type': 'rate_limit_error',
              'code': code,
              'message': 'private',
            },
          }),
          status,
        ),
      );
      final h = await _harness(gateway);
      await h.controller().send('test');
      expect(gateway.requests, hasLength(1));
      expect((await h.latestRun()).status, RunStatus.failed);
    });
  }

  for (final kind in ['408', 'timeout', 'socket']) {
    test('$kind 从传输边界进入重试', () async {
      final gateway = _Gateway((options, attempt) async {
        if (attempt > 1) {
          return ResponseBody.fromString(
            _text(ApiProtocol.openaiCompletions, 'success', complete: true),
            200,
          );
        }
        if (kind == '408') return ResponseBody.fromString('{}', 408);
        if (kind == 'timeout') {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return ResponseBody(
          Stream<Uint8List>.error(const SocketException('fixture')),
          200,
        );
      });
      final h = await _harness(gateway);
      await h.controller().send('test');
      expect(gateway.requests, hasLength(2));
      expect((await h.latestRun()).status, RunStatus.completed);
    });
  }

  test('Retry-After 等待期间可立即停止，不提前请求，不增加尝试数', () async {
    final gateway = _Gateway(
      (_, _) async => ResponseBody.fromString(
        '{}',
        429,
        headers: {
          'retry-after': ['60'],
        },
      ),
    );
    final h = await _harness(gateway);
    final sending = h.controller().send('test');
    await h.waitUntil(() => h.state().retry != null);
    expect(h.state().retry!.delay, const Duration(seconds: 60));
    expect(h.state().retry!.attempt, 1);
    expect(h.state().isGenerating, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(gateway.requests, hasLength(1));
    h.controller().stop();
    await sending.timeout(const Duration(seconds: 1));
    expect((await h.latestRun()).status, RunStatus.stopped);
    expect((await h.latestRun()).modelAttemptCount, 1);
    expect(h.state().retry, isNull);
  });

  test('部分输出后的退避中停止保留失败尝试，不再开始请求', () async {
    final gateway = _Gateway(
      (_, _) async => ResponseBody.fromString(
        '${_text(ApiProtocol.openaiCompletions, 'partial')}${_error(ApiProtocol.openaiCompletions)}',
        200,
      ),
    );
    final h = await _harness(
      gateway,
      retryPolicy: const ModelRetryPolicy(baseDelay: Duration(seconds: 60)),
    );
    final sending = h.controller().send('test');
    await h.waitUntil(() => h.state().retry != null);
    h.controller().stop();
    await sending.timeout(const Duration(seconds: 1));
    expect(gateway.requests, hasLength(1));
    expect((await h.branch()).last.text, contains('partial'));
    expect((await h.latestRun()).status, RunStatus.stopped);
  });

  test('预算耗尽仅尝试三次，每次独立保存，不残留 streaming', () async {
    final gateway = _Gateway(
      (_, attempt) async => ResponseBody.fromString(
        '${_text(ApiProtocol.openaiCompletions, 'partial-$attempt')}${_error(ApiProtocol.openaiCompletions)}',
        200,
      ),
    );
    final h = await _harness(gateway);
    await h.controller().send('test');
    final thread = (await (await h.conversations()).getThread(
      h.conversationId()!,
    ))!;
    expect(gateway.requests, hasLength(3));
    expect(
      thread.messages.where((m) => m.status == MessageStatus.failed),
      hasLength(3),
    );
    expect(
      thread.messages.where((m) => m.status == MessageStatus.streaming),
      isEmpty,
    );
    expect(thread.branch.last.text, contains('partial-3'));
    expect(thread.branch.last.text, isNot(contains('partial-1')));
    expect((await h.latestRun()).finishReason, RunFinishReason.modelError);
    expect(h.state().retry, isNull);
  });

  test('不完整工具响应先重试；已执行动作之后的模型重试不重做动作', () async {
    final tool = RecordingTool(name: 'write_file');
    final gateway = _Gateway(
      (_, attempt) async => switch (attempt) {
        1 => ResponseBody.fromString(
          _call('not-executed', complete: false),
          200,
        ),
        2 => ResponseBody.fromString(_call('executed'), 200),
        3 => ResponseBody.fromString('{}', 503),
        _ => ResponseBody.fromString(
          _text(ApiProtocol.openaiCompletions, 'done', complete: true),
          200,
        ),
      },
    );
    final h = await _harness(gateway, registry: ToolRegistry([tool]));
    await h.controller().send('test');
    expect(gateway.requests, hasLength(4));
    expect(gateway.requests[1].data, gateway.requests[0].data);
    expect(gateway.requests[3].data, gateway.requests[2].data);
    expect(jsonEncode(gateway.requests[2].data), contains('executed'));
    expect(
      jsonEncode(gateway.requests[2].data),
      isNot(contains('not-executed')),
    );
    expect(tool.executions, hasLength(1));
    expect((await h.recordsByCall()).keys, ['executed']);
    final run = await h.latestRun();
    expect(run.turnCount, 2);
    expect(run.modelAttemptCount, 4);
    expect(run.status, RunStatus.completed);
  });

  test('失败尝试保存失败属于 StorageFailure，禁止继续重试', () async {
    final gateway = _Gateway(
      (_, _) async => ResponseBody.fromString(
        '${_text(ApiProtocol.openaiCompletions, 'partial')}${_error(ApiProtocol.openaiCompletions)}',
        200,
      ),
    );
    final h = await _harness(gateway);
    await h.database.customStatement(
      "CREATE TRIGGER fail_attempt BEFORE UPDATE ON messages WHEN NEW.status = 'failed' AND NEW.parts_json != '[]' BEGIN SELECT RAISE(ABORT, 'fixture storage error'); END",
    );
    await expectLater(
      h.controller().send('test'),
      throwsA(isA<StorageFailure>()),
    );
    expect(gateway.requests, hasLength(1));
    expect(h.state().isGenerating, isFalse);
    expect((await h.latestRun()).finishReason, RunFinishReason.storageError);
  });

  test('重试清空上次的 usage 和计时状态，模型请求配置不变', () async {
    final h = await ToolLoopHarness.create();
    h.provider.turns.addAll([
      Stream.fromIterable([
        const ReasoningDelta(partId: 'r', text: 'old'),
        const UsageChunk(usage: TokenUsage(promptTokens: 999)),
        const ResponseError(
          error: ProviderError(ProviderErrorCategory.network, 'fixture'),
        ),
      ]),
      textTurn('new'),
    ]);
    await h.controller().send('test');
    expect(identical(h.provider.requests[0], h.provider.requests[1]), isTrue);
    expect((await h.branch()).last.usage, isNull);
    expect((await h.branch()).last.thinkingDurationMs, isNull);
  });

  test('手动重新生成保留历史工具结果，而不是退回原始用户输入', () async {
    final tool = RecordingTool(name: 'write_file');
    final h = await ToolLoopHarness.create(registry: ToolRegistry([tool]));
    h.provider.turns.addAll([
      toolTurn(callId: 'write', toolName: 'write_file', arguments: '{}'),
      Stream.error(const ProviderError(ProviderErrorCategory.auth, 'fixture')),
      textTurn('已根据已有工具结果继续回答'),
    ]);
    await h.controller().send('test');
    await h.controller().regenerate();
    final results = h.provider.requests.last.messages
        .expand((m) => m.parts)
        .whereType<ResolvedToolResult>();
    expect(results.single.callId, 'write');
    expect(tool.executions, hasLength(1));
    expect((await h.latestRun()).status, RunStatus.completed);
  });
}
