import '../../data/models/provider_profile.dart';
import 'ai_provider.dart';
import 'openai/openai_compatible_provider.dart';

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
