import 'dart:convert';

import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_message.dart';
import '../dio_failure_mapper.dart';
import '../part_assembler.dart';
import '../sse_transport.dart';
import 'think_tag_filter.dart';

/// OpenAI 兼容协议的 SSE 解析。
///
/// 有状态：跨事件跟踪内容块与工具调用；正文里的 think 标签经
/// [ThinkTagSplitter] 拆到思考通道。设计为可脱离网络独立单测。
abstract final class OpenAiSseDecoder {
  static const _dataPrefix = 'data:';
  static const _doneMarker = '[DONE]';

  /// 解析单行 SSE 文本（含 `data:` 前缀）并收口，用于报文级测试与诊断；
  /// 流式使用 [decode]：它只在整个响应收口时发一次 ResponseEnd。
  static List<ChatChunk> parseLine(String line) {
    if (!line.startsWith(_dataPrefix)) return const [];
    final decoder = _CompletionsStreamDecoder();
    final chunks = decoder.parse(line.substring(_dataPrefix.length));
    // 空载荷与畸形 JSON 不是协议事件：既不产出内容，也不收口。
    if (!decoder.sawEvent) return const [];
    return [...chunks, ...decoder.finish()];
  }

  /// 把 HTTP 响应字节流按 SSE 事件解码为类型化事件流。
  ///
  /// 收口时机：[DONE]、带内错误或字节流结束（网关提前断开时也要有明确结果）。
  static Stream<ChatChunk> decode(Stream<List<int>> byteStream) async* {
    final decoder = _CompletionsStreamDecoder();
    await for (final data in decodeSseDataLines(byteStream)) {
      for (final chunk in decoder.parse(data)) {
        yield chunk;
      }
      if (decoder.isDone) return;
    }
    for (final chunk in decoder.finish()) {
      yield chunk;
    }
  }
}

class _CompletionsStreamDecoder {
  _CompletionsStreamDecoder() {
    _parts = PartAssembler(_out.add);
  }

  final _out = <ChatChunk>[];
  late final PartAssembler _parts;
  final _think = ThinkTagSplitter();
  TokenUsage? _usage;
  var _terminated = false;
  var _sawEvent = false;
  var _finished = false;

  /// 是否已收口（发过 ResponseEnd 或流内错误）。
  bool get isDone => _terminated || _finished;

  /// 本次解析是否识别出一个协议事件（单事件解析据此决定是否收口）。
  bool get sawEvent => _sawEvent;

  /// 解析一个 data 载荷，返回本次产生的事件（可能为空）。
  List<ChatChunk> parse(String payload) {
    if (isDone) return const [];
    final data = payload.trim();
    if (data.isEmpty) return const [];
    if (data == OpenAiSseDecoder._doneMarker) {
      _sawEvent = true;
      return finish();
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      // 容错：忽略格式异常的事件，不中断整条流。
      return const [];
    }
    if (decoded is! Map<String, dynamic>) return const [];
    _sawEvent = true;

    // 网关在 SSE 流内返回的带内错误（HTTP 200 + {"error": ...}），
    // 必须显形；用 ResponseError 事件表达，不抛异常。
    final error = decoded['error'];
    if (error != null) {
      _terminated = true;
      _out.add(ResponseError(error: mapProtocolError(error)));
      return _drain();
    }

    _usage = _parseUsage(decoded['usage']) ?? _usage;
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final choice = choices.first;
      if (choice is Map<String, dynamic>) _parseChoice(choice);
    }
    return _drain();
  }

  /// 响应收口：补齐未结束的块，产出 usage 与 ResponseEnd。
  List<ChatChunk> finish({TokenUsage? usage}) {
    if (isDone) return const [];
    final tail = _think.flush();
    if (tail.reasoning.isNotEmpty) _parts.reasoning(0, tail.reasoning);
    if (tail.content.isNotEmpty) _parts.text(0, tail.content);
    _finished = true;
    _parts.finish(usage: usage ?? _usage);
    return _drain();
  }

  void _parseChoice(Map<String, dynamic> choice) {
    final delta = choice['delta'];
    if (delta is! Map<String, dynamic>) return;

    // 协议字段给出的思考优先于正文里的 think 标签。
    final reasoning = _parseReasoning(delta);
    if (reasoning != null) {
      _parts.reasoning(0, reasoning.text, providerData: reasoning.providerData);
    }

    final content = delta['content'];
    if (content is String && content.isNotEmpty) {
      final split = _think.push(content);
      if (split.reasoning.isNotEmpty) _parts.reasoning(0, split.reasoning);
      if (split.content.isNotEmpty) _parts.text(0, split.content);
    }

    final calls = delta['tool_calls'];
    if (calls is List) {
      for (final call in calls) {
        if (call is! Map<String, dynamic>) continue;
        final function = call['function'];
        final arguments = function is Map<String, dynamic>
            ? function['arguments']
            : null;
        _parts.toolCall(
          // 同一响应内 tool_calls 的 index 稳定；缺省时按第 0 个处理。
          switch (call['index']) {
            final int index => index,
            _ => 0,
          },
          callId: call['id'] is String ? call['id'] as String : null,
          toolName:
              function is Map<String, dynamic> && function['name'] is String
              ? function['name'] as String
              : null,
          argumentsFragment: arguments is String ? arguments : null,
        );
      }
    }
  }

  /// 结构化推理明细，按 index 累积：回传时要原样送回去。
  final _details = <int, Map<String, dynamic>>{};

  /// 解析思考增量，并带回回传所需的来源信息。
  ///
  /// 来源字段名（`reasoning_content` 等）与结构化明细都要留给下一轮请求：
  /// 前者决定回传时用哪个字段，后者本身就是协议要求的原样载荷。
  ({String text, Map<String, dynamic>? providerData})? _parseReasoning(
    Map<String, dynamic> delta,
  ) {
    for (final field in ['reasoning_content', 'reasoning', 'reasoning_text']) {
      final text = delta[field];
      if (text is String && text.isNotEmpty) {
        return (text: text, providerData: {'field': field});
      }
    }
    final details = delta['reasoning_details'];
    if (details is! List) return null;
    _accumulateDetails(details);
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
    if (reasoning.isEmpty && _details.isEmpty) return null;
    return (
      text: reasoning.toString(),
      providerData: {'details': _detailsInOrder()},
    );
  }

  /// 明细按 index 合并：文本类字段追加，签名等整段字段覆盖。
  void _accumulateDetails(List<Object?> details) {
    for (final detail in details) {
      if (detail is! Map) continue;
      final entry = Map<String, dynamic>.from(detail);
      final index = entry['index'];
      final key = index is int ? index : _details.length;
      final existing = _details[key];
      if (existing == null) {
        _details[key] = entry;
        continue;
      }
      for (final field in ['text', 'summary', 'data']) {
        final fragment = entry[field];
        if (fragment is! String || fragment.isEmpty) continue;
        final current = existing[field];
        existing[field] = current is String ? '$current$fragment' : fragment;
      }
      for (final field in ['type', 'id', 'signature']) {
        if (entry[field] != null) existing[field] = entry[field];
      }
    }
  }

  List<Map<String, dynamic>> _detailsInOrder() {
    final keys = _details.keys.toList()..sort();
    return [for (final key in keys) _details[key]!];
  }

  static TokenUsage? _parseUsage(Object? usage) {
    if (usage is! Map<String, dynamic>) {
      return null;
    }
    int? asInt(Object? value) => value is int ? value : null;
    final details = usage['completion_tokens_details'];
    return TokenUsage(
      inputTokens: asInt(usage['prompt_tokens']) ?? _cachedTokens(usage),
      outputTokens: asInt(usage['completion_tokens']),
      reasoningTokens: details is Map<String, dynamic>
          ? asInt(details['reasoning_tokens'])
          : null,
      cachedInputTokens: _cachedTokens(usage),
    );
  }

  /// 缓存命中的输入 token（OpenAI 兼容协议的 prompt_tokens_details.cached_tokens）。
  static int? _cachedTokens(Map<String, dynamic> usage) {
    final details = usage['prompt_tokens_details'];
    if (details is! Map<String, dynamic>) return null;
    final cached = details['cached_tokens'];
    return cached is int ? cached : null;
  }

  List<ChatChunk> _drain() {
    if (_out.isEmpty) return const [];
    final events = List<ChatChunk>.of(_out);
    _out.clear();
    return events;
  }
}
