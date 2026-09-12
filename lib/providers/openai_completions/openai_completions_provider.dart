import 'dart:convert';

import 'package:dio/dio.dart';

import '../../data/datasources/remote/dio_client.dart';
import '../../data/models/api_protocol.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/openai_compat.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/provider_profile.dart';
import '../../data/models/reasoning_effort.dart';
import '../ai_provider.dart';
import '../attachment_encoder.dart';
import '../dio_failure_mapper.dart';
import '../sse_transport.dart';
import 'sse_decoder.dart';

/// 构造 chat/completions 请求体（design 第五部分 §4.2、§4.4）。
///
/// 纯请求映射，便于单测：systemPrompt 与 system 角色消息按
/// [OpenAiCompat.supportsDeveloperRole] 取 developer/system 角色；
/// 图片按 [ResolvedImage.attachment] 的本地文件编码为 data URI；
/// 工具调用回填 assistant.tool_calls，工具结果按调用 ID 配对为 role=tool 消息；
/// 推理等级按 [OpenAiCompat.thinkingFormat] 映射。
Future<Map<String, dynamic>> buildCompletionsPayload(
  ChatRequest request, {
  required OpenAiCompat compat,
  bool supportsImages = true,
  bool supportsReasoning = true,
}) async {
  final attachments = RequestAttachmentEncoder(supportsImages: supportsImages);
  final messages = <Map<String, dynamic>>[];
  if (request.systemPrompt.isNotEmpty) {
    messages.add({
      'role': _systemRole(compat),
      'content': request.systemPrompt,
    });
  }
  for (final message in request.messages) {
    messages.addAll(await _completionsMessages(message, compat, attachments));
  }

  final payload = <String, dynamic>{
    'model': request.modelId,
    'messages': messages,
    'stream': true,
    if (request.temperature != null) 'temperature': request.temperature,
  };
  final maxTokens = request.maxOutputTokens;
  if (maxTokens != null) {
    payload[compat.maxTokensField] = maxTokens;
  }
  // 未开放工具时不下发工具定义。
  if (request.tools.isNotEmpty) {
    payload['tools'] = [
      for (final tool in request.tools)
        {
          'type': 'function',
          'function': {
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.inputSchema,
          },
        },
    ];
  }
  _applyReasoningEffort(
    payload,
    request.reasoningEffort,
    compat.thinkingFormat,
    supported: supportsReasoning,
  );
  return payload;
}

Future<List<Map<String, dynamic>>> _completionsMessages(
  ResolvedMessage message,
  OpenAiCompat compat,
  RequestAttachmentEncoder attachments,
) async {
  // 正文与附件按 part 顺序收集，保持「文字-图片-文字」的相对位置。
  final blocks = <Object>[];
  final calls = <ResolvedToolCall>[];
  final results = <ResolvedToolResult>[];
  for (final part in message.parts) {
    switch (part) {
      case ResolvedText(:final text):
        if (text.isNotEmpty) blocks.add(text);
      case ResolvedImage(:final attachment):
        final payload = await attachments.encode(attachment);
        blocks.add(payload.isImage ? payload : (payload.text ?? ''));
      case ResolvedToolCall():
        calls.add(part);
      case ResolvedToolResult():
        results.add(part);
      case ResolvedReasoning():
        // OpenAI 兼容协议没有回传思考的字段，思考块不进入请求。
        break;
    }
  }

  final messages = <Map<String, dynamic>>[];
  if (blocks.isNotEmpty ||
      calls.isNotEmpty ||
      message.role == ChatRole.system) {
    messages.add({
      'role': _roleFor(message.role, compat),
      'content': _completionsContent(blocks),
      if (calls.isNotEmpty)
        'tool_calls': [
          for (final call in calls)
            {
              'id': call.callId,
              'type': 'function',
              'function': {
                'name': call.toolName,
                'arguments': jsonEncode(call.arguments),
              },
            },
        ],
    });
  }
  for (final result in results) {
    messages.add({
      'role': 'tool',
      'tool_call_id': result.callId,
      'content': result.content,
    });
  }
  return messages;
}

/// 没有附件时内容保持纯字符串，有附件时变为结构化数组。
Object _completionsContent(List<Object> blocks) {
  if (blocks.every((block) => block is String)) return blocks.join();
  return [
    for (final block in blocks)
      if (block is String)
        {'type': 'text', 'text': block}
      else
        {
          'type': 'image_url',
          'image_url': {'url': (block as AttachmentPayload).dataUri},
        },
  ];
}

String _systemRole(OpenAiCompat compat) =>
    compat.supportsDeveloperRole ? 'developer' : 'system';

String _roleFor(ChatRole role, OpenAiCompat compat) => switch (role) {
  ChatRole.system => _systemRole(compat),
  ChatRole.user => 'user',
  ChatRole.assistant => 'assistant',
  ChatRole.tool => 'tool',
};

void _applyReasoningEffort(
  Map<String, dynamic> payload,
  ReasoningEffort effort,
  ThinkingFormat format, {
  required bool supported,
}) {
  // 模型未声明支持推理：不下发任何推理字段。
  if (!supported) return;
  switch (format) {
    case ThinkingFormat.openai:
      // openai 格式没有通用的「关闭」取值（部分端点拒绝 none），off 不下发。
      if (effort != ReasoningEffort.off) {
        payload['reasoning_effort'] = effort.name;
      }
    case ThinkingFormat.openrouter:
      payload['reasoning'] = {
        'effort': effort == ReasoningEffort.off ? 'none' : effort.name,
      };
    case ThinkingFormat.deepseek:
      payload['thinking'] = {
        'type': effort == ReasoningEffort.off ? 'disabled' : 'enabled',
      };
    case ThinkingFormat.qwen:
      // qwen 只有开关语义：低等级视为关，中及以上才开启思考。
      payload['enable_thinking'] =
          effort != ReasoningEffort.off && effort != ReasoningEffort.low;
  }
}

/// OpenAI 兼容 chat/completions 协议实现（design 第五部分 §4.4）。
///
/// DeepSeek、Ollama、自定义网关等复用本协议，差异由
/// [OpenAiCompat]（baseUrl 嗅探 + profile 覆盖）声明。
class OpenAiCompletionsProvider implements AiProvider {
  factory OpenAiCompletionsProvider({
    required ProviderProfile profile,
    required String apiKey,
    Dio? dio,
  }) {
    return OpenAiCompletionsProvider._(
      profile,
      apiKey,
      dio ?? createAppDio(baseUrl: profile.baseUrl),
    );
  }

  OpenAiCompletionsProvider._(this._profile, this._apiKey, this._dio);

  final ProviderProfile _profile;
  final String _apiKey;
  final Dio _dio;

  OpenAiCompat get _compat =>
      OpenAiCompat.resolve(_profile.baseUrl, _profile.compatOverrides);

  @override
  ApiProtocol get protocol => ApiProtocol.openaiCompletions;

  /// 免 Key 服务商不发送鉴权头。
  Map<String, String> get _headers =>
      _profile.requiresKey ? {'Authorization': 'Bearer $_apiKey'} : const {};

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) async* {
    final payload = await buildCompletionsPayload(
      request,
      compat: _compat,
      supportsImages: modelSupportsImages(_profile, request.modelId),
      supportsReasoning: modelSupportsReasoning(_profile, request.modelId),
    );
    yield* postSseStream(
      dio: _dio,
      uri: resolveEndpoint(_profile.baseUrl, 'chat/completions'),
      payload: payload,
      headers: _headers,
      decode: OpenAiSseDecoder.decode,
    );
  }

  @override
  Future<List<ProfileModel>> listModels() async {
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        resolveEndpoint(_profile.baseUrl, 'models'),
        options: Options(headers: _headers),
      );
      final data = response.data?['data'];
      if (data is! List) {
        return const [];
      }
      return [
        for (final item in data)
          if (item is Map<String, dynamic> && item['id'] is String)
            ProfileModel(id: item['id'] as String),
      ];
    } on DioException catch (e) {
      throw mapDioExceptionToProviderError(e);
    }
  }
}
