import 'dart:convert';

import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/reasoning_effort.dart';
import '../attachment_encoder.dart';
import '../dio_failure_mapper.dart';
import '../part_assembler.dart';
import '../sse_transport.dart';

/// 构造 Responses API（POST /responses）请求体。
///
/// systemPrompt 置首条 developer 消息；system 角色消息同样作为 developer。
/// 推理等级映射为 `reasoning: {effort, summary: auto}`（off → effort none）；
/// 模型不支持推理时不下发 reasoning 字段。
///
/// [requestEncryptedReasoning] 为 true 时索要 `reasoning.encrypted_content`：
/// 推理 item 需要由客户端原样回放，加密载荷是把它带过服务端状态的唯一办法
/// （pi 的做法；官方端点默认 store=false 语义下必须带）。网关不一定认识这个
/// 参数，所以只在确认支持的端点上开启。
Future<Map<String, dynamic>> buildResponsesPayload(
  ChatRequest request, {
  bool supportsImages = true,
  bool supportsReasoning = true,
  bool requestEncryptedReasoning = false,
}) async {
  final attachments = RequestAttachmentEncoder(supportsImages: supportsImages);
  final input = <Map<String, dynamic>>[
    if (request.systemPrompt.isNotEmpty)
      {
        'role': 'developer',
        'content': [
          {'type': 'input_text', 'text': request.systemPrompt},
        ],
      },
  ];
  for (final message in request.messages) {
    input.addAll(await _responsesItems(message, attachments));
  }

  return {
    'model': request.modelId,
    'input': input,
    'stream': true,
    if (supportsReasoning)
      'reasoning': request.reasoningEffort == ReasoningEffort.off
          ? {'effort': 'none'}
          : {'effort': request.reasoningEffort.name, 'summary': 'auto'},
    if (requestEncryptedReasoning) 'include': ['reasoning.encrypted_content'],
    if (request.temperature != null) 'temperature': request.temperature,
    if (request.maxOutputTokens != null)
      'max_output_tokens': request.maxOutputTokens,
    // 未开放工具时不下发工具定义。
    if (request.tools.isNotEmpty)
      'tools': [
        for (final tool in request.tools)
          {
            'type': 'function',
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.inputSchema,
          },
      ],
  };
}

Future<List<Map<String, dynamic>>> _responsesItems(
  ResolvedMessage message,
  RequestAttachmentEncoder attachments,
) async {
  final blocks = <Map<String, dynamic>>[];
  final reasoning = <Map<String, dynamic>>[];
  for (final part in message.parts) {
    switch (part) {
      case ResolvedText(:final text):
        if (text.isEmpty) break;
        blocks.add({
          'type': message.role == ChatRole.assistant
              ? 'output_text'
              : 'input_text',
          'text': text,
        });
      case ResolvedImage(:final attachment):
        final payload = await attachments.encode(attachment);
        if (payload.isImage) {
          blocks.add({'type': 'input_image', 'image_url': payload.dataUri});
        } else if (payload.text case final text?) {
          blocks.add({'type': 'input_text', 'text': text});
        }
      case ResolvedReasoning(:final text, :final providerData):
        if (!message.sameModel) {
          // 跨模型的思考就地降级成正文（pi 的 transform-messages 规则 2）：
          // 协议状态不能再回传，内容本身不必丢。
          if (text.trim().isNotEmpty) {
            blocks.add({
              'type': message.role == ChatRole.assistant
                  ? 'output_text'
                  : 'input_text',
              'text': text,
            });
          }
          break;
        }
        // 推理 item 原样回放（顶层 item），位次在这一轮的正文与调用之前。
        final item = providerData?['item'];
        if (item is Map<String, dynamic>) {
          reasoning.add(item);
        } else if (item is Map) {
          reasoning.add(Map<String, dynamic>.from(item));
        }
      case ResolvedToolCall():
      case ResolvedToolResult():
        // 函数调用与结果在下面按顶层 item 组织。
        break;
    }
  }

  final items = <Map<String, dynamic>>[...reasoning];
  if (message.role == ChatRole.system) {
    if (blocks.isEmpty) return items;
    return [
      ...reasoning,
      {'role': 'developer', 'content': blocks},
    ];
  }
  // 工具消息没有 message 形态：结果只作为顶层 function_call_output item
  // （Responses 的角色只有 user/assistant/system/developer）。
  if (blocks.isNotEmpty && message.role != ChatRole.tool) {
    items.add({'role': message.role.name, 'content': blocks});
  }
  for (final part in message.parts) {
    switch (part) {
      case ResolvedToolCall(:final callId, :final toolName, :final arguments):
        // 函数调用是顶层 item，不嵌在 message 里。
        items.add({
          'type': 'function_call',
          'call_id': callId,
          'name': toolName,
          'arguments': jsonEncode(arguments),
        });
      case ResolvedToolResult(:final callId, :final content):
        items.add({
          'type': 'function_call_output',
          'call_id': callId,
          'output': content,
        });
      default:
        break;
    }
  }
  return items;
}

/// Responses API 的 SSE 事件解析。
abstract final class ResponsesSseDecoder {
  /// 独立解析单个 data 载荷并收口；跨事件去重与合并应使用 [decode]。
  static List<ChatChunk> parseEvent(String data) {
    final decoder = _ResponsesStreamDecoder();
    final chunks = decoder.parse(data, standalone: true);
    // 畸形的载荷不是协议事件：既不产出内容，也不收口。
    if (!decoder.sawEvent) return const [];
    return [...chunks, ...decoder.finish(complete: true)];
  }

  /// 每条响应独立追踪 item 与文本段，只补齐已发前缀的缺失后缀。
  static Stream<ChatChunk> decode(Stream<List<int>> byteStream) async* {
    final decoder = _ResponsesStreamDecoder();
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

enum _ResponseChannel { summary, reasoning, content }

class _ResponsesStreamDecoder {
  _ResponsesStreamDecoder() {
    _parts = PartAssembler(_out.add);
  }

  final _out = <ChatChunk>[];
  late final PartAssembler _parts;
  final _byId = <String, _ResponseItem>{};
  final _byIndex = <int, _ResponseItem>{};
  final _items = <_ResponseItem>[];
  _ResponseItem? _anonymousItem;
  _ResponsePart? _lastReasoningPart;
  _ResponsePart? _lastContentPart;
  var _nextItemOrder = 0;
  var _terminated = false;
  var _sawEvent = false;
  var _finished = false;

  bool get isDone => _terminated || _finished;

  /// 本次解析是否识别出一个协议事件（单事件解析据此决定是否收口）。
  bool get sawEvent => _sawEvent;

  List<ChatChunk> parse(String data, {bool standalone = false}) {
    if (isDone) return const [];
    if (data.trim() == '[DONE]') return finish(complete: _normalFinish ?? true);
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      return const [];
    }
    if (decoded is! Map<String, dynamic>) return const [];
    _sawEvent = true;
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
        final item = _item(decoded);
        final value = decoded['item'];
        if (value is Map<String, dynamic>) {
          _readToolCall(item, value, snapshot: false);
        }
        return const [];
      case 'response.function_call_arguments.delta':
        _readToolArguments(_item(decoded), decoded['delta'], snapshot: false);
      case 'response.function_call_arguments.done':
        _readToolArguments(
          _item(decoded),
          decoded['arguments'],
          snapshot: true,
        );
      case 'response.output_item.done':
        _readItem(_item(decoded), decoded['item']);
      case 'response.completed':
      case 'response.incomplete':
        _normalFinish = type == 'response.completed';
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
        // 先交付已经补出的内容，再报流内错误。
        _flush(finish: false);
        _terminated = true;
        _out.add(
          ResponseError(
            error: mapProtocolError(decoded['response'] ?? decoded),
          ),
        );
        return _drain();
      case 'response.error':
      case 'error':
        _flush(finish: false);
        _terminated = true;
        _out.add(ResponseError(error: mapProtocolError(decoded)));
        return _drain();
      default:
        return const [];
    }
    _flush(finish: done || standalone, done: done, usage: usage);
    if (done) return [..._drain(), ...finish(complete: _normalFinish == true)];
    return _drain();
  }

  /// 响应收口：补齐未结束的块，产出 usage 与 ResponseEnd。
  bool? _normalFinish;

  List<ChatChunk> finish({TokenUsage? usage, bool? complete}) {
    if (isDone) return const [];
    _finished = true;
    _flush(finish: true);
    _parts.finish(
      usage: usage ?? _pendingUsage,
      complete: _normalFinish ?? complete ?? false,
    );
    return _drain();
  }

  TokenUsage? _pendingUsage;

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
      // 推理 item 要原样回传：服务端按 rs_* ↔ fc_* 校验配对，缺了它下一轮
      // 带函数调用的请求会被判为「function_call 缺少配对的 reasoning item」。
      final replay = _reasoningItem(value);
      if (replay != null) {
        _parts.reasoning(item, '', providerData: {'item': replay});
      }
    } else if (value['type'] == 'message') {
      _readParts(item, value['content'], _ResponseChannel.content);
    } else if (value['type'] == 'function_call') {
      _readToolCall(item, value, snapshot: true);
    }
    item.complete = true;
  }

  /// 读取函数调用的身份字段；[snapshot] 为 true 时 arguments 是完整快照。
  void _readToolCall(
    _ResponseItem item,
    Map<String, dynamic> value, {
    required bool snapshot,
  }) {
    final rawCallId = value['call_id'];
    if (rawCallId is String && rawCallId.isNotEmpty) {
      item.toolCall.callId = rawCallId;
    }
    final rawName = value['name'];
    if (rawName is String && rawName.isNotEmpty) {
      item.toolCall.name = rawName;
    }
    final tool = item.toolCall;
    if (tool.callId != null || tool.name != null) {
      _parts.toolCall(
        item,
        callId: tool.callId,
        toolName: tool.name,
        argumentsFragment: _argumentsSuffix(tool, value['arguments'], snapshot),
      );
    }
    if (snapshot) tool.complete = true;
  }

  void _readToolArguments(
    _ResponseItem item,
    Object? value, {
    required bool snapshot,
  }) {
    final tool = item.toolCall;
    final fragment = _argumentsSuffix(tool, value, snapshot);
    if (fragment == null) return;
    _parts.toolCall(
      item,
      callId: tool.callId,
      toolName: tool.name,
      argumentsFragment: fragment,
    );
  }

  /// 参数片段只追加；完整快照只补已发前缀的缺失后缀，不重复追加。
  String? _argumentsSuffix(
    _ResponseToolCall tool,
    Object? value,
    bool snapshot,
  ) {
    if (value is! String || value.isEmpty) return null;
    if (!snapshot) {
      tool.arguments += value;
      return value;
    }
    if (!value.startsWith(tool.arguments)) return null;
    final suffix = value.substring(tool.arguments.length);
    tool.arguments = value;
    return suffix.isEmpty ? null : suffix;
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

  /// 把当前已知的文本补齐到事件流；完成快照只补缺失后缀，不重复追加。
  void _flush({bool finish = false, bool done = false, TokenUsage? usage}) {
    final items = [..._items]
      ..sort((a, b) {
        final order = (a.outputIndex ?? a.order).compareTo(
          b.outputIndex ?? b.order,
        );
        return order == 0 ? a.order.compareTo(b.order) : order;
      });
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
          // 只能追加，不能把旧段的快照后缀错插到后来段后面。
          final canAppend =
              !part.complete ||
              part.emitted.isEmpty ||
              identical(previous, part);
          if (suffix.isNotEmpty && canAppend) {
            var text = suffix;
            if (previous != null &&
                !identical(previous, part) &&
                item.separateParts) {
              text = '\n\n$text';
            }
            // 同一个 part 的增量落到同一个块：key 用 part 本身，
            // partId 由组装器按首现顺序分配。
            if (isReasoning) {
              _parts.reasoning(part, text);
              _lastReasoningPart = part;
            } else {
              _parts.text(part, text);
              _lastContentPart = part;
            }
            part.emitted = part.text;
          }
          if (!finish && !item.complete && !part.complete) break;
          nextIndex = entry.key.$2 + 1;
        }
      }
    }
    if (usage != null) _pendingUsage = usage;
  }

  /// 回放用的推理 item：只保留服务端认得的字段。
  ///
  /// 没有任何可回放内容的 item（无 id、无加密载荷）不留：回传一个空壳只会
  /// 让端点报错。加密载荷只有请求了 `reasoning.encrypted_content` 才有。
  static Map<String, dynamic>? _reasoningItem(Map<String, dynamic> value) {
    final id = value['id'];
    final encrypted = value['encrypted_content'];
    if (id is! String && encrypted is! String) return null;
    return {
      'type': 'reasoning',
      if (id is String) 'id': id,
      if (value['summary'] is List) 'summary': value['summary'],
      if (value['content'] is List) 'content': value['content'],
      if (encrypted is String) 'encrypted_content': encrypted,
    };
  }

  static int? _index(Object? value) =>
      value is int && value >= 0 ? value : null;

  static TokenUsage? _parseUsage(Object? response) {
    if (response is! Map<String, dynamic>) return null;
    final usage = response['usage'];
    if (usage is! Map<String, dynamic>) return null;
    int? asInt(Object? value) => value is int ? value : null;
    final outputDetails = usage['output_tokens_details'];
    final inputDetails = usage['input_tokens_details'];
    return TokenUsage(
      inputTokens: asInt(usage['input_tokens']),
      outputTokens: asInt(usage['output_tokens']),
      reasoningTokens: outputDetails is Map<String, dynamic>
          ? asInt(outputDetails['reasoning_tokens'])
          : null,
      cachedInputTokens: inputDetails is Map<String, dynamic>
          ? asInt(inputDetails['cached_tokens'])
          : null,
    );
  }

  List<ChatChunk> _drain() {
    if (_out.isEmpty) return const [];
    final events = List<ChatChunk>.of(_out);
    _out.clear();
    return events;
  }
}

class _ResponseItem {
  _ResponseItem(this.order);

  final int order;
  int? outputIndex;
  var separateParts = false;
  var complete = false;
  final parts = <(_ResponseChannel, int), _ResponsePart>{};
  final toolCall = _ResponseToolCall();

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

/// 一个函数调用在响应内的累积状态（参数只追加，不逐段解析 JSON）。
class _ResponseToolCall {
  String? callId;
  String? name;
  var arguments = '';
  var complete = false;
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
