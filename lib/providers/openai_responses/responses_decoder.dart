import 'dart:convert';

import '../../core/error/failure.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/reasoning_effort.dart';
import '../attachment_encoder.dart';
import '../sse_transport.dart';

/// 构造 Responses API（POST /responses）请求体。
///
/// 纯函数便于单测。system 消息置首条 developer 角色；
/// 推理等级映射为 `reasoning: {effort, summary: auto}`（off → effort none）。
Map<String, dynamic> buildResponsesPayload(
  ChatRequest request, {
  List<List<AttachmentPayload>>? attachments,
}) {
  List<AttachmentPayload> partsFor(int index) =>
      attachments == null || index >= attachments.length
      ? const <AttachmentPayload>[]
      : attachments[index];

  List<Map<String, dynamic>> userContent(ChatMessage message, int index) {
    return [
      if (message.content.isNotEmpty)
        {'type': 'input_text', 'text': message.content},
      for (final part in partsFor(index))
        if (part.isImage)
          {
            'type': 'input_image',
            'image_url': 'data:${part.mimeType};base64,${part.base64Data}',
          }
        else
          {'type': 'input_text', 'text': part.text},
    ];
  }

  return {
    'model': request.model,
    'input': [
      for (var index = 0; index < request.messages.length; index++)
        switch (request.messages[index].role) {
          ChatRole.system => {
            'role': 'developer',
            'content': [
              {'type': 'input_text', 'text': request.messages[index].content},
            ],
          },
          ChatRole.user => {
            'role': 'user',
            'content': userContent(request.messages[index], index),
          },
          ChatRole.assistant => {
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': request.messages[index].content},
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
  /// 独立解析单个 data 载荷；跨事件去重应使用 [decode]。
  ///
  /// `response.failed` / `error` 事件以 [ServerFailure] 抛出。
  static ChatChunk? parseEvent(String data) =>
      _ResponsesStreamDecoder().parse(data, standalone: true);

  /// 每条响应独立追踪 item 与文本段，只补齐已发前缀的缺失后缀。
  static Stream<ChatChunk> decode(Stream<List<int>> byteStream) async* {
    final decoder = _ResponsesStreamDecoder();
    await for (final data in decodeSseDataLines(byteStream)) {
      final chunk = decoder.parse(data);
      if (chunk != null) yield chunk;
    }
    final pending = decoder.flush(finish: true);
    if (pending != null) yield pending;
  }
}

enum _ResponseChannel { summary, reasoning, content }

class _ResponsesStreamDecoder {
  final _byId = <String, _ResponseItem>{};
  final _byIndex = <int, _ResponseItem>{};
  final _items = <_ResponseItem>[];
  _ResponseItem? _anonymousItem;
  _ResponsePart? _lastReasoningPart;
  _ResponsePart? _lastContentPart;
  var _nextItemOrder = 0;

  ChatChunk? parse(String data, {bool standalone = false}) {
    if (data.trim() == '[DONE]') return flush(finish: true, done: true);
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final type = decoded['type'];
    var done = false;
    TokenUsage? usage;
    switch (type) {
      case 'response.output_text.delta':
      case 'response.output_text.done':
      case 'response.reasoning_summary_text.delta':
      case 'response.reasoning_summary_text.done':
      case 'response.reasoning_text.delta':
      case 'response.reasoning_text.done':
        final channel = switch (type) {
          'response.output_text.delta' ||
          'response.output_text.done' => _ResponseChannel.content,
          'response.reasoning_summary_text.delta' ||
          'response.reasoning_summary_text.done' => _ResponseChannel.summary,
          _ => _ResponseChannel.reasoning,
        };
        final snapshot = (type as String).endsWith('.done');
        _item(decoded).update(
          channel,
          _index(
                decoded[channel == _ResponseChannel.summary
                    ? 'summary_index'
                    : 'content_index'],
              ) ??
              0,
          decoded[snapshot ? 'text' : 'delta'],
          snapshot: snapshot,
        );
      case 'response.reasoning_summary_part.done':
        _readPart(
          _item(decoded),
          decoded['part'],
          _ResponseChannel.summary,
          _index(decoded['summary_index']) ?? 0,
        );
      case 'response.content_part.done':
        final part = decoded['part'];
        _readPart(
          _item(decoded),
          part,
          part is Map && part['type'] == 'reasoning_text'
              ? _ResponseChannel.reasoning
              : _ResponseChannel.content,
          _index(decoded['content_index']) ?? 0,
        );
      case 'response.output_item.added':
        _item(decoded);
        return null;
      case 'response.output_item.done':
        _readItem(_item(decoded), decoded['item']);
      case 'response.completed':
      case 'response.incomplete':
        final response = decoded['response'];
        if (response is Map<String, dynamic>) {
          final output = response['output'];
          if (output is List) {
            for (var index = 0; index < output.length; index++) {
              final item = output[index];
              if (item is! Map<String, dynamic>) continue;
              _readItem(_item({'item': item, 'output_index': index}), item);
            }
          }
        }
        done = true;
        usage = _parseUsage(response);
      case 'response.failed':
        throw ServerFailure('响应失败: ${_errorMessage(decoded['response'])}');
      case 'response.error':
      case 'error':
        throw ServerFailure('响应错误: ${_errorMessage(decoded)}');
      default:
        return null;
    }
    return flush(finish: done || standalone, done: done, usage: usage);
  }

  _ResponseItem _item(Map<String, dynamic> event) {
    final value = event['item'];
    final rawId = event['item_id'] ?? (value is Map ? value['id'] : null);
    final id = rawId is String && rawId.isNotEmpty ? rawId : null;
    final index = _index(event['output_index']);
    final byId = _byId[id];
    final byIndex = _byIndex[index];
    var item = byId ?? byIndex;
    if (byId != null && byIndex != null && !identical(byId, byIndex)) {
      final target = byId.order < byIndex.order ? byId : byIndex;
      final source = identical(target, byId) ? byIndex : byId;
      for (final entry in source.parts.entries) {
        final part = target.parts.putIfAbsent(entry.key, () => entry.value);
        if (!identical(part, entry.value)) {
          part.merge(entry.value);
          if (identical(_lastReasoningPart, entry.value)) {
            _lastReasoningPart = part;
          }
          if (identical(_lastContentPart, entry.value)) _lastContentPart = part;
        }
      }
      target.complete |= source.complete;
      target.separateParts |= source.separateParts;
      _byId.updateAll((_, value) => identical(value, source) ? target : value);
      _byIndex.updateAll(
        (_, value) => identical(value, source) ? target : value,
      );
      _items.remove(source);
      item = target;
    }
    if (id == null && index == null) item ??= _anonymousItem;
    if (item == null) {
      item = _ResponseItem(_nextItemOrder++);
      _items.add(item);
    }
    if (id == null && index == null) _anonymousItem = item;
    if (id != null) _byId[id] = item;
    if (index != null) {
      _byIndex[index] = item;
      item.outputIndex = index;
    }
    item.separateParts |=
        id != null ||
        index != null ||
        event.containsKey('summary_index') ||
        event.containsKey('content_index');
    return item;
  }

  void _readItem(_ResponseItem item, Object? value) {
    if (value is! Map<String, dynamic>) return;
    if (value['type'] == 'reasoning') {
      _readParts(item, value['summary'], _ResponseChannel.summary);
      _readParts(item, value['content'], _ResponseChannel.reasoning);
      item.update(_ResponseChannel.reasoning, 0, value['text'], snapshot: true);
    } else if (value['type'] == 'message') {
      _readParts(item, value['content'], _ResponseChannel.content);
    }
    item.complete = true;
  }

  void _readParts(_ResponseItem item, Object? parts, _ResponseChannel channel) {
    if (parts is! List) return;
    for (var index = 0; index < parts.length; index++) {
      _readPart(item, parts[index], channel, index);
    }
  }

  void _readPart(
    _ResponseItem item,
    Object? part,
    _ResponseChannel channel,
    int index,
  ) {
    if (part is! Map<String, dynamic>) return;
    final accepted = switch (channel) {
      _ResponseChannel.summary => part['type'] == 'summary_text',
      _ResponseChannel.reasoning =>
        part['type'] == 'reasoning_text' || part['type'] == 'text',
      _ResponseChannel.content => part['type'] == 'output_text',
    };
    if (accepted) item.update(channel, index, part['text'], snapshot: true);
  }

  ChatChunk? flush({
    bool finish = false,
    bool done = false,
    TokenUsage? usage,
  }) {
    final items = [..._items]
      ..sort((a, b) {
        final order = (a.outputIndex ?? a.order).compareTo(
          b.outputIndex ?? b.order,
        );
        return order == 0 ? a.order.compareTo(b.order) : order;
      });
    final reasoning = StringBuffer();
    final content = StringBuffer();
    for (final item in items) {
      for (final channel in _ResponseChannel.values) {
        final parts =
            item.parts.entries
                .where((entry) => entry.key.$1 == channel)
                .toList()
              ..sort((a, b) => a.key.$2.compareTo(b.key.$2));
        var nextIndex = 0;
        for (final entry in parts) {
          if (!finish && !item.complete && entry.key.$2 != nextIndex) break;
          final part = entry.value;
          final suffix = part.text.substring(part.emitted.length);
          final isReasoning = channel != _ResponseChannel.content;
          final previous = isReasoning ? _lastReasoningPart : _lastContentPart;
          // ChatChunk 只能追加，不能把旧段的快照后缀错插到后来段后面。
          final canAppend =
              !part.complete ||
              part.emitted.isEmpty ||
              identical(previous, part);
          if (suffix.isNotEmpty && canAppend) {
            final buffer = isReasoning ? reasoning : content;
            if (previous != null &&
                !identical(previous, part) &&
                item.separateParts) {
              buffer.write('\n\n');
            }
            buffer.write(suffix);
            part.emitted = part.text;
            if (isReasoning) {
              _lastReasoningPart = part;
            } else {
              _lastContentPart = part;
            }
          }
          if (!finish && !item.complete && !part.complete) break;
          nextIndex = entry.key.$2 + 1;
        }
      }
    }
    if (content.isEmpty && reasoning.isEmpty && !done) return null;
    return ChatChunk(
      delta: content.toString(),
      reasoningDelta: reasoning.isEmpty ? null : reasoning.toString(),
      done: done,
      usage: usage,
    );
  }

  static int? _index(Object? value) =>
      value is int && value >= 0 ? value : null;

  static String _errorMessage(Object? holder) {
    if (holder is Map<String, dynamic>) {
      final error = holder['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        return error['message'] as String;
      }
      if (holder['message'] is String) return holder['message'] as String;
    }
    return '未知错误';
  }

  static TokenUsage? _parseUsage(Object? response) {
    if (response is! Map<String, dynamic>) return null;
    final usage = response['usage'];
    if (usage is! Map<String, dynamic>) return null;
    int? asInt(Object? value) => value is int ? value : null;
    return TokenUsage(
      promptTokens: asInt(usage['input_tokens']),
      completionTokens: asInt(usage['output_tokens']),
      totalTokens: asInt(usage['total_tokens']),
    );
  }
}

class _ResponseItem {
  _ResponseItem(this.order);

  final int order;
  int? outputIndex;
  var separateParts = false;
  var complete = false;
  final parts = <(_ResponseChannel, int), _ResponsePart>{};

  void update(
    _ResponseChannel channel,
    int index,
    Object? value, {
    required bool snapshot,
  }) {
    if (value is! String) return;
    final part = parts.putIfAbsent((channel, index), _ResponsePart.new);
    if (snapshot) {
      if (value.startsWith(part.text)) part.text = value;
      part.complete = true;
    } else if (!part.complete) {
      part.text += value;
    }
  }
}

class _ResponsePart {
  var text = '';
  var emitted = '';
  var complete = false;

  void merge(_ResponsePart other) {
    if (other.text.startsWith(text)) text = other.text;
    if (other.emitted.startsWith(emitted) && text.startsWith(other.emitted)) {
      emitted = other.emitted;
    }
    complete |= other.complete;
  }
}
