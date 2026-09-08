import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/app.dart';
import 'package:phase/core/router/app_router.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/conversation.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // 回归测试：go_router 18 检测不到 Flutter SDK 内置 MaterialApp 时会把路由
  // 退化为 NoTransitionPage（见 app_router.dart 注释），这里守住「跳转必须有动画」。
  testWidgets('路由跳转有过渡动画', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => preferences),
          conversationsProvider.overrideWith(
            (ref) => Stream.value(const <Conversation>[]),
          ),
          providerProfilesProvider.overrideWith(
            (ref) => Stream.value(const <ProviderProfile>[]),
          ),
        ],
        child: const PhaseApp(),
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(Navigator).first);
    final router = ProviderScope.containerOf(element).read(appRouterProvider);
    router.push('/settings');

    await tester.pump();
    expect(
      tester.hasRunningAnimations,
      isTrue,
      reason: 'push /settings 后没有任何正在进行的动画',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpAndSettle();
    expect(find.text('主题模式'), findsOneWidget);

    // 返回同样要有动画。
    router.pop();
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue, reason: 'pop 时没有动画');
    await tester.pumpAndSettle();
    expect(find.text('向相月提问，或选择一个助手'), findsOneWidget);
  });
}
