import 'package:dio/dio.dart';

import '../../data/datasources/remote/dio_client.dart';
import '../../data/models/ai_model.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/provider_profile.dart';
import '../ai_provider.dart';
import '../dio_failure_mapper.dart';
import '../attachment_encoder.dart';
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
  String get id => _profile.id;

  @override
  ProviderCapabilities get capabilities =>
      const ProviderCapabilities(supportsStreaming: true);

  Map<String, String> get _authHeaders => {'x-goog-api-key': _apiKey};

  Uri _resolve(String path) {
    final base = _profile.baseUrl.endsWith('/')
        ? _profile.baseUrl
        : '${_profile.baseUrl}/';
    return Uri.parse(base).resolve(path);
  }

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) async* {
    final attachments = await encodeRequestAttachments(
      request,
      supportsImages: modelSupportsImages(_profile, request.model),
    );
    yield* postSseStream(
      dio: _dio,
      uri: _resolve(
        'v1beta/models/${request.model}:streamGenerateContent?alt=sse',
      ),
      payload: buildGooglePayload(request, attachments: attachments),
      headers: _authHeaders,
      decode: GoogleSseDecoder.decode,
    );
  }

  @override
  Future<List<AiModel>> listModels() async {
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        _resolve('v1beta/models'),
        options: Options(headers: _authHeaders),
      );
      final models = response.data?['models'];
      if (models is! List) {
        return const [];
      }
      return [
        for (final item in models)
          if (item is Map<String, dynamic> && item['name'] is String)
            AiModel(
              // name 形如 models/gemini-x，调用时只需要 id 部分。
              id: (item['name'] as String).replaceFirst('models/', ''),
              displayName: item['displayName'] is String
                  ? item['displayName'] as String
                  : null,
            ),
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
