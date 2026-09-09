import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_icon_badge.dart';

/// 可在键盘与短屏下滚动的对话引导，不承诺尚未实现的助手能力。
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const ValueKey('chat-empty-scroll'),
        primary: false,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - AppSpacing.section),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIconBadge(
                    icon: Symbols.dark_mode,
                    tone: AppTone.gold,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text('此刻，想聊些什么？', style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    '向相月提问，或选择一个助手',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/assistants'),
                    icon: const Icon(Symbols.smart_toy),
                    label: const Text('选择助手'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
