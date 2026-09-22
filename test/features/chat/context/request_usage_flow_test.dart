import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/model_request_record.dart';
import 'package:phase/data/models/token_usage.dart';
import 'package:phase/data/repositories/model_request_repository.dart';
import 'package:phase/features/tools/tool.dart';

import '../../tools/tool_loop_harness.dart';
import '../../tools/tool_regression_test.dart' show Gateway, sse;

String response(ApiProtocol protocol, {bool fail = false}) =>
    switch (protocol) {
      ApiProtocol.openaiCompletions => [
        sse({
          'model': 'actual-model',
          'usage': {
            'prompt_tokens': 100,
            'prompt_tokens_details': {'cached_tokens': 80},
            'completion_tokens': 9,
          },
        }),
        sse({
          'usage': {
            'completion_tokens': 7,
            'completion_tokens_details': {'reasoning_tokens': 2},
            'total_tokens': 107,
          },
          'choices': [
            {
              'delta': {'content': 'fixture answer'},
              if (!fail) 'finish_reason': 'stop',
            },
          ],
        }),
        fail
            ? sse({
                'error': {'code': 'server_error'},
              })
            : 'data: [DONE]\n\n',
      ].join(),
      ApiProtocol.openaiResponses => [
        sse({
          'type': 'response.created',
          'response': {
            'model': 'actual-model',
            'usage': {
              'input_tokens': 100,
              'input_tokens_details': {'cached_tokens': 80},
              'output_tokens': 9,
            },
          },
        }),
        sse({
          'type': fail ? 'response.failed' : 'response.completed',
          'response': {
            if (fail) 'error': {'code': 'server_error'},
            'usage': {
              'output_tokens': 7,
              'output_tokens_details': {'reasoning_tokens': 2},
              'total_tokens': 107,
            },
            'output': [
              {
                'type': 'message',
                'id': 'm',
                'content': [
                  {'type': 'output_text', 'text': 'fixture answer'},
                ],
              },
            ],
          },
        }),
      ].join(),
      ApiProtocol.anthropicMessages => [
        sse({
          'type': 'message_start',
          'message': {
            'model': 'actual-model',
            'usage': {
              'input_tokens': 20,
              'cache_read_input_tokens': 80,
              'cache_creation_input_tokens': 0,
              'output_tokens': 1,
            },
          },
        }),
        sse({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': 'fixture answer'},
        }),
        sse({
          'type': 'message_delta',
          'delta': {'stop_reason': 'end_turn'},
          'usage': {'output_tokens': 7},
        }),
        fail
            ? sse({
                'type': 'error',
                'error': {'type': 'overloaded_error'},
              })
            : sse({'type': 'message_stop'}),
      ].join(),
      ApiProtocol.googleGenerativeAi => [
        sse({
          'modelVersion': 'actual-model',
          'usageMetadata': {
            'promptTokenCount': 100,
            'cachedContentTokenCount': 80,
            'candidatesTokenCount': 5,
            'thoughtsTokenCount': 2,
            'totalTokenCount': 107,
          },
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'fixture answer'},
                ],
              },
              if (!fail) 'finishReason': 'STOP',
            },
          ],
        }),
        if (fail)
          sse({
            'error': {'code': 503, 'status': 'UNAVAILABLE'},
          }),
      ].join(),
    };

void main() {
  for (final protocol in ApiProtocol.values) {
    test('${protocol.name} 真实适配器 → 重试 → 请求事实与消息投影，不重复累计', () async {
      final gateway = await Gateway.start([
        response(protocol, fail: true),
        response(protocol),
      ]);
      final h = await ToolLoopHarness.create(
        protocol: protocol,
        registry: ToolRegistry([]),
        factory: (p, k) => gateway.factory(p, k, protocol),
      );
      await h.controller().send('样本任务');
      final records = await ModelRequestRepository(h.database)
          .list(h.conversationId()!);
      expect(records, hasLength(2));
      expect(records.map((r) => r.status).toSet(), {
        ModelRequestStatus.failed,
        ModelRequestStatus.completed,
      });
      expect(records.map((r) => r.attemptIndex).toSet(), {1, 2});
      expect(
        records.every(
          (r) => r.usage?.promptTokens == 100 && r.usage?.outputTokens == 7,
        ),
        isTrue,
      );
      expect(records.every((r) => r.responseModelId == 'actual-model'), isTrue);
      final totals = RequestUsageTotals(records);
      expect(totals.metric(UsageField.totalTokens).tokens, 214);
      expect(totals.cacheHitRate, .8);
      expect((await h.branch()).last.usage!.totalTokens, 107);
      expect((await h.latestRun()).turnCount, 1);
      expect((await h.latestRun()).modelAttemptCount, 2);
      expect(gateway.requests.first, gateway.requests.last);
    });
  }

  for (final reportUsage in [false, true]) {
    test('停止${reportUsage ? '保留已报告快照' : '保留未知消耗'}，迟到用量不能覆盖', () async {
      final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
      final stream = StreamController<ChatChunk>();
      h.provider.turns.add(stream.stream);
      final sending = h.controller().send('task');
      await h.waitUntil(() => h.provider.requests.isNotEmpty);
      if (reportUsage) {
        stream.add(const UsageChunk(usage: TokenUsage(promptTokens: 42)));
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
      h.controller().stop();
      await sending;
      stream.add(const UsageChunk(usage: TokenUsage(promptTokens: 999)));
      await stream.close();
      final records = await ModelRequestRepository(h.database)
          .list(h.conversationId()!);
      expect(records.single.status, ModelRequestStatus.cancelled);
      expect(records.single.usage?.promptTokens, reportUsage ? 42 : null);
      expect(RequestUsageTotals(records).requestCount, 1);
    });
  }

  test('复制用量自包含且标继承，删除原会话不破坏查看，新请求单独累计', () async {
    final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
    h.provider.turns.add(
      Stream.fromIterable([
        ...(await textTurn('answer').toList()).where((c) => c is! ResponseEnd),
        const UsageChunk(
          usage: TokenUsage(promptTokens: 10, outputTokens: 3, totalTokens: 13),
        ),
        const ResponseEnd(),
      ]),
    );
    await h.controller().send('task');
    final originalId = h.conversationId()!;
    final repository = await h.conversations();
    final copy = await repository.duplicateConversation(originalId);
    await repository.deleteConversation(originalId);
    final records = await ModelRequestRepository(h.database).list(copy.id);
    expect(records.single.isInherited, isTrue);
    expect(records.single.originRequestId, isNotNull);
    expect(records.single.contextSnapshot, isEmpty);
    expect(RequestUsageTotals(records).requestCount, 0);
    expect(
      (await repository.getThread(copy.id))!.branch.last.usage!.totalTokens,
      13,
    );
    await h.controller().openConversation(copy.id);
    h.provider.turns.add(textTurn('new answer'));
    await h.controller().send('new task');
    expect(
      RequestUsageTotals(await ModelRequestRepository(h.database).list(copy.id))
          .requestCount,
      1,
    );
  });
}
