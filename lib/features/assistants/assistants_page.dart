import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_scaffold.dart';

/// 如实展示助手能力的开发状态，并提供返回对话的入口。
class AssistantsPage extends StatelessWidget {
  const AssistantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '助手',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIconBadge(
                  icon: Symbols.smart_toy,
                  tone: AppTone.lavender,
                  size: 64,
                  iconSize: 32,
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  header: true,
                  child: Text(
                    '助手功能即将上线',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Symbols.chat_bubble),
                  label: const Text('返回对话'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
