import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_icon_badge.dart';
import 'package:phase/core/widgets/app_scaffold.dart';
import 'package:phase/features/assistants/assistants_page.dart';

void main() {
  testWidgets('助手无冗余未来说明，保留即将上线状态与真实返回', (tester) async {
    final router = await _pumpHost(tester);
    await tester.tap(find.text('打开助手'));
    await tester.pumpAndSettle();
    expect(find.byType(AppScaffold), findsOneWidget);
    expect(find.byType(AppIconBadge), findsOneWidget);
    expect(find.text('助手功能即将上线'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.textContaining('系统提示词（system prompt）与任务模板'), findsNothing);
    expect(find.textContaining('现在，先与已配置的模型'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('创建助手'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.text('返回对话'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('对话目的页'), findsOneWidget);
    expect(find.byType(AssistantsPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(320, 760), scale: 1.3, keyboard: 0.0, dark: false),
    (size: const Size(360, 800), scale: 1.3, keyboard: 0.0, dark: true),
    (size: const Size(320, 760), scale: 2.0, keyboard: 0.0, dark: true),
    (size: const Size(360, 800), scale: 2.0, keyboard: 0.0, dark: false),
    (size: const Size(800, 360), scale: 2.0, keyboard: 160.0, dark: true),
  ]) {
    testWidgets('助手空态在窄屏/短窗口可滚动返回：$scenario', (tester) async {
      final router = await _pumpHost(
        tester,
        size: scenario.size,
        scale: scenario.scale,
        keyboard: scenario.keyboard,
        dark: scenario.dark,
        initialLocation: '/assistants',
      );
      expect(find.text('助手功能即将上线'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('返回对话'));
      await tester.pumpAndSettle();
      expect(find.text('返回对话').hitTestable(), findsOneWidget);
      await tester.tap(find.text('返回对话'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.text('对话目的页'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<GoRouter> _pumpHost(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  double keyboard = 0,
  bool dark = false,
  String initialLocation = '/',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.padding = FakeViewPadding(
    top: 24,
    bottom: keyboard == 0 ? 24 : 0,
  );
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('对话目的页'),
                TextButton(
                  onPressed: () => context.push('/assistants'),
                  child: const Text('打开助手'),
                ),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/assistants',
        builder: (context, state) => const AssistantsPage(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
