import 'package:dio/dio.dart';

import '../../data/datasources/remote/dio_client.dart';
import '../../data/models/ai_model.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/openai_compat.dart';
import '../../data/models/provider_profile.dart';
import '../../data/models/reasoning_effort.dart';
import '../ai_provider.dart';
import '../dio_failure_mapper.dart';
import '../sse_transport.dart';
import 'sse_decoder.dart';
import 'think_tag_filter.dart';

/// 构造 chat/completions 请求体。
///
/// 纯函数便于单测；推理等级按 [OpenAiCompat.thinkingFormat] 映射。
Map<String, dynamic> buildCompletionsPayload({
  required ChatRequest request,
  required OpenAiCompat compat,
}) {
  final payload = <String, dynamic>{
    'model': request.model,
    'messages': [
      for (final message in request.messages)
        {'role': _roleFor(message, compat), 'content': message.content},
    ],
    'stream': true,
    if (request.temperature != null) 'temperature': request.temperature,
  };
  final maxTokens = request.maxTokens;
  if (maxTokens != null) {
    payload[compat.maxTokensField] = maxTokens;
  }
  _applyReasoningEffort(payload, request.reasoningEffort, compat.thinkingFormat);
  return payload;
}

String _roleFor(ChatMessage message, OpenAiCompat compat) {
  if (message.role == ChatRole.system) {
    return compat.supportsDeveloperRole ? 'developer' : 'system';
  }
  return message.role.name;
}

void _applyReasoningEffort(
  Map<String, dynamic> payload,
  ReasoningEffort? effort,
  ThinkingFormat format,
) {
  if (effort == null) {
    return;
  }
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
      payload['enable_thinking'] =
          effort == ReasoningEffort.medium || effort == ReasoningEffort.high;
  }
}

/// OpenAI 兼容 chat/completions 协议实现（AGENTS.md §4：默认实现）。
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
  String get id => _profile.id;

  @override
  ProviderCapabilities get capabilities =>
      const ProviderCapabilities(supportsStreaming: true);

  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer $_apiKey',
  };

  /// baseUrl 以 / 结尾与否都能正确拼接子路径。
  Uri _resolve(String path) {
    final base = _profile.baseUrl.endsWith('/')
        ? _profile.baseUrl
        : '${_profile.baseUrl}/';
    return Uri.parse(base).resolve(path);
  }

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) {
    return postSseStream(
      dio: _dio,
      uri: _resolve('chat/completions'),
      payload: buildCompletionsPayload(request: request, compat: _compat),
      headers: _authHeaders,
      // think 标签拆分放在解码之后，保持 SSE 解析器纯粹。
      decode: (body) => splitThinkTags(OpenAiSseDecoder.decode(body)),
    );
  }

  @override
  Future<List<AiModel>> listModels() async {
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        _resolve('models'),
        options: Options(headers: _authHeaders),
      );
      final data = response.data?['data'];
      if (data is! List) {
        return const [];
      }
      return [
        for (final item in data)
          if (item is Map<String, dynamic> && item['id'] is String)
            AiModel(id: item['id'] as String),
      ];
    } on DioException catch (e) {
      throw mapDioExceptionToFailure(e);
    }
  }

  @override
  Future<void> validateKey() async {
    // 以拉取模型列表作为连通性 + 鉴权校验。
    await listModels();
  }
}
