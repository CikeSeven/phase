import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/app_icon_badge.dart';

/// 本地品牌标识；彩色标识保留原色，单色标识适配深浅主题。
class ProviderLogo extends StatelessWidget {
  const ProviderLogo({
    required this.presetId,
    super.key,
    this.size = 40,
    this.logoSize = 24,
  }) : assert(size > 0),
       assert(logoSize > 0);

  final String presetId;
  final double size;
  final double logoSize;

  static const _assets = {
    'openai': 'openai',
    'anthropic': 'anthropic',
    'google': 'google',
    'deepseek': 'deepseek',
    'moonshot': 'moonshot',
    'moonshot-intl': 'moonshot',
    'zhipu': 'zhipu',
    'zai': 'zai',
    'qwen': 'qwen',
    'siliconflow': 'siliconflow',
    'minimax': 'minimax',
    'minimax-cn': 'minimax',
    'openrouter': 'openrouter',
    'groq': 'groq',
    'xai': 'xai',
    'mistral': 'mistral',
    'cerebras': 'cerebras',
    'together': 'together',
    'fireworks': 'fireworks',
    'nvidia': 'nvidia',
    'huggingface': 'huggingface',
    'baseten': 'baseten',
    'vercel-ai-gateway': 'vercel-ai-gateway',
    'ollama': 'ollama',
  };

  static const _coloredAssets = {
    'google',
    'deepseek',
    'zhipu',
    'qwen',
    'siliconflow',
    'minimax',
    'mistral',
    'cerebras',
    'together',
    'fireworks',
    'nvidia',
    'huggingface',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[presetId];
    if (asset == null) {
      return AppIconBadge(
        icon: LucideIcons.slidersHorizontal,
        tone: AppTone.teal,
        size: size,
        iconSize: logoSize,
      );
    }
    final colors = Theme.of(context).colorScheme;
    final colored = _coloredAssets.contains(asset);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colored ? Colors.white : colors.surfaceContainerLowest,
          borderRadius: AppRadius.smallAll,
        ),
        child: SvgPicture.asset(
          'assets/provider_logos/$asset.svg',
          width: logoSize,
          height: logoSize,
          theme: SvgTheme(
            currentColor: colored ? Colors.black : colors.onSurface,
          ),
          colorFilter: colored
              ? null
              : ColorFilter.mode(colors.onSurface, BlendMode.srcIn),
        ),
      ),
    );
  }
}
