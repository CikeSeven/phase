import 'dart:convert';

import '../../core/error/failure.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/reasoning_effort.dart';
import '../sse_transport.dart';

/// 构造 Google Generative AI（streamGenerateContent）请求体。
///
/// 纯函数便于单测。system 提取为 systemInstruction；
/// 推理等级映射 `generationConfig.thinkingConfig.thinkingBudget`
///（off → 0；Gemini 2.x 支持以 0 关闭思考）。
Map<String, dynamic> buildGooglePayload(ChatRequest request) {
  return {
    'contents': [
      for (final message in request.messages)
        if (message.role != ChatRole.system)
          {
            'role': message.role == ChatRole.assistant ? 'model' : 'user',
            'parts': [
              {'text': message.content},
            ],
          },
    ],
    if (_systemText(request.messages) case final system?)
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
    'generationConfig': {
      if (request.reasoningEffort case final effort?)
        'thinkingConfig': {
          'thinkingBudget': switch (effort) {
            ReasoningEffort.off => 0,
            ReasoningEffort.low => 1024,
            ReasoningEffort.medium => 8192,
            ReasoningEffort.high => 24576,
          },
        },
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.maxTokens != null) 'maxOutputTokens': request.maxTokens,
    },
  };
}

String? _systemText(List<ChatMessage> messages) {
  final parts = [
    for (final message in messages)
      if (message.role == ChatRole.system) message.content,
  ];
  return parts.isEmpty ? null : parts.join('\n\n');
}

/// Google Generative AI 的 SSE 解析：每个 data 块是一个
/// GenerateContentResponse JSON；`thought: true` 的 part 是思考。
abstract final class GoogleSseDecoder {
  /// 解析单个 data 载荷；无产出的块返回 null。
  static ChatChunk? parseEvent(String data) {
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    if (decoded['error'] is Map<String, dynamic>) {
      final error = decoded['error'] as Map<String, dynamic>;
      throw ServerFailure('响应错误: ${error['message'] ?? '未知错误'}');
    }

    var content = '';
    var reasoning = '';
    var done = false;
    final candidates = decoded['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final candidate = candidates.first;
      if (candidate is Map<String, dynamic>) {
        final contentNode = candidate['content'];
        if (contentNode is Map<String, dynamic>) {
          final parts = contentNode['parts'];
          if (parts is List) {
            for (final part in parts) {
              if (part is! Map<String, dynamic>) {
                continue;
              }
              final text = part['text'];
              if (text is! String || text.isEmpty) {
                continue;
              }
              if (part['thought'] == true) {
                reasoning += text;
              } else {
                content += text;
              }
            }
          }
        }
        done = candidate['finishReason'] != null;
      }
    }

    final usage = _parseUsage(decoded['usageMetadata']);
    if (content.isEmpty && reasoning.isEmpty && !done && usage == null) {
      return null;
    }
    return ChatChunk(
      delta: content,
      reasoningDelta: reasoning.isEmpty ? null : reasoning,
      done: done,
      usage: usage,
    );
  }

  static TokenUsage? _parseUsage(Object? usageMetadata) {
    if (usageMetadata is! Map<String, dynamic>) {
      return null;
    }
    int? asInt(Object? value) => value is int ? value : null;
    return TokenUsage(
      promptTokens: asInt(usageMetadata['promptTokenCount']),
      completionTokens: asInt(usageMetadata['candidatesTokenCount']),
      totalTokens: asInt(usageMetadata['totalTokenCount']),
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
