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
import 'google_decoder.dart';

/// Google Generative AI 协议实现
///（POST {baseUrl}/v1beta/models/{model}:streamGenerateContent?alt=sse）。
class GoogleGenerativeAiProvider implements AiProvider {
  factory GoogleGenerativeAiProvider({
    required ProviderProfile profile,
    required String apiKey,
    Dio? dio,
  }) {
    return GoogleGenerativeAiProvider._(
      profile,
      apiKey,
      dio ?? createAppDio(baseUrl: profile.baseUrl),
    );
  }

  GoogleGenerativeAiProvider._(this._profile, this._apiKey, this._dio);

  final ProviderProfile _profile;
  final String _apiKey;
  final Dio _dio;

  @override
  ApiProtocol get protocol => ApiProtocol.googleGenerativeAi;

  /// 免 Key 服务商不发送鉴权头。
  Map<String, String> get _headers =>
      _profile.requiresKey ? {'x-goog-api-key': _apiKey} : const {};

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) async* {
    yield* postSseStream(
      dio: _dio,
      uri: resolveEndpoint(
        _profile.baseUrl,
        'v1beta/models/${request.modelId}:streamGenerateContent?alt=sse',
      ),
      payload: await buildGooglePayload(
        request,
        supportsImages: modelSupportsImages(_profile, request.modelId),
        supportsReasoning: modelSupportsReasoning(_profile, request.modelId),
      ),
      headers: _headers,
      // 协议状态块写入当次模型 id，与后续请求绑定。
      decode: GoogleSseDecoder.decode,
    );
  }

  @override
  Future<List<ProfileModel>> listModels() async {
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        resolveEndpoint(_profile.baseUrl, 'v1beta/models'),
        options: Options(headers: _headers),
      );
      final models = response.data?['models'];
      if (models is! List) {
        return const [];
      }
      return [
        for (final item in models)
          if (item is Map<String, dynamic> && item['name'] is String)
            ProfileModel(
              // name 形如 models/gemini-x，调用时只需要 id 部分。
              id: (item['name'] as String).replaceFirst('models/', ''),
              displayName: item['displayName'] is String
                  ? item['displayName'] as String
                  : null,
            ),
      ];
    } on DioException catch (e) {
      throw mapDioExceptionToProviderError(e);
    }
  }
}
