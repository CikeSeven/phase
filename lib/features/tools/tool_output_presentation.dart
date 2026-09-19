import 'dart:convert';

import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_source.dart';

/// 只解释已知内置工具的结果封装；原始记录与模型回填内容保持不变。
String presentToolOutput(ToolCallRecord record, String result) {
  final Object? decoded;
  try {
    decoded = jsonDecode(result);
  } on FormatException {
    return result;
  }
  if (record.source?.kind != ToolSourceKind.mcp &&
      decoded is Map<String, dynamic>) {
    switch (record.toolName) {
      case 'shell':
        if (decoded case {
          'stdout': final String out,
          'stderr': final String err,
        }) {
          return [
            if (out.isNotEmpty || err.isNotEmpty)
              '$out${out.isNotEmpty && !out.endsWith('\n') && err.isNotEmpty ? '\n' : ''}$err',
            if (out.isEmpty && err.isEmpty) '（无输出）',
            if (decoded['exitCode'] case final num code when code != 0)
              '退出码：$code',
            if (decoded['signal'] case final num signal) '终止信号：$signal',
            if (decoded['cancelled'] == true) '命令已停止',
            if (decoded['timedOut'] == true) '命令执行超时',
            if (decoded['outputLimitExceeded'] == true) '输出达到上限，进程已停止',
            if (decoded['previewTruncated'] == true)
              record.artifacts.isEmpty ? '输出预览已截断' : '输出预览已截断，完整输出见附件',
            if (decoded['error'] case final String error) error,
          ].join('\n\n');
        }
      case 'read_file':
        if (decoded['text'] case final String content) {
          return _contentWithDetails(content, decoded, const {
            'text',
            'uri',
            'name',
            'mimeType',
            'size',
            'sha256',
          });
        }
      case 'read_skill':
        if (decoded['content'] case final String content) {
          return _contentWithDetails(content, decoded, const {
            'content',
            'skillId',
            'name',
            'revision',
            'source',
            'relativePath',
            'execution',
          });
        }
      case 'prepare_skill':
        if (decoded['guestPath'] case final String path) {
          return _contentWithDetails(path, decoded, const {
            'guestPath',
            'skillId',
            'revision',
            'instruction',
          });
        }
    }
  }
  // 第三方工具和其他结构化结果不猜测字段含义，不丢弃返回值。
  return decoded is Map || decoded is List
      ? const JsonEncoder.withIndent('  ').convert(decoded)
      : result;
}

String _contentWithDetails(
  String content,
  Map<String, dynamic> result,
  Set<String> envelopeKeys,
) => [
  content.isEmpty ? '（空内容）' : content,
  for (final entry in result.entries)
    if (!envelopeKeys.contains(entry.key))
      '${entry.key}: ${toolValueText(entry.value)}',
].join('\n\n');

/// 文本保留实际换行；结构化值保留类型和层级，空字符串与 null 可区分。
String toolValueText(Object? value) => value is String && value.isNotEmpty
    ? value
    : const JsonEncoder.withIndent('  ').convert(value);
