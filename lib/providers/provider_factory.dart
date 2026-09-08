import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/provider_profile.dart';
import 'ai_provider.dart';
import 'openai/openai_compatible_provider.dart';

part 'provider_factory.g.dart';

/// 由 ProviderProfile + API Key 构造对应的 AiProvider 实现。
///
/// API Key 由调用方从 SecureKeyStorage 读出后传入，本函数不经手持久化。
AiProvider buildAiProvider(ProviderProfile profile, String apiKey) {
  return switch (profile.type) {
    ProviderType.openaiCompatible => OpenAiCompatibleProvider(
      profile: profile,
      apiKey: apiKey,
    ),
  };
}

/// AiProvider 构造工厂。
///
/// 单独开注入点是为了让测试能 override 成 fake AiProvider，
/// 不必伪造网络层。
@Riverpod(keepAlive: true)
AiProvider Function(ProviderProfile profile, String apiKey) aiProviderFactory(
  Ref ref,
) {
  return buildAiProvider;
}
