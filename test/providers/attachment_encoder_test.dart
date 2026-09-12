import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/openai_compat.dart';
import 'package:phase/providers/anthropic_messages/anthropic_decoder.dart';
import 'package:phase/providers/attachment_encoder.dart';
import 'package:phase/providers/google_generative_ai/google_decoder.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';
import 'package:phase/providers/openai_responses/responses_decoder.dart';

void main() {
  late Directory temp;
  late Attachment image;
  late Attachment doc;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('phase-encoder');
    File('${temp.path}/a.png').writeAsBytesSync([137, 80, 78, 71]);
    File('${temp.path}/note.md').writeAsStringSync('# 标题\n正文');
    File('${temp.path}/note.extracted.txt').writeAsStringSync('# 标题\n正文');
    image = _attachment(
      id: 'a',
      kind: AttachmentKind.image,
      name: 'a.png',
      mimeType: 'image/png',
      path: '${temp.path}/a.png',
    );
    doc = _attachment(
      id: 'd',
      kind: AttachmentKind.text,
      name: 'note.md',
      mimeType: 'text/markdown',
      path: '${temp.path}/note.md',
      extractedTextPath: '${temp.path}/note.extracted.txt',
    );
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('encodeAttachment', () {
    test('图片编码为无前缀 base64，文档内联抽取文本并带文件名头', () async {
      final encoder = RequestAttachmentEncoder(supportsImages: true);
      final encodedImage = await encoder.encode(image);
      final encodedDoc = await encoder.encode(doc);
      expect(encodedImage.base64Data, base64Encode([137, 80, 78, 71]));
      expect(encodedImage.isImage, isTrue);
      expect(
        encodedImage.dataUri,
        'data:image/png;base64,${base64Encode([137, 80, 78, 71])}',
      );
      expect(encodedDoc.text, '<附件 name="note.md">\n# 标题\n正文\n</附件>');
    });

    test('同一个附件在一次请求构建内只读一次', () async {
      final encoder = RequestAttachmentEncoder(supportsImages: true);
      final first = await encoder.encode(image);
      final second = await encoder.encode(image);
      expect(identical(first, second), isTrue);
    });

    test('模型不支持图片时降级为占位文本', () async {
      final encoded = await RequestAttachmentEncoder(supportsImages: false)
          .encode(image);
      expect(encoded.isImage, isFalse);
      expect(encoded.text, contains('不支持图片'));
    });

    test('附件文件丢失降级为占位文本而不中断', () async {
      temp.deleteSync(recursive: true);
      final encoder = RequestAttachmentEncoder(supportsImages: true);
      expect((await encoder.encode(image)).text, contains('已丢失'));
      expect((await encoder.encode(doc)).text, contains('已丢失'));
    });
  });

  group('四协议附件报文', () {
    // request 引用 setUp 里初始化的附件，必须惰性求值。
    ChatRequest request() => ChatRequest(
      modelId: 'm',
      messages: [
        ResolvedMessage(
          role: ChatRole.user,
          parts: [
            const ResolvedText('描述这张图'),
            ResolvedImage(image),
            ResolvedImage(doc),
          ],
        ),
      ],
    );

    test('OpenAI Completions：content 数组含 text/image_url', () async {
      final payload = await buildCompletionsPayload(
        request(),
        compat: const OpenAiCompat(),
      );
      final content = (payload['messages'] as List).single['content'] as List;
      expect(content[0], {'type': 'text', 'text': '描述这张图'});
      expect(content[1]['type'], 'image_url');
      expect(
        content[1]['image_url']['url'],
        startsWith('data:image/png;base64,'),
      );
      expect(content[2], {
        'type': 'text',
        'text': '<附件 name="note.md">\n# 标题\n正文\n</附件>',
      });
    });

    test('OpenAI Responses：input_image', () async {
      final payload = await buildResponsesPayload(request());
      final content = (payload['input'] as List).single['content'] as List;
      expect(content[0], {'type': 'input_text', 'text': '描述这张图'});
      expect(content[1], {
        'type': 'input_image',
        'image_url': 'data:image/png;base64,${base64Encode([137, 80, 78, 71])}',
      });
      expect(content[2], {
        'type': 'input_text',
        'text': '<附件 name="note.md">\n# 标题\n正文\n</附件>',
      });
    });

    test('Anthropic：image source base64', () async {
      final payload = await buildAnthropicPayload(request());
      final content = (payload['messages'] as List).single['content'] as List;
      expect(content[0], {'type': 'text', 'text': '描述这张图'});
      expect(content[1], {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': 'image/png',
          'data': base64Encode([137, 80, 78, 71]),
        },
      });
      expect(content[2], {
        'type': 'text',
        'text': '<附件 name="note.md">\n# 标题\n正文\n</附件>',
      });
    });

    test('Google：inline_data', () async {
      final payload = await buildGooglePayload(request());
      final parts = (payload['contents'] as List).single['parts'] as List;
      expect(parts[0], {'text': '描述这张图'});
      expect(parts[1], {
        'inline_data': {
          'mime_type': 'image/png',
          'data': base64Encode([137, 80, 78, 71]),
        },
      });
      expect(parts[2], {'text': '<附件 name="note.md">\n# 标题\n正文\n</附件>'});
    });

    test('模型不支持图片时按占位文本下发', () async {
      final payload = await buildCompletionsPayload(
        request(),
        compat: const OpenAiCompat(),
        supportsImages: false,
      );
      final content = (payload['messages'] as List).single['content'];
      // 降级后没有图片块，正文保持纯文本快路径。
      expect(content, isA<String>());
      expect(content, contains('描述这张图'));
      expect(content, contains('不支持图片'));
    });

    test('无附件时保持纯文本快路径（content 仍是字符串）', () async {
      final plain = ChatRequest(
        modelId: 'm',
        messages: const [
          ResolvedMessage(role: ChatRole.user, parts: [ResolvedText('描述这张图')]),
        ],
      );
      final payload = await buildCompletionsPayload(
        plain,
        compat: const OpenAiCompat(),
      );
      expect((payload['messages'] as List).single['content'], '描述这张图');
      final responses = await buildResponsesPayload(plain);
      expect((responses['input'] as List).single['content'], [
        {'type': 'input_text', 'text': '描述这张图'},
      ]);
    });
  });
}

Attachment _attachment({
  required String id,
  required AttachmentKind kind,
  required String name,
  required String mimeType,
  required String path,
  String? extractedTextPath,
}) {
  return Attachment(
    id: id,
    conversationId: 'c1',
    kind: kind,
    name: name,
    mimeType: mimeType,
    size: 4,
    localPath: path,
    extractedTextPath: extractedTextPath,
    createdAt: DateTime(2026),
  );
}
