import 'dart:convert';

import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_source.dart';

const _defaultPreviewBytes = 8 * 1024;
const _omission = '\n…【输出预览已截断】…\n';

/// 原始结果留在工具记录；结果消息与请求使用同一份有界投影。
String toolResultText(ToolCallRecord record, {String? fallback}) {
  final content = record.result ?? fallback ?? toolStatusText(record.status);
  final limit = _previewLimit(record);
  if (utf8.encode(content).length <= limit) return content;

  if (record.source?.kind != ToolSourceKind.mcp &&
      const {'shell', 'termux_shell'}.contains(record.toolName)) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic> &&
          decoded['stdout'] is String &&
          decoded['stderr'] is String) {
        return _commandPreview(record, decoded, limit);
      }
    } on FormatException {
      // 准备或执行失败也可能返回纯文本，不猜测命令结果字段。
    }
  }

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
  preview['stdout'] = _textPreview(stdout, stdoutBudget);
  preview['stderr'] = _textPreview(stderr, stderrBudget);
  // 状态、已知效果与产物引用不裁剪；必要事实自身过大时由上下文准入收口。
  return jsonEncode(preview);
}

int _previewLimit(ToolCallRecord record) =>
    const {'read_file', 'list_files'}.contains(record.toolName)
    ? 128 * 1024
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

/// 按最终 JSON 转义后的字节预算保留首尾，不切开 UTF-8 字符。
String _textPreview(String text, int budget) {
  if (budget <= 0) return '';
  if (_encodedTextBytes(text) <= budget) return text;
  if (_encodedTextBytes(_omission) > budget) return '';
  final bytes = utf8.encode(text);
  var lower = 0;
  var upper = bytes.length.clamp(0, budget);
  var result = _omission;
  while (lower <= upper) {
    final size = (lower + upper) ~/ 2;
    final headSize = size ~/ 2;
    var headEnd = headSize;
    while (headEnd > 0 && (bytes[headEnd] & 0xc0) == 0x80) {
      headEnd--;
    }
    var tailStart = bytes.length - (size - headSize);
    while (tailStart < bytes.length && (bytes[tailStart] & 0xc0) == 0x80) {
      tailStart++;
    }
    final candidate =
        '${utf8.decode(bytes.sublist(0, headEnd))}'
        '$_omission${utf8.decode(bytes.sublist(tailStart))}';
    if (_encodedTextBytes(candidate) <= budget) {
      result = candidate;
      lower = size + 1;
    } else {
      upper = size - 1;
    }
  }
  return result;
}
