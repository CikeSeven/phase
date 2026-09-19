import 'dart:convert';
import 'dart:io';

import 'tool.dart';

const maxFileReadBytes = 16 * 1024;
const maxFileReadLines = 2000;
const maxFileWriteBytes = 2 * 1024 * 1024;

class FileToolException implements Exception {
  const FileToolException(this.code, this.message);
  final String code;
  final String message;
}

String? validateFileRead(Map<String, dynamic> arguments) {
  for (final key in ['offset', 'limit']) {
    final value = arguments[key];
    if (value != null && (value is! int || value < 1)) {
      return '$key 必须是从 1 开始的整数';
    }
  }
  return null;
}

class FileTextPage {
  const FileTextPage(this.text, this.startLine, this.lineCount, this.hasMore);
  final String text;
  final int startLine;
  final int lineCount;
  final bool hasMore;
  int get endLine => startLine + lineCount - 1;
  Map<String, Object?> toJson() => {
    'text': text,
    'startLine': startLine,
    'endLine': endLine,
    'truncated': hasMore,
    if (hasMore) 'nextOffset': endLine + 1,
  };
  String render() =>
      '$text\n\n[第 $startLine–$endLine 行；'
      '${hasMore ? '继续读取：offset=${endLine + 1}' : '已到结尾'}]';
}

/// 按字节流扫描，跳过的行和超长行不积存在内存中；只返回完整 UTF-8 行。
Future<FileTextPage> readFilePage(
  File file,
  Map<String, dynamic> arguments,
  RunCancellation cancellation,
) async {
  final invalid = validateFileRead(arguments);
  if (invalid != null) throw ToolArgumentException('read_file', invalid);
  final offset = arguments['offset'] as int? ?? 1;
  final limit = (arguments['limit'] as int? ?? maxFileReadLines).clamp(
    1,
    maxFileReadLines,
  );
  final lines = <String>[];
  final buffer = <int>[];
  var line = 1;
  var used = 0;
  FileTextPage page(bool more) =>
      FileTextPage(lines.join('\n'), offset, lines.length, more);
  bool addLine() {
    if (line < offset) return true;
    if (lines.length == limit ||
        used + buffer.length + (lines.isEmpty ? 0 : 1) > maxFileReadBytes) {
      return false;
    }
    final text = utf8.decode(buffer);
    if (text.contains('\u0000')) {
      throw const FileToolException('notText', '文件包含二进制内容，不能作为 UTF-8 文本读取');
    }
    used += buffer.length + (lines.isEmpty ? 0 : 1);
    lines.add(text.endsWith('\r') ? text.substring(0, text.length - 1) : text);
    buffer.clear();
    return true;
  }

  cancellation.throwIfCancelled();
  await for (final chunk in file.openRead()) {
    cancellation.throwIfCancelled();
    for (final byte in chunk) {
      if (byte == 10) {
        if (!addLine()) return page(true);
        line++;
      } else if (line >= offset) {
        if (lines.length == limit) return page(true);
        if (used + buffer.length + 1 + (lines.isEmpty ? 0 : 1) >
            maxFileReadBytes) {
          if (lines.isNotEmpty) return page(true);
          throw FileToolException(
            'lineTooLong',
            '第 $line 行超过 ${maxFileReadBytes ~/ 1024} KiB，无法按完整行返回；'
                '请通过工作区 shell 提取该行的片段。',
          );
        }
        buffer.add(byte);
      }
    }
  }
  cancellation.throwIfCancelled();
  if (line < offset) {
    throw FileToolException(
      'offsetOutOfRange',
      'offset=$offset 超过文件结尾（共 $line 行）',
    );
  }
  if (!addLine()) return page(true);
  return page(false);
}

String? validateFileEdits(Map<String, dynamic> arguments) {
  final edits = arguments['edits'];
  if (edits is! List || edits.isEmpty) return 'edits 必须包含至少一处替换';
  for (final edit in edits) {
    if (edit is! Map ||
        edit['oldText'] is! String ||
        (edit['oldText'] as String).isEmpty ||
        edit['newText'] is! String ||
        edit.keys.any((key) => key != 'oldText' && key != 'newText')) {
      return '每处替换必须包含非空 oldText 和字符串 newText（允许为空以删除内容）';
    }
  }
  return null;
}

/// 所有替换匹配原文，整体校验后才生成结果，不让前一处替换影响后一处匹配。
String applyFileEdits(String original, Map<String, dynamic> arguments) {
  final invalid = validateFileEdits(arguments);
  if (invalid != null) throw ToolArgumentException('edit_file', invalid);
  final bom = original.startsWith('\ufeff') ? '\ufeff' : '';
  final body = original.substring(bom.length);
  final crlf =
      body.contains('\r\n') && !body.replaceAll('\r\n', '').contains('\n');
  final text = body.replaceAll('\r\n', '\n');
  final replacements = <({int start, int end, String text})>[];
  for (final (index, edit) in (arguments['edits'] as List).indexed) {
    final oldText = (edit['oldText'] as String).replaceAll('\r\n', '\n');
    final newText = (edit['newText'] as String).replaceAll('\r\n', '\n');
    final start = text.indexOf(oldText);
    if (start < 0) {
      throw FileToolException(
        'textNotFound',
        '第 ${index + 1} 处 oldText 未匹配；请先 read_file 获取当前原文',
      );
    }
    if (text.indexOf(oldText, start + 1) >= 0) {
      throw FileToolException(
        'ambiguousEdit',
        '第 ${index + 1} 处 oldText 不唯一；请加入相邻原文以唯一定位',
      );
    }
    replacements.add((
      start: start,
      end: start + oldText.length,
      text: newText,
    ));
  }
  replacements.sort((a, b) => a.start.compareTo(b.start));
  final output = StringBuffer();
  var cursor = 0;
  for (final edit in replacements) {
    if (edit.start < cursor) {
      throw const FileToolException(
        'overlappingEdits',
        'edits 中的原文区域重叠；请合并为一处替换',
      );
    }
    output.write(text.substring(cursor, edit.start));
    output.write(edit.text);
    cursor = edit.end;
  }
  output.write(text.substring(cursor));
  final result = output.toString();
  return '$bom${crlf ? result.replaceAll('\n', '\r\n') : result}';
}

Future<String> readEditableText(File file) async {
  final bytes = await file.readAsBytes();
  final text = utf8.decode(bytes);
  // Dart 的 UTF-8 解码会移除 BOM；编辑时显式保留它。
  return bytes.length >= 3 &&
          bytes[0] == 0xef &&
          bytes[1] == 0xbb &&
          bytes[2] == 0xbf
      ? '\ufeff$text'
      : text;
}
