import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_list_tile.dart';

/// 设置分区入口，沿用列表色面与按压形变。
class SettingsEntry extends StatelessWidget {
  const SettingsEntry({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.tone = AppTone.primary,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final AppTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppListTile(
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    leading: AppIconBadge(icon: icon, tone: tone),
    trailing: onTap == null ? null : const Icon(Symbols.chevron_right),
    onTap: onTap,
  );
}
