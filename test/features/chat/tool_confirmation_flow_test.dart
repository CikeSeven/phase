import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/core/widgets/app_sheet.dart';
import 'package:phase/features/chat/chat_page.dart';
import 'package:phase/features/chat/tool_confirmation_host.dart';
import 'package:phase/features/chat/tool_confirmation_sheet.dart';
import 'package:phase/features/tools/tool_card.dart';
import 'package:phase/features/execution/execution_controller.dart';

import '../tools/tool_loop_harness.dart';

/// 聊天页上的工具确认闭环：面板展示真实参数，决定后与执行、卡片状态一致。
void main() {
  const writeArguments = '{"path":"summary.md","content":"# 摘要\\n第一条"}';

  /// 装配聊天页：真实库、脚本化模型响应与临时产物目录。
  Future<ToolLoopHarness> pumpChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = await ToolLoopHarness.create(
      models: const [
        ProfileModel(id: 'model-a', enabled: true, supportsTools: true),
      ],
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const ChatPage()),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Scaffold(body: Text('设置入口')),
        ),
        GoRoute(
          path: '/settings/providers',
          builder: (context, state) => const Scaffold(body: Text('服务商入口')),
        ),
        GoRoute(
          path: '/assistants',
          builder: (context, state) => const Scaffold(body: Text('助手入口')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: ToolConfirmationHost(
              navigatorKey: router.routerDelegate.navigatorKey,
              child: child!,
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    return harness;
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const ValueKey('chat-message-input')),
      text,
    );
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
  }

  Future<void> waitForPanel(WidgetTester tester) async {
    await _until(
      tester,
      () => find
          .byKey(const ValueKey('tool-confirmation-body'))
          .evaluate()
          .isNotEmpty,
      reason: '确认面板未出现',
    );
    // 面板每秒刷新剩余时间：pumpAndSettle 会一直推进虚拟时钟直到"稳定"，
    // 把 60 秒确认期限耗光。用有界推进等入场动画结束。
    await _settle(tester);
    await _settle(tester);
  }

  File artifactFile(ToolLoopHarness harness) {
    return File(
      p.join(
        harness.artifactsDir(harness.conversationId()!).path,
        'summary.md',
      ),
    );
  }

  testWidgets('前后台移交及关闭重开保持同一确认与原期限，不提前执行', (tester) async {
    final harness = await pumpChat(tester);
    harness.provider.turns.addAll([
      toolTurn(
        callId: 'call_1',
        toolName: 'write_file',
        arguments: writeArguments,
      ),
      textTurn('保存完成'),
    ]);
    await send(tester, '保存摘要');
    await waitForPanel(tester);
    final pending = harness.container
        .read(executionControllerProvider)
        .confirmation!;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await _settle(tester);
    expect(find.byKey(const ValueKey('tool-confirmation-body')), findsNothing);
    expect(artifactFile(harness).existsSync(), isFalse);
    // paused 后不再绘帧，后台渲染树不表示面板仍然可见。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(
      harness.container.read(executionControllerProvider).confirmation,
      same(pending),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await waitForPanel(tester);
    expect(
      tester
          .widget<ToolConfirmationSheet>(find.byType(ToolConfirmationSheet))
          .request
          .expiresAt,
      pending.expiresAt,
    );
    final navigator = Navigator.of(
      tester.element(find.byType(ToolConfirmationSheet)),
    );
    navigator.pop();
    await _settle(tester);
    expect(
      harness.container.read(executionControllerProvider).confirmation,
      same(pending),
    );
    await tester.tap(find.byKey(const ValueKey('reopen-tool-confirmation')));
    await waitForPanel(tester);
    expect(
      tester
          .widget<ToolConfirmationSheet>(find.byType(ToolConfirmationSheet))
          .request
          .expiresAt,
      pending.expiresAt,
    );
    await tester.tap(find.byKey(const ValueKey('tool-confirm-allow')));
    await _until(tester, () => !harness.state().isGenerating, reason: '运行未结束');
    expect(artifactFile(harness).existsSync(), isTrue);
    expect((await harness.recordsByCall()).values, hasLength(1));
  });

  testWidgets('应用级确认在设置路由仍可操作，返回聊天保留执行结果', (tester) async {
    final harness = await pumpChat(tester);
    final router = GoRouter.of(tester.element(find.byType(ChatPage)));
    unawaited(router.push('/settings'));
    await _settle(tester);
    harness.provider.turns.addAll([
      toolTurn(
        callId: 'call_1',
        toolName: 'write_file',
        arguments: writeArguments,
      ),
      textTurn('已拒绝保存'),
    ]);
    unawaited(harness.controller().send('保存摘要'));
    await waitForPanel(tester);
    await tester.tap(find.byKey(const ValueKey('tool-confirm-reject')));
    await _until(tester, () => !harness.state().isGenerating, reason: '运行未结束');
    expect(artifactFile(harness).existsSync(), isFalse);
    router.pop();
    await _settle(tester);
    expect(
      (await harness.recordsByCall())['call_1']!.status,
      ToolCallStatus.rejected,
    );
    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets('确认面板展示本次写入的真实参数，批准后落盘并显示工具卡片', (tester) async {
    final harness = await pumpChat(tester);
    harness.provider.turns.addAll([
      toolTurn(
        callId: 'call_1',
        toolName: 'write_file',
        arguments: writeArguments,
      ),
      textTurn('已保存到产物目录'),
    ]);

    await send(tester, '把摘要写成文件');
    await waitForPanel(tester);

    // 面板内容：工具、动作摘要、真实参数、通道与剩余时间。
    // 工具卡片在等待确认时已进流，因此页面上同时有卡片与面板标题两处。
    expect(find.text('写入文件'), findsNWidgets(2));
    expect(tester.widget<AppSheet>(find.byType(AppSheet)).title, '写入文件');
    // 动作摘要与目标都来自工具自己的描述，展示的是这次动作的真实内容。
    expect(find.textContaining('写入文件「summary.md」'), findsWidgets);
    expect(find.textContaining('执行通道：应用内'), findsOneWidget);
    expect(
      tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('tool-parameter-path')),
          )
          .data,
      'summary.md',
    );
    expect(
      tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('tool-parameter-content')),
          )
          .data,
      '# 摘要\n第一条',
    );
    expect(
      find.byKey(const ValueKey('tool-confirmation-countdown')),
      findsOneWidget,
    );
    // 未批准前不落盘。
    expect(artifactFile(harness).existsSync(), isFalse);

    await tester.tap(find.byKey(const ValueKey('tool-confirm-allow')));
    await _settle(tester);

    final artifact = artifactFile(harness);
    await _until(tester, () => artifact.existsSync(), reason: '产物未写入');
    expect(artifact.readAsStringSync(), '# 摘要\n第一条');

    // 运行继续到下一轮：状态回到运行中，工具记录为已完成的批准调用。
    await _until(tester, () => !harness.state().isGenerating, reason: '运行未收口');
    await _settle(tester);
    final record = await _record(harness, 'call_1');
    expect(record.status, ToolCallStatus.succeeded);
    expect(record.decision, ToolDecision.approved);
    expect((await _run(harness)).status, RunStatus.completed);

    // 聊天流里的工具卡片：读记录显示状态与结果，不显示原始参数 JSON。
    expect(find.byType(ToolCard), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(ValueKey('tool-status-${record.id}')))
          .data,
      '已完成',
    );
    expect(find.textContaining('已创建「summary.md」'), findsOneWidget);
    expect(find.textContaining('{"path"'), findsNothing);

    // 产物 chip 打开内容：文本类直接显示。
    final attachmentId = record.artifacts.single;
    await tester.tap(find.byKey(ValueKey('tool-artifact-$attachmentId')));
    await _settle(tester);
    final content = find.descendant(
      of: find.byKey(const ValueKey('tool-artifact-content')),
      matching: find.byType(SelectableText),
    );
    expect(content, findsOneWidget);
    expect(tester.widget<SelectableText>(content).data, '# 摘要\n第一条');
  });

  testWidgets('拒绝后不执行动作，工具卡片显示已拒绝', (tester) async {
    final harness = await pumpChat(tester);
    harness.provider.turns.addAll([
      toolTurn(
        callId: 'call_1',
        toolName: 'write_file',
        arguments: writeArguments,
      ),
      textTurn('好，那就不写'),
    ]);

    await send(tester, '把摘要写成文件');
    await waitForPanel(tester);
    await tester.tap(find.byKey(const ValueKey('tool-confirm-reject')));
    await _settle(tester);

    await _until(tester, () => !harness.state().isGenerating, reason: '运行未收口');
    await _settle(tester);
    final record = await _record(harness, 'call_1');
    expect(record.status, ToolCallStatus.rejected);
    expect(record.decision, ToolDecision.rejected);
    expect(artifactFile(harness).existsSync(), isFalse);
    expect(find.byType(ToolCard), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(ValueKey('tool-status-${record.id}')))
          .data,
      '已拒绝',
    );
    // 拒绝不结束运行：下一轮回答照常落下。
    expect(find.text('好，那就不写'), findsOneWidget);
  });

  testWidgets('确认面板的停止任务结束整次运行，工具不执行', (tester) async {
    final harness = await pumpChat(tester);
    // 只准备一轮响应：停止后不应再发出模型请求。
    harness.provider.turns.add(
      toolTurn(
        callId: 'call_1',
        toolName: 'write_file',
        arguments: writeArguments,
      ),
    );

    await send(tester, '把摘要写成文件');
    await waitForPanel(tester);
    await tester.tap(find.byKey(const ValueKey('tool-confirm-stop')));
    await _settle(tester);

    await _until(
      tester,
      () => !harness.state().isGenerating,
      reason: '停止后运行未收口',
    );
    await _settle(tester);
    expect(harness.provider.requests, hasLength(1));
    expect(artifactFile(harness).existsSync(), isFalse);
    final run = await _run(harness);
    expect(run.status, RunStatus.stopped);
    expect(run.finishReason, RunFinishReason.cancelled);
    final record = await _record(harness, 'call_1');
    expect(record.status, ToolCallStatus.cancelled);
    expect(record.decision, isNull);
    expect(find.byType(ToolCard), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(ValueKey('tool-status-${record.id}')))
          .data,
      '已取消',
    );
  });
}

Future<ToolCallRecord> _record(ToolLoopHarness harness, String callId) async {
  final records = await harness.recordsByCall();
  return records[callId]!;
}

Future<AgentRun> _run(ToolLoopHarness harness) => harness.latestRun();

/// 有界推进 UI 与真实异步（库、文件、流）。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _until(
  WidgetTester tester,
  FutureOr<bool> Function() condition, {
  required String reason,
}) async {
  for (var i = 0; i < 120; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 30));
    if (await tester.runAsync(() async => await condition()) ?? false) return;
  }
  fail('等待超时：$reason');
}
