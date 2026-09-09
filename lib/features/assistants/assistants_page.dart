import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_scaffold.dart';

/// 如实展示助手能力的开发状态，并提供返回对话的入口。
class AssistantsPage extends StatelessWidget {
  const AssistantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '助手',
      body: AppEmptyState(
        icon: Symbols.smart_toy,
        tone: AppTone.lavender,
        title: '助手功能即将上线',
        message:
            '未来可为常用任务保存系统提示词（system prompt）与任务模板。'
            '\n现在，先与已配置的模型展开对话。',
        action: FilledButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Symbols.chat_bubble),
          label: const Text('返回对话'),
        ),
      ),
    );
  }
}
