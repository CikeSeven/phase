import 'package:dio/dio.dart';

import '../../data/datasources/remote/dio_client.dart';
import '../../data/models/api_protocol.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/provider_profile.dart';
import '../ai_provider.dart';
import '../attachment_encoder.dart';
import '../dio_failure_mapper.dart';
import '../sse_transport.dart';
import 'anthropic_decoder.dart';

/// Anthropic Messages API 协议实现（POST {baseUrl}/v1/messages）。
class AnthropicMessagesProvider implements AiProvider {
  factory AnthropicMessagesProvider({
    required ProviderProfile profile,
    required String apiKey,
    Dio? dio,
  }) {
    return AnthropicMessagesProvider._(
      profile,
      apiKey,
      dio ?? createAppDio(baseUrl: profile.baseUrl),
    );
  }

  AnthropicMessagesProvider._(this._profile, this._apiKey, this._dio);

  final ProviderProfile _profile;
  final String _apiKey;
  final Dio _dio;

  static const _anthropicVersion = '2023-06-01';

  @override
  ApiProtocol get protocol => ApiProtocol.anthropicMessages;

  /// 免 Key 服务商只发送协议版本头。
  Map<String, String> get _headers => {
    if (_profile.requiresKey) 'x-api-key': _apiKey,
    'anthropic-version': _anthropicVersion,
  };

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) async* {
    yield* postSseStream(
      dio: _dio,
      uri: resolveEndpoint(_profile.baseUrl, 'v1/messages'),
      payload: await buildAnthropicPayload(
        request,
        supportsImages: modelSupportsImages(_profile, request.modelId),
        supportsReasoning: modelSupportsReasoning(_profile, request.modelId),
      ),
      headers: _headers,
      decode: AnthropicSseDecoder.decode,
    );
  }

  @override
  Future<List<ProfileModel>> listModels() async {
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        resolveEndpoint(_profile.baseUrl, 'v1/models'),
        options: Options(headers: _headers),
      );
      final data = response.data?['data'];
      if (data is! List) {
        return const [];
      }
      return [
        for (final item in data)
          if (item is Map<String, dynamic> && item['id'] is String)
            ProfileModel(
              id: item['id'] as String,
              displayName: item['display_name'] is String
                  ? item['display_name'] as String
                  : null,
            ),
      ];
    } on DioException catch (e) {
      throw mapDioExceptionToProviderError(e);
    }
  }
}
