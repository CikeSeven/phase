import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/error/failure.dart';
import '../../data/datasources/remote/dio_client.dart';
import '../../data/models/ai_model.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_request.dart';
import '../../data/models/provider_profile.dart';
import '../ai_provider.dart';
import 'sse_decoder.dart';
import 'think_tag_filter.dart';

/// 把 dio 异常映射为统一的 [Failure] 体系。
///
/// 纯函数，便于独立单测。
Failure mapDioExceptionToFailure(DioException error) {
  switch (error.type) {
    case DioExceptionType.cancel:
      return CancelledFailure('请求已取消', cause: error);
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return NetworkFailure('连接失败或超时: ${error.message}', cause: error);
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return AuthFailure('鉴权失败 (HTTP $status)', cause: error);
      }
      if (status == 429) {
        return RateLimitFailure('触发限流 (HTTP 429)', cause: error);
      }
      if (status >= 500) {
        return ServerFailure('服务端错误 (HTTP $status)', cause: error);
      }
      return UnknownFailure('未预期的响应 (HTTP $status)', cause: error);
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return UnknownFailure('网络请求异常: ${error.message}', cause: error);
  }
}

/// OpenAI 兼容协议实现（AGENTS.md §4：默认实现）。
///
/// DeepSeek、Ollama、自定义 OpenAI 兼容网关等一律复用本类，
/// 仅 ProviderProfile 的 baseUrl / apiKey 不同。
class OpenAiCompatibleProvider implements AiProvider {
  factory OpenAiCompatibleProvider({
    required ProviderProfile profile,
    required String apiKey,
    Dio? dio,
  }) {
    return OpenAiCompatibleProvider._(
      profile,
      apiKey,
      dio ?? createAppDio(baseUrl: profile.baseUrl),
    );
  }

  OpenAiCompatibleProvider._(this._profile, this._apiKey, this._dio);

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

  /// baseUrl 以 / 结尾与否都能正确拼接子路径。
  Uri _resolve(String path) {
    final base = _profile.baseUrl.endsWith('/')
        ? _profile.baseUrl
        : '${_profile.baseUrl}/';
    return Uri.parse(base).resolve(path);
  }

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) {
    final cancelToken = CancelToken();
    // 手写 controller 是为了把「订阅取消」桥接到 dio 的 CancelToken，
    // 保证停止生成即时生效（AGENTS.md §4 取消语义）。
    final controller = StreamController<ChatChunk>();

    controller.onListen = () async {
      try {
        final response = await _dio.postUri<ResponseBody>(
          _resolve('chat/completions'),
          data: _buildPayload(request),
          options: Options(
            responseType: ResponseType.stream,
            headers: _authHeaders,
          ),
          cancelToken: cancelToken,
        );
        final body = response.data;
        if (body == null) {
          throw const ServerFailure('响应体为空');
        }
        // think 标签拆分放在解码之后，保持 SSE 解析器纯粹。
        await controller.addStream(
          splitThinkTags(OpenAiSseDecoder.decode(body.stream)),
        );
      } on DioException catch (e) {
        if (!controller.isClosed) {
          controller.addError(mapDioExceptionToFailure(e));
        }
      }
      if (!controller.isClosed) {
        await controller.close();
      }
    };

    controller.onCancel = () {
      cancelToken.cancel('用户停止生成');
    };

    return controller.stream;
  }

  Map<String, dynamic> _buildPayload(ChatRequest request) {
    return {
      'model': request.model,
      'messages': [
        for (final message in request.messages)
          {'role': message.role.name, 'content': message.content},
      ],
      'stream': true,
      if (request.temperature != null) 'temperature': request.temperature,
    };
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
