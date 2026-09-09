import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/models/api_protocol.dart';
import 'provider_ui.dart';

/// 从底部面板选择 API 协议，替换占满宽度的下拉菜单。
class ProviderProtocolSheet extends StatelessWidget {
  const ProviderProtocolSheet({required this.selected, super.key});

  final ApiProtocol selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AppSheet(
      title: 'API 协议',
      child: ListView.separated(
        key: const ValueKey('protocol-scroll'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.xl,
        ),
        itemCount: ApiProtocol.values.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
        itemBuilder: (context, index) {
          final protocol = ApiProtocol.values[index];
          final selected = protocol == this.selected;
          final foreground = selected
              ? colors.onPrimaryContainer
              : colors.onSurface;
          return Semantics(
            selected: selected,
            button: true,
            child: Material(
              borderRadius: AppRadius.mediumAll,
              color: selected
                  ? colors.primaryContainer.withValues(alpha: 0.72)
                  : colors.surface.withValues(alpha: 0),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('protocol-${protocol.name}'),
                onTap: () => Navigator.of(context).pop(protocol),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.m,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ProviderUi.protocolLabel(protocol),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: foreground,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              ProviderUi.protocolHint(protocol),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: selected
                                    ? foreground
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      SizedBox.square(
                        dimension: 24,
                        child: selected
                            ? Icon(
                                Symbols.check_circle,
                                color: foreground,
                                fill: 1,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
