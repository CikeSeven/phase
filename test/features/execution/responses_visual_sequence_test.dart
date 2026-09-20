import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/providers/openai_responses/openai_responses_provider.dart';

import '../../support/fake_channel_driver.dart';
import '../tools/tool_loop_harness.dart';
import 'visual_tools_test.dart' show screenshotResult;

typedef _Call = ({String id, String name, Map<String, dynamic> args});

const _open = (
  id: 'open',
  name: 'open_app',
  args: <String, dynamic>{'packageName': 'app.fixture.target'},
);
const _capture = (
  id: 'capture',
  name: 'capture_screen',
  args: <String, dynamic>{},
);
const _captureAgain = (
  id: 'capture_again',
  name: 'capture_screen',
  args: <String, dynamic>{},
);
const _gesture = (
  id: 'gesture',
  name: 'perform_gestures',
  args: <String, dynamic>{
    'packageName': 'app.fixture.target',
    'actions': [
      {'type': 'wait', 'durationMs': 10},
    ],
  },
);

// 截获 Dio 序列化后的字节；SSE 和原生结果使用可控样本，不调用外部模型。
class _ResponsesGateway implements HttpClientAdapter {
  _ResponsesGateway(this.turns);
  final List<List<_Call>> turns;
  final payloads = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = await utf8.decoder.bind(requestStream!).join();
    payloads.add(jsonDecode(body) as Map<String, dynamic>);
    final index = payloads.length - 1;
    final calls = index < turns.length ? turns[index] : const <_Call>[];
    final event = {
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
          if (calls.isEmpty)
            {
              'type': 'message',
              'id': 'answer',
              'content': [
                {'type': 'output_text', 'text': '测试结束'},
              ],
            },
        ],
      },
    };
    return ResponseBody.fromString(
      'data: ${jsonEncode(event)}\n\n',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final cases =
      <
        ({
          String name,
          List<List<_Call>> turns,
          ExecutionStatus? noImageStatus,
          List<String> imageCalls,
        })
      >[
        (
          name: '仅打开应用返回控件树，不假装已取得截图',
          turns: [
            [_open],
          ],
          noImageStatus: null,
          imageCalls: [],
        ),
        (
          name: '直接截图',
          turns: [
            [_capture],
          ],
          noImageStatus: null,
          imageCalls: ['capture'],
        ),
        (
          name: '打开应用后分轮截图',
          turns: [
            [_open],
            [_capture],
          ],
          noImageStatus: null,
          imageCalls: ['capture'],
        ),
        (
          name: '同轮打开应用并截图',
          turns: [
            [_open, _capture],
          ],
          noImageStatus: null,
          imageCalls: ['capture'],
        ),
        (
          name: '同轮截图两次，第一次图片也必须送达',
          turns: [
            [_open],
            [_capture, _captureAgain],
          ],
          noImageStatus: null,
          imageCalls: ['capture', 'capture_again'],
        ),
        (
          name: '同轮后一次截图失败不丢弃已经取得的图片',
          turns: [
            [_open],
            [_capture, _captureAgain],
          ],
          noImageStatus: ExecutionStatus.succeeded,
          imageCalls: ['capture'],
        ),
        (
          name: '同轮手势没有返回新图时保留截图',
          turns: [
            [_open],
            [_capture, _gesture],
          ],
          noImageStatus: ExecutionStatus.succeeded,
          imageCalls: ['capture'],
        ),
        (
          name: '后续一轮手势没有新图时保留历史截图',
          turns: [
            [_open],
            [_capture],
            [_gesture],
          ],
          noImageStatus: ExecutionStatus.succeeded,
          imageCalls: ['capture'],
        ),
        (
          // 真机 2026-09-21 01:30 记录：截图成功后手势失败，下一轮旧规则丢图。
          name: '打开应用截图后手势失败，下一轮仍保留已取得的截图',
          turns: [
            [_open],
            [_capture],
            [_gesture],
          ],
          noImageStatus: ExecutionStatus.failed,
          imageCalls: ['capture'],
        ),
        (
          name: '新一轮截图替换旧一轮图片',
          turns: [
            [_open],
            [_capture],
            [_captureAgain],
          ],
          noImageStatus: null,
          imageCalls: ['capture_again'],
        ),
      ];
  for (final scenario in cases) {
    test('Responses ${scenario.name}：原生结果 → 落库 → 实际请求图片字节', () async {
      final gateway = _ResponsesGateway(scenario.turns);
      final h = await ToolLoopHarness.create(
        protocol: ApiProtocol.openaiResponses,
        factory: (profile, _) => OpenAiResponsesProvider(
          profile: profile.copyWith(requiresKey: false),
          apiKey: '',
          dio: Dio()..httpClientAdapter = gateway,
        ),
      );
      h.onConfirmation = (_) async => ToolDecision.approved;
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      addTearDown(
        () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
      );
      final driver =
          h.container.read(channelDriverProvider) as FakeChannelDriver;
      var captures = 0;
      driver.executeHandler = (request, _) async {
        if (request.action == ExecutionAction.openApp) {
          binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          return ExecutionResult(
            toolCallId: request.toolCallId,
            status: ExecutionStatus.succeeded,
            result: {
              'actionAccepted': true,
              'snapshot': {'packageName': 'app.fixture.target', 'nodes': []},
            },
            artifacts: [],
          );
        }
        if (request.action == ExecutionAction.captureScreen) captures++;
        if (scenario.noImageStatus != null &&
            (captures > 1 ||
                request.action == ExecutionAction.performGestures)) {
          final gesture = request.action == ExecutionAction.performGestures;
          return ExecutionResult(
            toolCallId: request.toolCallId,
            status: gesture ? scenario.noImageStatus! : ExecutionStatus.failed,
            result: gesture
                ? scenario.noImageStatus == ExecutionStatus.failed
                      ? {'completedCount': 0, 'reason': 'gestureRejected'}
                      : {
                          'completedCount': 1,
                          'observationError': 'screenshotFailed',
                        }
                : {'reason': 'screenshotFailed'},
            artifacts: [],
          );
        }
        final result = await screenshotResult(
          h,
          request,
          id: 'screen-$captures',
        );
        final artifact = result.artifacts.single;
        final bytes = img.encodePng(
          img.Image(width: 3, height: 4)
            ..setPixelRgb(0, 0, captures * 40, 0, 0),
        );
        await File(artifact.localPath!).writeAsBytes(bytes);
        artifact.size = bytes.length;
        return result;
      };

      await h.controller().send('打开应用后观察页面');
      expect(gateway.payloads, hasLength(scenario.turns.length + 1));
      final records = await h.recordsByCall();
      if (scenario.noImageStatus == ExecutionStatus.failed) {
        expect(records['gesture']!.status, ToolCallStatus.failed);
        expect(records['gesture']!.artifacts, isEmpty);
      }
      final attachments = await (await h.conversations()).attachmentsFor(
        h.conversationId()!,
      );
      final input = gateway.payloads.last['input'] as List;
      final imageOutputs = input
          .where(
            (item) =>
                item['type'] == 'function_call_output' &&
                item['output'] is List,
          )
          .toList();
      expect(
        imageOutputs.map((item) => item['call_id']).toList(),
        scenario.imageCalls,
      );
      for (final callId in scenario.imageCalls) {
        final record = records[callId]!;
        final attachment = attachments.singleWhere(
          (image) => image.id == record.artifacts.single,
        );
        expect(File(attachment.localPath).existsSync(), isTrue);
        final output =
            (imageOutputs.singleWhere(
                  (item) => item['call_id'] == callId,
                )['output']
                as List);
        expect(output.where((part) => part['type'] == 'input_image').single, {
          'type': 'input_image',
          'image_url':
              'data:image/png;base64,${base64Encode(await File(attachment.localPath).readAsBytes())}',
        });
      }
      expect(
        jsonEncode(gateway.payloads.last),
        isNot(contains(h.tempDir.path)),
      );
      expect((await h.latestRun()).status, RunStatus.completed);
      expect((await h.branch()).last.text, '测试结束');

      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await h.controller().send('回到相月后继续描述刚才取得的图片');
      expect(gateway.payloads, hasLength(scenario.turns.length + 2));
      final replay = gateway.payloads.last['input'] as List;
      expect(replay.take(input.length).toList(), input);
      expect((await h.recordsByCall()).keys, unorderedEquals(records.keys));
    });
  }
}
