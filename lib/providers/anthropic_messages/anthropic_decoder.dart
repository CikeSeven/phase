import 'dart:convert';

import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/reasoning_effort.dart';
import '../attachment_encoder.dart';
import '../dio_failure_mapper.dart';
import '../part_assembler.dart';
import '../sse_transport.dart';

/// 构造 Anthropic Messages（POST /v1/messages）请求体。
///
/// systemPrompt 提取为顶层 system 字段；system 角色消息并入其中。
/// 推理等级映射 `thinking: {type: enabled, budget_tokens}`，
/// 并保证 budget + 1024 ≤ max_tokens（不够就抬 max_tokens）；
/// 模型不支持推理时不下发 thinking 字段。
Future<Map<String, dynamic>> buildAnthropicPayload(
  ChatRequest request, {
  bool supportsImages = true,
  bool supportsReasoning = true,
}) async {
  final attachments = RequestAttachmentEncoder(supportsImages: supportsImages);
  var maxTokens = request.maxOutputTokens ?? 8192;
  Map<String, dynamic>? thinking;
  if (supportsReasoning) {
    if (request.reasoningEffort == ReasoningEffort.off) {
      thinking = {'type': 'disabled'};
    } else {
      final budget = _thinkingBudget(request.reasoningEffort);
      if (budget + 1024 > maxTokens) {
        maxTokens = budget + 1024;
      }
      thinking = {'type': 'enabled', 'budget_tokens': budget};
    }
  }

  final messages = <Map<String, dynamic>>[];
  var index = 0;
  while (index < request.messages.length) {
    final message = request.messages[index];
    // system 角色消息并入顶层 system 字段，不进入 messages。
    if (message.role == ChatRole.system) {
      index++;
      continue;
    }

    // 连续的工具结果合并成一条 user 消息：Anthropic 要求 tool_result 块
    // 紧跟对应的 tool_use，一轮多个调用必须留在同一条消息里
    // （严格端点会直接拒绝逐条发送的形态）。
    if (_isToolResult(message)) {
      final blocks = <Map<String, dynamic>>[];
      while (index < request.messages.length &&
          _isToolResult(request.messages[index])) {
        blocks.addAll(
          await _anthropicBlocks(request.messages[index], attachments),
        );
        index++;
      }
      if (blocks.isNotEmpty) {
        messages.add({'role': 'user', 'content': blocks});
      }
      continue;
    }

    final blocks = await _anthropicBlocks(message, attachments);
    if (blocks.isNotEmpty) {
      messages.add({
        'role': message.role == ChatRole.assistant ? 'assistant' : 'user',
        'content': blocks,
      });
    }
    index++;
  }

  final system = _systemText(request);
  return {
    'model': request.modelId,
    'max_tokens': maxTokens,
    'messages': messages,
    if (system.isNotEmpty) 'system': system,
    'stream': true,
    'thinking': ?thinking,
    if (request.temperature != null) 'temperature': request.temperature,
    // 未开放工具时不下发工具定义；连续的工具结果留在同一条 user 消息里。
    if (request.tools.isNotEmpty)
      'tools': [
        for (final tool in request.tools)
          {
            'name': tool.name,
            'description': tool.description,
            'input_schema': tool.inputSchema,
          },
      ],
  };
}

int _thinkingBudget(ReasoningEffort effort) => switch (effort) {
  ReasoningEffort.low => 1024,
  ReasoningEffort.medium => 4096,
  ReasoningEffort.high => 16384,
  ReasoningEffort.xhigh => 32768,
  ReasoningEffort.max => 65536,
  ReasoningEffort.off => 0,
};

Future<List<Map<String, dynamic>>> _anthropicBlocks(
  ResolvedMessage message,
  RequestAttachmentEncoder attachments,
) async {
  final blocks = <Map<String, dynamic>>[];
  for (final part in message.parts) {
    switch (part) {
      case ResolvedText(:final text):
        if (text.isNotEmpty) blocks.add({'type': 'text', 'text': text});
      case ResolvedImage(:final attachment):
        final payload = await attachments.encode(attachment);
        if (payload.isImage) {
          blocks.add({
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': payload.mimeType,
              'data': payload.base64Data,
            },
          });
        } else if (payload.text case final text?) {
          blocks.add({'type': 'text', 'text': text});
        }
      case ResolvedReasoning(:final providerData):
        // 三档：同模型且带签名 → 原样回传；跨模型 → 就地降级成普通文本；
        // 没签名也没内容 → 丢弃。签名只对生成它的模型有效，跨模型送回去
        // 会被判为非法（pi 的 transform-messages 规则 2）。
        final redacted = providerData?['data'];
        final signature = providerData?['signature'];
        if (providerData?['type'] == 'redacted_thinking' &&
            redacted is String) {
          // 加密思考是不透明载荷，只能给同一个模型。
          if (message.sameModel) {
            blocks.add({'type': 'redacted_thinking', 'data': redacted});
          }
        } else if (signature is String && signature.isNotEmpty) {
          if (message.sameModel) {
            blocks.add({
              'type': 'thinking',
              'thinking': part.text,
              'signature': signature,
            });
          } else if (part.text.trim().isNotEmpty) {
            blocks.add({'type': 'text', 'text': part.text});
          }
        } else if (part.text.trim().isNotEmpty) {
          // 没签名的思考块不能当 thinking 回传：降级成普通文本，位置不变。
          blocks.add({'type': 'text', 'text': part.text});
        }
      case ResolvedToolCall(:final callId, :final toolName, :final arguments):
        blocks.add({
          'type': 'tool_use',
          'id': callId,
          'name': toolName,
          'input': arguments,
        });
      case ResolvedToolResult(:final callId, :final content, :final isError):
        blocks.add({
          'type': 'tool_result',
          'tool_use_id': callId,
          'content': content,
          if (isError) 'is_error': true,
        });
    }
  }
  return blocks;
}

/// 只含工具结果的消息：Anthropic 里它们要合并进一条 user 消息。
bool _isToolResult(ResolvedMessage message) =>
    message.parts.isNotEmpty &&
    message.parts.every((part) => part is ResolvedToolResult);

/// systemPrompt 与 system 角色消息的合并结果。
String _systemText(ChatRequest request) => [
  if (request.systemPrompt.isNotEmpty) request.systemPrompt,
  for (final message in request.messages)
    if (message.role == ChatRole.system)
      for (final part in message.parts)
        if (part is ResolvedText && part.text.isNotEmpty) part.text,
].join('\n\n');

/// Anthropic Messages 的 SSE 事件解析。
abstract final class AnthropicSseDecoder {
  /// 独立解析单个 data 载荷（message_start 的 input_tokens 由本次调用自行读取）；
  /// 跨事件的 usage 合成使用 [decode]。
  static List<ChatChunk> parseEvent(String data) {
    final decoder = _AnthropicStreamDecoder();
    final chunks = decoder.parse(data);
    // 畸形的载荷不是协议事件：既不产出内容，也不收口。
    if (!decoder.sawEvent) return const [];
    return [...chunks, ...decoder.finish()];
  }

  /// 把 HTTP 响应字节流解码为类型化事件流；message_stop 或流结束收口。
  static Stream<ChatChunk> decode(Stream<List<int>> byteStream) async* {
    final decoder = _AnthropicStreamDecoder();
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

class _AnthropicStreamDecoder {
  _AnthropicStreamDecoder() {
    _parts = PartAssembler(_out.add);
  }

  final _out = <ChatChunk>[];
  late final PartAssembler _parts;
  int? _inputTokens;
  int? _cachedInputTokens;
  TokenUsage? _usage;
  var _terminated = false;
  var _sawEvent = false;
  var _finished = false;

  bool get isDone => _terminated || _finished;

  /// 本次解析是否识别出一个协议事件（单事件解析据此决定是否收口）。
  bool get sawEvent => _sawEvent;

  /// 解析一个 data 载荷，返回本次产生的事件（可能为空）。
  List<ChatChunk> parse(String data) {
    if (isDone) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      return const [];
    }
    if (decoded is! Map<String, dynamic>) return const [];
    _sawEvent = true;

    switch (decoded['type']) {
      case 'message_start':
        final start = _readUsage(decoded);
        _inputTokens = start?.inputTokens ?? _inputTokens;
        _cachedInputTokens = start?.cachedInputTokens ?? _cachedInputTokens;
      case 'content_block_start':
        _parseBlockStart(decoded);
      case 'content_block_delta':
        _parseBlockDelta(decoded);
      case 'content_block_stop':
        if (decoded['index'] case final int index) _parts.close(index);
      case 'message_delta':
        _usage =
            _parseUsage(
              decoded['usage'],
              inputTokens: _inputTokens,
              cachedInputTokens: _cachedInputTokens,
            ) ??
            _usage;
      case 'message_stop':
        return finish();
      case 'error':
        // 协议明确的错误字段是唯一分类依据。
        _terminated = true;
        _out.add(ResponseError(error: mapProtocolError(decoded['error'])));
      default:
        // ping、message_start 以外的元事件等没有内容产出。
        break;
    }
    return _drain();
  }

  /// 响应收口：补齐未结束的块，产出 usage 与 ResponseEnd。
  List<ChatChunk> finish({TokenUsage? usage}) {
    if (isDone) return const [];
    _finished = true;
    _parts.finish(usage: usage ?? _usage);
    return _drain();
  }

  void _parseBlockStart(Map<String, dynamic> event) {
    final index = event['index'];
    final block = event['content_block'];
    if (index is! int || block is! Map<String, dynamic>) return;
    switch (block['type']) {
      case 'tool_use':
        _parts.toolCall(
          index,
          callId: block['id'] is String ? block['id'] as String : null,
          toolName: block['name'] is String ? block['name'] as String : null,
          // 非流式网关可能直接在块首给出完整参数。
          argumentsFragment: switch (block['input']) {
            final Map<String, dynamic> input when input.isNotEmpty =>
              jsonEncode(input),
            _ => null,
          },
        );
      case 'thinking':
        _parts.reasoning(
          index,
          block['thinking'] is String ? block['thinking'] as String : '',
          providerData: switch (block['signature']) {
            final String signature when signature.isNotEmpty => {
              'signature': signature,
            },
            _ => null,
          },
        );
      case 'redacted_thinking':
        // 加密内容只是回传数据，不作为公开思考展示。
        _parts.reasoning(
          index,
          '',
          providerData: {
            'type': 'redacted_thinking',
            if (block['data'] case final String data) 'data': data,
          },
        );
      default:
        // text 块在首个增量到达时开始，不在这里发 PartStart。
        break;
    }
  }

  void _parseBlockDelta(Map<String, dynamic> event) {
    final index = event['index'];
    final delta = event['delta'];
    if (index is! int || delta is! Map<String, dynamic>) return;
    switch (delta['type']) {
      case 'text_delta':
        if (delta['text'] case final String text) _parts.text(index, text);
      case 'thinking_delta':
        if (delta['thinking'] case final String thinking) {
          _parts.reasoning(index, thinking);
        }
      case 'signature_delta':
        if (delta['signature'] case final String signature
            when signature.isNotEmpty) {
          _parts.reasoning(index, '', providerData: {'signature': signature});
        }
      case 'input_json_delta':
        // 参数片段只追加到调用缓冲，不在这里解析 JSON。
        if (delta['partial_json'] case final String fragment) {
          _parts.toolCall(index, argumentsFragment: fragment);
        }
      default:
        break;
    }
  }

  TokenUsage? _readUsage(Map<String, dynamic> event) {
    final message = event['message'];
    if (message is! Map<String, dynamic>) return null;
    return _parseUsage(message['usage']);
  }

  /// message_delta 常省略 input_tokens 与缓存字段，用 message_start 读到的值补齐。
  static TokenUsage? _parseUsage(
    Object? usage, {
    int? inputTokens,
    int? cachedInputTokens,
  }) {
    if (usage is! Map<String, dynamic>) {
      return null;
    }
    int? asInt(Object? value) => value is int ? value : null;
    return TokenUsage(
      inputTokens: asInt(usage['input_tokens']) ?? inputTokens,
      outputTokens: asInt(usage['output_tokens']),
      cachedInputTokens:
          asInt(usage['cache_read_input_tokens']) ?? cachedInputTokens,
    );
  }

  List<ChatChunk> _drain() {
    if (_out.isEmpty) return const [];
    final events = List<ChatChunk>.of(_out);
    _out.clear();
    return events;
  }
}
