import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/providers/provider_factory.dart';

import '../../support/fake_channel_driver.dart';
import '../tools/tool_loop_harness.dart';
import 'visual_tools_test.dart' show screenshotResult;

String _sse(Object value) => 'data: ${jsonEncode(value)}\n\n';

// 可控 SSE 仅验证协议回填与落库，不代表真实模型已经识别图像内容。
const _answerText = '测试最终回答';

String _calls(ApiProtocol protocol, {bool googleCallIds = false}) {
  final calls = [
    (id: 'capture', name: 'capture_screen', args: <String, dynamic>{}),
    (id: 'info', name: 'system_info', args: <String, dynamic>{}),
  ];
  return switch (protocol) {
    ApiProtocol.openaiCompletions =>
      '${_sse({
        'choices': [
          {
            'delta': {
              'tool_calls': [
                for (final (index, call) in calls.indexed) {
                    'index': index,
                    'id': call.id,
                    'type': 'function',
                    'function': {'name': call.name, 'arguments': jsonEncode(call.args)},
                  },
              ],
            },
            'finish_reason': 'tool_calls',
          },
        ],
      })}data: [DONE]\n\n',
    ApiProtocol.openaiResponses => _sse({
      'type': 'response.completed',
      'response': {
        'status': 'completed',
        'output': [
          for (final call in calls)
            {
              'type': 'function_call',
              'id': 'fc_${call.id}',
              'call_id': call.id,
              'name': call.name,
              'arguments': jsonEncode(call.args),
              'status': 'completed',
            },
        ],
      },
    }),
    ApiProtocol.anthropicMessages => [
      for (final (index, call) in calls.indexed) ...[
        _sse({
          'type': 'content_block_start',
          'index': index,
          'content_block': {
            'type': 'tool_use',
            'id': call.id,
            'name': call.name,
            'input': {},
          },
        }),
        _sse({
          'type': 'content_block_delta',
          'index': index,
          'delta': {
            'type': 'input_json_delta',
            'partial_json': jsonEncode(call.args),
          },
        }),
        _sse({'type': 'content_block_stop', 'index': index}),
      ],
      _sse({
        'type': 'message_delta',
        'delta': {'stop_reason': 'tool_use'},
      }),
      _sse({'type': 'message_stop'}),
    ].join(),
    ApiProtocol.googleGenerativeAi => _sse({
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              for (final call in calls)
                {
                  'functionCall': {
                    if (googleCallIds) 'id': call.id,
                    'name': call.name,
                    'args': call.args,
                  },
                  'thoughtSignature': 'fixture-signature',
                },
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    }),
  };
}

String _answer(ApiProtocol protocol) => switch (protocol) {
  ApiProtocol.openaiCompletions =>
    '${_sse({
      'choices': [
        {
          'delta': {'content': _answerText},
          'finish_reason': 'stop',
        },
      ],
    })}data: [DONE]\n\n',
  ApiProtocol.openaiResponses => _sse({
    'type': 'response.completed',
    'response': {
      'status': 'completed',
      'output': [
        {
          'type': 'message',
          'id': 'answer',
          'content': [
            {'type': 'output_text', 'text': _answerText},
          ],
        },
      ],
    },
  }),
  ApiProtocol.anthropicMessages =>
    _sse({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': _answerText},
        }) +
        _sse({'type': 'message_stop'}),
  ApiProtocol.googleGenerativeAi => _sse({
    'candidates': [
      {
        'content': {
          'role': 'model',
          'parts': [
            {'text': _answerText},
          ],
        },
        'finishReason': 'STOP',
      },
    ],
  }),
};

void main() {
  final cases = [
    for (final protocol in ApiProtocol.values)
      (
        protocol,
        protocol == ApiProtocol.googleGenerativeAi
            ? 'gemini-3-pro-preview'
            : 'model-a',
      ),
    (ApiProtocol.googleGenerativeAi, 'gemini-2.5-flash'),
  ];
  for (final (protocol, modelId) in cases) {
    final nativeGoogleImages = modelId == 'gemini-3-pro-preview';
    final label = '${protocol.name}/$modelId';
    test('$label 原始 SSE → 截图落库 → 图片回填 → 历史回放', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final payloads = <Map<String, dynamic>>[];
      final listener = server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        payloads.add(jsonDecode(body) as Map<String, dynamic>);
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          payloads.length == 1
              ? _calls(protocol, googleCallIds: nativeGoogleImages)
              : _answer(protocol),
        );
        await request.response.close();
      });
      addTearDown(() async {
        await listener.cancel();
        await server.close(force: true);
      });
      final h = await ToolLoopHarness.create(
        protocol: protocol,
        models: [ProfileModel(id: modelId)],
        factory: (profile, key) => buildAiProvider(
          profile.copyWith(
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
            requiresKey: false,
          ),
          '',
        ),
      );
      h.onConfirmation = (_) async => ToolDecision.approved;
      final driver =
          h.container.read(channelDriverProvider) as FakeChannelDriver;
      driver.executeHandler = (request, _) => screenshotResult(h, request);
      await h.controller().send('观察当前页面').timeout(const Duration(seconds: 10));
      expect(payloads, hasLength(2));
      final record = (await h.recordsByCall()).values.singleWhere(
        (r) => r.toolName == 'capture_screen',
      );
      expect(record.status, ToolCallStatus.succeeded);
      final attachment = (await (await h.conversations()).attachmentsFor(
        h.conversationId()!,
      )).single;
      expect(record.artifacts, [attachment.id]);
      final encoded = base64Encode(
        await File(attachment.localPath).readAsBytes(),
      );
      final wire = jsonEncode(payloads.last);
      expect(wire, contains(encoded));
      expect(wire, isNot(contains(attachment.localPath)));
      expect(wire, contains('image_pixels'));
      // Image observations must not split parallel tool result groups.
      switch (protocol) {
        case ApiProtocol.openaiCompletions:
          final messages = payloads.last['messages'] as List;
          final firstResult = messages.indexWhere((m) => m['role'] == 'tool');
          expect(messages[firstResult + 1]['role'], 'tool');
          expect(messages[firstResult + 2]['role'], 'user');
          expect(jsonEncode(messages[firstResult + 2]), contains('image_url'));
        case ApiProtocol.openaiResponses:
          final input = payloads.last['input'] as List;
          final firstResult = input.indexWhere(
            (m) => m['type'] == 'function_call_output',
          );
          expect(input[firstResult]['call_id'], record.providerCallId);
          final output = input[firstResult]['output'] as List;
          expect(output, [
            {'type': 'input_text', 'text': record.result},
            {
              'type': 'input_image',
              'image_url': 'data:image/png;base64,$encoded',
            },
          ]);
          expect(input[firstResult + 1]['type'], 'function_call_output');
          expect(input[firstResult + 1]['output'], isA<String>());
          expect(firstResult + 2, input.length);
          expect(input.where((item) => item['role'] == 'user'), hasLength(1));
        case ApiProtocol.anthropicMessages:
          final messages = payloads.last['messages'] as List;
          final results = messages.firstWhere(
            (m) =>
                (m['content'] as List).any((p) => p['type'] == 'tool_result'),
          );
          expect(
            (results['content'] as List).where(
              (p) => p['type'] == 'tool_result',
            ),
            hasLength(2),
          );
          final imageResult = (results['content'] as List).singleWhere(
            (part) => part['tool_use_id'] == record.providerCallId,
          );
          expect(imageResult['content'], [
            {'type': 'text', 'text': record.result},
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/png',
                'data': encoded,
              },
            },
          ]);
          expect(messages.last, results);
          expect(
            messages.where((item) => item['role'] == 'user'),
            hasLength(2),
          );
        case ApiProtocol.googleGenerativeAi:
          final contents = payloads.last['contents'] as List;
          final results = contents.firstWhere(
            (m) =>
                (m['parts'] as List).any((p) => p['functionResponse'] != null),
          );
          expect(
            (results['parts'] as List).where(
              (p) => p['functionResponse'] != null,
            ),
            hasLength(2),
          );
          final imageResult =
              (results['parts'] as List).singleWhere(
                    (part) =>
                        part['functionResponse']?['name'] == 'capture_screen',
                  )['functionResponse']
                  as Map;
          if (nativeGoogleImages) {
            expect(record.providerCallId, 'capture');
            expect(imageResult, {
              'id': record.providerCallId,
              'name': 'capture_screen',
              'response': {'result': record.result},
              'parts': [
                {
                  'inlineData': {'mimeType': 'image/png', 'data': encoded},
                },
              ],
            });
            final calls = contents.singleWhere(
              (item) => item['role'] == 'model',
            );
            expect(calls['parts'][0]['functionCall']['id'], 'capture');
            expect(calls['parts'][0]['thoughtSignature'], 'fixture-signature');
            expect(contents.last, results);
          } else {
            expect(imageResult, isNot(contains('parts')));
            expect(imageResult, isNot(contains('id')));
            expect(contents.indexOf(results), contents.length - 2);
            expect(contents.last['parts'].last, {
              'inline_data': {'mime_type': 'image/png', 'data': encoded},
            });
          }
      }
      expect((await h.branch()).last.role, ChatRole.assistant);
      expect((await h.branch()).last.text, _answerText);
      expect((await h.latestRun()).status, RunStatus.completed);

      if (protocol == ApiProtocol.openaiResponses) {
        final originalInput = payloads.last['input'] as List;
        final originalOutput = originalInput.singleWhere(
          (item) =>
              item['type'] == 'function_call_output' &&
              item['call_id'] == record.providerCallId,
        );
        await h
            .controller()
            .send('继续描述刚才的截图')
            .timeout(const Duration(seconds: 10));
        expect(payloads, hasLength(3));
        final replay = payloads.last['input'] as List;
        expect(
          replay.singleWhere(
            (item) =>
                item['type'] == 'function_call_output' &&
                item['call_id'] == record.providerCallId,
          ),
          originalOutput,
        );
        expect(replay.where((item) => item['role'] == 'user'), hasLength(2));
        expect('input_image'.allMatches(jsonEncode(replay)), hasLength(1));
        expect((await h.branch()).last.text, _answerText);
        expect((await h.latestRun()).status, RunStatus.completed);
      }
      if (protocol == ApiProtocol.anthropicMessages ||
          protocol == ApiProtocol.googleGenerativeAi) {
        final field = protocol == ApiProtocol.anthropicMessages
            ? 'messages'
            : 'contents';
        final original = payloads.last[field] as List;
        await h
            .controller()
            .send('继续描述刚才的截图')
            .timeout(const Duration(seconds: 10));
        expect(payloads, hasLength(3));
        final replay = payloads.last[field] as List;
        // 落库后的历史回放保持整个调用/结果/图片前缀，仅追加回答和用户追问。
        expect(replay.take(original.length).toList(), original);
        expect(replay.length, original.length + 2);
        expect((await h.recordsByCall()), hasLength(2));
        expect((await h.branch()).last.text, _answerText);
        expect((await h.latestRun()).status, RunStatus.completed);
      }
    });
  }
}
