import 'dart:convert';

import '../../data/models/api_protocol.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/message_part.dart';
import '../../data/models/reasoning_effort.dart';
import '../attachment_encoder.dart';
import '../dio_failure_mapper.dart';
import '../part_assembler.dart';
import '../sse_transport.dart';

/// 构造 Google Generative AI（streamGenerateContent）请求体。
///
/// systemPrompt 提取为 systemInstruction；system 角色消息并入其中。
/// 推理等级映射 `generationConfig.thinkingConfig.thinkingBudget`
/// （off → 0；Gemini 2.x 支持以 0 关闭思考）；模型不支持推理时不下发。
Future<Map<String, dynamic>> buildGooglePayload(
  ChatRequest request, {
  bool supportsImages = true,
  bool supportsReasoning = true,
}) async {
  final attachments = RequestAttachmentEncoder(supportsImages: supportsImages);
  // functionResponse 按函数名回填，name 从同一批消息里的调用记录取回。
  final toolNames = <String, String>{
    for (final message in request.messages)
      for (final part in message.parts)
        if (part is ResolvedToolCall) part.callId: part.toolName,
  };

  final contents = <Map<String, dynamic>>[];
  for (final message in request.messages) {
    // system 角色消息并入 systemInstruction，不进入 contents。
    if (message.role == ChatRole.system) continue;
    final parts = await _googleParts(message, attachments, toolNames);
    contents.add({
      'role': message.role == ChatRole.assistant ? 'model' : 'user',
      // Gemini 拒绝空 parts；没有内容时保留一个空文本占位。
      'parts': parts.isEmpty
          ? const [
              <String, dynamic>{'text': ''},
            ]
          : parts,
    });
  }

  final system = _systemText(request);
  return {
    'contents': contents,
    if (system.isNotEmpty)
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
    'generationConfig': {
      if (supportsReasoning)
        'thinkingConfig': {
          'thinkingBudget': switch (request.reasoningEffort) {
            ReasoningEffort.off => 0,
            ReasoningEffort.low => 1024,
            ReasoningEffort.medium => 8192,
            ReasoningEffort.high => 24576,
            ReasoningEffort.xhigh => 49152,
            ReasoningEffort.max => 98304,
          },
        },
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.maxOutputTokens != null)
        'maxOutputTokens': request.maxOutputTokens,
    },
    // 未开放工具时不下发工具定义。
    if (request.tools.isNotEmpty)
      'tools': [
        {
          'functionDeclarations': [
            for (final tool in request.tools)
              {
                'name': tool.name,
                'description': tool.description,
                'parameters': tool.inputSchema,
              },
          ],
        },
      ],
  };
}

Future<List<Map<String, dynamic>>> _googleParts(
  ResolvedMessage message,
  RequestAttachmentEncoder attachments,
  Map<String, String> toolNames,
) async {
  final parts = <Map<String, dynamic>>[];
  for (final part in message.parts) {
    switch (part) {
      case ResolvedText(:final text):
        if (text.isNotEmpty) parts.add({'text': text});
      case ResolvedImage(:final attachment):
        final payload = await attachments.encode(attachment);
        if (payload.isImage) {
          parts.add({
            'inline_data': {
              'mime_type': payload.mimeType,
              'data': payload.base64Data,
            },
          });
        } else if (payload.text case final text?) {
          parts.add({'text': text});
        }
      case ResolvedToolCall(
        :final toolName,
        :final arguments,
        :final providerData,
      ):
        parts.add({
          'functionCall': {
            'name': toolName,
            'args': arguments,
            // 协议状态（thoughtSignature）随当前协议的 functionCall 一起回传。
            if (providerData?['thoughtSignature'] case final String signature)
              'thoughtSignature': signature,
          },
        });
      case ResolvedToolResult(:final callId, :final content, :final isError):
        parts.add({
          'functionResponse': {
            'name': toolNames[callId] ?? callId,
            'response': isError ? {'error': content} : {'result': content},
          },
        });
      case ResolvedReasoning():
        // 公开思考摘要不回传：Gemini 只用 functionCall 上的签名状态延续上下文。
        break;
    }
  }
  return parts;
}

/// systemPrompt 与 system 角色消息的合并结果。
String _systemText(ChatRequest request) => [
  if (request.systemPrompt.isNotEmpty) request.systemPrompt,
  for (final message in request.messages)
    if (message.role == ChatRole.system)
      for (final part in message.parts)
        if (part is ResolvedText && part.text.isNotEmpty) part.text,
].join('\n\n');

/// Google Generative AI 的 SSE 解析：每个 data 块是一个
/// GenerateContentResponse JSON；`thought: true` 的 part 是公开思考。
abstract final class GoogleSseDecoder {
  /// 独立解析单个 data 载荷并收口，用于报文级测试与诊断。
  static List<ChatChunk> parseEvent(String data, {String modelId = ''}) {
    final decoder = _GoogleStreamDecoder(modelId: modelId);
    final chunks = decoder.parse(data);
    // 畸形的载荷不是协议事件：既不产出内容，也不收口。
    if (!decoder.sawEvent) return const [];
    return [...chunks, ...decoder.finish()];
  }

  /// 把 HTTP 响应字节流解码为类型化事件流。
  ///
  /// [modelId] 写进协议状态块（[ProviderPart]），与后续请求绑定同一模型。
  static Stream<ChatChunk> decode(
    Stream<List<int>> byteStream, {
    String modelId = '',
  }) async* {
    final decoder = _GoogleStreamDecoder(modelId: modelId);
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

class _GoogleStreamDecoder {
  _GoogleStreamDecoder({required this.modelId}) {
    _parts = PartAssembler(_out.add);
  }

  /// 当前响应的模型 id，随协议状态一起写入 [ProviderPart]。
  final String modelId;

  final _out = <ChatChunk>[];
  late final PartAssembler _parts;

  /// functionCall 在响应内的序号；Gemini 不给块编号，按出现顺序编号。
  var _toolIndex = 0;
  var _providerCount = 0;
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

    if (decoded['error'] is Map<String, dynamic>) {
      // 协议明确的错误字段是唯一分类依据。
      _terminated = true;
      _out.add(ResponseError(error: mapProtocolError(decoded)));
      return _drain();
    }

    _usage = _parseUsage(decoded['usageMetadata']) ?? _usage;
    final candidates = decoded['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final candidate = candidates.first;
      if (candidate is Map<String, dynamic>) _parseCandidate(candidate);
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

  void _parseCandidate(Map<String, dynamic> candidate) {
    final content = candidate['content'];
    if (content is Map<String, dynamic>) {
      final parts = content['parts'];
      if (parts is List) {
        for (final part in parts) {
          if (part is Map<String, dynamic>) _parsePart(part);
        }
      }
    }
    // finishReason 只表示本次响应结束（STOP/MAX_TOKENS 都按正常结束处理），
    // 收口统一在流结束时做，保证 usage 不被丢掉。
  }

  void _parsePart(Map<String, dynamic> part) {
    final text = part['text'];
    if (text is String && text.isNotEmpty) {
      if (part['thought'] == true) {
        _parts.reasoning(0, text);
      } else {
        _parts.text(0, text);
      }
      return;
    }

    final call = part['functionCall'];
    if (call is Map<String, dynamic>) {
      final index = _toolIndex++;
      // Gemini 的 functionCall 一次给全参数，没有增量片段。
      _parts.toolCall(
        index,
        toolName: call['name'] is String ? call['name'] as String : null,
        argumentsFragment: switch (call['args']) {
          final Map<String, dynamic> args => jsonEncode(args),
          _ => null,
        },
      );
      // thoughtSignature 必须随该调用回传，且不能当成公开思考展示；
      // 它绑定到本次响应的工具块，由上层存入工具记录的 providerData，
      // 下一次请求按 Google 协议回填。
      final partId = _parts.partIdOf(PartKind.toolCall, index);
      final signature = part['thoughtSignature'];
      if (partId != null && signature is String && signature.isNotEmpty) {
        _addProviderState({
          'toolCallId': partId,
          'thoughtSignature': signature,
        });
      }
    }
    // P0 不使用服务端内置工具（搜索/代码执行），其余 part 类型不进入内容。
  }

  void _addProviderState(Map<String, dynamic> data) {
    final partId = 'provider_${_providerCount++}';
    _out.add(PartStart(partId: partId, kind: PartKind.provider));
    _out.add(
      PartEnd(
        partId: partId,
        part: ProviderPart(
          protocol: ApiProtocol.googleGenerativeAi.name,
          modelId: modelId,
          data: data,
        ),
      ),
    );
  }

  static TokenUsage? _parseUsage(Object? usageMetadata) {
    if (usageMetadata is! Map<String, dynamic>) {
      return null;
    }
    int? asInt(Object? value) => value is int ? value : null;
    return TokenUsage(
      inputTokens: asInt(usageMetadata['promptTokenCount']),
      outputTokens: asInt(usageMetadata['candidatesTokenCount']),
      reasoningTokens: asInt(usageMetadata['thoughtsTokenCount']),
      cachedInputTokens: asInt(usageMetadata['cachedContentTokenCount']),
    );
  }

  List<ChatChunk> _drain() {
    if (_out.isEmpty) return const [];
    final events = List<ChatChunk>.of(_out);
    _out.clear();
    return events;
  }
}
