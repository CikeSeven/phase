import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';

/// GitHub 风格 Callout / Alert 类型。
enum ChatAlertType {
  note,
  tip,
  important,
  warning,
  caution;

  static ChatAlertType fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'tip':
        return ChatAlertType.tip;
      case 'important':
        return ChatAlertType.important;
      case 'warning':
        return ChatAlertType.warning;
      case 'caution' || 'danger' || 'error':
        return ChatAlertType.caution;
      case 'note' || 'info':
      default:
        return ChatAlertType.note;
    }
  }

  String get defaultTitle {
    switch (this) {
      case ChatAlertType.note:
        return '说明';
      case ChatAlertType.tip:
        return '提示';
      case ChatAlertType.important:
        return '重点';
      case ChatAlertType.warning:
        return '警告';
      case ChatAlertType.caution:
        return '注意';
    }
  }

  IconData get icon {
    switch (this) {
      case ChatAlertType.note:
        return LucideIcons.info;
      case ChatAlertType.tip:
        return LucideIcons.lightbulb;
      case ChatAlertType.important:
        return LucideIcons.sparkles;
      case ChatAlertType.warning:
        return LucideIcons.triangleAlert;
      case ChatAlertType.caution:
        return LucideIcons.shieldAlert;
    }
  }

  Color resolveColor(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brandColors;

    switch (this) {
      case ChatAlertType.note:
        return theme.colorScheme.primary;
      case ChatAlertType.tip:
        return brand.teal;
      case ChatAlertType.important:
        return brand.lavender;
      case ChatAlertType.warning:
        return brand.gold;
      case ChatAlertType.caution:
        return theme.colorScheme.error;
    }
  }
}

/// GitHub 风格 Callout / 警告卡片组件。
class ChatMarkdownAlert extends StatelessWidget {
  const ChatMarkdownAlert({
    required this.type,
    this.title,
    this.titleWidget,
    this.body,
    super.key,
  });

  final ChatAlertType type;
  final String? title;
  final Widget? titleWidget;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = type.resolveColor(context);
    final displayTitle = (title != null && title!.trim().isNotEmpty)
        ? title!.trim()
        : type.defaultTitle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Material(
        color: accentColor.withValues(alpha: isDark ? 0.12 : 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.controlAll,
          side: BorderSide(
            color: accentColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accentColor, width: 3.5)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(type.icon, size: 18, color: accentColor),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child:
                        titleWidget ??
                        Text(
                          displayTitle,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                  ),
                ],
              ),
              if (body != null) ...[
                const SizedBox(height: AppSpacing.s),
                body!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 标准引用块组件。
class ChatMarkdownQuote extends StatelessWidget {
  const ChatMarkdownQuote({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Material(
        color: Color.alphaBlend(
          colors.primary.withValues(alpha: 0.05),
          colors.surfaceContainerLow,
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppRadius.control),
          bottomRight: Radius.circular(AppRadius.control),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: colors.primary.withValues(alpha: 0.7),
                width: 3.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m,
          ),
          child: child,
        ),
      ),
    );
  }
}
