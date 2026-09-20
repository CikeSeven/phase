import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/tools/tool.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <ExecutionRequest>[];
  final cancellations = <String>[];
  late Completer<ExecutionResult> response;
  late PigeonChannelDriver driver;

  void host(String method, Future<Object?> Function(Object?) handler) {
    final channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.phase.ExecutionHostApi.$method',
      ExecutionHostApi.pigeonChannelCodec,
    );
    messenger.setMockDecodedMessageHandler<Object?>(channel, handler);
    addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
  }

  ExecutionRequest request({String id = 'app-call', int timeout = 500}) =>
      ExecutionRequest(
        runId: 'run',
        toolCallId: id,
        action: ExecutionAction.clickNode,
        arguments: {'value': 'fixed'},
        target: ExecutionTarget(
          packageName: 'test.fixture',
          snapshotId: 'snapshot',
          nodeId: 'node',
        ),
        timeoutMs: timeout,
      );
  ExecutionResult success(String id) => ExecutionResult(
    toolCallId: id,
    status: ExecutionStatus.succeeded,
    result: {'observed': true},
    artifacts: [],
  );

  setUp(() async {
    calls.clear();
    cancellations.clear();
    response = Completer<ExecutionResult>();
    host('startRun', (_) async => [HostReply()]);
    host('endRun', (_) async => [null]);
    host('cancel', (message) async {
      cancellations.add((message as List).single as String);
      return [null];
    });
    host('execute', (message) async {
      calls.add((message as List).single as ExecutionRequest);
      return [await response.future];
    });
    driver = PigeonChannelDriver(cancelGrace: const Duration(milliseconds: 20));
    addTearDown(driver.dispose);
    await driver.startRun('run');
  });

  test('真实 Pigeon 编解码保留应用调用 ID 和固定参数；进度不产生终态', () async {
    final cancel = RunCancellation();
    addTearDown(cancel.cancel);
    final progress = <int>[];
    final input = request();
    var finished = false;
    final result = driver
        .execute(
          input,
          cancel,
          onProgress: (event) => progress.add(event.sequence),
        )
        .then((value) {
          finished = true;
          return value;
        });
    input.arguments['value'] = 'changed';
    await Future<void>.delayed(Duration.zero);
    expect(calls.single.toolCallId, 'app-call');
    expect(calls.single.arguments, {'value': 'fixed'});
    expect(calls.single.target.snapshotId, 'snapshot');
    for (final sequence in [1, 1, 0, 2]) {
      driver.progress(
        ExecutionProgress(
          toolCallId: 'app-call',
          sequence: sequence,
          kind: ProgressKind.stage,
          payload: 'observing',
        ),
      );
    }
    driver.progress(
      ExecutionProgress(
        toolCallId: 'other',
        sequence: 3,
        kind: ProgressKind.stage,
        payload: 'ignored',
      ),
    );
    expect(progress, [1, 2]);
    expect(finished, isFalse);
    response.complete(success('app-call'));
    expect((await result).status, ExecutionStatus.succeeded);
    driver.progress(
      ExecutionProgress(
        toolCallId: 'app-call',
        sequence: 3,
        kind: ProgressKind.stage,
        payload: 'late',
      ),
    );
    expect(progress, [1, 2]);
    expect(
      (await driver.execute(request(), cancel)).error,
      ChannelError.invalidArguments,
    );
    expect(calls, hasLength(1));
  });

  test('等待响应时取消传到底层，取消收口后迟到成功不改终态', () async {
    final cancel = RunCancellation();
    final result = driver.execute(request(), cancel);
    await Future<void>.delayed(Duration.zero);
    cancel.cancel();
    final stopped = await result;
    expect(cancellations, ['app-call']);
    expect(stopped.status, ExecutionStatus.cancelled);
    response.complete(success('app-call'));
    await Future<void>.delayed(Duration.zero);
    expect(stopped.status, ExecutionStatus.cancelled);
  });

  test('派发前取消不调用平台；派发后以原生明确结果收口', () async {
    final before = RunCancellation()..cancel();
    expect(
      (await driver.execute(request(), before)).status,
      ExecutionStatus.cancelled,
    );
    expect(calls, isEmpty);
    final during = RunCancellation();
    final result = driver.execute(request(), during);
    await Future<void>.delayed(Duration.zero);
    during.cancel();
    response.complete(
      ExecutionResult(
        toolCallId: 'app-call',
        status: ExecutionStatus.cancelled,
        result: {},
        artifacts: [],
      ),
    );
    expect((await result).status, ExecutionStatus.cancelled);
  });

  test('错配结果和桥接异常不能伪装成功，异常内容不进入业务结果', () async {
    final cancel = RunCancellation();
    addTearDown(cancel.cancel);
    final result = driver.execute(request(), cancel);
    response.complete(success('provider-call-not-app-call'));
    expect((await result).status, ExecutionStatus.failed);
    host('execute', (_) async => ['native-error', 'secret fixture', null]);
    final failed = await driver.execute(request(id: 'second'), cancel);
    expect(failed.status, ExecutionStatus.failed);
    expect(failed.result, isEmpty);
  });

  test('底层无回调有界超时并取消；销毁也收口在途 Future', () async {
    final cancel = RunCancellation();
    addTearDown(cancel.cancel);
    expect(
      (await driver.execute(request(timeout: 10), cancel)).status,
      ExecutionStatus.failed,
    );
    expect(cancellations, contains('app-call'));
    final pending = driver.execute(request(id: 'second'), cancel);
    await driver.dispose();
    expect((await pending).status, ExecutionStatus.cancelled);
    response.complete(success('app-call'));
  });

  test('生成的 FlutterApi 将原生停止/决定交给同一事件订阅', () async {
    final events = <NativeExecutionEvent>[];
    final subscription = driver.events.listen(events.add);
    addTearDown(subscription.cancel);
    final codec = ExecutionFlutterApi.pigeonChannelCodec;
    for (final entry in {
      'stopRequested': ['run', null],
      'confirmationDecision': ['run', 'app-call', ConfirmationDecision.approve],
      'continueRequested': ['run', 'user-call'],
    }.entries) {
      final done = Completer<void>();
      messenger.handlePlatformMessage(
        'dev.flutter.pigeon.phase.ExecutionFlutterApi.${entry.key}',
        codec.encodeMessage(entry.value),
        (_) => done.complete(),
      );
      await done.future;
    }
    expect(events[0], isA<NativeStop>().having((e) => e.runId, 'run', 'run'));
    expect(
      events[1],
      isA<NativeDecision>().having((e) => e.toolCallId, 'call', 'app-call'),
    );
    expect(
      events[2],
      isA<NativeContinue>().having((e) => e.toolCallId, 'call', 'user-call'),
    );
  });

  test('面板快照通过真实桥接保留独立正文、公开思考与等待标识', () async {
    TaskPanelSnapshot? received;
    host('setTaskPanel', (message) async {
      received = (message as List).single as TaskPanelSnapshot;
      return [null];
    });
    await driver.setTaskPanel(
      TaskPanelSnapshot(
        runId: 'run',
        phase: TaskPanelPhase.waitingUser,
        status: '等待你操作',
        messages: [
          TaskPanelMessage(
            id: 'r',
            kind: TaskPanelMessageKind.reasoning,
            label: '思考',
            text: '公开摘要',
          ),
          TaskPanelMessage(
            id: 't',
            kind: TaskPanelMessageKind.text,
            label: '相月',
            text: '正文',
          ),
        ],
        waitingToolCallId: 'user-call',
        userPrompt: '请登录',
      ),
    );
    expect(received!.phase, TaskPanelPhase.waitingUser);
    expect(received!.messages.first.text, '公开摘要');
    expect(received!.messages.last.text, '正文');
    expect(received!.waitingToolCallId, 'user-call');
  });

  test('查询能力失败映射安全 Failure，未实现通道不伪造可用', () async {
    host('queryCapabilities', (_) async => ['error', 'private-token', null]);
    await expectLater(
      driver.queryCapabilities(),
      throwsA(
        isA<ExecutionFailure>().having(
          (e) => e.userMessage,
          'safe message',
          isNot(contains('private-token')),
        ),
      ),
    );
  });
}
