import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/app.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/message_bubble.dart';
import 'package:phase/features/chat/model_selection.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';
import 'package:phase/providers/openai_responses/openai_responses_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixtureKeys extends SecureKeyStorage {
  @override
  Future<String?> readApiKey(String providerProfileId) async => 'fixture-only';
}

class _SseRequest {
  _SseRequest(this.options, Future<void>? cancelFuture) {
    if (cancelFuture != null) unawaited(_observeCancellation(cancelFuture));
  }

  final RequestOptions options;
  final body = StreamController<Uint8List>();
  var cancelled = false;

  Future<void> _observeCancellation(Future<void> cancelFuture) async {
    await cancelFuture;
    cancelled = true;
    unawaited(body.close());
  }

  void add(String sse) {
    for (final byte in utf8.encode(sse)) {
      body.add(Uint8List.fromList([byte]));
    }
  }

  void finish() => unawaited(body.close());
}

class _SseAdapter implements HttpClientAdapter {
  final requests = <_SseRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final request = _SseRequest(options, cancelFuture);
    requests.add(request);
    return ResponseBody(
      request.body.stream,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {
    for (final request in requests) {
      request.finish();
    }
  }
}

void main() {
  for (final protocol in [
    ApiProtocol.openaiResponses,
    ApiProtocol.openaiCompletions,
  ]) {
    testWidgets(
      '${protocol.name} 原始 SSE 经真实 Provider、Controller、DB 到可见思考，保留停止与错误',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final db = AppDatabase(NativeDatabase.memory());
        final keys = _FixtureKeys();
        final adapter = _SseAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        await tester.runAsync(() async {
          await ProviderProfileRepository(db, keys).saveProfile(
            id: 'raw-response-test',
            name: '响应联调',
            protocol: protocol,
            baseUrl: 'https://example.invalid/v1',
            defaultModel: 'reasoning-fixture',
            models: const [
              ProfileModel(id: 'reasoning-fixture', supportsReasoning: true),
            ],
          );
        });
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) => preferences),
            appDatabaseProvider.overrideWith((ref) => db),
            secureKeyStorageProvider.overrideWith((ref) => keys),
            aiProviderFactoryProvider.overrideWith(
              (ref) => (profile, apiKey) {
                return protocol == ApiProtocol.openaiResponses
                    ? OpenAiResponsesProvider(
                        profile: profile,
                        apiKey: apiKey,
                        dio: dio,
                      )
                    : OpenAiCompletionsProvider(
                        profile: profile,
                        apiKey: apiKey,
                        dio: dio,
                      );
              },
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const PhaseApp(),
            ),
          );
          await _until(
            tester,
            () => container.read(modelSelectionProvider).value != null,
          );
          await tester.pumpAndSettle();
          await _send(tester, '验证公开思考');
          await _until(tester, () => adapter.requests.length == 1);
          final first = adapter.requests.single;
          expect(first.options.method, 'POST');
          expect(
            first.options.uri.path,
            protocol == ApiProtocol.openaiResponses
                ? '/v1/responses'
                : '/v1/chat/completions',
          );
          expect((first.options.data as Map)['model'], 'reasoning-fixture');

          const reasoning = '先核对输入，再给结论。';
          first.add(_reasoningFixture(protocol, reasoning));
          await _until(
            tester,
            () => find.text(reasoning).evaluate().isNotEmpty,
          );
          expect(find.text('思考中…'), findsOneWidget);
          expect(find.text(reasoning), findsOneWidget);
          expect(_assistant(tester).reasoning, reasoning);
          expect(_assistant(tester).status, ChatMessageStatus.streaming);

          first.add(_completedFixture(protocol, reasoning, '正文答案'));
          first.finish();
          await _until(
            tester,
            () => !container.read(chatControllerProvider).isGenerating,
          );
          await tester.pumpAndSettle();
          expect(find.text('已思考'), findsOneWidget);
          expect(find.text(reasoning), findsOneWidget);
          expect(find.text('正文答案', findRichText: true), findsOneWidget);
          final conversationId = container
              .read(chatControllerProvider)
              .conversationId!;
          var rows = await tester.runAsync(
            () => db.getMessageRows(conversationId),
          );
          expect(rows, hasLength(2));
          expect(rows!.last.reasoning, reasoning);
          expect(rows.last.content, '正文答案');
          expect(rows.last.status, ChatMessageStatus.done);

          await _send(tester, '测试停止');
          await _until(tester, () => adapter.requests.length == 2);
          final second = adapter.requests.last;
          second.add(_reasoningFixture(protocol, '停止前公开摘要'));
          second.add(_bodyFixture(protocol, '部分正文'));
          await _until(
            tester,
            () => find.text('部分正文', findRichText: true).evaluate().isNotEmpty,
          );
          expect(second.cancelled, isFalse);
          await tester.tap(find.byTooltip('停止生成'));
          await _until(
            tester,
            () => !container.read(chatControllerProvider).isGenerating,
          );
          await tester.pumpAndSettle();
          second.add(_bodyFixture(protocol, '停止后的内容不得追加'));
          second.finish();
          await _until(tester, () => second.cancelled);
          rows = await tester.runAsync(() => db.getMessageRows(conversationId));
          expect(rows, hasLength(4));
          expect(rows!.last.reasoning, '停止前公开摘要');
          expect(rows.last.content, '部分正文');
          expect(rows.last.status, ChatMessageStatus.done);

          await _send(tester, '测试错误');
          await _until(tester, () => adapter.requests.length == 3);
          final third = adapter.requests.last;
          third.add(
            protocol == ApiProtocol.openaiResponses
                ? 'data:{"type":"response.failed","response":{"error":{"message":"fixture overload"}}}\n\n'
                : 'data:{"error":{"message":"fixture overload"}}\n\n',
          );
          third.finish();
          await _until(
            tester,
            () => !container.read(chatControllerProvider).isGenerating,
          );
          await tester.pumpAndSettle();
          rows = await tester.runAsync(() => db.getMessageRows(conversationId));
          expect(rows, hasLength(6));
          expect(rows!.last.reasoning, isNull);
          expect(rows.last.status, ChatMessageStatus.error);
          expect(rows.last.content, '服务商暂时不可用，请稍后再试');
          expect(find.text('回复未完成'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          dio.close(force: true);
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          var closed = false;
          unawaited(db.close().then((_) => closed = true));
          await _until(tester, () => closed);
        }
      },
    );
  }
}

ChatMessage _assistant(WidgetTester tester) => tester
    .widgetList<MessageBubble>(find.byType(MessageBubble))
    .map((bubble) => bubble.message)
    .lastWhere((message) => message.role == ChatRole.assistant);

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pump();
  await tester.tap(find.byTooltip('发送'));
}

String _reasoningFixture(ApiProtocol protocol, String text) =>
    protocol == ApiProtocol.openaiResponses
    ? 'data:{"type":"response.reasoning_summary_text.done",\r\n'
          'data:"item_id":"r1","output_index":0,"summary_index":0,"text":${jsonEncode(text)}}\r\n\r\n'
    : 'data:{"choices":[{"delta":{\r\n'
          'data:"reasoning_details":[{"type":"reasoning.summary","summary":${jsonEncode(text)}}]}}]}\r\n\r\n';

String _bodyFixture(ApiProtocol protocol, String text) =>
    protocol == ApiProtocol.openaiResponses
    ? 'data:${jsonEncode({'type': 'response.output_text.delta', 'item_id': 'm1', 'output_index': 1, 'content_index': 0, 'delta': text})}\n\n'
    : 'data:${jsonEncode({
        'choices': [
          {
            'delta': {'content': text},
          },
        ],
      })}\n\n';

String _completedFixture(ApiProtocol protocol, String reasoning, String text) {
  if (protocol == ApiProtocol.openaiCompletions) {
    return '${_bodyFixture(protocol, text)}'
        'data:{"choices":[{"delta":{},"finish_reason":"stop"}]}\n'
        'data:[DONE]\n\n';
  }
  return 'data:${jsonEncode({
    'type': 'response.completed',
    'response': {
      'output': [
        {
          'type': 'reasoning',
          'id': 'r1',
          'summary': [
            {'type': 'summary_text', 'text': reasoning},
          ],
        },
        {
          'type': 'message',
          'id': 'm1',
          'content': [
            {'type': 'output_text', 'text': text},
          ],
        },
      ],
      'usage': {'input_tokens': 1, 'output_tokens': 2, 'total_tokens': 3},
    },
  })}\n\n';
}

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 30));
    if (condition()) return;
  }
  fail('真实 SSE 到界面/数据库的状态未按预期完成');
}
