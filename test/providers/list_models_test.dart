import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/provider_error.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/providers/anthropic_messages/anthropic_messages_provider.dart';
import 'package:phase/providers/google_generative_ai/google_generative_ai_provider.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';
import 'package:phase/providers/openai_responses/openai_responses_provider.dart';

void main() {
  group('listModels 返回 ProfileModel 并带上鉴权头', () {
    test('OpenAI 兼容：data[].id 映射为模型 id', () async {
      final adapter = _FakeAdapter('{"data":[{"id":"gpt-x"},{"id":"gpt-y"}]}');
      final models = await _completions(adapter: adapter).listModels();
      expect(models.map((model) => model.id), ['gpt-x', 'gpt-y']);
      expect(adapter.lastRequest!.headers['Authorization'], 'Bearer key-1');
      expect(adapter.lastRequest!.uri.path, '/v1/models');
    });

    test('Anthropic：display_name 映射为展示名', () async {
      final adapter = _FakeAdapter(
        '{"data":[{"id":"claude-sonnet-4","display_name":"Claude Sonnet 4"}]}',
      );
      final models = await _anthropic(adapter: adapter).listModels();
      expect(models.single.id, 'claude-sonnet-4');
      expect(models.single.label, 'Claude Sonnet 4');
      expect(adapter.lastRequest!.headers['x-api-key'], 'key-1');
      expect(adapter.lastRequest!.headers['anthropic-version'], '2023-06-01');
    });

    test('Google：models/ 前缀被去掉', () async {
      final adapter = _FakeAdapter(
        '{"models":[{"name":"models/gemini-2.5-pro","displayName":"Gemini 2.5 Pro"}]}',
      );
      final models = await _google(adapter: adapter).listModels();
      expect(models.single.id, 'gemini-2.5-pro');
      expect(models.single.label, 'Gemini 2.5 Pro');
      expect(adapter.lastRequest!.headers['x-goog-api-key'], 'key-1');
    });

    test('Responses：data[].id 映射为模型 id', () async {
      final adapter = _FakeAdapter('{"data":[{"id":"gpt-5"}]}');
      final models = await _responses(adapter: adapter).listModels();
      expect(models.single.id, 'gpt-5');
      expect(adapter.lastRequest!.uri.path, '/v1/models');
    });

    test('requiresKey 为 false 时不发送鉴权头', () async {
      final adapter = _FakeAdapter('{"data":[{"id":"llama"}]}');
      final models = await _completions(
        adapter: adapter,
        requiresKey: false,
      ).listModels();
      expect(models.single.id, 'llama');
      expect(
        adapter.lastRequest!.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('每个实现的 protocol 对应 profile 所选协议', () {
      expect(_completions().protocol, ApiProtocol.openaiCompletions);
      expect(_responses().protocol, ApiProtocol.openaiResponses);
      expect(_anthropic().protocol, ApiProtocol.anthropicMessages);
      expect(_google().protocol, ApiProtocol.googleGenerativeAi);
    });
  });

  group('请求层错误映射为 ProviderError', () {
    test('HTTP 401 映射为 auth', () async {
      final provider = _completions(
        adapter: _FakeAdapter('{}', statusCode: 401),
      );
      await expectLater(
        provider.listModels(),
        throwsA(
          isA<ProviderError>().having(
            (error) => error.category,
            'category',
            ProviderErrorCategory.auth,
          ),
        ),
      );
    });

    test('HTTP 429 映射为 rateLimit', () async {
      final provider = _completions(
        adapter: _FakeAdapter('{}', statusCode: 429),
      );
      await expectLater(
        provider.listModels(),
        throwsA(
          isA<ProviderError>().having(
            (error) => error.category,
            'category',
            ProviderErrorCategory.rateLimit,
          ),
        ),
      );
    });

    test('未填写服务商地址时给出配置错误，不发送请求', () async {
      final adapter = _FakeAdapter('{}');
      final provider = _completions(adapter: adapter, baseUrl: '');
      await expectLater(
        provider.listModels(),
        throwsA(
          isA<ProviderError>().having(
            (error) => error.category,
            'category',
            ProviderErrorCategory.config,
          ),
        ),
      );
      expect(adapter.lastRequest, isNull);
    });
  });

  group('streamChat 全链路', () {
    test('请求体带上模型名，SSE 事件按契约输出', () async {
      final adapter = _FakeAdapter(
        'data: {"choices":[{"delta":{"content":"你好"}}]}\n\n'
        'data: {"choices":[{"delta":{},"finish_reason":"stop"}],'
        '"usage":{"prompt_tokens":1,"completion_tokens":2}}\n\n'
        'data: [DONE]\n\n',
        contentType: 'text/event-stream',
      );
      final provider = _completions(adapter: adapter);
      final chunks = await provider
          .streamChat(
            const ChatRequest(
              modelId: 'test-model',
              messages: [
                ResolvedMessage(
                  role: ChatRole.user,
                  parts: [ResolvedText('你好')],
                ),
              ],
            ),
          )
          .toList();

      final payload = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(payload['model'], 'test-model');
      expect(payload['stream'], isTrue);
      expect(
        chunks.whereType<TextDelta>().map((chunk) => chunk.text).join(),
        '你好',
      );
      expect(chunks.whereType<UsageChunk>().single.usage.outputTokens, 2);
      expect(chunks.last, isA<ResponseEnd>());
    });

    test('免 Key 服务商的对话请求不带鉴权头', () async {
      final adapter = _FakeAdapter(
        'data: [DONE]\n\n',
        contentType: 'text/event-stream',
      );
      await _completions(adapter: adapter, requiresKey: false)
          .streamChat(
            const ChatRequest(
              modelId: 'llama3',
              messages: [
                ResolvedMessage(
                  role: ChatRole.user,
                  parts: [ResolvedText('你好')],
                ),
              ],
            ),
          )
          .toList();
      expect(
        adapter.lastRequest!.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('HTTP 错误以 ProviderError 抛出，不是流内事件', () async {
      final provider = _completions(
        adapter: _FakeAdapter(
          '{"error":{"type":"overloaded_error"}}',
          statusCode: 529,
        ),
      );
      await expectLater(
        provider
            .streamChat(
              const ChatRequest(
                modelId: 'test-model',
                messages: [
                  ResolvedMessage(
                    role: ChatRole.user,
                    parts: [ResolvedText('你好')],
                  ),
                ],
              ),
            )
            .toList(),
        throwsA(
          isA<ProviderError>().having(
            (error) => error.category,
            'category',
            ProviderErrorCategory.providerError,
          ),
        ),
      );
    });

    test('订阅取消会中断底层请求', () async {
      final adapter = _CancellableAdapter();
      final provider = _completions(adapter: adapter);
      final subscription = provider
          .streamChat(
            const ChatRequest(
              modelId: 'test-model',
              messages: [
                ResolvedMessage(
                  role: ChatRole.user,
                  parts: [ResolvedText('你好')],
                ),
              ],
            ),
          )
          .listen((_) {});
      await adapter.started.future;
      await subscription.cancel();
      expect(adapter.cancelled, isTrue);
    });
  });
}

ProviderProfile _profile({
  required ApiProtocol protocol,
  String baseUrl = 'https://example.com/v1',
  bool requiresKey = true,
}) {
  return ProviderProfile(
    id: 'p1',
    name: '测试服务商',
    protocol: protocol,
    baseUrl: baseUrl,
    requiresKey: requiresKey,
    createdAt: DateTime(2026),
  );
}

OpenAiCompletionsProvider _completions({
  HttpClientAdapter? adapter,
  bool requiresKey = true,
  String baseUrl = 'https://example.com/v1',
}) {
  return OpenAiCompletionsProvider(
    profile: _profile(
      protocol: ApiProtocol.openaiCompletions,
      baseUrl: baseUrl,
      requiresKey: requiresKey,
    ),
    apiKey: 'key-1',
    dio: _dio(adapter),
  );
}

OpenAiResponsesProvider _responses({_FakeAdapter? adapter}) {
  return OpenAiResponsesProvider(
    profile: _profile(protocol: ApiProtocol.openaiResponses),
    apiKey: 'key-1',
    dio: _dio(adapter),
  );
}

AnthropicMessagesProvider _anthropic({_FakeAdapter? adapter}) {
  return AnthropicMessagesProvider(
    profile: _profile(
      protocol: ApiProtocol.anthropicMessages,
      baseUrl: 'https://api.anthropic.com',
    ),
    apiKey: 'key-1',
    dio: _dio(adapter),
  );
}

GoogleGenerativeAiProvider _google({_FakeAdapter? adapter}) {
  return GoogleGenerativeAiProvider(
    profile: _profile(
      protocol: ApiProtocol.googleGenerativeAi,
      baseUrl: 'https://generativelanguage.googleapis.com',
    ),
    apiKey: 'key-1',
    dio: _dio(adapter),
  );
}

Dio _dio(HttpClientAdapter? adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/v1'));
  if (adapter != null) dio.httpClientAdapter = adapter;
  return dio;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(
    this.body, {
    this.statusCode = 200,
    this.contentType = 'application/json',
  });

  final String body;
  final int statusCode;
  final String contentType;

  /// 最近一次请求；用于断言 URL、头与请求体。
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 一直等待、只在取消时结束的适配器，用于验证停止生成。
class _CancellableAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  var cancelled = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    started.complete();
    final controller = StreamController<Uint8List>();
    cancelFuture?.whenComplete(() {
      cancelled = true;
      if (!controller.isClosed) controller.close();
    });
    return ResponseBody(controller.stream, 200);
  }

  @override
  void close({bool force = false}) {}
}
