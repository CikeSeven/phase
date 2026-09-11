import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
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

/// 模型能力开关的紧凑小片，用于模型卡片的密集控制区。
class CapabilityChip extends StatelessWidget {
  const CapabilityChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
    this.icon,
    this.tooltip,
  });

  final String label;
  final bool selected;

  /// null 表示禁用（如表单锁定中）。
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      tooltip: tooltip,
      selected: selected,
      onSelected: onSelected,
      // 默认勾选标记会叠在 avatar 图标上；选中态改用底色 + 图标变色表达。
      showCheckmark: false,
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 16,
              color: selected
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      labelStyle: Theme.of(context).textTheme.labelMedium,
      // 收紧图标与文字间距（默认 8dp，图标只有 16dp 时显得空）。
      labelPadding: const EdgeInsets.only(left: AppSpacing.xs),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
    );
  }
}
