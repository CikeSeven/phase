import 'dart:convert';

import '../../core/error/failure.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/reasoning_effort.dart';
import '../sse_transport.dart';

/// 构造 Responses API（POST /responses）请求体。
///
/// 纯函数便于单测。system 消息置首条 developer 角色；
/// 推理等级映射为 `reasoning: {effort, summary: auto}`（off → effort none）。
Map<String, dynamic> buildResponsesPayload(ChatRequest request) {
  return {
    'model': request.model,
    'input': [
      for (final message in request.messages)
        switch (message.role) {
          ChatRole.system => {
            'role': 'developer',
            'content': [
              {'type': 'input_text', 'text': message.content},
            ],
          },
          ChatRole.user => {
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': message.content},
            ],
          },
          ChatRole.assistant => {
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': message.content},
            ],
          },
        },
    ],
    'stream': true,
    if (request.reasoningEffort case final effort?)
      'reasoning': effort == ReasoningEffort.off
          ? {'effort': 'none'}
          : {'effort': effort.name, 'summary': 'auto'},
    if (request.temperature != null) 'temperature': request.temperature,
    if (request.maxTokens != null) 'max_output_tokens': request.maxTokens,
  };
}

/// Responses API 的 SSE 事件解析。
abstract final class ResponsesSseDecoder {
  /// 解析单个 data 载荷；无事件的类型返回 null。
  ///
  /// `response.failed` / `error` 事件以 [ServerFailure] 抛出。
  static ChatChunk? parseEvent(String data) {
    if (data == '[DONE]') {
      return const ChatChunk(delta: '', done: true);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return switch (decoded['type']) {
      'response.output_text.delta' => ChatChunk(
        delta: decoded['delta'] is String ? decoded['delta'] as String : '',
      ),
      'response.reasoning_summary_text.delta' ||
      'response.reasoning_text.delta' => ChatChunk(
        delta: '',
        reasoningDelta: decoded['delta'] is String
            ? decoded['delta'] as String
            : null,
      ),
      'response.completed' ||
      'response.incomplete' => ChatChunk(
        delta: '',
        done: true,
        usage: _parseUsage(decoded['response']),
      ),
      'response.failed' => throw ServerFailure(
        '响应失败: ${_errorMessage(decoded['response'])}',
      ),
      'response.error' || 'error' => throw ServerFailure(
        '响应错误: ${_errorMessage(decoded)}',
      ),
      _ => null,
    };
  }

  static String _errorMessage(Object? holder) {
    if (holder is Map<String, dynamic>) {
      final error = holder['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        return error['message'] as String;
      }
    }
    return '未知错误';
  }

  static TokenUsage? _parseUsage(Object? response) {
    if (response is! Map<String, dynamic>) {
      return null;
    }
    final usage = response['usage'];
    if (usage is! Map<String, dynamic>) {
      return null;
    }
    int? asInt(Object? value) => value is int ? value : null;
    return TokenUsage(
      promptTokens: asInt(usage['input_tokens']),
      completionTokens: asInt(usage['output_tokens']),
      totalTokens: asInt(usage['total_tokens']),
    );
  }

  static Stream<ChatChunk> decode(Stream<List<int>> byteStream) async* {
    await for (final data in decodeSseDataLines(byteStream)) {
      final chunk = parseEvent(data);
      if (chunk != null) {
        yield chunk;
      }
    }
  }
}
