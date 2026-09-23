import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'dart:io';

import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/app.dart';
import 'package:path/path.dart' as p;
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/model_catalog_cache.dart';
import 'package:phase/data/models/model_catalog.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/message_bubble.dart';
import 'package:phase/features/chat/model_selection.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';
import 'package:phase/providers/openai_responses/openai_responses_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_secure_storage.dart';

class _FixtureKeys extends SecureKeyStorage {
  _FixtureKeys() : super(FakeSecureStorage({'api_key_p1': 'fixture-only'}));
}

/// 从消息内容块取公开思考文本。
String? _reasoningOf(ChatMessage message) {
  final parts = message.parts.whereType<ReasoningPart>();
  if (parts.isEmpty) return null;
  return parts.map((part) => part.publicText).join();
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
  for (final (protocol, useCapturedSample) in [
    (ApiProtocol.openaiResponses, false),
    (ApiProtocol.openaiCompletions, false),
    (ApiProtocol.openaiResponses, true),
  ]) {
    final captured = useCapturedSample ? _capturedFirstTurn() : null;
    testWidgets(
      '${protocol.name}${useCapturedSample ? ' 真机首轮脱敏样本' : ''} 原始 SSE 经真实 Provider、Controller、DB 到可见思考，保留停止与错误',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final tempDir = Directory.systemTemp.createTempSync('phase_sse_flow');
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });
        // widget 测试的 fake-async 无法驱动后台 isolate：同 isolate 打开加密库。
        final db = openAppDatabase(
          path: p.join(tempDir.path, 'phase.sqlite'),
          hexKey: '0123456789abcdef' * 4,
          background: false,
        );
        final keys = _FixtureKeys();
        final adapter = _SseAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final modelId = protocol == ApiProtocol.openaiResponses
            ? 'gpt-6-astra'
            : 'reasoning-fixture';
        await tester.runAsync(() async {
          await ProviderProfileRepository(db, keys).createProfile(
            name: '响应联调',
            protocol: protocol,
            baseUrl: 'https://example.invalid/v1',
            defaultModel: modelId,
            models: [ProfileModel(id: modelId, supportsReasoning: true)],
          );
        });
        SharedPreferences.setMockInitialValues({
          'last_reasoning_effort': 'high',
        });
        final preferences = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            modelCatalogProvider.overrideWith(
              (ref) async => ModelCatalog.empty,
            ),
            sharedPreferencesProvider.overrideWith((ref) => preferences),
            appDatabaseProvider.overrideWith((ref) => db),
            secureKeyStorageProvider.overrideWith((ref) => keys),
            workspaceRepositoryProvider.overrideWith(
              (ref) => WorkspaceRepository(db, tempDir),
            ),
            attachmentStorageProvider.overrideWith(
              (ref) => AttachmentStorage(
                Directory(p.join(tempDir.path, 'attachments')),
              ),
            ),
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
          await _settleUi(tester);
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
          expect((first.options.data as Map)['model'], modelId);
          if (protocol == ApiProtocol.openaiResponses) {
            expect((first.options.data as Map)['reasoning'], {
              'effort': 'high',
              'summary': 'auto',
            });
            expect((first.options.data as Map)['store'], isFalse);
            expect((first.options.data as Map)['include'], [
              'reasoning.encrypted_content',
            ]);
            expect(
              ((first.options.data as Map)['input'] as List).where(
                (item) => item['role'] == 'user',
              ),
              hasLength(1),
            );
          }

          final reasoning = captured?.reasoning ?? '先核对输入，再给结论。';
          first.add(captured?.prefix ?? _reasoningFixture(protocol, reasoning));
          await _until(
            tester,
            () => find.textContaining('思考中…').evaluate().isNotEmpty,
          );
          expect(find.textContaining('思考中…'), findsOneWidget);
          expect(find.text(reasoning), findsNothing);
          await tester.tap(find.textContaining('思考中…'));
          await tester.pump();
          expect(find.text(reasoning), findsOneWidget);
          expect(_reasoningOf(_assistant(tester)), reasoning);
          expect(_assistant(tester).status, MessageStatus.streaming);

          // pi 在 output_item.done 以完整 summary 收口；不能把修订后的
          // 公开摘要仅留在 providerData，显示和落库仍沿用不完整的增量。
          final finalReasoning =
              captured?.reasoning ??
              (protocol == ApiProtocol.openaiResponses
                  ? '核对输入完成，再给结论。'
                  : reasoning);
          first.add(
            captured?.tail ??
                _completedFixture(protocol, finalReasoning, '正文答案'),
          );
          first.finish();
          await _until(
            tester,
            () => !container.read(chatControllerProvider).isGenerating,
          );
          await _settleUi(tester);
          expect(_assistant(tester).text, '正文答案');
          expect(_reasoningOf(_assistant(tester)), finalReasoning);
          expect(find.text(finalReasoning), findsOneWidget);
          expect(_assistant(tester).status, MessageStatus.completed);
          var rows = (await tester.runAsync(() => _messageRows(db)))!;
          expect(rows, hasLength(2));
          expect(_reasoningOf(_messageOf(rows.last)), finalReasoning);
          expect(rows.last.partsJson, contains('正文答案'));
          expect(rows.last.status, MessageStatus.completed);
          final recorded = _messageOf(rows.last).parts
              .whereType<ReasoningPart>()
              .where((part) => part.publicText.isNotEmpty)
              .toList();
          expect(recorded, hasLength(captured == null ? 1 : 4));
          for (final part in recorded) {
            expect(part.startedAt, isNotNull);
            expect(part.durationMs, isNotNull);
          }
          expect(
            rows.last.thinkingDurationMs,
            recorded.fold<int>(0, (sum, part) => sum + part.durationMs!),
          );
          expect(find.textContaining('已思考'), findsOneWidget);
          // 正文到达后完成当前段计时；手动展开仍保留，重建消息后来自落库数据。
          final recordedDurations = recorded
              .map((part) => part.durationMs)
              .toList();
          await _settleUi(tester);
          rows = (await tester.runAsync(() => _messageRows(db)))!;
          expect(
            _messageOf(rows.last).parts
                .whereType<ReasoningPart>()
                .where((part) => part.publicText.isNotEmpty)
                .map((part) => part.durationMs)
                .toList(),
            recordedDurations,
          );

          // 离开并重新打开会话，验证不是仅由流式内存保住完整摘要。
          final controller = container.read(chatControllerProvider.notifier);
          final conversationId = rows.last.conversationId;
          controller.startNewConversation();
          await _settleUi(tester);
          var reopened = false;
          unawaited(
            controller
                .openConversation(conversationId)
                .then((_) => reopened = true),
          );
          await _until(tester, () => reopened);
          await _settleUi(tester);
          expect(_reasoningOf(_assistant(tester)), finalReasoning);
          expect(find.text(finalReasoning), findsNothing);
          await tester.tap(find.textContaining('已思考'));
          await tester.pump();
          expect(find.text(finalReasoning), findsOneWidget);

          await _send(tester, '测试停止');
          await _until(tester, () => adapter.requests.length == 2);
          final second = adapter.requests.last;
          if (protocol == ApiProtocol.openaiResponses) {
            final payload = second.options.data as Map;
            expect(
              payload['reasoning'],
              (first.options.data as Map)['reasoning'],
            );
            final reasoningItems = (payload['input'] as List).where(
              (item) => (item as Map)['type'] == 'reasoning',
            );
            expect(
              reasoningItems.map((item) => item['summary']).toList(),
              captured?.summaries ??
                  [
                    [
                      {'type': 'summary_text', 'text': finalReasoning},
                    ],
                  ],
            );
          }
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
          await _settleUi(tester);
          await _until(tester, () => second.cancelled);
          expect(second.body.isClosed, isTrue);
          expect(_assistant(tester).text, '部分正文');
          expect(_assistant(tester).status, MessageStatus.cancelled);
          rows = (await tester.runAsync(() => _messageRows(db)))!;
          expect(rows, hasLength(4));
          expect(_reasoningOf(_messageOf(rows.last)), '停止前公开摘要');
          expect(
            _messageOf(rows.last).parts
                .whereType<ReasoningPart>()
                .where((part) => part.publicText.isNotEmpty)
                .single
                .durationMs,
            isNotNull,
          );
          expect(rows.last.partsJson, contains('部分正文'));
          expect(rows.last.status, MessageStatus.cancelled);

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
          await _settleUi(tester);
          expect(_assistant(tester).status, MessageStatus.failed);
          expect(_assistant(tester).text, '服务商暂时不可用，请稍后再试');
          rows = (await tester.runAsync(() => _messageRows(db)))!;
          expect(rows, hasLength(6));
          expect(_reasoningOf(_messageOf(rows.last)), isNull);
          expect(rows.last.status, MessageStatus.failed);
          expect(rows.last.partsJson, contains('服务商暂时不可用，请稍后再试'));
          // 网关原文只进诊断，不落库、不上屏。
          expect(rows.last.partsJson, isNot(contains('fixture overload')));
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

({String prefix, String tail, String reasoning, List<Object?> summaries})
_capturedFirstTurn() {
  final wire = File('test/fixtures/providers/astra_first_turn_reasoning.sse')
      .readAsStringSync();
  final boundary = wire.indexOf('event: response.output_text.done\n');
  final terminal = wire.trimRight().split('\n\n').last;
  final data =
      jsonDecode(terminal.substring(terminal.indexOf('data:') + 5)) as Map;
  final items = (data['response']['output'] as List).where(
    (item) => item['type'] == 'reasoning',
  );
  final summaries = items.map((item) => item['summary']).toList();
  return (
    prefix: wire.substring(0, boundary),
    tail: wire.substring(boundary),
    reasoning: summaries
        .expand((summary) => summary as List)
        .map((part) => part['text'] as String)
        .join('\n\n'),
    summaries: summaries,
  );
}

Future<List<MessageRow>> _messageRows(AppDatabase db) {
  return (db.select(
    db.messages,
  )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
}

ChatMessage _messageOf(MessageRow row) {
  return ChatMessage(
    id: row.id,
    conversationId: row.conversationId,
    role: row.role,
    status: row.status,
    parts: decodeMessageParts(jsonDecode(row.partsJson)),
    createdAt: row.createdAt,
  );
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

/// 有界推进 UI：思考面板收起/流式光标不保证收敛，不用 pumpAndSettle。
Future<void> _settleUi(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 30));
    if (condition()) return;
  }
  fail('真实 SSE 到界面/数据库的状态未按预期完成');
}
