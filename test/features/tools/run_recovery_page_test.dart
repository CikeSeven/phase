import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/app.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/features/settings/theme_mode_controller.dart';
import 'package:phase/features/tools/run_recovery_controller.dart';
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
    testWidgets('启动可达核验入口，取消不改变记录，保存后继续不重做 ${dark ? '深色窄屏' : '浅色'}', (
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
      expect(
        h.container
            .read(runRecoveryControllerProvider)
            .requireValue
            .single
            .needsVerification,
        isTrue,
      );
      expect(h.provider.requests, isEmpty);
      await tester.tap(find.byKey(const ValueKey('open-recovered-runs')));
      await settleRecovery(tester);
      expect(find.byType(RunRecoveryPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      final verify = find.byKey(const ValueKey('verify-tool-record-0'));
      await tester.ensureVisible(verify);
      await tester.tap(verify);
      await settleRecovery(tester);
      await tester.ensureVisible(find.text('取消'));
      await tester.tap(find.text('取消'));
      await settleRecovery(tester);
      expect(
        (await h.recordsByCall())['call-0']!.status,
        ToolCallStatus.unknown,
      );

      await tester.tap(verify);
      await settleRecovery(tester);
      final status = find.byKey(const ValueKey('verification-status'));
      await tester.ensureVisible(status);
      await tester.tap(status);
      await settleRecovery(tester);
      await tester.tap(find.text('已确认成功').last);
      await settleRecovery(tester);
      final result = find.byKey(const ValueKey('verification-result'));
      await tester.ensureVisible(result);
      await tester.enterText(result, '已人工检查目标文件');
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-verification')),
      );
      await tester.tap(find.byKey(const ValueKey('save-verification')));
      await settleRecovery(tester);
      expect(
        (await h.recordsByCall())['call-0']!.status,
        ToolCallStatus.succeeded,
      );
      h.provider.turns.add(textTurn('核验后继续'));
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
