import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/data/models/permission_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/agent_plan.dart';
import 'package:phase/data/repositories/plan_repository.dart';
import 'package:phase/data/repositories/memory_repository.dart';
import 'package:phase/features/chat/chat_input_bar.dart';
import 'package:phase/features/chat/context/conversation_context_page.dart';
import 'package:phase/features/memory/memories_page.dart';
import 'package:phase/features/tools/tool.dart';

import '../../tools/tool_loop_harness.dart';

Future<void> pumpPage(
  WidgetTester tester,
  ToolLoopHarness h,
  Widget child,
  double scale,
  bool dark,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
  }
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  for (final (size, scale, dark) in [
    (const Size(360, 800), 1.0, false),
    (const Size(360, 800), 1.0, true),
    (const Size(320, 700), 2.0, false),
    (const Size(800, 360), 2.0, true),
  ]) {
    testWidgets('计划/记忆表单可滚动取消保存 $size $scale $dark', (tester) async {
      late ToolLoopHarness h;
      late String planId;
      await tester.runAsync(() async {
        h = await ToolLoopHarness.create(registry: ToolRegistry([]));
        await h.controller().setPermissionMode(PermissionMode.plan);
        h.provider.turns.add(
          toolTurn(
            callId: 'p',
            toolName: 'submit_plan',
            arguments: '{"title":"需要用户批准的计划","steps":["先读取必要资料并保留来源","再给出总结，不做任何外部写入"]}',
          ),
        );
        await h.controller().send('请先规划');
        planId = (await PlanRepository(
          h.database,
        ).watch(h.conversationId()!).first).single.id;
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await pumpPage(
        tester,
        h,
        ConversationContextPage(conversationId: h.conversationId()!),
        scale,
        dark,
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final edit = find.text('编辑');
      await tapVisible(tester, edit);
      final title = find.widgetWithText(TextField, '标题');
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      await tester.enterText(title, '未保存的草稿');
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect((await PlanRepository(h.database).latest(planId)).revision, 1);
      });
      await tapVisible(tester, edit);
      await tester.enterText(find.widgetWithText(TextField, '标题'), '修订后的计划');
      await tester.ensureVisible(find.text('保存新修订'));
      await tester.tap(find.text('保存新修订'));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect((await PlanRepository(h.database).latest(planId)).revision, 2);
      });
      expect(tester.takeException(), isNull);
      h.provider.turns.add(textTurn('执行完成'));
      final approve = find.text('批准并执行');
      await tester.scrollUntilVisible(
        approve,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(approve.hitTestable());
      });
      // 交替驱动 Flutter 调度与数据库 IO，不在 fake-async 帧暂停时等待整个运行。
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        if (h.provider.requests.length == 2 && !h.state().isGenerating) break;
      }
      expect(
        h.provider.requests.length == 2 && !h.state().isGenerating,
        isTrue,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final approved = await PlanRepository(h.database).latest(planId);
        expect(approved.status, PlanStatus.approved);
        expect((await h.latestRun()).configuration.planRevision, 2);
      });

      await pumpPage(tester, h, const MemoriesPage(), scale, dark);
      await tester.tap(find.byTooltip('添加记忆'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '记忆内容'), '新记忆');
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(await MemoryRepository(h.database).watch().first, isEmpty);
      });
      await tester.tap(find.byTooltip('添加记忆'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '记忆内容'),
        '用户选择的长期偏好',
      );
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      expect(find.text('用户选择的长期偏好'), findsOneWidget);
      await tapVisible(tester, find.text('编辑'));
      await tester.enterText(find.widgetWithText(TextField, '记忆内容'), '修改后的偏好');
      await tester.ensureVisible(find.text('保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      expect(find.text('修改后的偏好'), findsOneWidget);
      await tapVisible(tester, find.text('删除'));
      expect(find.text('删除记忆？'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(await MemoryRepository(h.database).watch().first, isEmpty);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('输入栏模式显式切换且触区无溢出 $size $scale', (tester) async {
      late ToolLoopHarness h;
      await tester.runAsync(() async {
        h = await ToolLoopHarness.create(registry: ToolRegistry([]));
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await pumpPage(
        tester,
        h,
        const Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: ChatInputBar()),
        ),
        scale,
        dark,
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-agent-mode')));
      await tester.pumpAndSettle();
      expect(find.text('计划模式'), findsOneWidget);
      expect(
        h.container.read(conversationPermissionsProvider).value!.mode,
        PermissionMode.basic,
      );
      await tester.tap(find.byKey(const ValueKey('permission-mode-plan')));
      await tester.pumpAndSettle();
      expect(
        h.container.read(conversationPermissionsProvider).value!.mode,
        PermissionMode.plan,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
