import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/visual_tools.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/providers/openai_responses/responses_decoder.dart';

import '../../features/tools/tool_loop_harness.dart';
import '../../support/fake_channel_driver.dart';

void main() {
  final tool = VisualTool(
    ExecutionAction.performGestures,
    () => throw StateError('No device'),
  );
  test('Responses 保留可选字段，每种手势仅声明该类型实际可用的参数', () async {
    final payload = await buildResponsesPayload(
      ChatRequest(
        modelId: 'gpt-6-astra',
        messages: const [],
        tools: ToolRegistry([tool])
            .definitionsFor({tool.name}, {tool.policyKey: ToolPolicy.allow}),
      ),
    );
    final definition = (payload['tools'] as List).single as Map;
    expect(definition['strict'], isFalse);
    final schemas =
        definition['parameters']['properties']['actions']['items']['anyOf']
            as List;
    for (final (type, required, optional) in [
      ('tap', ['type', 'x', 'y'], <String>[]),
      ('double_tap', ['type', 'x', 'y'], <String>[]),
      ('long_press', ['type', 'x', 'y'], ['durationMs']),
      ('swipe', ['type', 'x', 'y', 'endX', 'endY'], ['durationMs']),
      ('wait', ['type'], ['durationMs']),
    ]) {
      final schema = schemas.singleWhere(
        (s) => s['properties']['type']['enum'].single == type,
      );
      expect(schema['required'], required);
      expect(
        (schema['properties'] as Map).keys,
        unorderedEquals([...required, ...optional]),
      );
      expect(schema['additionalProperties'], isFalse);
    }
    for (final schema in schemas) {
      final duration = schema['properties']['durationMs'];
      if (duration != null) expect(duration['maximum'], 2000);
    }
  });

  test('真机 tap 多余字段在派发前明确指出；模型另发合法 tap 后只执行一次', () async {
    final h = await ToolLoopHarness.create();
    h.onConfirmation = (_) async => ToolDecision.approved;
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    final dispatched = <ExecutionRequest>[];
    driver.executeHandler = (request, _) async {
      dispatched.add(request);
      return ExecutionResult(
        toolCallId: request.toolCallId,
        status: ExecutionStatus.succeeded,
        result: {'completedCount': 1, 'observationError': 'screenshotFailed'},
        artifacts: [],
      );
    };
    // 2026-09-21 真机失败形态：tap 被填入 swipe/长按的字段。使用假包名、固定坐标。
    final invalid = {
      'type': 'tap',
      'x': 10,
      'y': 20,
      'endX': 0,
      'endY': 0,
      'durationMs': 0,
    };
    final valid = {'type': 'tap', 'x': 10, 'y': 20};
    Map<String, dynamic> arguments(Map<String, dynamic> action) => {
      'packageName': 'app.fixture.target',
      'coordinateSpace': 'image_pixels',
      'imageWidth': 100,
      'imageHeight': 200,
      'actions': [action],
    };
    h.provider.turns.addAll([
      toolTurn(
        callId: 'bad',
        toolName: 'perform_gestures',
        arguments: jsonEncode(arguments(invalid)),
      ),
      toolTurn(
        callId: 'good',
        toolName: 'perform_gestures',
        arguments: jsonEncode(arguments(valid)),
      ),
      textTurn('测试完成'),
    ]);
    await h.controller().send('点击目标');
    final records = await h.recordsByCall();
    expect(records['bad']!.errorCode, 'invalidArguments');
    expect(records['bad']!.result, '第 1 步 tap 只接受 type、x、y；请省略其余字段。');
    expect(records['bad']!.startedAt, isNull);
    expect(records['bad']!.arguments, arguments(invalid));
    expect(dispatched, hasLength(1));
    expect(dispatched.single.arguments, arguments(valid));
    expect(records['good']!.status, ToolCallStatus.succeeded);
  });
}
