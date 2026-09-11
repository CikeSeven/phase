import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/providers/anthropic_messages/anthropic_decoder.dart';
import 'package:phase/providers/attachment_encoder.dart';
import 'package:phase/providers/google_generative_ai/google_decoder.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';
import 'package:phase/data/models/openai_compat.dart';
import 'package:phase/providers/openai_responses/responses_decoder.dart';

void main() {
  late Directory temp;
  late ChatAttachment image;
  late ChatAttachment doc;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('phase-encoder');
    File('${temp.path}/a.png').writeAsBytesSync([137, 80, 78, 71]);
    File('${temp.path}/note.md').writeAsStringSync('# 标题\n正文');
    image = ChatAttachment(
      id: 'a',
      type: ChatAttachmentType.image,
      name: 'a.png',
      mimeType: 'image/png',
      path: '${temp.path}/a.png',
      size: 4,
    );
    doc = ChatAttachment(
      id: 'd',
      type: ChatAttachmentType.file,
      name: 'note.md',
      mimeType: 'text/markdown',
      path: '${temp.path}/note.md',
      size: 8,
    );
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('encodeAttachments', () {
    test('图片编码为无前缀 base64，文本文件内联并带文件名头', () async {
      final payloads = await encodeAttachments([
        image,
        doc,
      ], supportsImages: true);
      expect(payloads[0].base64Data, base64Encode([137, 80, 78, 71]));
      expect(payloads[0].isImage, isTrue);
      expect(payloads[1].text, '<附件 name="note.md">\n# 标题\n正文\n</附件>');
    });

    test('模型不支持图片时降级为占位文本', () async {
      final payloads = await encodeAttachments([image], supportsImages: false);
      expect(payloads.single.isImage, isFalse);
      expect(payloads.single.text, contains('不支持图片'));
    });

    test('附件文件丢失降级为占位文本而不中断', () async {
      temp.deleteSync(recursive: true);
      final payloads = await encodeAttachments([
        image,
        doc,
      ], supportsImages: true);
      expect(payloads[0].text, contains('已丢失'));
      expect(payloads[1].text, contains('已丢失'));
    });
  });

  group('四协议附件报文', () {
    // request 引用 setUp 里初始化的附件，必须惰性求值。
    ChatRequest request() => ChatRequest(
      model: 'm',
      messages: [
        ChatMessage(
          role: ChatRole.user,
          content: '描述这张图',
          attachments: [image, doc],
        ),
      ],
    );

    late List<AttachmentPayload> payloads;
    setUp(() async {
      payloads = await encodeAttachments([image, doc], supportsImages: true);
    });

    test('OpenAI Completions：content 数组含 text/image_url', () {
      final payload = buildCompletionsPayload(
        request: request(),
        compat: const OpenAiCompat(),
        attachments: [payloads],
      );
      final content = (payload['messages'] as List).single['content'] as List;
      expect(content[0], {'type': 'text', 'text': '描述这张图'});
      expect(content[1], {
        'type': 'image_url',
        'image_url': {'url': 'data:image/png;base64,${payloads[0].base64Data}'},
      });
      expect(content[2], {'type': 'text', 'text': payloads[1].text});
    });

    test('OpenAI Responses：input_image', () {
      final payload = buildResponsesPayload(request(), attachments: [payloads]);
      final content = (payload['input'] as List).single['content'] as List;
      expect(content[0], {'type': 'input_text', 'text': '描述这张图'});
      expect(content[1], {
        'type': 'input_image',
        'image_url': 'data:image/png;base64,${payloads[0].base64Data}',
      });
      expect(content[2], {'type': 'input_text', 'text': payloads[1].text});
    });

    test('Anthropic：image source base64', () {
      final payload = buildAnthropicPayload(request(), attachments: [payloads]);
      final content = (payload['messages'] as List).single['content'] as List;
      expect(content[0], {'type': 'text', 'text': '描述这张图'});
      expect(content[1], {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': 'image/png',
          'data': payloads[0].base64Data,
        },
      });
      expect(content[2], {'type': 'text', 'text': payloads[1].text});
    });

    test('Google：inline_data', () {
      final payload = buildGooglePayload(request(), attachments: [payloads]);
      final parts = (payload['contents'] as List).single['parts'] as List;
      expect(parts[0], {'text': '描述这张图'});
      expect(parts[1], {
        'inline_data': {
          'mime_type': 'image/png',
          'data': payloads[0].base64Data,
        },
      });
      expect(parts[2], {'text': payloads[1].text});
    });

    test('无附件时保持纯文本快路径（content 仍是字符串）', () {
      final payload = buildCompletionsPayload(
        request: request(),
        compat: const OpenAiCompat(),
      );
      expect((payload['messages'] as List).single['content'], '描述这张图');
      final responses = buildResponsesPayload(request());
      expect((responses['input'] as List).single['content'], [
        {'type': 'input_text', 'text': '描述这张图'},
      ]);
    });
  });
}
