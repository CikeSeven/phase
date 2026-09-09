import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/providers/dio_failure_mapper.dart';
import 'package:phase/providers/openai_completions/sse_decoder.dart';

void main() {
  group('OpenAiSseDecoder.parseLine', () {
    test('解析普通增量行', () {
      final chunk = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"content":"你好"},"finish_reason":null}]}',
      );
      expect(chunk, isNotNull);
      expect(chunk!.delta, '你好');
      expect(chunk.done, isFalse);
      expect(chunk.usage, isNull);
    });

    test('解析 [DONE] 终止标记', () {
      final chunk = OpenAiSseDecoder.parseLine('data: [DONE]');
      expect(chunk, isNotNull);
      expect(chunk!.done, isTrue);
      expect(chunk.delta, isEmpty);
    });

    test('解析带 finish_reason 的结束行', () {
      final chunk = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}',
      );
      expect(chunk, isNotNull);
      expect(chunk!.done, isTrue);
      expect(chunk.delta, isEmpty);
    });

    test('解析 reasoning_content 字段（DeepSeek R1 风格）', () {
      final chunk = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"reasoning_content":"在想","content":""},'
        '"finish_reason":null}]}',
      );
      expect(chunk, isNotNull);
      expect(chunk!.reasoningDelta, '在想');
      expect(chunk.delta, isEmpty);
      expect(chunk.done, isFalse);
    });

    test('reasoning_content 与 content 可同帧出现', () {
      final chunk = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"reasoning_content":"想",'
        '"content":"答"},"finish_reason":null}]}',
      );
      expect(chunk, isNotNull);
      expect(chunk!.reasoningDelta, '想');
      expect(chunk.delta, '答');
    });

    test('解析 usage 信息', () {
      final chunk = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"content":""},"finish_reason":"stop"}],'
        '"usage":{"prompt_tokens":3,"completion_tokens":5,"total_tokens":8}}',
      );
      expect(chunk, isNotNull);
      expect(chunk!.usage, isNotNull);
      expect(chunk.usage!.promptTokens, 3);
      expect(chunk.usage!.completionTokens, 5);
      expect(chunk.usage!.totalTokens, 8);
    });

    test('空行、注释与非 data 行不产生事件', () {
      expect(OpenAiSseDecoder.parseLine(''), isNull);
      expect(OpenAiSseDecoder.parseLine(': keep-alive'), isNull);
      expect(OpenAiSseDecoder.parseLine('event: message'), isNull);
      expect(OpenAiSseDecoder.parseLine('data: '), isNull);
    });

    test('格式异常的行被忽略而不抛出', () {
      expect(OpenAiSseDecoder.parseLine('data: {not json'), isNull);
      expect(OpenAiSseDecoder.parseLine('data: "just a string"'), isNull);
    });
  });

  group('OpenAiSseDecoder.decode', () {
    test('完整 SSE 字节流解析为 ChatChunk 序列', () async {
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

      expect(chunks, hasLength(4));
      expect(chunks[0].delta, '你');
      expect(chunks[1].delta, '好');
      expect(chunks[2].done, isTrue);
      expect(chunks[3].done, isTrue);
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
      expect(chunks, hasLength(1));
      expect(chunks.single.delta, '完整的一句');
    });
  });

  group('mapDioExceptionToFailure', () {
    DioException dioError(DioExceptionType type, {int? statusCode}) {
      return DioException(
        requestOptions: RequestOptions(),
        type: type,
        response: statusCode == null
            ? null
            : Response<dynamic>(
                requestOptions: RequestOptions(),
                statusCode: statusCode,
              ),
      );
    }

    test('HTTP 401 / 403 映射为 AuthFailure', () {
      expect(
        mapDioExceptionToFailure(
          dioError(DioExceptionType.badResponse, statusCode: 401),
        ),
        isA<AuthFailure>(),
      );
      expect(
        mapDioExceptionToFailure(
          dioError(DioExceptionType.badResponse, statusCode: 403),
        ),
        isA<AuthFailure>(),
      );
    });

    test('HTTP 429 映射为 RateLimitFailure', () {
      expect(
        mapDioExceptionToFailure(
          dioError(DioExceptionType.badResponse, statusCode: 429),
        ),
        isA<RateLimitFailure>(),
      );
    });

    test('HTTP 5xx 映射为 ServerFailure', () {
      expect(
        mapDioExceptionToFailure(
          dioError(DioExceptionType.badResponse, statusCode: 500),
        ),
        isA<ServerFailure>(),
      );
      expect(
        mapDioExceptionToFailure(
          dioError(DioExceptionType.badResponse, statusCode: 503),
        ),
        isA<ServerFailure>(),
      );
    });

    test('连接错误与超时映射为 NetworkFailure', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          mapDioExceptionToFailure(dioError(type)),
          isA<NetworkFailure>(),
          reason: '$type 应映射为 NetworkFailure',
        );
      }
    });

    test('取消映射为 CancelledFailure', () {
      expect(
        mapDioExceptionToFailure(dioError(DioExceptionType.cancel)),
        isA<CancelledFailure>(),
      );
    });

    test('其他 4xx 与未知错误映射为 UnknownFailure', () {
      expect(
        mapDioExceptionToFailure(
          dioError(DioExceptionType.badResponse, statusCode: 400),
        ),
        isA<UnknownFailure>(),
      );
      expect(
        mapDioExceptionToFailure(dioError(DioExceptionType.unknown)),
        isA<UnknownFailure>(),
      );
    });
  });

  // 网关字段变体：reasoning / reasoning_text 也应解析为思考增量（gpt 系网关常见）。
  group('reasoning 字段变体', () {
    test('delta.reasoning 解析为思考增量', () {
      final chunk = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"reasoning":"嗯"},"index":0}]}',
      );
      expect(chunk?.reasoningDelta, '嗯');
    });

    test('delta.reasoning_text 解析为思考增量', () {
      final chunk = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"reasoning_text":"想想"},"index":0}]}',
      );
      expect(chunk?.reasoningDelta, '想想');
    });

    test('reasoning_content 优先级高于 reasoning', () {
      final chunk = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"reasoning_content":"A","reasoning":"B"},"index":0}]}',
      );
      expect(chunk?.reasoningDelta, 'A');
    });
  });

  group('公开 reasoning_details 后备', () {
    test('details-only 接收 reasoning.text.text 与 reasoning.summary.summary', () {
      final chunk = OpenAiSseDecoder.parseLine(
        'data:{"choices":[{"delta":{"reasoning_details":['
        '{"type":"reasoning.text","text":"先检查"},'
        '{"type":"reasoning.summary","summary":"输入。"}'
        '],"content":"正文"}}]}',
      );
      expect(chunk?.reasoningDelta, '先检查输入。');
      expect(chunk?.delta, '正文');
    });

    test('首非空别名优先，不能与同帧 details 重复追加', () {
      for (final alias in [
        'reasoning_content',
        'reasoning',
        'reasoning_text',
      ]) {
        final chunk = OpenAiSseDecoder.parseLine(
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
        expect(chunk?.reasoningDelta, '摘要', reason: alias);
      }
    });

    test('encrypted、signature、usage 与畸形 details 不能生成思考', () {
      final chunk = OpenAiSseDecoder.parseLine(
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
      expect(chunk?.reasoningDelta, isNull);
      expect(chunk?.delta, isEmpty);
      expect(chunk?.usage?.completionTokens, 10);
    });

    test('空别名允许公开 details 后备，非 List details 忽略', () {
      final chunk = OpenAiSseDecoder.parseLine(
        'data: {"choices":[{"delta":{"reasoning_content":"",'
        '"reasoning_details":[{"type":"reasoning.text","text":"摘要"}]}}]}',
      );
      expect(chunk?.reasoningDelta, '摘要');
      expect(
        OpenAiSseDecoder.parseLine(
          'data: {"choices":[{"delta":{"reasoning_details":{"text":"不接受"}}}]}',
        )?.reasoningDelta,
        isNull,
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
      expect(chunks.first.reasoningDelta, '中文摘要');
      expect(chunks.last.errorMessage, 'overloaded');
      expect(chunks.last.done, isTrue);
    });
  });

  // 带内错误事件（HTTP 200 的 SSE 里夹 {"error": ...}）必须解析出来，不能吞掉。
  group('带内错误事件', () {
    test('error 对象为 message 字符串', () {
      final chunk = OpenAiSseDecoder.parseLine(
        'data: {"error":{"message":"reasoning_effort is not supported"}}',
      );
      expect(chunk?.errorMessage, 'reasoning_effort is not supported');
      expect(chunk?.done, isTrue);
    });

    test('error 为纯字符串', () {
      final chunk = OpenAiSseDecoder.parseLine('data: {"error":"boom"}');
      expect(chunk?.errorMessage, 'boom');
    });
  });
}
