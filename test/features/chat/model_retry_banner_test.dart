import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/chat_run_banner.dart';
import 'package:phase/features/chat/model_retry.dart';

class _RetryChat extends ChatController {
  @override
  ChatState build() => const ChatState(
    isGenerating: true,
    retry: ModelRetryState(
      attempt: 1,
      maxRetries: 2,
      delay: Duration(seconds: 2),
    ),
  );

  void settle() => state = const ChatState();
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('自动重试提示 $dark：320dp/2x 字号可换行，收尾后移除', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = _RetryChat();
      final container = ProviderContainer(
        overrides: [chatControllerProvider.overrideWith(() => controller)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: const MediaQuery(
              data: MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(body: ChatRunBanner()),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('model-retry-status')), findsOneWidget);
      expect(find.text('自动重试 1/2 · 等待 2 秒'), findsOneWidget);
      expect(tester.takeException(), isNull);
      controller.settle();
      await tester.pump();
      expect(find.byKey(const ValueKey('model-retry-status')), findsNothing);
    });
  }
}
