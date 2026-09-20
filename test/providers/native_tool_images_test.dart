import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/providers/anthropic_messages/anthropic_decoder.dart';
import 'package:phase/providers/google_generative_ai/google_decoder.dart';

void main() {
  late Directory temp;
  late Attachment screenshot;
  late Attachment otherImage;
  late String screenshotData;
  late String otherData;
  const metadata = '{"imageWidth":1,"imageHeight":1}';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('phase-native-tool-images-');
    Future<Attachment> saveImage(String id, int red, int green) async {
      final bytes = img.encodePng(
        img.Image(width: 1, height: 1)..setPixelRgb(0, 0, red, green, 0),
      );
      final file = await File('${temp.path}/$id.png').writeAsBytes(bytes);
      return Attachment(
        id: id,
        kind: AttachmentKind.artifact,
        name: '$id.png',
        mimeType: 'image/png',
        size: bytes.length,
        localPath: file.path,
        createdAt: DateTime(2026),
      );
    }

    screenshot = await saveImage('screen', 255, 0);
    otherImage = await saveImage('other', 0, 255);
    screenshotData = base64Encode(
      await File(screenshot.localPath).readAsBytes(),
    );
    otherData = base64Encode(await File(otherImage.localPath).readAsBytes());
  });
  tearDown(() async => temp.delete(recursive: true));

  ChatRequest request({
    String modelId = 'gemini-3-pro-preview',
    bool isError = false,
    List<Attachment>? images,
    List<ResolvedMessage> trailingMessages = const [],
  }) => ChatRequest(
    modelId: modelId,
    messages: [
      const ResolvedMessage(
        role: ChatRole.user,
        parts: [ResolvedText('查看工具返回的图片')],
      ),
      const ResolvedMessage(
        role: ChatRole.assistant,
        parts: [
          ResolvedToolCall(
            callId: 'capture',
            toolName: 'capture_screen',
            arguments: {},
          ),
          ResolvedToolCall(
            callId: 'info',
            toolName: 'system_info',
            arguments: {},
          ),
          ResolvedToolCall(
            callId: 'mcp',
            toolName: 'mcp_images',
            arguments: {},
          ),
        ],
      ),
      ResolvedMessage(
        role: ChatRole.tool,
        parts: [
          ResolvedToolResult(
            callId: 'capture',
            content: metadata,
            images: images ?? [screenshot],
            isError: isError,
          ),
        ],
      ),
      const ResolvedMessage(
        role: ChatRole.tool,
        parts: [ResolvedToolResult(callId: 'info', content: 'Android')],
      ),
      ResolvedMessage(
        role: ChatRole.tool,
        parts: [
          ResolvedToolResult(
            callId: 'mcp',
            content: '两个图片产物',
            images: [otherImage, screenshot],
          ),
        ],
      ),
      ...trailingMessages,
    ],
  );

  Map<String, Object> anthropicImage(String data) => {
    'type': 'image',
    'source': {'type': 'base64', 'media_type': 'image/png', 'data': data},
  };
  Map<String, Object> googleImage(String data) => {
    'inlineData': {'mimeType': 'image/png', 'data': data},
  };

  test('只有图片的工具结果不补空文本块；无图片的空结果保留原字符串', () async {
    final imageOnly = ChatRequest(
      modelId: 'gemini-3-pro-preview',
      messages: [
        ResolvedMessage(
          role: ChatRole.tool,
          parts: [
            ResolvedToolResult(
              callId: 'image',
              content: '',
              images: [screenshot],
            ),
          ],
        ),
        const ResolvedMessage(
          role: ChatRole.tool,
          parts: [ResolvedToolResult(callId: 'empty', content: '')],
        ),
      ],
    );
    final anthropic = await buildAnthropicPayload(imageOnly);
    final blocks = (anthropic['messages'] as List).single['content'] as List;
    expect(blocks[0]['content'], [anthropicImage(screenshotData)]);
    expect(blocks[1]['content'], '');
    final google = await buildGooglePayload(imageOnly);
    final parts = (google['contents'] as List).single['parts'] as List;
    expect(parts[0]['functionResponse']['parts'], [
      googleImage(screenshotData),
    ]);
    expect(parts[1]['functionResponse'], isNot(contains('parts')));
  });

  group('Anthropic 原生工具图片', () {
    test('多工具结果同组，图片归属各自 tool_use_id，不另发用户图片消息', () async {
      final payload = await buildAnthropicPayload(request());
      final messages = payload['messages'] as List;
      expect(messages, hasLength(3));
      expect(messages.last, {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': 'capture',
            'content': [
              {'type': 'text', 'text': metadata},
              anthropicImage(screenshotData),
            ],
          },
          {'type': 'tool_result', 'tool_use_id': 'info', 'content': 'Android'},
          {
            'type': 'tool_result',
            'tool_use_id': 'mcp',
            'content': [
              {'type': 'text', 'text': '两个图片产物'},
              anthropicImage(otherData),
              anthropicImage(screenshotData),
            ],
          },
        ],
      });
      expect(jsonEncode(payload), isNot(contains(temp.path)));
    });

    test('带图错误保留 is_error，直接发图格式不变，历史图片不重复追加', () async {
      final payload = await buildAnthropicPayload(
        request(
          isError: true,
          trailingMessages: [
            const ResolvedMessage(
              role: ChatRole.assistant,
              parts: [ResolvedText('收到')],
            ),
            ResolvedMessage(
              role: ChatRole.user,
              parts: [ResolvedImage(screenshot)],
            ),
          ],
        ),
      );
      final messages = payload['messages'] as List;
      expect(messages, hasLength(5));
      expect(messages[2]['content'][0]['is_error'], isTrue);
      expect(messages.last['content'], [anthropicImage(screenshotData)]);
      expect('"type":"image"'.allMatches(jsonEncode(payload)), hasLength(4));
    });

    for (final supported in [true, false]) {
      test(supported ? '文件丢失在原工具结果中说明' : '关闭图片能力后只回填说明，不发送图片字节', () async {
        if (supported) await File(screenshot.localPath).delete();
        final payload = await buildAnthropicPayload(
          request(),
          supportsImages: supported,
        );
        final messages = payload['messages'] as List;
        expect(messages, hasLength(3));
        expect(messages.last['content'][0]['content'], [
          {'type': 'text', 'text': metadata},
          {
            'type': 'text',
            'text': supported ? '[图片文件已丢失]' : '[图片已省略：当前模型不支持图片输入]',
          },
        ]);
        expect(jsonEncode(payload), isNot(contains(screenshotData)));
        if (!supported) expect(jsonEncode(payload), isNot(contains(otherData)));
      });
    }
  });

  group('Google 原生工具图片', () {
    for (final modelId in ['gemini-3-pro-preview', 'gemini-3.1-pro-preview']) {
      test('$modelId 图片嵌入对应 functionResponse.parts，完整结果组不拆散', () async {
        final payload = await buildGooglePayload(request(modelId: modelId));
        final contents = payload['contents'] as List;
        expect(contents, hasLength(3));
        expect(contents[1]['parts'][0]['functionCall']['id'], 'capture');
        expect(contents.last['parts'], [
          {
            'functionResponse': {
              'id': 'capture',
              'name': 'capture_screen',
              'response': {'result': metadata},
              'parts': [googleImage(screenshotData)],
            },
          },
          {
            'functionResponse': {
              'id': 'info',
              'name': 'system_info',
              'response': {'result': 'Android'},
            },
          },
          {
            'functionResponse': {
              'id': 'mcp',
              'name': 'mcp_images',
              'response': {'result': '两个图片产物'},
              'parts': [googleImage(otherData), googleImage(screenshotData)],
            },
          },
        ]);
        expect(jsonEncode(payload), isNot(contains(temp.path)));
      });
    }

    for (final modelId in [
      'gemini-2.5-flash',
      'custom-model',
      'proxy-gemini-3-pro',
    ]) {
      test('$modelId 保留结果组之后的图片观察，不猜测别名能力', () async {
        final payload = await buildGooglePayload(request(modelId: modelId));
        final contents = payload['contents'] as List;
        expect(contents, hasLength(4));
        final results = contents[2]['parts'] as List;
        expect(results, hasLength(3));
        for (final part in results) {
          expect(part['functionResponse'], isNot(contains('parts')));
          expect(part['functionResponse'], isNot(contains('id')));
        }
        final images = (contents.last['parts'] as List).where(
          (part) => part['inline_data'] != null,
        );
        expect(images.map((part) => part['inline_data']['data']), [
          screenshotData,
          otherData,
          screenshotData,
        ]);
      });
    }

    test('带图错误保留 error，直接发图格式不变，历史图片不重复追加', () async {
      final payload = await buildGooglePayload(
        request(
          isError: true,
          trailingMessages: [
            const ResolvedMessage(
              role: ChatRole.assistant,
              parts: [ResolvedText('收到')],
            ),
            ResolvedMessage(
              role: ChatRole.user,
              parts: [ResolvedImage(screenshot)],
            ),
          ],
        ),
      );
      final contents = payload['contents'] as List;
      expect(contents, hasLength(5));
      expect(contents[2]['parts'][0]['functionResponse']['response'], {
        'error': metadata,
      });
      expect(contents.last['parts'], [
        {
          'inline_data': {'mime_type': 'image/png', 'data': screenshotData},
        },
      ]);
      expect('inlineData'.allMatches(jsonEncode(payload)), hasLength(3));
    });

    for (final supported in [true, false]) {
      test(
        supported ? '文件丢失并入 response 说明，不构造无效图片 part' : '关闭图片能力不发 inlineData',
        () async {
          if (supported) await File(screenshot.localPath).delete();
          final payload = await buildGooglePayload(
            request(),
            supportsImages: supported,
          );
          final contents = payload['contents'] as List;
          expect(contents, hasLength(3));
          final result = contents.last['parts'][0]['functionResponse'] as Map;
          final notice = supported ? '[图片文件已丢失]' : '[图片已省略：当前模型不支持图片输入]';
          expect(result['response'], {'result': '$metadata\n$notice'});
          expect(result, isNot(contains('parts')));
          expect(jsonEncode(payload), isNot(contains(screenshotData)));
          if (!supported) {
            expect(jsonEncode(payload), isNot(contains(otherData)));
          }
        },
      );
    }
  });
}
