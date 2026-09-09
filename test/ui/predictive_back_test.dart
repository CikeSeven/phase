import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/app.dart';
import 'package:phase/core/router/app_router.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/conversation.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('预测性返回在拖动中更新路由，可取消，也可提交返回', (tester) async {
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
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    final router = container.read(appRouterProvider);
    router.push('/settings');
    await tester.pumpAndSettle();
    final route =
        ModalRoute.of(tester.element(find.byType(SettingsPage)))!
            as PageRoute<void>;
    expect(route.popGestureEnabled, isTrue);

    expect(await _backEvent(tester, 'startBackGesture', progress: 0), isTrue);
    await _backEvent(tester, 'updateBackGestureProgress', progress: 0.55);
    await tester.pump();
    expect(route.popGestureInProgress, isTrue);
    expect(route.animation!.value, lessThan(1));
    expect(route.animation!.value, greaterThan(0));

    await _backEvent(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(route.popGestureInProgress, isFalse);
    expect(route.animation!.value, 1);
    expect(find.text('主题模式'), findsOneWidget);

    expect(await _backEvent(tester, 'startBackGesture', progress: 0), isTrue);
    await _backEvent(tester, 'updateBackGestureProgress', progress: 0.7);
    await tester.pump();
    await _backEvent(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('向相月提问，或选择一个助手'), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('真实侧栏进入设置后预测返回不丢失侧栏状态', (tester) async {
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

    await tester.tap(find.byTooltip('打开会话列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    final route =
        ModalRoute.of(tester.element(find.byType(SettingsPage)))!
            as PageRoute<void>;
    expect(route.popGestureEnabled, isTrue);

    expect(await _backEvent(tester, 'startBackGesture', progress: 0), isTrue);
    await _backEvent(tester, 'updateBackGestureProgress', progress: 0.55);
    await tester.pump();
    expect(route.popGestureInProgress, isTrue);
    await _backEvent(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    expect(await _backEvent(tester, 'startBackGesture', progress: 0), isTrue);
    await _backEvent(tester, 'updateBackGestureProgress', progress: 0.7);
    await tester.pump();
    await _backEvent(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byType(Drawer), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('向相月提问，或选择一个助手'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<Object?> _backEvent(
  WidgetTester tester,
  String method, {
  double? progress,
}) async {
  final result = Completer<Object?>();
  const codec = StandardMethodCodec();
  final data = codec.encodeMethodCall(
    MethodCall(
      method,
      progress == null
          ? null
          : <String, Object>{
              'touchOffset': <double>[progress * 240, 320],
              'progress': progress,
              'swipeEdge': 0,
            },
    ),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.backGesture.name,
    data,
    (reply) =>
        result.complete(reply == null ? null : codec.decodeEnvelope(reply)),
  );
  return result.future;
}
