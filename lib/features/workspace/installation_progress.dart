import 'dart:async';

import 'package:flutter/material.dart';

/// 阶段位置不等于完成百分比；只展示执行器的真实输出与时间。
class InstallationProgress extends StatefulWidget {
  const InstallationProgress({
    super.key,
    required this.title,
    required this.steps,
    required this.current,
    required this.description,
    this.detail,
    this.lines = const [],
    this.startedAt,
    this.updatedAt,
    this.running = true,
  });

  final String title;
  final List<String> steps;
  final int current;
  final String description;
  final String? detail;
  final List<String> lines;
  final DateTime? startedAt;
  final DateTime? updatedAt;
  final bool running;

  @override
  State<InstallationProgress> createState() => _InstallationProgressState();
}

class _InstallationProgressState extends State<InstallationProgress> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateTimer();
  }

  @override
  void didUpdateWidget(InstallationProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running != widget.running ||
        oldWidget.startedAt != widget.startedAt) {
      _updateTimer();
    }
  }

  void _updateTimer() {
    _timer?.cancel();
    if (widget.running && widget.startedAt != null) {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final silence = now.difference(widget.updatedAt ?? widget.startedAt ?? now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.title} · 第 ${widget.current + 1} / ${widget.steps.length} 步'
          '${widget.running ? '' : ' · 已停止'}',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (var i = 0; i < widget.steps.length; i++)
              Text(
                '${i < widget.current
                    ? '✓'
                    : i == widget.current
                    ? '›'
                    : i + 1} ${widget.steps[i]}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: i == widget.current
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: i == widget.current ? FontWeight.bold : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(widget.steps[widget.current], style: theme.textTheme.titleSmall),
        Text(widget.description),
        if (widget.detail != null) Text(widget.detail!),
        if (widget.running && widget.startedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            '本步骤已用 ${_duration(now.difference(widget.startedAt!))}'
            ' · ${widget.updatedAt == null ? '等待进度' : '${silence.inSeconds} 秒前更新'}',
            style: theme.textTheme.bodySmall,
          ),
          if (silence.inSeconds >= 20)
            const Text('暂时没有新进度，可能在等待网络或处理文件；这不代表已经完成，可取消后重试。'),
        ],
        if (widget.lines.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('最近输出', style: theme.textTheme.labelLarge),
          for (final line in widget.lines)
            Text(line, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }

  String _duration(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
}
