import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/models/command_task.dart';

IconData taskStatusIcon(CommandTaskStatus status) => switch (status) {
  CommandTaskStatus.starting => LucideIcons.hourglass,
  CommandTaskStatus.running => LucideIcons.play,
  CommandTaskStatus.stopping => LucideIcons.loaderCircle,
  CommandTaskStatus.succeeded => LucideIcons.circleCheck,
  CommandTaskStatus.failed => LucideIcons.circleAlert,
  CommandTaskStatus.cancelled => LucideIcons.square,
  CommandTaskStatus.timedOut => LucideIcons.timer,
  CommandTaskStatus.interrupted => LucideIcons.unplug,
};

Color taskStatusColor(BuildContext context, CommandTaskStatus status) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    CommandTaskStatus.failed || CommandTaskStatus.timedOut => colors.error,
    CommandTaskStatus.succeeded => colors.tertiary,
    CommandTaskStatus.cancelled ||
    CommandTaskStatus.interrupted => colors.onSurfaceVariant,
    _ => colors.primary,
  };
}

String taskDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

String taskDuration(CommandTask task) {
  final elapsed = (task.finishedAt ?? DateTime.now()).difference(
    task.startedAt ?? task.createdAt,
  );
  final seconds = elapsed.inSeconds.clamp(0, 2147483647);
  if (seconds < 60) return '$seconds 秒';
  if (seconds < 3600) return '${seconds ~/ 60} 分 ${seconds % 60} 秒';
  return '${seconds ~/ 3600} 时 ${(seconds % 3600) ~/ 60} 分';
}

String taskByteSize(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KiB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
