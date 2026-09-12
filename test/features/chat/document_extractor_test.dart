import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/features/chat/document_extractor.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// 文档抽取：PDF 用真实生成的 PDF，DOCX 用真实 ZIP 结构。
void main() {
  const extractor = DocumentExtractor();
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('phase_extract');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<String> write(String name, List<int> bytes) async {
    final file = File(p.join(temp.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// 生成一份含文字的 PDF（用 PDF 库自己生成，避免脆弱的二进制夹具）。
  List<int> buildPdf(String text) {
    final document = PdfDocument();
    document.pages.add().graphics.drawString(
      text,
      PdfStandardFont(PdfFontFamily.helvetica, 14),
    );
    final bytes = document.saveSync();
    document.dispose();
    return bytes;
  }

  /// 生成一份最小 DOCX：ZIP 里放 word/document.xml。
  List<int> buildDocx(String xmlBody) {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'word/document.xml',
          '<?xml version="1.0" encoding="UTF-8"?>'
              '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
              '<w:body>$xmlBody</w:body></w:document>',
        ),
      );
    return ZipEncoder().encode(archive);
  }

  test('PDF：抽取正文文字', () async {
    final path = await write('sample.pdf', buildPdf('Hello PDF extraction'));
    final result = await extractor.extract(path: path, extension: 'pdf');
    expect(result.text, contains('Hello PDF extraction'));
    expect(result.truncated, isFalse);
  });

  test('DOCX：按段落顺序取文字，保留制表与换行', () async {
    final path = await write(
      'sample.docx',
      buildDocx(
        '<w:p><w:r><w:t>第一段</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>第二段</w:t></w:r><w:r><w:tab/><w:t>制表后</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>结论</w:t></w:r><w:r><w:br/><w:t>换行内</w:t></w:r></w:p>',
      ),
    );
    final result = await extractor.extract(path: path, extension: 'docx');

    expect(result.text.indexOf('第一段'), lessThan(result.text.indexOf('第二段')));
    expect(result.text.indexOf('第二段'), lessThan(result.text.indexOf('结论')));
    expect(result.text, contains('制表后'));
    expect(result.text, contains('换行内'));
    // 段落之间保留换行。
    expect(
      result.text.split('\n').where((line) => line.trim().isNotEmpty),
      hasLength(3),
    );
  });

  test('DOCX：转义字符按原文还原', () async {
    final path = await write(
      'escape.docx',
      buildDocx(
        '<w:p><w:r><w:t>a &lt; b &amp;&amp; c &gt; d</w:t></w:r></w:p>',
      ),
    );
    final result = await extractor.extract(path: path, extension: 'docx');
    expect(result.text.trim(), 'a < b && c > d');
  });

  test('没有可提取文字时明确报错（扫描件需要 OCR）', () async {
    final path = await write(
      'empty.docx',
      buildDocx('<w:p><w:r><w:t></w:t></w:r></w:p>'),
    );
    await expectLater(
      extractor.extract(path: path, extension: 'docx'),
      throwsA(
        isA<DocumentExtractionException>().having(
          (error) => error.reason,
          'reason',
          contains('OCR'),
        ),
      ),
    );
  });

  test('文件不是有效文档时给出解析失败原因', () async {
    final path = await write('broken.docx', Uint8List.fromList([1, 2, 3, 4]));
    await expectLater(
      extractor.extract(path: path, extension: 'docx'),
      throwsA(isA<DocumentExtractionException>()),
    );
  });

  test('文件缺失时报「不可读」，不抛裸异常', () async {
    await expectLater(
      extractor.extract(
        path: p.join(temp.path, 'missing.pdf'),
        extension: 'pdf',
      ),
      throwsA(
        isA<DocumentExtractionException>().having(
          (error) => error.reason,
          'reason',
          contains('不可读'),
        ),
      ),
    );
  });

  test('超长文本按上限截断并标记', () async {
    // 生成超过上限的正文（上限见 DocumentExtractor.maxCharacters）。
    final long = '这是一段很长的正文。' * 25000;
    final path = await write(
      'long.docx',
      buildDocx('<w:p><w:r><w:t>$long</w:t></w:r></w:p>'),
    );
    final result = await extractor.extract(path: path, extension: 'docx');

    expect(result.truncated, isTrue);
    expect(result.text.length, DocumentExtractor.maxCharacters);
  });

  test('支持的扩展名判定只看 PDF/DOCX', () {
    expect(DocumentExtractor.supports('pdf'), isTrue);
    expect(DocumentExtractor.supports('DOCX'), isTrue);
    expect(DocumentExtractor.supports('txt'), isFalse);
    expect(DocumentExtractor.supports('png'), isFalse);
  });
}
