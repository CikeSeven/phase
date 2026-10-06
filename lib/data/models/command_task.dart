import 'dart:typed_data';

import 'workspace.dart';

enum TaskCompletionDelivery { none, pending, delivered, suppressed }

enum CommandTaskStatus {
  starting,
  running,
  stopping,
  succeeded,
  failed,
  cancelled,
  timedOut,
  interrupted;

  bool get active => switch (this) {
    starting || running || stopping => true,
    _ => false,
  };

  String get label => switch (this) {
    starting => '启动中',
    running => '运行中',
    stopping => '停止中',
    succeeded => '已完成',
    failed => '已失败',
    cancelled => '已停止',
    timedOut => '已超时',
    interrupted => '已中断',
  };
}

class CommandTask {
  const CommandTask({
    required this.id,
    required this.conversationId,
    required this.workspace,
    required this.title,
    required this.command,
    required this.cwd,
    required this.createdAt,
    this.status = CommandTaskStatus.starting,
    this.runId,
    this.toolCallId,
    this.timeoutMs,
    this.startedAt,
    this.finishedAt,
    this.exitCode,
    this.signal,
    this.error,
    this.stdoutBytes = 0,
    this.stderrBytes = 0,
    this.notifyOnCompletion = true,
    this.completionDelivery = TaskCompletionDelivery.none,
  });

  final String id;
  final String conversationId;
  final WorkspaceSnapshot workspace;
  final String title;
  final String command;
  final String cwd;
  final String? runId;
  final String? toolCallId;
  final int? timeoutMs;
  final CommandTaskStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int? exitCode;
  final int? signal;
  final String? error;
  final int stdoutBytes;
  final int stderrBytes;
  final bool notifyOnCompletion;
  final TaskCompletionDelivery completionDelivery;

  CommandTask copyWith({
    CommandTaskStatus? status,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? exitCode,
    int? signal,
    String? error,
    int? stdoutBytes,
    int? stderrBytes,
    TaskCompletionDelivery? completionDelivery,
  }) => CommandTask(
    id: id,
    conversationId: conversationId,
    workspace: workspace,
    title: title,
    command: command,
    cwd: cwd,
    createdAt: createdAt,
    runId: runId,
    toolCallId: toolCallId,
    timeoutMs: timeoutMs,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    exitCode: exitCode ?? this.exitCode,
    signal: signal ?? this.signal,
    error: error ?? this.error,
    stdoutBytes: stdoutBytes ?? this.stdoutBytes,
    stderrBytes: stderrBytes ?? this.stderrBytes,
    notifyOnCompletion: notifyOnCompletion,
    completionDelivery: completionDelivery ?? this.completionDelivery,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'workspace': workspace.toJson(),
    'title': title,
    'command': command,
    'cwd': cwd,
    'runId': runId,
    'toolCallId': toolCallId,
    'timeoutMs': timeoutMs,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'exitCode': exitCode,
    'signal': signal,
    'error': error,
    'stdoutBytes': stdoutBytes,
    'stderrBytes': stderrBytes,
    'notifyOnCompletion': notifyOnCompletion,
    'completionDelivery': completionDelivery.name,
  };

  factory CommandTask.fromJson(Map<String, dynamic> json) => CommandTask(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    workspace: WorkspaceSnapshot.fromJson(
      json['workspace'] as Map<String, dynamic>,
    ),
    title: json['title'] as String,
    command: json['command'] as String,
    cwd: json['cwd'] as String,
    runId: json['runId'] as String?,
    toolCallId: json['toolCallId'] as String?,
    timeoutMs: json['timeoutMs'] as int?,
    status: CommandTaskStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    startedAt: json['startedAt'] == null
        ? null
        : DateTime.parse(json['startedAt'] as String),
    finishedAt: json['finishedAt'] == null
        ? null
        : DateTime.parse(json['finishedAt'] as String),
    exitCode: json['exitCode'] as int?,
    signal: json['signal'] as int?,
    error: json['error'] as String?,
    stdoutBytes: json['stdoutBytes'] as int,
    stderrBytes: json['stderrBytes'] as int,
    // Tasks recorded before completion delivery was introduced stay quiet.
    notifyOnCompletion: json['notifyOnCompletion'] as bool? ?? false,
    completionDelivery: TaskCompletionDelivery.values.byName(
      json['completionDelivery'] as String? ?? 'none',
    ),
  );

  Map<String, dynamic> summary({
    bool fullCommand = false,
    bool includeCommand = true,
  }) => {
    'taskId': id,
    'title': title,
    if (includeCommand)
      'command': fullCommand || command.length <= 240
          ? command
          : '${command.substring(0, 240)}...',
    if (includeCommand)
      'cwd': cwd.length <= 240 ? cwd : '${cwd.substring(0, 240)}...',
    if (includeCommand && cwd.length > 240) 'cwdTruncated': true,
    if (includeCommand && !fullCommand && command.length > 240)
      'commandTruncated': true,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': ?startedAt?.toIso8601String(),
    'finishedAt': ?finishedAt?.toIso8601String(),
    'exitCode': ?exitCode,
    'signal': ?signal,
    'error': ?error,
    'stdoutBytes': stdoutBytes,
    'stderrBytes': stderrBytes,
    'notifyOnCompletion': notifyOnCompletion,
  };
}

class CommandTaskData {
  const CommandTaskData(this.task, this.stdout, this.stderr);
  final CommandTask task;
  final Uint8List stdout;
  final Uint8List stderr;
}
