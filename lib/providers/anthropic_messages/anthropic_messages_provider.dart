import 'package:dio/dio.dart';

import '../../data/datasources/remote/dio_client.dart';
import '../../data/models/ai_model.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/provider_profile.dart';
import '../ai_provider.dart';
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
  String get id => _profile.id;

  @override
  ProviderCapabilities get capabilities =>
      const ProviderCapabilities(supportsStreaming: true);

  Map<String, String> get _authHeaders => {
    'x-api-key': _apiKey,
    'anthropic-version': _anthropicVersion,
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
      uri: _resolve('v1/messages'),
      payload: buildAnthropicPayload(request),
      headers: _authHeaders,
      decode: AnthropicSseDecoder.decode,
    );
  }

  @override
  Future<List<AiModel>> listModels() async {
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        _resolve('v1/models'),
        options: Options(headers: _authHeaders),
      );
      final data = response.data?['data'];
      if (data is! List) {
        return const [];
      }
      return [
        for (final item in data)
          if (item is Map<String, dynamic> && item['id'] is String)
            AiModel(
              id: item['id'] as String,
              displayName: item['display_name'] is String
                  ? item['display_name'] as String
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
