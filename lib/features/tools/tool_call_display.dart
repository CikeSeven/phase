import 'dart:convert';

import '../../../data/models/attachment.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_source.dart';
import 'application_tool_display.dart';
import 'tool_diff.dart';
import 'tool_presentation.dart';

/// 各工具按自身语义展示调用，不把内置工具渲染成参数表单。
class ToolCallDisplay {
  const ToolCallDisplay({
    this.call,
    this.metadata,
    this.diff,
    this.output,
    this.copyText,
    this.copyLabel = '复制调用',
    this.showScreenshots = false,
  });

  final String? call;
  final String? metadata;
  final List<ToolDiffLine>? diff;
  final String? output;
  final String? copyText;
  final String copyLabel;
  final bool showScreenshots;

  static bool isBuiltIn(ToolCallRecord record) =>
      record.source?.kind != ToolSourceKind.mcp;

  static String title(ToolCallRecord record) =>
      ApplicationToolDisplay.supports(record)
      ? ApplicationToolDisplay(record).title ??
            ToolPresentation.recordLabel(record)
      : ToolPresentation.recordLabel(record);

  static String? detail(ToolCallRecord record, {String? appName}) {
    if (!isBuiltIn(record)) return null;
    if (ApplicationToolDisplay.supports(record)) {
      return record.toolName == 'list_apps'
          ? null
          : appName ??
                (record.toolName == 'capture_screen' && record.result == null
                    ? '当前应用'
                    : '应用名称不可用');
    }
    final args = record.arguments;
    return switch (record.toolName) {
      'shell' => args['command'] is String ? '\$ ${args['command']}' : null,
      'write_file' ||
      'edit_file' ||
      'read_file' => args['path'] is String ? args['path'] as String : null,
      'list_files' => args['path'] is String ? args['path'] as String : '.',
      'read_skill' =>
        '${args['skillId']} / ${args['relativePath'] ?? 'SKILL.md'}',
      'prepare_skill' =>
        args['skillId'] is String ? args['skillId'] as String : null,
      'http_request' => '${args['method'] ?? 'GET'} ${args['url'] ?? ''}',
      _ => null,
    };
  }

  factory ToolCallDisplay.fromRecord(ToolCallRecord record) {
    final args = record.arguments;
    if (ApplicationToolDisplay.supports(record)) {
      final app = ApplicationToolDisplay(record);
      return ToolCallDisplay(
        call: app.call,
        output: app.output(
          record.result ?? ToolPresentation.outputText(record),
        ),
        showScreenshots: app.showScreenshots,
      );
    }
    final output = ToolPresentation.outputText(record);
    if (isBuiltIn(record)) {
      switch (record.toolName) {
        case 'shell':
          if (args['command'] case final String command) {
            final metadata = [
              if (args['cwd'] case final String cwd when cwd != '/workspace')
                cwd,
              if (args['timeoutMs'] case final num ms when ms != 60000)
                '超时 ${ms / 1000} 秒',
            ];
            return ToolCallDisplay(
              call: '\$ $command',
              metadata: metadata.isEmpty ? null : metadata.join(' · '),
              copyText: command,
              copyLabel: '复制命令',
              output: output,
            );
          }
        case 'write_file':
          if (args['content'] case final String content) {
            return ToolCallDisplay(
              diff: toolWriteDiff(content),
              copyText: content,
              copyLabel: '复制文件内容',
              output: _writeNotice(record, output),
            );
          }
        case 'edit_file':
          if (args['edits'] case final List edits when edits.isNotEmpty) {
            if (edits.every(
              (edit) =>
                  edit is Map<String, dynamic> &&
                  edit['oldText'] is String &&
                  edit['newText'] is String,
            )) {
              final diff = toolEditDiff(edits.cast<Map<String, dynamic>>());
              return ToolCallDisplay(
                diff: diff,
                copyText: diff.map((line) => line.display).join('\n'),
                copyLabel: '复制差异',
                output: _writeNotice(record, output),
              );
            }
          }
        case 'read_file':
        case 'list_files':
          return ToolCallDisplay(
            metadata: [
              if (args['offset'] != null) '起始位置 ${args['offset']}',
              if (args['limit'] != null) '最多 ${args['limit']} 项',
            ].where((s) => s.isNotEmpty).join(' · '),
            output: output,
          );
        case 'read_skill':
        case 'prepare_skill':
          return ToolCallDisplay(output: output);
        case 'http_request':
          final body = args['body'];
          return ToolCallDisplay(
            call: [
              if (args['headers'] case final Map headers)
                for (final entry in headers.entries)
                  '${entry.key}: ${entry.value}',
              if (body is String && body.isNotEmpty) body,
            ].join('\n'),
            output: output,
          );
      }
    }
    return ToolCallDisplay(
      call: args.isEmpty
          ? null
          : const JsonEncoder.withIndent('  ').convert(args),
      output: output,
    );
  }

  static String? _writeNotice(ToolCallRecord record, String output) {
    if (record.status != ToolCallStatus.succeeded) {
      return ToolPresentation.isInFlight(record.status) ? null : output;
    }
    final raw = record.result;
    if (raw == null || raw.isEmpty) return null;
    try {
      if (jsonDecode(raw) case final Map result) {
        final notices = [
          for (final key in ['warning', 'reason', 'error', 'extractionError'])
            if (result[key] case final String notice) notice,
        ];
        return notices.isEmpty ? null : notices.join('\n');
      }
    } on FormatException {
      // 本地文件成功回执是文本；警告和失败仍保留原文。
    }
    return raw.startsWith('已写入「') || raw.startsWith('已替换 ') ? null : output;
  }

  /// 已完整显示的命令日志不再重复列成文件，用户生成的产物仍保留。
  static String? artifactLabel(ToolCallRecord record, Attachment artifact) {
    if (isBuiltIn(record) && record.toolName == 'shell') {
      for (final stream in ['stdout', 'stderr']) {
        if (artifact.name != '${record.id}-$stream.txt') continue;
        try {
          if (jsonDecode(record.result ?? '') case final Map result) {
            if (result[stream] case final String text) {
              // UTF-8 在预览边界被截开时，替换字符可能比原字节更长。
              // 明确截断的日志不能靠重编码长度判断为已完整展示。
              if (result['previewTruncated'] != true &&
                  artifact.size <= utf8.encode(text).length) {
                return null;
              }
              return stream == 'stdout' ? '完整命令输出' : '完整错误输出';
            }
          }
        } on FormatException {
          // 不根据文件名隐藏未识别的结果。
        }
      }
    }
    return artifact.name;
  }
}
