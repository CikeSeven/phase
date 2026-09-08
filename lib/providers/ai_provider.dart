import '../../data/models/ai_model.dart';
import '../../data/models/chat_chunk.dart';
import '../../data/models/chat_request.dart';

/// AI 服务商统一抽象（AGENTS.md §4）。
///
/// 所有厂商差异收敛在 lib/providers/ 内，上层只面对此接口与
/// core/error 的 Failure 类型。
abstract class AiProvider {
  /// 对应 ProviderProfile.id。
  String get id;

  ProviderCapabilities get capabilities;

  /// 流式对话。订阅取消必须即时终止底层请求（停止生成）。
  ///
  /// 错误以 [Failure] 子类型抛出。
  Stream<ChatChunk> streamChat(ChatRequest request);

  /// 拉取该服务商可用的模型列表。
  Future<List<AiModel>> listModels();

  /// 校验当前配置（Base URL + API Key）可用。
  Future<void> validateKey();
}

class ProviderCapabilities {
  const ProviderCapabilities({
    this.supportsStreaming = true,
    this.supportsVision = false,
    this.supportsToolCalls = false,
  });

  final bool supportsStreaming;
  final bool supportsVision;
  final bool supportsToolCalls;
}
