import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/features/chat/chat_run_banner.dart';
import 'package:phase/features/execution/execution_controller.dart';

import '../tools/tool_loop_harness.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('相月内也能继续用户操作，320dp / 2x 字号 ${dark ? "深色" : "浅色"}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await ToolLoopHarness.create();
      h.provider.turns.addAll([
        toolTurn(
          callId: 'wait',
          toolName: 'wait_for_user',
          arguments: '{"prompt":"请在目标应用完成登录，操作完成后再点击继续。"}',
        ),
        textTurn('操作权已交还'),
      ]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const Scaffold(
                body: SingleChildScrollView(child: ChatRunBanner()),
              ),
            ),
          ),
        ),
      );
      final sending = h.controller().send('请等待我操作');
      await _until(
        tester,
        () => h.container.read(executionControllerProvider).userAction != null,
      );
      await tester.pump();
      expect(find.text('等待你操作 · AI 已暂停'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final button = find.byKey(const ValueKey('continue-user-action'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await _until(tester, () => !h.state().isGenerating);
      await sending;
      await tester.pump();
      expect(find.byKey(const ValueKey('waiting-for-user')), findsNothing);
      expect(h.provider.requests, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 120; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 30));
    if (ready()) return;
  }
  fail('等待用户操作界面切换超时');
}
