import 'package:dio/dio.dart';

import '../../data/datasources/remote/dio_client.dart';
import '../../data/models/ai_model.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/provider_profile.dart';
import '../ai_provider.dart';
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
  String get id => _profile.id;

  @override
  ProviderCapabilities get capabilities =>
      const ProviderCapabilities(supportsStreaming: true);

  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer $_apiKey',
  };

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
      uri: _resolve('responses'),
      payload: buildResponsesPayload(request),
      headers: _authHeaders,
      decode: ResponsesSseDecoder.decode,
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
    await listModels();
  }
}
