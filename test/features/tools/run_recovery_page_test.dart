import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/app.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/features/settings/theme_mode_controller.dart';
import 'package:phase/features/tools/run_recovery_page.dart';
import 'package:phase/features/tools/tool.dart';

import 'run_recovery_fixture.dart';
import 'tool_loop_harness.dart';

Future<void> settleRecovery(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 30));
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('中断任务直接继续，无结果核验入口且不重发已派发调用 ${dark ? '深色窄屏' : '浅色'}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(dark ? 320 : 360, 800);
      tester.platformDispatcher.textScaleFactorTestValue = dark ? 2 : 1;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final echo = RecordingTool(name: 'echo');
      final h = await ToolLoopHarness.create(registry: ToolRegistry([echo]));
      final run = (await tester.runAsync(
        () => seedInterrupted(h, [ToolCallStatus.executing]),
      ))!;
      await h.container
          .read(themeModeControllerProvider.notifier)
          .setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const PhaseApp(),
        ),
      );
      await settleRecovery(tester);
      expect(h.provider.requests, isEmpty);
      await tester.tap(find.byKey(const ValueKey('open-recovered-runs')));
      await settleRecovery(tester);
      expect(find.byType(RunRecoveryPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('核验结果'), findsNothing);
      expect(find.byKey(const ValueKey('verification-status')), findsNothing);
      expect(
        (await h.recordsByCall())['call-0']!.status,
        ToolCallStatus.failed,
      );
      h.provider.turns.add(textTurn('由 AI 处理已返回的错误'));
      final resume = find.byKey(ValueKey('resume-run-${run.id}'));
      await tester.ensureVisible(resume);
      await tester.tap(resume);
      for (var i = 0; i < 40 && h.state().isGenerating; i++) {
        await settleRecovery(tester);
      }
      await settleRecovery(tester);
      expect(h.state().isGenerating, isFalse);
      expect(echo.executions, isEmpty);
      expect(h.provider.requests, hasLength(1));
      AgentRun? stored;
      final reading = h
          .runs()
          .then((repository) => repository.getById(run.id))
          .then((value) => stored = value);
      for (var i = 0; i < 20 && stored == null; i++) {
        await settleRecovery(tester);
      }
      expect(stored?.status, RunStatus.completed);
      await reading;
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await settleRecovery(tester);
    });
  }
}
