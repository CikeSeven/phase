import 'dart:convert';

import '../../core/error/failure.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/reasoning_effort.dart';
import '../attachment_encoder.dart';
import '../sse_transport.dart';

/// 构造 Anthropic Messages（POST /v1/messages）请求体。
///
/// 纯函数便于单测。system 提取为独立字段；
/// 推理等级映射 `thinking: {type: enabled, budget_tokens}`，
/// 并保证 budget + 1024 ≤ max_tokens（不够就抬 max_tokens）。
Map<String, dynamic> buildAnthropicPayload(
  ChatRequest request, {
  List<List<AttachmentPayload>>? attachments,
}) {
  var maxTokens = request.maxTokens ?? 8192;
  Map<String, dynamic>? thinking;
  if (request.reasoningEffort case final effort?) {
    if (effort == ReasoningEffort.off) {
      thinking = {'type': 'disabled'};
    } else {
      final budget = switch (effort) {
        ReasoningEffort.low => 1024,
        ReasoningEffort.medium => 4096,
        ReasoningEffort.high => 16384,
        ReasoningEffort.xhigh => 32768,
        ReasoningEffort.max => 65536,
        ReasoningEffort.off => 0,
      };
      if (budget + 1024 > maxTokens) {
        maxTokens = budget + 1024;
      }
      thinking = {'type': 'enabled', 'budget_tokens': budget};
    }
  }

  Object contentFor(ChatMessage message, int index) {
    final parts = attachments == null || index >= attachments.length
        ? const <AttachmentPayload>[]
        : attachments[index];
    if (parts.isEmpty) {
      return message.content;
    }
    return [
      if (message.content.isNotEmpty) {'type': 'text', 'text': message.content},
      for (final part in parts)
        if (part.isImage)
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': part.mimeType,
              'data': part.base64Data,
            },
          }
        else
          {'type': 'text', 'text': part.text},
    ];
  }

  return {
    'model': request.model,
    'max_tokens': maxTokens,
    'messages': [
      for (var index = 0; index < request.messages.length; index++)
        if (request.messages[index].role != ChatRole.system)
          {
            'role': request.messages[index].role.name,
            'content': contentFor(request.messages[index], index),
          },
    ],
    'system': ?_systemText(request.messages),
    'stream': true,
    'thinking': ?thinking,
    if (request.temperature != null) 'temperature': request.temperature,
  };
}

String? _systemText(List<ChatMessage> messages) {
  final parts = [
    for (final message in messages)
      if (message.role == ChatRole.system) message.content,
  ];
  return parts.isEmpty ? null : parts.join('\n\n');
}

/// Anthropic Messages 的 SSE 事件解析。
abstract final class AnthropicSseDecoder {
  /// 解析单个 data 载荷；无产出的类型返回 null。
  ///
  /// [inputTokens] 传入 message_start 阶段读到的值，在 message_delta
  /// 合成 usage 时并入（代理网关在 message_delta 里常省略 input_tokens）。
  /// `error` 事件以 [ServerFailure] 抛出。
  static ChatChunk? parseEvent(String data, {int? inputTokens}) {
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
      'content_block_delta' => _parseBlockDelta(decoded['delta']),
      'message_delta' => ChatChunk(
        delta: '',
        done: true,
        usage: _parseUsage(decoded['usage'], inputTokens),
      ),
      'message_stop' => const ChatChunk(delta: '', done: true),
      'error' => throw ServerFailure(
        '响应错误: ${_errorMessage(decoded['error'])}',
      ),
      _ => null,
    };
  }

  static ChatChunk? _parseBlockDelta(Object? delta) {
    if (delta is! Map<String, dynamic>) {
      return null;
    }
    return switch (delta['type']) {
      'text_delta' => ChatChunk(
        delta: delta['text'] is String ? delta['text'] as String : '',
      ),
      'thinking_delta' => ChatChunk(
        delta: '',
        reasoningDelta: delta['thinking'] is String
            ? delta['thinking'] as String
            : null,
      ),
      _ => null,
    };
  }

  static String _errorMessage(Object? error) {
    if (error is Map<String, dynamic> && error['message'] is String) {
      return error['message'] as String;
    }
    return '未知错误';
  }

  static TokenUsage? _parseUsage(Object? usage, int? inputTokens) {
    if (usage is! Map<String, dynamic>) {
      return null;
    }
    int? asInt(Object? value) => value is int ? value : null;
    final prompt = asInt(usage['input_tokens']) ?? inputTokens;
    final completion = asInt(usage['output_tokens']);
    return TokenUsage(
      promptTokens: prompt,
      completionTokens: completion,
      totalTokens: prompt != null && completion != null
          ? prompt + completion
          : null,
    );
  }

  static int? readInputTokens(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic> &&
          decoded['type'] == 'message_start') {
        final message = decoded['message'];
        if (message is Map<String, dynamic>) {
          final usage = message['usage'];
          if (usage is Map<String, dynamic> && usage['input_tokens'] is int) {
            return usage['input_tokens'] as int;
          }
        }
      }
    } on FormatException {
      // 按无 input_tokens 处理。
    }
    return null;
  }

  static Stream<ChatChunk> decode(Stream<List<int>> byteStream) async* {
    int? inputTokens;
    await for (final data in decodeSseDataLines(byteStream)) {
      inputTokens ??= readInputTokens(data);
      final chunk = parseEvent(data, inputTokens: inputTokens);
      if (chunk != null) {
        yield chunk;
      }
    }
  }
}
