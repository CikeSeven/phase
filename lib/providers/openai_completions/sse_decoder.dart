import 'dart:convert';

import '../../data/models/chat_chunk.dart';
import '../sse_transport.dart';

/// OpenAI 兼容协议的 SSE 解析。
///
/// 设计为纯函数，便于脱离网络独立单测。
abstract final class OpenAiSseDecoder {
  static const _dataPrefix = 'data:';
  static const _doneMarker = '[DONE]';

  /// 解析单行 SSE 文本；不产生事件的行（空行、注释、字段行）返回 null。
  static ChatChunk? parseLine(String line) {
    if (!line.startsWith(_dataPrefix)) {
      return null;
    }
    return _parseData(line.substring(_dataPrefix.length));
  }

  static ChatChunk? _parseData(String payload) {
    final data = payload.trim();
    if (data.isEmpty) {
      return null;
    }
    if (data == _doneMarker) {
      return const ChatChunk(delta: '', done: true);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      // 容错：忽略格式异常的事件，不中断整条流。
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return _parseEvent(decoded);
  }

  static ChatChunk? _parseEvent(Map<String, dynamic> event) {
    // 网关在 SSE 流内返回的带内错误（HTTP 200 + {"error": ...}），
    // 必须显形，不能当无事件行吞掉。
    final error = event['error'];
    if (error != null) {
      final message = switch (error) {
        {'message': final String m} => m,
        String() => error,
        _ => jsonEncode(error),
      };
      return ChatChunk(delta: '', done: true, errorMessage: message);
    }
    final usage = _parseUsage(event['usage']);
    final choices = event['choices'];
    if (choices is! List || choices.isEmpty) {
      // usage 可能单独出现在最后一个 chunk（choices 为空）。
      return usage == null
          ? null
          : ChatChunk(delta: '', done: true, usage: usage);
    }
    final choice = choices.first;
    if (choice is! Map<String, dynamic>) {
      return null;
    }
    final delta = choice['delta'];
    final content = delta is Map<String, dynamic> ? delta['content'] : null;
    final reasoning = _parseReasoning(delta);
    final finished = choice['finish_reason'] != null;
    return ChatChunk(
      delta: content is String ? content : '',
      reasoningDelta: reasoning,
      done: finished,
      usage: usage,
    );
  }

  static String? _parseReasoning(Object? delta) {
    if (delta is! Map<String, dynamic>) return null;
    for (final field in ['reasoning_content', 'reasoning', 'reasoning_text']) {
      final text = delta[field];
      if (text is String && text.isNotEmpty) return text;
    }
    final details = delta['reasoning_details'];
    if (details is! List) return null;
    final reasoning = StringBuffer();
    for (final detail in details) {
      final text = switch (detail) {
        {'type': 'reasoning.text', 'text': final String text} => text,
        {'type': 'reasoning.summary', 'summary': final String summary} =>
          summary,
        _ => null,
      };
      if (text != null) reasoning.write(text);
    }
    return reasoning.isEmpty ? null : reasoning.toString();
  }

  static TokenUsage? _parseUsage(Object? usage) {
    if (usage is! Map<String, dynamic>) {
      return null;
    }
    int? asInt(Object? value) => value is int ? value : null;
    return TokenUsage(
      promptTokens: asInt(usage['prompt_tokens']),
      completionTokens: asInt(usage['completion_tokens']),
      totalTokens: asInt(usage['total_tokens']),
    );
  }

  /// 把 HTTP 响应字节流按 SSE 事件解码为 [ChatChunk] 事件流。
  static Stream<ChatChunk> decode(Stream<List<int>> byteStream) async* {
    await for (final data in decodeSseDataLines(byteStream)) {
      final chunk = _parseData(data);
      if (chunk != null) {
        yield chunk;
      }
    }
  }
}
