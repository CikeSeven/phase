import 'package:phase/features/execution/task_activity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/execution_controller.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/tools/tool_executor.dart';

import '../../support/fake_channel_driver.dart';

void main() {
  late FakeChannelDriver driver;
  late ProviderContainer container;
  late ExecutionController controller;
  late RunCancellation cancellation;
  late int stopped;
  ToolConfirmationRequest request({
    String id = 'call',
    Duration remaining = const Duration(seconds: 60),
  }) => ToolConfirmationRequest(
    record: ToolCallRecord(
      id: id,
      runId: 'run',
      assistantMessageId: 'message',
      toolName: 'click_node',
      arguments: {'nodeId': 'node'},
      channel: ExecutionChannel.accessibility,
      defaultPolicy: ToolPolicy.ask,
      status: ToolCallStatus.awaitingConfirmation,
      createdAt: DateTime.now(),
    ),
    summary: '点击预置条目',
    policy: ToolPolicy.ask,
    expiresAt: DateTime.now().add(remaining),
  );

  setUp(() {
    stopped = 0;
    cancellation = RunCancellation();
    driver = FakeChannelDriver();
    container = ProviderContainer(
      overrides: [channelDriverProvider.overrideWith((_) => driver)],
    );
    controller = container.read(executionControllerProvider.notifier);
    controller.beginRun(
      'run',
      stop: () {
        stopped++;
        cancellation.cancel();
      },
    );
    addTearDown(() async {
      cancellation.cancel();
      await controller.endRun('run').catchError((Object _) {});
      container.dispose();
      await driver.dispose();
    });
  });

  test('用户等待无自动超时；前后台切换、旧继续与重复继续不串调用', () async {
    await controller.ensureDeviceHost('run');
    driver.latestSnapshot = {'snapshotId': 'old'};
    final first = controller.waitForUser(
      const UserActionRequest(runId: 'run', toolCallId: 'first', prompt: '请登录'),
      cancellation,
    );
    expect(driver.latestSnapshot, isNull);
    controller.setForeground(false);
    controller.setForeground(true);
    expect(
      container.read(executionControllerProvider).userAction!.prompt,
      '请登录',
    );
    expect(controller.continueRun('old', 'first'), isFalse);
    expect(controller.continueRun('run', 'first'), isTrue);
    expect(controller.continueRun('run', 'first'), isFalse);
    await first;
    final second = controller.waitForUser(
      const UserActionRequest(
        runId: 'run',
        toolCallId: 'second',
        prompt: '请确认选择',
      ),
      cancellation,
    );
    expect(controller.continueRun('run', 'first'), isFalse);
    controller.stopRun('run');
    await expectLater(second, throwsA(isA<ToolCancelled>()));
    expect(container.read(executionControllerProvider).userAction, isNull);
  });

  test('面板快照有界并合并高频更新，旧运行更新被忽略', () async {
    await controller.ensureDeviceHost('run');
    await Future<void>.delayed(Duration.zero);
    final before = driver.panels.length;
    for (var index = 0; index < 100; index++) {
      controller.updateActivity(
        'run',
        const TaskActivity().copyWith(
          phase: TaskPanelPhase.thinking,
          status: '正在思考',
          messages: [
            TaskMessage(
              id: 'r',
              kind: TaskPanelMessageKind.reasoning,
              label: '思考',
              text: '${'月' * 1000}$index',
            ),
            TaskMessage(
              id: 't',
              kind: TaskPanelMessageKind.text,
              label: '相月',
              text: '正文',
            ),
          ],
        ),
      );
    }
    controller.updateActivity('old', const TaskActivity(status: '旧运行'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(driver.panels.length, before + 1);
    expect(
      driver.panels.last.messages.first.text.length,
      lessThanOrEqualTo(481),
    );
    expect(driver.panels.last.messages.first.text, endsWith('99'));
    expect(driver.panels.last.messages.last.text, '正文');
    expect(driver.panels.last.status, '正在思考');
    expect(panelExcerpt('前😀后', limit: 2), '…后');
  });

  test('点击继续与停止同时发生，以取消收口', () async {
    await controller.ensureDeviceHost('run');
    final waiting = controller.waitForUser(
      const UserActionRequest(runId: 'run', toolCallId: 'call', prompt: '请操作'),
      cancellation,
    );
    expect(controller.continueRun('run', 'call'), isTrue);
    controller.stopRun('run');
    await expectLater(waiting, throwsA(isA<ToolCancelled>()));
    expect(container.read(executionControllerProvider).userAction, isNull);
  });

  test('面板失联结束等待并停止任务', () async {
    await controller.ensureDeviceHost('run');
    await Future<void>.delayed(Duration.zero);
    driver.panelFailure = const ExecutionFailure(
      ExecutionFailureCode.unavailable,
    );
    final waiting = controller.waitForUser(
      const UserActionRequest(runId: 'run', toolCallId: 'call', prompt: '请操作'),
      cancellation,
    );
    await expectLater(waiting, throwsA(isA<ToolCancelled>()));
    expect(stopped, 1);
    expect(
      container.read(executionControllerProvider).failure,
      isA<ExecutionFailure>(),
    );
    expect(controller.continueRun('run', 'call'), isFalse);
  });

  test('命令只在已有无障碍权限时附带面板，缺权限不阻塞命令', () async {
    await controller.showAvailablePanel('run');
    expect(driver.starts, isEmpty);
    driver.accessibilityConnected = true;
    await controller.showAvailablePanel('run');
    expect(driver.starts, ['run']);
    await controller.showAvailablePanel('run');
    expect(driver.starts, ['run']);
  });

  test('普通任务不启动服务；设备宿主只启动一次并随任务结束释放', () async {
    expect(driver.starts, isEmpty);
    await controller.ensureDeviceHost('run');
    await controller.ensureDeviceHost('run');
    expect(driver.starts, ['run']);
    await controller.endRun('run');
    expect(driver.ends, ['run']);
    expect(container.read(executionControllerProvider).runId, isNull);
  });

  test('确认前后台移交保持调用和原期限；旧决定、重复决定不能批准新调用', () async {
    await controller.ensureDeviceHost('run');
    final pending = request();
    final decision = controller.confirm(pending, cancellation);
    controller.setForeground(false);
    await Future<void>.delayed(Duration.zero);
    expect(
      driver.confirmations.last!.expiresAtMs,
      pending.expiresAt.millisecondsSinceEpoch,
    );
    driver.eventsController.add(
      NativeDecision('other', 'call', ConfirmationDecision.approve),
    );
    expect(
      container.read(executionControllerProvider).confirmation,
      same(pending),
    );
    controller.setForeground(true);
    driver.eventsController.add(
      NativeDecision('run', 'call', ConfirmationDecision.approve),
    );
    expect(controller.decide('run', 'call', ToolDecision.rejected), isTrue);
    expect(controller.decide('run', 'call', ToolDecision.approved), isFalse);
    expect(await decision, ToolDecision.rejected);
    final next = controller.confirm(request(id: 'next'), cancellation);
    expect(controller.decide('run', 'call', ToolDecision.approved), isFalse);
    controller.setForeground(false);
    driver.eventsController.add(
      NativeDecision('run', 'next', ConfirmationDecision.approve),
    );
    expect(await next, ToolDecision.approved);
  });

  test('没有页面也按原期限过期，过期批准无效', () async {
    final pending = request(remaining: const Duration(milliseconds: 20));
    final result = controller.confirm(pending, cancellation);
    expect(await result, ToolDecision.expired);
    expect(controller.decide('run', 'call', ToolDecision.approved), isFalse);
    expect(container.read(executionControllerProvider).confirmation, isNull);
  });

  test('原生停止先取消任务；迟到批准与旧任务停止不影响新任务', () async {
    await controller.ensureDeviceHost('run');
    final result = controller.confirm(request(), cancellation);
    driver.eventsController.add(NativeStop('old'));
    expect(stopped, 0);
    driver.eventsController.add(NativeStop('run'));
    driver.eventsController.add(NativeStop('run'));
    expect(await result, ToolDecision.expired);
    expect(stopped, 1);
    expect(controller.decide('run', 'call', ToolDecision.approved), isFalse);
    await controller.endRun('run');
    controller.beginRun('new', stop: () => stopped++);
    driver.eventsController.add(NativeStop('run'));
    expect(stopped, 1);
    await controller.endRun('new');
  });

  test('服务启动和释放失败不吞掉，也不阻塞下一根任务', () async {
    driver.startFailure = const ExecutionFailure(
      ExecutionFailureCode.permissionRequired,
    );
    await expectLater(
      controller.ensureDeviceHost('run'),
      throwsA(isA<ExecutionFailure>()),
    );
    expect(stopped, 0);
    await controller.endRun('run');
    driver.startFailure = null;
    controller.beginRun('next', stop: () {});
    await controller.ensureDeviceHost('next');
    driver.endFailure = const ExecutionFailure(
      ExecutionFailureCode.unavailable,
    );
    await expectLater(
      controller.endRun('next'),
      throwsA(isA<ExecutionFailure>()),
    );
    expect(container.read(executionControllerProvider).runId, isNull);
    expect(
      container.read(executionControllerProvider).failure,
      isA<ExecutionFailure>(),
    );
  });

  test('原生确认展示失败停止任务，不等到超时后继续调度', () async {
    await controller.ensureDeviceHost('run');
    driver.confirmationFailure = const ExecutionFailure(
      ExecutionFailureCode.unavailable,
    );
    controller.setForeground(false);
    final result = controller.confirm(request(), cancellation);
    expect(await result, ToolDecision.expired);
    expect(stopped, 1);
  });
}
