import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app_icon_badge.dart';
import '../../../data/models/api_protocol.dart';

/// 服务商界面的语义图标与协议文案，不参与协议选择。
abstract final class ProviderUi {
  static IconData icon(String presetId) => switch (presetId) {
    'openai' => Symbols.hexagon,
    'anthropic' => Symbols.chat_bubble,
    'google' => Symbols.auto_awesome,
    'deepseek' => Symbols.water,
    'moonshot' || 'moonshot-intl' => Symbols.dark_mode,
    'zhipu' || 'zai' => Symbols.psychology,
    'qwen' => Symbols.cloud,
    'siliconflow' => Symbols.waves,
    'minimax' || 'minimax-cn' => Symbols.compress,
    'openrouter' => Symbols.hub,
    'groq' => Symbols.bolt,
    'xai' => Symbols.star,
    'mistral' => Symbols.air,
    'cerebras' => Symbols.memory,
    'together' => Symbols.groups,
    'fireworks' => Symbols.celebration,
    'nvidia' => Symbols.developer_board,
    'huggingface' => Symbols.emoji_emotions,
    'baseten' => Symbols.deployed_code,
    'vercel-ai-gateway' => Symbols.change_history,
    'ollama' => Symbols.dns,
    _ => Symbols.tune,
  };

  static AppTone tone(String presetId) => switch (presetId) {
    'openai' || 'xai' => AppTone.primary,
    'anthropic' || 'google' || 'moonshot' => AppTone.lavender,
    _ => AppTone.teal,
  };

  static String protocolLabel(ApiProtocol protocol) => switch (protocol) {
    ApiProtocol.openaiCompletions => 'OpenAI 兼容',
    ApiProtocol.openaiResponses => 'OpenAI Responses',
    ApiProtocol.anthropicMessages => 'Anthropic Messages',
    ApiProtocol.googleGenerativeAi => 'Google Generative AI',
  };

  static String protocolHint(ApiProtocol protocol) => switch (protocol) {
    ApiProtocol.openaiCompletions => 'POST /chat/completions',
    ApiProtocol.openaiResponses => 'POST /responses',
    ApiProtocol.anthropicMessages => 'POST /v1/messages',
    ApiProtocol.googleGenerativeAi =>
      'POST /v1beta/models/{model}:streamGenerateContent',
  };
}
