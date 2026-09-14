import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/visual_tools.dart';
import 'package:phase/features/tools/tool_presentation.dart';
import 'package:phase/providers/tool_result_images.dart';

import '../../support/fake_channel_driver.dart';
import '../tools/tool_loop_harness.dart';

const _package = 'app.fixture.target';
const _actions = [
  {'type': 'tap', 'x': 1, 'y': 1},
  {'type': 'wait', 'durationMs': 10},
  {'type': 'swipe', 'x': 1, 'y': 1, 'endX': 2, 'endY': 3},
];

Future<ExecutionResult> screenshotResult(
  ToolLoopHarness h,
  ExecutionRequest request, {
  String id = 'screen-1',
}) async {
  final bytes = img.encodePng(img.Image(width: 3, height: 4));
  final source = File('${h.tempDir.path}/native-$id.png');
  await source.writeAsBytes(bytes);
  return ExecutionResult(
    toolCallId: request.toolCallId,
    status: ExecutionStatus.succeeded,
    result: {
      'screenshot': {
        'screenshotId': id,
        'packageName': _package,
        'imageWidth': 3,
        'imageHeight': 4,
        'coordinateSpace': 'image_pixels',
        'screenBounds': [0, 40, 6, 48],
        'rotation': 0,
      },
    },
    artifacts: [
      ExecutionArtifact(
        uri: source.uri.toString(),
        name: 'screen.png',
        size: bytes.length,
        localPath: source.path,
      ),
    ],
  );
}

void main() {
  test('截图保存成可预览产物，图像进入下一轮，连续截图只回填最新图像', () async {
    final h = await ToolLoopHarness.create();
    h.onConfirmation = (_) async => ToolDecision.approved;
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    var index = 0;
    driver.executeHandler = (request, _) {
      if (request.action == ExecutionAction.captureScreen) {
        expect(request.arguments, isEmpty);
        expect(request.target.packageName, isNull);
      }
      return screenshotResult(h, request, id: 'screen-${++index}');
    };
    h.provider.turns.addAll([
      toolTurn(callId: 'capture', toolName: 'capture_screen', arguments: '{}'),
      toolTurn(
        callId: 'gestures',
        toolName: 'perform_gestures',
        arguments: jsonEncode({
          'packageName': _package,
          'coordinateSpace': 'image_pixels',
          'imageWidth': 3,
          'imageHeight': 4,
          'actions': _actions,
        }),
      ),
      textTurn('已根据图像观察完成'),
    ]);
    await h.controller().send('观察后执行手势组合');
    final schema = h.provider.requests.first.tools
        .singleWhere((tool) => tool.name == 'capture_screen')
        .inputSchema;
    expect(schema['properties'], isEmpty);
    expect(schema['required'], isEmpty);
    final records = await h.recordsByCall();
    expect(
      records.values.every(
        (record) => record.status == ToolCallStatus.succeeded,
      ),
      isTrue,
    );
    final images = expandToolResultImages(h.provider.requests.last.messages)
        .expand((m) => m.parts)
        .whereType<ResolvedImage>()
        .toList();
    expect(images, hasLength(1));
    expect(images.single.attachment.id, records['gestures']!.artifacts.single);
    expect(images.single.attachment.isImage, isTrue);
    expect(File(images.single.attachment.localPath).existsSync(), isTrue);
    expect(File('${h.tempDir.path}/native-screen-1.png').existsSync(), isFalse);
    expect(File('${h.tempDir.path}/native-screen-2.png').existsSync(), isFalse);
    expect(driver.deviceTasks, [true]);
    expect(ToolPresentation.summary(records['capture']!), contains('3 × 4'));
    expect(
      jsonDecode(records['capture']!.result!)['screenshot']['packageName'],
      _package,
    );
    expect((await h.latestRun()).status, RunStatus.completed);
  });

  test('截图不接受模型指定目标，额外参数在确认和派发前拒绝', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    var confirmations = 0;
    h.onConfirmation = (_) async {
      confirmations++;
      return ToolDecision.approved;
    };
    h.provider.turns.addAll([
      toolTurn(
        callId: 'capture',
        toolName: 'capture_screen',
        arguments: jsonEncode({'packageName': _package}),
      ),
      textTurn('应当直接读取当前页面'),
    ]);
    await h.controller().send('看当前页面');
    expect(confirmations, 0);
    expect(driver.starts, isEmpty);
    expect((await h.recordsByCall())['capture']!.errorCode, 'invalidArguments');
  });

  test('不支持图片的模型拒绝截图，但仍开放独立的手势工具', () async {
    final h = await ToolLoopHarness.create(
      models: const [ProfileModel(id: 'model-a', supportsImages: false)],
    );
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    h.provider.turns.addAll([
      toolTurn(callId: 'capture', toolName: 'capture_screen', arguments: '{}'),
      textTurn('改用文本观察'),
    ]);
    await h.controller().send('观察');
    expect(
      h.provider.requests.first.tools.map((tool) => tool.name),
      isNot(contains('capture_screen')),
    );
    expect(
      h.provider.requests.first.tools.map((tool) => tool.name),
      contains('perform_gestures'),
    );
    expect(driver.starts, isEmpty);
    expect(
      (await h.recordsByCall())['capture']!.status,
      ToolCallStatus.rejected,
    );
  });

  test('整个组合的非法参数在确认和宿主准备之前被拒绝', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    var confirmations = 0;
    h.onConfirmation = (_) async {
      confirmations++;
      return ToolDecision.approved;
    };
    h.provider.turns.addAll([
      toolTurn(
        callId: 'bad',
        toolName: 'perform_gestures',
        arguments: jsonEncode({
          'packageName': _package,
          'coordinateSpace': 'image_pixels',
          'imageWidth': 3,
          'imageHeight': 4,
          'actions': [
            _actions.first,
            {'type': 'swipe', 'x': 1, 'y': 1},
          ],
        }),
      ),
      textTurn('参数无效'),
    ]);
    await h.controller().send('执行');
    expect(driver.starts, isEmpty);
    expect(confirmations, 0);
    expect((await h.recordsByCall())['bad']!.errorCode, 'invalidArguments');
  });

  test('拒绝组合不派发；批次参数完整展示，不改写坐标', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    var executed = 0;
    driver.executeHandler = (request, _) {
      executed++;
      return screenshotResult(h, request);
    };
    h.onConfirmation = (request) async {
      expect(request.record.arguments['actions'], _actions);
      expect(
        ToolPresentation.parameterDetails(request.record).last.value,
        contains('endY'),
      );
      return ToolDecision.rejected;
    };
    h.provider.turns.addAll([
      toolTurn(
        callId: 'refuse',
        toolName: 'perform_gestures',
        arguments: jsonEncode({
          'packageName': _package,
          'coordinateSpace': 'image_pixels',
          'imageWidth': 3,
          'imageHeight': 4,
          'actions': _actions,
        }),
      ),
      textTurn('未执行'),
    ]);
    await h.controller().send('执行');
    expect(executed, 0);
    expect(
      (await h.recordsByCall())['refuse']!.status,
      ToolCallStatus.rejected,
    );
  });

  test('停止保留已执行与正在派发步骤，不开始下一轮或重发组合', () async {
    final h = await ToolLoopHarness.create();
    h.onConfirmation = (_) async => ToolDecision.approved;
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    final entered = Completer<void>();
    var executions = 0;
    driver.executeHandler = (request, cancellation) async {
      executions++;
      entered.complete();
      await cancellation.whenCancelled;
      return ExecutionResult(
        toolCallId: request.toolCallId,
        status: ExecutionStatus.cancelled,
        result: {
          'completedCount': 1,
          'completedSteps': [
            {'index': 0, 'actionAccepted': true},
          ],
          'activeStep': 1,
          'activeStepDispatched': true,
        },
        artifacts: [],
        error: ChannelError.cancelled,
      );
    };
    h.provider.turns.add(
      toolTurn(
        callId: 'stop',
        toolName: 'perform_gestures',
        arguments: jsonEncode({
          'packageName': _package,
          'coordinateSpace': 'image_pixels',
          'imageWidth': 3,
          'imageHeight': 4,
          'actions': _actions,
        }),
      ),
    );
    final sending = h.controller().send('执行');
    await entered.future;
    h.controller().stop();
    await sending;
    final record = (await h.recordsByCall())['stop']!;
    expect(record.status, ToolCallStatus.cancelled);
    expect(jsonDecode(record.result!)['completedCount'], 1);
    expect(jsonDecode(record.result!)['activeStepDispatched'], isTrue);
    expect(executions, 1);
    expect(h.provider.requests, hasLength(1));
    expect((await h.latestRun()).status, RunStatus.stopped);
  });

  for (final missing in [true, false]) {
    test(missing ? '截图文件丢失作为工具错误回填，不停止根任务' : '截图记录写库失败仍停止任务', () async {
      final h = await ToolLoopHarness.create(
        saveArtifact: missing
            ? null
            : (_) async => throw const StorageFailure('fixture'),
      );
      h.onConfirmation = (_) async => ToolDecision.approved;
      final driver =
          h.container.read(channelDriverProvider) as FakeChannelDriver;
      driver.executeHandler = (request, _) async {
        final result = await screenshotResult(h, request);
        if (missing) await File(result.artifacts.single.localPath!).delete();
        return result;
      };
      h.provider.turns.addAll([
        toolTurn(callId: 'read', toolName: 'capture_screen', arguments: '{}'),
        textTurn('无法取得截图'),
      ]);
      if (missing) {
        await h.controller().send('截图');
        expect(
          (await h.recordsByCall())['read']!.errorCode,
          'screenshotReadFailed',
        );
        expect(h.provider.requests, hasLength(2));
      } else {
        await expectLater(
          h.controller().send('截图'),
          throwsA(isA<StorageFailure>()),
        );
        expect(
          (await h.latestRun()).finishReason,
          RunFinishReason.storageError,
        );
        expect(h.provider.requests, hasLength(1));
      }
    });
  }

  test('手势无需截图或图片能力，同一坐标可在新调用中重复使用，观察失败不改写动作成功', () async {
    final h = await ToolLoopHarness.create(
      models: const [ProfileModel(id: 'model-a', supportsImages: false)],
    );
    h.onConfirmation = (_) async => ToolDecision.approved;
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    final calls = <ExecutionRequest>[];
    driver.executeHandler = (request, _) async {
      calls.add(request);
      expect(request.action, ExecutionAction.performGestures);
      expect(request.arguments.containsKey('screenshotId'), isFalse);
      return ExecutionResult(
        toolCallId: request.toolCallId,
        status: ExecutionStatus.succeeded,
        result: {
          'completedCount': 1,
          'completedSteps': [
            {'type': 'tap', 'x': 100, 'y': 200, 'actionAccepted': true},
          ],
          'observationError': 'screenshotPermissionRequired',
        },
        artifacts: [],
      );
    };
    final arguments = jsonEncode({
      'packageName': 'app.xiangyue.phase',
      'actions': [
        {'type': 'tap', 'x': 100, 'y': 200},
      ],
    });
    h.provider.turns.addAll([
      toolTurn(
        callId: 'first',
        toolName: 'perform_gestures',
        arguments: arguments,
      ),
      toolTurn(
        callId: 'second',
        toolName: 'perform_gestures',
        arguments: arguments,
      ),
      textTurn('手势完成，操作后截图不可用'),
    ]);
    await h.controller().send('执行两次相同坐标的手势');
    expect(calls, hasLength(2));
    expect(calls.map((request) => request.toolCallId).toSet(), hasLength(2));
    final records = await h.recordsByCall();
    for (final record in records.values) {
      expect(record.status, ToolCallStatus.succeeded);
      expect(jsonDecode(record.result!)['completedCount'], 1);
      expect(ToolPresentation.summary(record), contains('系统已完成 1 步手势'));
      expect(ToolPresentation.summary(record), contains('操作后截图不可用'));
    }
    expect((await h.latestRun()).status, RunStatus.completed);
  });

  test('手势完成后原生截图副本丢失，仅回填观察错误，不自动重复动作', () async {
    final h = await ToolLoopHarness.create();
    h.onConfirmation = (_) async => ToolDecision.approved;
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    var executions = 0;
    driver.executeHandler = (request, _) async {
      executions++;
      final result = await screenshotResult(h, request);
      result.result['completedCount'] = 1;
      await File(result.artifacts.single.localPath!).delete();
      return result;
    };
    h.provider.turns.addAll([
      toolTurn(
        callId: 'gesture',
        toolName: 'perform_gestures',
        arguments: jsonEncode({
          'packageName': _package,
          'actions': [
            {'type': 'tap', 'x': 1, 'y': 1},
          ],
        }),
      ),
      textTurn('系统已完成手势，但截图文件无法读取'),
    ]);
    await h.controller().send('点击');
    final record = (await h.recordsByCall())['gesture']!;
    expect(record.status, ToolCallStatus.succeeded);
    expect(jsonDecode(record.result!)['completedCount'], 1);
    expect(
      jsonDecode(record.result!)['observationError'],
      contains('无法读取截图文件'),
    );
    expect(executions, 1);
    expect((await h.latestRun()).status, RunStatus.completed);
  });

  test('图片坐标缺少宽高在确认前拒绝，屏幕坐标无需附带截图信息', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    var confirmations = 0;
    h.onConfirmation = (_) async {
      confirmations++;
      return ToolDecision.approved;
    };
    h.provider.turns.addAll([
      toolTurn(
        callId: 'invalid',
        toolName: 'perform_gestures',
        arguments: jsonEncode({
          'packageName': _package,
          'coordinateSpace': 'image_pixels',
          'actions': _actions,
        }),
      ),
      textTurn('需要图片宽高才能换算'),
    ]);
    await h.controller().send('点击图片坐标');
    expect(confirmations, 0);
    expect(driver.starts, isEmpty);
    expect((await h.recordsByCall())['invalid']!.errorCode, 'invalidArguments');
  });

  test('手势参数拒绝越界类型、未知字段、非有限数及超大组合', () {
    expect(validateGestureActions(_actions), isNull);
    for (final value in [
      [],
      List.filled(11, _actions.first),
      [
        {'type': 'tap', 'x': double.nan, 'y': 2},
      ],
      [
        {'type': 'wait', 'durationMs': 2.5},
      ],
      [
        {'type': 'tap', 'x': 2, 'y': 2, 'command': 'x'},
      ],
      List.filled(8, {'type': 'wait', 'durationMs': 2000}),
    ]) {
      expect(validateGestureActions(value), isNotNull);
    }
  });
}
