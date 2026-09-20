import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/providers/openai_responses/responses_decoder.dart';

void main() {
  late Directory temp;
  late Attachment screenshot;
  const pngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
      '/x8AAwMCAO+aB9sAAAAASUVORK5CYII=';
  const imageBlock = {
    'type': 'input_image',
    'image_url': 'data:image/png;base64,$pngBase64',
  };
  const metadata = '{"screenshot":{"imageWidth":1,"imageHeight":1}}';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('phase-responses-images-');
    final file = await File('${temp.path}/screen.png')
        .writeAsBytes(base64Decode(pngBase64));
    screenshot = Attachment(
      id: 'screen',
      conversationId: 'conversation',
      kind: AttachmentKind.artifact,
      name: 'screen.png',
      mimeType: 'image/png',
      size: await file.length(),
      localPath: file.path,
      createdAt: DateTime(2026),
    );
  });
  tearDown(() async => temp.delete(recursive: true));

  ChatRequest request({
    List<Attachment>? images,
    List<ResolvedMessage> trailingMessages = const [],
  }) => ChatRequest(
    modelId: 'gpt-6-astra',
    messages: [
      const ResolvedMessage(
        role: ChatRole.user,
        parts: [ResolvedText('观察当前页面')],
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
        ],
      ),
      ResolvedMessage(
        role: ChatRole.tool,
        parts: [
          ResolvedToolResult(
            callId: 'capture',
            content: metadata,
            images: images ?? [screenshot],
          ),
          const ResolvedToolResult(callId: 'info', content: 'Android'),
        ],
      ),
      ...trailingMessages,
    ],
  );

  List<Map<String, dynamic>> input(Map<String, dynamic> payload) =>
      (payload['input'] as List).cast<Map<String, dynamic>>();

  Object? captureOutput(Map<String, dynamic> payload) => input(payload)
      .singleWhere(
        (item) =>
            item['type'] == 'function_call_output' &&
            item['call_id'] == 'capture',
      )['output'];

  test('工具图片和元数据绑定同一个 call_id，不另造 user 消息或拆散结果组', () async {
    final payload = await buildResponsesPayload(request());
    expect(input(payload), [
      {
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': '观察当前页面'},
        ],
      },
      {
        'type': 'function_call',
        'call_id': 'capture',
        'name': 'capture_screen',
        'arguments': '{}',
      },
      {
        'type': 'function_call',
        'call_id': 'info',
        'name': 'system_info',
        'arguments': '{}',
      },
      {
        'type': 'function_call_output',
        'call_id': 'capture',
        'output': [
          {'type': 'input_text', 'text': metadata},
          imageBlock,
        ],
      },
      {'type': 'function_call_output', 'call_id': 'info', 'output': 'Android'},
    ]);
    expect(jsonEncode(payload), isNot(contains(screenshot.localPath)));
  });

  test('直接上传和工具返回使用相同的图片内容块，历史回放不重复图片', () async {
    final payload = await buildResponsesPayload(
      request(
        trailingMessages: [
          const ResolvedMessage(
            role: ChatRole.assistant,
            parts: [ResolvedText('已收到工具结果')],
          ),
          ResolvedMessage(
            role: ChatRole.user,
            parts: [ResolvedImage(screenshot)],
          ),
        ],
      ),
    );
    final items = input(payload);
    final output = captureOutput(payload) as List;
    expect(output.last, imageBlock);
    expect(items.last['content'], [output.last]);
    expect(items.where((item) => item['role'] == 'user'), hasLength(2));
    expect('input_image'.allMatches(jsonEncode(payload)), hasLength(2));
  });

  test('多个图片工具各自回填，不把后一个工具的图片挂到前一个调用', () async {
    final payload = await buildResponsesPayload(
      request(
        trailingMessages: [
          const ResolvedMessage(
            role: ChatRole.assistant,
            parts: [
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
                callId: 'mcp',
                content: '两个图片产物',
                images: [screenshot, screenshot],
              ),
            ],
          ),
        ],
      ),
    );
    expect(captureOutput(payload), [
      {'type': 'input_text', 'text': metadata},
      imageBlock,
    ]);
    expect(input(payload).last, {
      'type': 'function_call_output',
      'call_id': 'mcp',
      'output': [
        {'type': 'input_text', 'text': '两个图片产物'},
        imageBlock,
        imageBlock,
      ],
    });
  });

  test('纯文本工具结果仍使用字符串', () async {
    final payload = await buildResponsesPayload(request(images: []));
    expect(captureOutput(payload), metadata);
  });

  for (final supportsImages in [true, false]) {
    test(supportsImages ? '图片文件丢失在同一工具结果里说明' : '关闭图片能力时不发送图片字节', () async {
      if (supportsImages) await File(screenshot.localPath).delete();
      final payload = await buildResponsesPayload(
        request(),
        supportsImages: supportsImages,
      );
      expect(captureOutput(payload), [
        {'type': 'input_text', 'text': metadata},
        {
          'type': 'input_text',
          'text': supportsImages ? '[图片文件已丢失]' : '[图片已省略：当前模型不支持图片输入]',
        },
      ]);
      expect(jsonEncode(payload), isNot(contains('input_image')));
      expect(jsonEncode(payload), isNot(contains(pngBase64)));
      expect(
        input(payload).where((item) => item['role'] == 'user'),
        hasLength(1),
      );
    });
  }
}
