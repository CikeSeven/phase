import 'dart:convert';

import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_source.dart';
import 'tool_output_limits.dart';

const _defaultPreviewBytes = ToolOutputLimits.maxBytes;
const _omission = '\n…【输出预览已截断】…\n';

/// 原始结果留在工具记录；结果消息与请求使用同一份有界投影。
String toolResultText(ToolCallRecord record, {String? fallback}) {
  final content = record.result ?? fallback ?? toolStatusText(record.status);
  final limit = _previewLimit(record);

  if (record.source?.kind != ToolSourceKind.mcp && record.toolName == 'shell') {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic> &&
          decoded['stdout'] is String &&
          decoded['stderr'] is String) {
        if (utf8.encode(content).length <= limit &&
            _lineCount(decoded['stdout'] as String) +
                    _lineCount(decoded['stderr'] as String) <=
                ToolOutputLimits.maxLines) {
          return content;
        }
        return _commandPreview(record, decoded, limit);
      }
    } on FormatException {
      // 准备或执行失败也可能返回纯文本，不猜测命令结果字段。
    }
  }
  if (utf8.encode(content).length <= limit) return content;

  final preview = <String, dynamic>{
    'sourceId': record.id,
    'toolStatus': record.status.name,
    if (record.errorCode != null) 'toolErrorCode': record.errorCode,
    if (record.artifacts.isNotEmpty) 'artifactIds': record.artifacts,
    'previewTruncated': true,
    'outputPreview': '',
  };
  final available = limit - utf8.encode(jsonEncode(preview)).length;
  preview['outputPreview'] = _textPreview(content, available);
  return jsonEncode(preview);
}

String _commandPreview(
  ToolCallRecord record,
  Map<String, dynamic> content,
  int limit,
) {
  final stdout = content['stdout'] as String;
  final stderr = content['stderr'] as String;
  final preview = <String, dynamic>{
    ...content,
    'stdout': '',
    'stderr': '',
    'sourceId': record.id,
    'toolStatus': record.status.name,
    if (record.errorCode != null) 'toolErrorCode': record.errorCode,
    if (record.artifacts.isNotEmpty) 'artifactIds': record.artifacts,
    'modelPreviewTruncated': true,
  };
  final available = (limit - utf8.encode(jsonEncode(preview)).length).clamp(
    0,
    limit,
  );
  final stdoutBytes = _encodedTextBytes(stdout);
  final stderrBytes = _encodedTextBytes(stderr);
  var stderrBudget = stderrBytes.clamp(0, available ~/ 2);
  final stdoutBudget = stdoutBytes.clamp(0, available - stderrBudget);
  stderrBudget = stderrBytes.clamp(0, available - stdoutBudget);
  var stderrLines = _lineCount(stderr).clamp(0, ToolOutputLimits.maxLines ~/ 2);
  final stdoutLines = _lineCount(stdout)
      .clamp(0, ToolOutputLimits.maxLines - stderrLines);
  stderrLines = _lineCount(stderr)
      .clamp(0, ToolOutputLimits.maxLines - stdoutLines);
  preview['stdout'] = _textPreview(
    truncateToolText(stdout, tail: true, maxLines: stdoutLines).text,
    stdoutBudget,
    tail: true,
  );
  preview['stderr'] = _textPreview(
    truncateToolText(stderr, tail: true, maxLines: stderrLines).text,
    stderrBudget,
    tail: true,
  );
  // 状态、已知效果与产物引用不裁剪；必要事实自身过大时由上下文准入收口。
  return jsonEncode(preview);
}

int _previewLimit(ToolCallRecord record) =>
    const {'task_output', 'task_list'}.contains(record.toolName) ||
        (record.toolName == 'shell' &&
            (record.arguments['background'] == true ||
                record.arguments['yieldMs'] != null))
    ? 256 * 1024
    : const {'read_file', 'list_files'}.contains(record.toolName)
    // A 50 KiB text page can expand sixfold inside a JSON result; keep its cursor.
    ? ToolOutputLimits.maxBytes * 6 + 2 * 1024
    : const {'grep', 'find'}.contains(record.toolName)
    ? ToolOutputLimits.maxBytes + 2 * 1024
    : record.toolName == 'read_memory'
    ? 16 * 1024
    : record.channel == ExecutionChannel.accessibility ||
          record.toolName == 'list_apps'
    ? 64 * 1024
    : _defaultPreviewBytes;

String toolStatusText(ToolCallStatus status) => switch (status) {
  ToolCallStatus.rejected => '用户拒绝了本次动作，没有执行。',
  ToolCallStatus.cancelled => '本次调用已取消，没有取得结果。',
  ToolCallStatus.prepared ||
  ToolCallStatus.awaitingConfirmation ||
  ToolCallStatus.executing => '本次调用没有返回内容。',
  ToolCallStatus.succeeded => '工具执行完成，但没有返回内容。',
  ToolCallStatus.failed => '工具执行失败，没有返回内容。',
};

int _encodedTextBytes(String text) => utf8.encode(jsonEncode(text)).length - 2;

int _lineCount(String text) => text.isEmpty
    ? 0
    : '\n'.allMatches(text).length + (text.endsWith('\n') ? 0 : 1);

/// Count JSON escaping too; commands retain the tail, other results the head.
String _textPreview(String text, int budget, {bool tail = false}) {
  if (budget <= 0) return '';
  if (_encodedTextBytes(text) <= budget) return text;
  if (_encodedTextBytes(_omission) > budget) return '';
  final bytes = utf8.encode(text);
  var lower = 0;
  var upper = bytes.length.clamp(0, budget);
  var result = _omission;
  while (lower <= upper) {
    final size = (lower + upper) ~/ 2;
    var headEnd = size;
    while (headEnd > 0 &&
        headEnd < bytes.length &&
        (bytes[headEnd] & 0xc0) == 0x80) {
      headEnd--;
    }
    var tailStart = bytes.length - size;
    while (tailStart < bytes.length && (bytes[tailStart] & 0xc0) == 0x80) {
      tailStart++;
    }
    final candidate = tail
        ? '$_omission${utf8.decode(bytes.sublist(tailStart))}'
        : '${utf8.decode(bytes.sublist(0, headEnd))}$_omission';
    if (_encodedTextBytes(candidate) <= budget) {
      result = candidate;
      lower = size + 1;
    } else {
      upper = size - 1;
    }
  }
  return result;
}
