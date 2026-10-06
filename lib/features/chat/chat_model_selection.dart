import '../../data/models/provider_profile.dart';
import '../../data/models/reasoning_effort.dart';

/// 当前生效的「服务商 × 模型 × 推理等级」组合。
class ChatModelSelection {
  const ChatModelSelection({
    required this.profile,
    required this.model,
    required this.supportsReasoning,
    required this.supportsImages,
    required this.supportsTools,
    required this.effort,
  });

  final ProviderProfile profile;
  final String model;

  /// 当前模型是否声明支持推理；false 时 effort 不下发。
  final bool supportsReasoning;

  /// 当前模型是否声明支持工具调用；false 时不下发工具定义。
  final bool supportsTools;

  /// 当前模型是否声明支持图片输入；false 时附件入口拦截图片。
  final bool supportsImages;

  final ReasoningEffort effort;
}

ChatModelSelection describeChatModelSelection({
  required ProviderProfile profile,
  required String model,
  required ReasoningEffort effort,
}) {
  final configured = profile.models
      .where((candidate) => candidate.id == model)
      .firstOrNull;
  return ChatModelSelection(
    profile: profile,
    model: model,
    effort: effort,
    supportsReasoning: configured?.supportsReasoning ?? true,
    supportsImages: configured?.supportsImages ?? true,
    supportsTools: configured?.supportsTools ?? true,
  );
}
