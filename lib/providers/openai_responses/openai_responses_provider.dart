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
import 'responses_decoder.dart';

/// OpenAI Responses API 协议实现（POST {baseUrl}/responses）。
class OpenAiResponsesProvider implements AiProvider {
  factory OpenAiResponsesProvider({
    required ProviderProfile profile,
    required String apiKey,
    Dio? dio,
  }) {
    return OpenAiResponsesProvider._(
      profile,
      apiKey,
      dio ?? createAppDio(baseUrl: profile.baseUrl),
    );
  }

  OpenAiResponsesProvider._(this._profile, this._apiKey, this._dio);

  final ProviderProfile _profile;
  final String _apiKey;
  final Dio _dio;

  @override
  ApiProtocol get protocol => ApiProtocol.openaiResponses;

  /// 免 Key 服务商不发送鉴权头。
  Map<String, String> get _headers =>
      _profile.requiresKey ? {'Authorization': 'Bearer $_apiKey'} : const {};

  /// 是否索要加密推理载荷（`include: ["reasoning.encrypted_content"]`）。
  ///
  /// 官方端点认这个参数，推理 item 靠它跨请求还原；网关不一定认识，
  /// 未知参数会被直接拒绝，因此只在官方端点上开启——不发这个参数时，
  /// 我们仍然原样回放服务端返回的推理 item。
  bool get _supportsEncryptedReasoning {
    final host = Uri.tryParse(_profile.baseUrl)?.host ?? '';
    return host == 'api.openai.com' || host.endsWith('.openai.azure.com');
  }

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) async* {
    yield* postSseStream(
      dio: _dio,
      uri: resolveEndpoint(_profile.baseUrl, 'responses'),
      payload: await buildResponsesPayload(
        request,
        supportsImages: modelSupportsImages(_profile, request.modelId),
        supportsReasoning: modelSupportsReasoning(_profile, request.modelId),
        requestEncryptedReasoning: _supportsEncryptedReasoning,
      ),
      headers: _headers,
      decode: ResponsesSseDecoder.decode,
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
