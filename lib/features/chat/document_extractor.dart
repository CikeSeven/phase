import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// 文档文本抽取的结果。
class DocumentText {
  const DocumentText({required this.text, this.truncated = false});

  final String text;

  /// 是否因为体积上限被截断。
  final bool truncated;

  bool get isEmpty => text.trim().isEmpty;
}

/// 文档抽取的失败原因（界面据此给出明确提示）。
class DocumentExtractionException implements Exception {
  const DocumentExtractionException(this.reason);

  /// 面向用户的说明，例如「扫描件需要 OCR」。
  final String reason;

  @override
  String toString() => 'DocumentExtractionException($reason)';
}

/// 本地文档文本抽取：PDF 用 PDF 解析库，DOCX 读 ZIP 内的 document.xml。
///
/// 抽取不改变原始文件：结果单独存成文本文件，由附件记录引用。
class DocumentExtractor {
  const DocumentExtractor();

  /// 抽取文本的最大字符数；超出按上限截断并标记。
  static const maxCharacters = 200000;

  /// 该扩展名是否由本抽取器处理。
  static bool supports(String extension) {
    final normalized = extension.toLowerCase();
    return normalized == 'pdf' || normalized == 'docx';
  }

  Future<DocumentText> extract({
    required String path,
    required String extension,
  }) async {
    final bytes = await _readBytes(path);
    if (bytes == null) {
      throw const DocumentExtractionException('文件不可读或已丢失');
    }
    final text = switch (extension.toLowerCase()) {
      'pdf' => _extractPdf(bytes),
      'docx' => _extractDocx(bytes),
      final other => throw DocumentExtractionException('暂不支持的文件类型：$other'),
    };
    if (text.trim().isEmpty) {
      // 扫描件或纯图片文档：明确说明需要 OCR，不把空文本当作已读取。
      throw const DocumentExtractionException('没有可提取的文字（扫描件需要 OCR）');
    }
    final truncated = text.length > maxCharacters;
    return DocumentText(
      text: truncated ? text.substring(0, maxCharacters) : text,
      truncated: truncated,
    );
  }

  Future<Uint8List?> _readBytes(String path) async {
    try {
      return await File(path).readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  /// PDF：逐页取文本，页与页之间用换行分隔。
  String _extractPdf(Uint8List bytes) {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      return extractor.extractText();
    } on DocumentExtractionException {
      rethrow;
    } on Exception catch (e) {
      throw DocumentExtractionException('PDF 解析失败：${_brief(e)}');
    } finally {
      document?.dispose();
    }
  }

  /// DOCX：解压读 word/document.xml，按段落/表格顺序取文字。
  String _extractDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final entry = archive.files.firstWhere(
        (file) => file.name == 'word/document.xml',
        orElse: () => throw const DocumentExtractionException(
          '不是有效的 DOCX：缺少 word/document.xml',
        ),
      );
      final xml = utf8.decode(entry.content);
      return _docxText(xml);
    } on DocumentExtractionException {
      rethrow;
    } on Exception catch (e) {
      throw DocumentExtractionException('DOCX 解析失败：${_brief(e)}');
    }
  }

  /// 按文档顺序读 w:p（段落）与 w:tab/w:br（制表与换行），其余标签忽略。
  ///
  /// 表格单元格里的段落同样是 w:p，因此文字顺序与阅读顺序一致。
  String _docxText(String xml) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < xml.length) {
      final open = xml.indexOf('<', index);
      if (open < 0) break;
      final close = xml.indexOf('>', open);
      if (close < 0) break;
      final tag = xml.substring(open + 1, close);
      index = close + 1;

      if (tag == 'w:t' || tag.startsWith('w:t ') || tag.startsWith('w:t/')) {
        if (tag.endsWith('/')) continue;
        final end = xml.indexOf('</w:t>', index);
        if (end < 0) break;
        buffer.write(_unescape(xml.substring(index, end)));
        index = end + '</w:t>'.length;
      } else if (tag == 'w:tab' || tag.startsWith('w:tab ')) {
        buffer.write('\t');
      } else if (tag == 'w:br' || tag.startsWith('w:br ')) {
        buffer.write('\n');
      } else if (tag == '/w:p') {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }

  String _unescape(String value) => value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  /// 解析库的异常可能很长：只留开头，避免把原文塞进用户提示。
  String _brief(Object error) {
    final message = '$error';
    return message.length > 120 ? '${message.substring(0, 120)}…' : message;
  }
}
