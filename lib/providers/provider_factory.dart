import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/api_protocol.dart';
import '../../data/models/provider_profile.dart';
import 'ai_provider.dart';
import 'anthropic_messages/anthropic_messages_provider.dart';
import 'google_generative_ai/google_generative_ai_provider.dart';
import 'openai_completions/openai_completions_provider.dart';
import 'openai_responses/openai_responses_provider.dart';

part 'provider_factory.g.dart';

/// 由 ProviderProfile + API Key 构造对应的 AiProvider 实现。
///
/// 协议差异收敛在各协议实现内，这里只按 profile.protocol 分派。
/// API Key 由调用方从 SecureKeyStorage 读出后传入，本函数不经手持久化。
AiProvider buildAiProvider(ProviderProfile profile, String apiKey) {
  return switch (profile.protocol) {
    ApiProtocol.openaiCompletions => OpenAiCompletionsProvider(
      profile: profile,
      apiKey: apiKey,
    ),
    ApiProtocol.openaiResponses => OpenAiResponsesProvider(
      profile: profile,
      apiKey: apiKey,
    ),
    ApiProtocol.anthropicMessages => AnthropicMessagesProvider(
      profile: profile,
      apiKey: apiKey,
    ),
    ApiProtocol.googleGenerativeAi => GoogleGenerativeAiProvider(
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
