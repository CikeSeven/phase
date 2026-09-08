import 'dart:convert';

import '../../data/models/chat_chunk.dart';

/// OpenAI 兼容协议的 SSE 解析。
///
/// 设计为纯函数，便于脱离网络独立单测。
abstract final class OpenAiSseDecoder {
  static const _dataPrefix = 'data: ';
  static const _doneMarker = '[DONE]';

  /// 解析单行 SSE 文本；不产生事件的行（空行、注释、字段行）返回 null。
  static ChatChunk? parseLine(String line) {
    if (!line.startsWith(_dataPrefix)) {
      return null;
    }
    final data = line.substring(_dataPrefix.length).trim();
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
      // 容错：忽略格式异常的增量行，不中断整条流。
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return _parseEvent(decoded);
  }

  static ChatChunk? _parseEvent(Map<String, dynamic> event) {
    final usage = _parseUsage(event['usage']);
    final choices = event['choices'];
    if (choices is! List || choices.isEmpty) {
      // usage 可能单独出现在最后一个 chunk（choices 为空）。
      return usage == null ? null : ChatChunk(delta: '', done: true, usage: usage);
    }
    final choice = choices.first;
    if (choice is! Map<String, dynamic>) {
      return null;
    }
    final delta = choice['delta'];
    final content = delta is Map<String, dynamic> ? delta['content'] : null;
    final finished = choice['finish_reason'] != null;
    return ChatChunk(
      delta: content is String ? content : '',
      done: finished,
      usage: usage,
    );
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

  /// 把 HTTP 响应字节流解码为 [ChatChunk] 事件流。
  ///
  /// utf8 解码 + 按行切分天然处理了跨 chunk 的半截行。
  static Stream<ChatChunk> decode(Stream<List<int>> byteStream) async* {
    final lines = utf8.decoder
        .bind(byteStream)
        .transform(const LineSplitter());
    await for (final line in lines) {
      final chunk = parseLine(line);
      if (chunk != null) {
        yield chunk;
      }
    }
  }
}
