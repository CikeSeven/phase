import 'package:flutter/material.dart';

import '../../../core/widgets/app_choice_chip.dart';
import '../../../data/models/api_protocol.dart';

/// 服务商界面的协议文案，不参与协议选择。
abstract final class ProviderUi {
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

/// 添加模型草稿中的能力选择。
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
    return AppChoiceChip(
      label: label,
      selected: selected,
      onSelected: onSelected,
      icon: icon,
      tooltip: tooltip,
    );
  }
}
