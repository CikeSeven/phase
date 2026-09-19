import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/attachment.dart';
import '../../../data/models/tool_call_record.dart';
import '../execution/application_names.dart';
import 'application_tool_display.dart';
import 'tool_card.dart';

/// 仅在应用工具需要名称时查询系统；纯展示组件不直接调用平台 API。
class ResolvedToolCard extends ConsumerWidget {
  const ResolvedToolCard({
    required this.record,
    this.artifacts = const [],
    this.onOpenArtifact,
    super.key,
  });

  final ToolCallRecord record;
  final List<Attachment> artifacts;
  final void Function(Attachment)? onOpenArtifact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? appName;
    if (ApplicationToolDisplay.supports(record)) {
      final package = ApplicationToolDisplay(record).packageName;
      if (package != null) {
        final names = ref.watch(applicationNamesProvider);
        appName =
            names.value?[package] ?? (names.isLoading ? '正在读取应用名称' : '应用名称不可用');
      }
    }
    return ToolCard(
      record: record,
      appName: appName,
      artifacts: artifacts,
      onOpenArtifact: onOpenArtifact,
    );
  }
}
