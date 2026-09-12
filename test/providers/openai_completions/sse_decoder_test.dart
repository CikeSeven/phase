import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/provider_error.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/providers/dio_failure_mapper.dart';
import 'package:phase/providers/openai_completions/sse_decoder.dart';

void main() {
  group('OpenAiSseDecoder.parseLine', () {
    test('解析普通增量行', () {
      final chunks = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"content":"你好"},"finish_reason":null}]}',
      );
      expect(_text(chunks), '你好');
      expect(chunks.whereType<PartStart>().single.partId, 'text_0');
      expect(chunks.whereType<PartStart>().single.kind, PartKind.text);
      expect(
        chunks.whereType<PartEnd>().single.part,
        isA<TextPart>().having((part) => part.text, 'text', '你好'),
      );
    });

    test('解析 [DONE] 终止标记', () {
      final chunks = OpenAiSseDecoder.parseLine('data: [DONE]');
      expect(chunks.whereType<ResponseEnd>(), hasLength(1));
      expect(_text(chunks), isEmpty);
    });

    test('解析带 finish_reason 的结束行', () {
      final chunks = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}',
      );
      expect(chunks.whereType<ResponseEnd>(), hasLength(1));
      expect(_text(chunks), isEmpty);
    });

    test('解析 reasoning_content 字段（DeepSeek R1 风格）', () {
      final chunks = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"reasoning_content":"在想","content":""},'
        '"finish_reason":null}]}',
      );
      expect(_reasoning(chunks), '在想');
      expect(_text(chunks), isEmpty);
      expect(chunks.whereType<PartStart>().single.kind, PartKind.reasoning);
    });

    test('reasoning_content 与 content 可同帧出现', () {
      final chunks = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"reasoning_content":"想",'
        '"content":"答"},"finish_reason":null}]}',
      );
      expect(_reasoning(chunks), '想');
      expect(_text(chunks), '答');
    });

    test('解析 usage 信息', () {
      final chunks = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"content":""},"finish_reason":"stop"}],'
        '"usage":{"prompt_tokens":3,"completion_tokens":5,"total_tokens":8,'
        '"completion_tokens_details":{"reasoning_tokens":2},'
        '"prompt_tokens_details":{"cached_tokens":1}}}',
      );
      final usage = _usage(chunks);
      expect(usage?.inputTokens, 3);
      expect(usage?.outputTokens, 5);
      expect(usage?.reasoningTokens, 2);
      expect(usage?.cachedInputTokens, 1);
    });

    test('空行、注释与非 data 行不产生事件', () {
      expect(OpenAiSseDecoder.parseLine(''), isEmpty);
      expect(OpenAiSseDecoder.parseLine(': keep-alive'), isEmpty);
      expect(OpenAiSseDecoder.parseLine('event: message'), isEmpty);
      expect(OpenAiSseDecoder.parseLine('data: '), isEmpty);
    });

    test('格式异常的行被忽略而不抛出', () {
      expect(OpenAiSseDecoder.parseLine('data: {not json'), isEmpty);
      expect(OpenAiSseDecoder.parseLine('data: "just a string"'), isEmpty);
    });
  });

  group('OpenAiSseDecoder.decode', () {
    test('完整 SSE 字节流解析为 ChatChunk 事件序列', () async {
      const sseText =
          'data: {"choices":[{"delta":{"content":"你"},'
          '"finish_reason":null}]}\n'
          '\n'
          'data: {"choices":[{"delta":{"content":"好"},'
          '"finish_reason":null}]}\n'
          '\n'
          'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n'
          '\n'
          'data: [DONE]\n'
          '\n';
      final chunks = await OpenAiSseDecoder.decode(
        Stream.value(utf8.encode(sseText)),
      ).toList();

      expect(chunks.first, isA<PartStart>());
      expect(_text(chunks), '你好');
      // 增量归并到同一 partId，完成快照不重复追加。
      expect(chunks.whereType<TextDelta>(), hasLength(2));
      expect(chunks.whereType<PartEnd>(), hasLength(1));
      expect(chunks.whereType<ResponseEnd>(), hasLength(1));
      expect(chunks.last, isA<ResponseEnd>());
      expect((chunks.last as ResponseEnd).hasVisibleContent, isTrue);
    });

    test('没有 [DONE] 的流在字节流结束时同样收口', () async {
      final chunks = await OpenAiSseDecoder.decode(
        Stream.value(
          utf8.encode('data: {"choices":[{"delta":{"content":"收尾"}}]}\n\n'),
        ),
      ).toList();
      expect(_text(chunks), '收尾');
      expect(chunks.last, isA<ResponseEnd>());
      expect(chunks.whereType<ResponseEnd>(), hasLength(1));
    });

    test('全空响应收口为 hasVisibleContent=false', () async {
      final chunks = await OpenAiSseDecoder.decode(
        Stream.value(utf8.encode('data: [DONE]\n\n')),
      ).toList();
      expect(chunks.single, isA<ResponseEnd>());
      expect((chunks.single as ResponseEnd).hasVisibleContent, isFalse);
    });

    test('跨 chunk 的半截行被正确拼接', () async {
      const line =
          'data: {"choices":[{"delta":{"content":"完整的一句"},'
          '"finish_reason":null}]}\n\n';
      final bytes = utf8.encode(line);
      // 以极小切片模拟网络分片，包含多字节 UTF-8 字符被切断的情况。
      final slices = [
        for (var i = 0; i < bytes.length; i += 7)
          bytes.sublist(i, i + 7 > bytes.length ? bytes.length : i + 7),
      ];
      final chunks = await OpenAiSseDecoder.decode(Stream.fromIterable(slices))
          .toList();
      expect(_text(chunks), '完整的一句');
    });
  });

  group('流式工具调用组装', () {
    test('参数片段只追加到调用缓冲，收口后给出完整调用', () async {
      const sseText =
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1",'
          '"type":"function","function":{"name":"get_weather","arguments":""}}]}}]}\n\n'
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
          '"function":{"arguments":"{\\"city\\":"}}]}}]}\n\n'
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
          '"function":{"arguments":"\\"北京\\"}"}}]}}]}\n\n'
          'data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}\n\n'
          'data: [DONE]\n\n';
      final chunks = await OpenAiSseDecoder.decode(
        Stream.value(utf8.encode(sseText)),
      ).toList();

      expect(chunks.whereType<PartStart>().single.partId, 'tool_0');
      expect(chunks.whereType<PartStart>().single.kind, PartKind.toolCall);
      final deltas = chunks.whereType<ToolCallDelta>().toList();
      // 首个片段带出调用 id 与工具名，后续片段只带参数。
      expect(deltas.first.callId, 'call_1');
      expect(deltas.first.toolName, 'get_weather');
      expect(deltas.every((delta) => delta.partId == 'tool_0'), isTrue);
      expect(
        deltas.map((delta) => delta.argumentsFragment ?? '').join(),
        '{"city":"北京"}',
      );
      expect(
        chunks.whereType<PartEnd>().single.part,
        isA<ToolCallPart>().having(
          (part) => part.toolCallId,
          'toolCallId',
          'call_1',
        ),
      );
      expect((chunks.last as ResponseEnd).hasVisibleContent, isTrue);
      // 正文通道没有内容：工具调用不算正文。
      expect(_text(chunks), isEmpty);
    });

    test('一轮内的多个调用按 index 分块', () async {
      const sseText =
          'data: {"choices":[{"delta":{"tool_calls":['
          '{"index":0,"id":"call_a","function":{"name":"a","arguments":"{}"}},'
          '{"index":1,"id":"call_b","function":{"name":"b","arguments":"{}"}}'
          ']}}]}\n\n'
          'data: [DONE]\n\n';
      final chunks = await OpenAiSseDecoder.decode(
        Stream.value(utf8.encode(sseText)),
      ).toList();
      final starts = chunks.whereType<PartStart>().toList();
      expect(starts.map((start) => start.partId), ['tool_0', 'tool_1']);
      expect(
        chunks.whereType<PartEnd>().map(
          (end) => (end.part as ToolCallPart).toolCallId,
        ),
        ['call_a', 'call_b'],
      );
    });
  });

  // 网关字段变体：reasoning / reasoning_text 也应解析为思考增量（gpt 系网关常见）。
  group('reasoning 字段变体', () {
    test('delta.reasoning 解析为思考增量', () {
      final chunks = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"reasoning":"嗯"},"index":0}]}',
      );
      expect(_reasoning(chunks), '嗯');
    });

    test('delta.reasoning_text 解析为思考增量', () {
      final chunks = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"reasoning_text":"想想"},"index":0}]}',
      );
      expect(_reasoning(chunks), '想想');
    });

    test('reasoning_content 优先级高于 reasoning', () {
      final chunks = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"reasoning_content":"A","reasoning":"B"},"index":0}]}',
      );
      expect(_reasoning(chunks), 'A');
    });
  });

  group('公开 reasoning_details 后备', () {
    test('details-only 接收 reasoning.text.text 与 reasoning.summary.summary', () {
      final chunks = OpenAiSseDecoder.parseLine(
        'data:{"choices":[{"delta":{"reasoning_details":['
        '{"type":"reasoning.text","text":"先检查"},'
        '{"type":"reasoning.summary","summary":"输入。"}'
        '],"content":"正文"}}]}',
      );
      expect(_reasoning(chunks), '先检查输入。');
      expect(_text(chunks), '正文');
    });

    test('首非空别名优先，不能与同帧 details 重复追加', () {
      for (final alias in [
        'reasoning_content',
        'reasoning',
        'reasoning_text',
      ]) {
        final chunks = OpenAiSseDecoder.parseLine(
          'data:${jsonEncode({
            'choices': [
              {
                'delta': {
                  'reasoning_content': '',
                  'reasoning': '',
                  'reasoning_text': '',
                  alias: '摘要',
                  'reasoning_details': [
                    {'type': 'reasoning.summary', 'summary': '摘要'},
                  ],
                },
              },
            ],
          })}',
        );
        expect(_reasoning(chunks), '摘要', reason: alias);
      }
    });

    test('encrypted、signature、usage 与畸形 details 不生成公开思考，但留下回传明细', () {
      final chunks = OpenAiSseDecoder.parseLine(
        'data:${jsonEncode({
          'choices': [
            {
              'delta': {
                'reasoning_details': [
                  null,
                  42,
                  {'type': 'reasoning.encrypted', 'data': 'cipher', 'text': 'hidden'},
                  {'type': 'signature', 'text': 'hidden'},
                  {'type': 'reasoning.text', 'text': 42},
                  {'type': 'reasoning.summary', 'summary': null},
                ],
              },
            },
          ],
          'usage': {'completion_tokens': 10, 'reasoning_tokens': 8},
        })}',
      );
      expect(_reasoning(chunks), isEmpty);
      expect(_text(chunks), isEmpty);
      // 明细没有可展示文本，但下一轮要原样送回去：块照样成立，带着协议状态。
      final ends = chunks.whereType<PartEnd>().toList();
      expect(ends, hasLength(1));
      expect(ends.single.part, isA<ReasoningPart>());
      expect(
        (ends.single.part as ReasoningPart).providerData?['details'],
        isNotEmpty,
      );
      expect(_usage(chunks)?.outputTokens, 10);
    });

    test('空别名允许公开 details 后备，非 List details 忽略', () {
      final chunks = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"reasoning_content":"",'
        '"reasoning_details":[{"type":"reasoning.text","text":"摘要"}]}}]}',
      );
      expect(_reasoning(chunks), '摘要');
      expect(
        _reasoning(
          OpenAiSseDecoder.parseLine(
            'data: {"choices":[{"delta":{"reasoning_details":{"text":"不接受"}}}]}',
          ),
        ),
        isEmpty,
      );
    });

    test('多行 data 的 details 与带内错误经过共享 framing', () async {
      const text =
          'data:{broken}\n\n'
          'data:{"choices":[{"delta":{\r\n'
          'data:"reasoning_details":[{"type":"reasoning.summary","summary":"中文摘要"}]}}]}\r\n\r\n'
          'data:{"error":\n'
          'data:{"message":"overloaded"}}\n\n';
      final chunks = await OpenAiSseDecoder.decode(
        Stream.fromIterable(utf8.encode(text).map((byte) => [byte])),
      ).toList();
      expect(_reasoning(chunks), '中文摘要');
      expect(_error(chunks)?.message, 'overloaded');
    });
  });

  // 带内错误事件（HTTP 200 的 SSE 里夹 {"error": ...}）必须解析出来，不能吞掉。
  group('带内错误事件', () {
    test('error 对象为 message 字符串', () {
      final chunks = OpenAiSseDecoder.parseLine(
        'data: {"error":{"message":"reasoning_effort is not supported"}}',
      );
      expect(_error(chunks)?.message, 'reasoning_effort is not supported');
      expect(chunks.whereType<ResponseEnd>(), isEmpty);
    });

    test('error 为纯字符串', () {
      final chunks = OpenAiSseDecoder.parseLine('data: {"error":"boom"}');
      expect(_error(chunks)?.message, 'boom');
    });

    test('协议错误字段决定分类，带内错误终结本响应', () async {
      final chunks = await OpenAiSseDecoder.decode(
        Stream.value(
          utf8.encode(
            'data: {"error":{"type":"rate_limit_error","message":"慢一点"}}\n\n'
            'data: {"choices":[{"delta":{"content":"迟到"}}]}\n\n',
          ),
        ),
      ).toList();
      expect(_error(chunks)?.category, ProviderErrorCategory.rateLimit);
      expect(_text(chunks), isEmpty);
      expect(chunks.whereType<ResponseEnd>(), isEmpty);
    });
  });

  group('mapDioExceptionToProviderError', () {
    DioException dioError(
      DioExceptionType type, {
      int? statusCode,
      Object? data,
    }) {
      return DioException(
        requestOptions: RequestOptions(),
        type: type,
        response: statusCode == null
            ? null
            : Response<dynamic>(
                requestOptions: RequestOptions(),
                statusCode: statusCode,
                data: data,
              ),
      );
    }

    test('HTTP 401 / 403 映射为 auth', () {
      expect(
        mapDioExceptionToProviderError(
          dioError(DioExceptionType.badResponse, statusCode: 401),
        ).category,
        ProviderErrorCategory.auth,
      );
      expect(
        mapDioExceptionToProviderError(
          dioError(DioExceptionType.badResponse, statusCode: 403),
        ).category,
        ProviderErrorCategory.auth,
      );
    });

    test('HTTP 429 映射为 rateLimit', () {
      expect(
        mapDioExceptionToProviderError(
          dioError(DioExceptionType.badResponse, statusCode: 429),
        ).category,
        ProviderErrorCategory.rateLimit,
      );
    });

    test('HTTP 5xx 映射为 providerError', () {
      for (final status in [500, 503, 529]) {
        expect(
          mapDioExceptionToProviderError(
            dioError(DioExceptionType.badResponse, statusCode: status),
          ).category,
          ProviderErrorCategory.providerError,
          reason: 'HTTP $status',
        );
      }
    });

    test('连接错误映射为 network，超时映射为 timeout', () {
      expect(
        mapDioExceptionToProviderError(
          dioError(DioExceptionType.connectionError),
        ).category,
        ProviderErrorCategory.network,
      );
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          mapDioExceptionToProviderError(dioError(type)).category,
          ProviderErrorCategory.timeout,
          reason: '$type 应映射为 timeout',
        );
      }
    });

    test('取消映射为 cancelled', () {
      expect(
        mapDioExceptionToProviderError(dioError(DioExceptionType.cancel))
            .category,
        ProviderErrorCategory.cancelled,
      );
    });

    test('其他 4xx 映射为 invalidRequest', () {
      expect(
        mapDioExceptionToProviderError(
          dioError(DioExceptionType.badResponse, statusCode: 400),
        ).category,
        ProviderErrorCategory.invalidRequest,
      );
      expect(
        mapDioExceptionToProviderError(dioError(DioExceptionType.unknown))
            .category,
        ProviderErrorCategory.network,
      );
    });

    test('协议明确错误字段优先于状态码', () {
      expect(
        mapDioExceptionToProviderError(
          dioError(
            DioExceptionType.badResponse,
            statusCode: 400,
            data: {
              'error': {'code': 'context_length_exceeded', 'message': '太长'},
            },
          ),
        ).category,
        ProviderErrorCategory.contextLimit,
      );
      expect(
        mapDioExceptionToProviderError(
          dioError(
            DioExceptionType.badResponse,
            statusCode: 500,
            data: {
              'error': {'type': 'invalid_request_error', 'message': '参数错'},
            },
          ),
        ).category,
        ProviderErrorCategory.invalidRequest,
      );
      // 未在协议错误字段表中出现的取值不猜测分类。
      expect(
        mapDioExceptionToProviderError(
          dioError(
            DioExceptionType.badResponse,
            statusCode: 402,
            data: {
              'error': {'code': 'some_unknown_code'},
            },
          ),
        ).category,
        ProviderErrorCategory.invalidRequest,
      );
    });
  });
}

String _text(List<ChatChunk> chunks) =>
    chunks.whereType<TextDelta>().map((chunk) => chunk.text).join();

String _reasoning(List<ChatChunk> chunks) =>
    chunks.whereType<ReasoningDelta>().map((chunk) => chunk.text).join();

TokenUsage? _usage(List<ChatChunk> chunks) {
  for (final chunk in chunks) {
    if (chunk is UsageChunk) return chunk.usage;
  }
  return null;
}

ProviderError? _error(List<ChatChunk> chunks) {
  for (final chunk in chunks) {
    if (chunk is ResponseError) return chunk.error;
  }
  return null;
}
