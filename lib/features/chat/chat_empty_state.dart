import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_icon_badge.dart';

/// 可在键盘与短屏下滚动的对话引导，不承诺尚未实现的助手能力。
///
/// 上下留白预留顶栏、运行提示与输入栏的高度，保证内容能滚出遮挡区。
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    this.topPadding = 0,
    this.bottomPadding = 0,
    this.projectName,
  });

  final double topPadding;
  final double bottomPadding;
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const ValueKey('chat-empty-scroll'),
        primary: false,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl + topPadding,
          AppSpacing.xl,
          AppSpacing.xl + bottomPadding,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(
              0,
              constraints.maxHeight -
                  AppSpacing.section -
                  topPadding -
                  bottomPadding,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconBadge(
                    icon: projectName == null
                        ? LucideIcons.moon
                        : LucideIcons.folder,
                    tone: projectName == null ? AppTone.gold : AppTone.teal,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      projectName == null
                          ? '向相月提问，或选择一个助手'
                          : '让我们在「$projectName」中构建什么？',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (projectName == null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push('/assistants'),
                      icon: const Icon(LucideIcons.bot),
                      label: const Text('选择助手'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
