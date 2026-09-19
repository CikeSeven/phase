import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_card.dart';
import 'package:phase/core/widgets/app_dialog.dart';
import 'package:phase/core/widgets/app_top_bar.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/features/settings/settings_page.dart';
import 'package:phase/features/settings/theme_mode_controller.dart';
import 'package:phase/features/settings/theme_mode_dialog.dart';
import 'package:phase/features/settings/theme_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('设置首页以单块外观预览为主，服务商轻量入口，品牌只读紧凑', (tester) async {
    final host = await _pumpSettings(tester);
    expect(find.byType(AppCard), findsNothing);
    expect(find.text('外观'), findsNothing);
    expect(find.text('关于'), findsNothing);
    expect(find.byType(AppTopBar).evaluate().single, isNotNull);
    final topBar = tester.widget<AppTopBar>(find.byType(AppTopBar));
    expect(topBar.showDivider, isFalse);
    final appearance = find.ancestor(
      of: find.text('主题模式'),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.borderRadius != null,
      ),
    );
    expect(appearance, findsOneWidget);
    final surface = tester.widget<Material>(appearance);
    expect(surface.shape, isNull);
    final text = tester.widget<Text>(find.text('主题模式'));
    expect(text.style?.fontSize, greaterThanOrEqualTo(16));
    expect(find.text('跟随系统'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(ThemePreview),
      ),
      findsOneWidget,
    );
    final provider = find.text('服务商配置');
    expect(provider, findsOneWidget);
    expect(find.text('执行与权限'), findsOneWidget);
    expect(find.text('扩展'), findsOneWidget);
    expect(find.byIcon(Symbols.chevron_right), findsNWidgets(5));
    expect(find.text('开发预览版'), findsOneWidget);
    expect(find.text('版本 1.0.0+1'), findsOneWidget);
    expect(find.text('你的多模型 AI 对话助手'), findsNothing);
    expect(find.text('管理连接地址、API Key 与模型'), findsNothing);
    final footer = tester.getRect(find.text('版本 1.0.0+1'));
    expect(footer.bottom, lessThanOrEqualTo(844 - 24));
    await _openTheme(tester);
    expect(
      tester.widget<AppDialog>(find.byType(AppDialog)).description,
      isNull,
    );
    for (final phrase in ['随系统变化', '自动适应设备外观', '清透月白', '柔和墨蓝']) {
      expect(find.textContaining(phrase), findsNothing);
    }
    for (final mode in ThemeMode.values) {
      expect(_option(mode), findsOneWidget);
    }
    await _chooseTheme(tester, ThemeMode.dark);
    await _tapVisible(tester, find.byKey(const ValueKey('apply-theme')));
    expect(host.preferences.getString('theme_mode'), 'dark');
  });

  testWidgets('系统、浅色和深色主题均通过预览确认真实切换并持久化', (tester) async {
    final host = await _pumpSettings(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();

    for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
      await _openTheme(tester);
      await _chooseTheme(tester, mode);
      expect(find.byType(AppDialog), findsOneWidget);
      await _tapVisible(tester, find.byKey(const ValueKey('apply-theme')));
      expect(find.byType(ThemeModeDialog), findsNothing);
      expect(host.preferences.getString('theme_mode'), mode.name);
      expect(host.container.read(themeModeControllerProvider), mode);
      expect(
        Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        mode == ThemeMode.light ? Brightness.light : Brightness.dark,
      );
    }

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SettingsPage))).brightness,
      Brightness.light,
    );
    expect(host.preferences.getString('theme_mode'), 'system');
    expect(find.text('主题模式'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('预览选择及取消不会改变已保存主题', (tester) async {
    final host = await _pumpSettings(tester, initialMode: ThemeMode.dark);
    await _openTheme(tester);
    await _chooseTheme(tester, ThemeMode.light);
    expect(host.preferences.getString('theme_mode'), 'dark');
    expect(host.container.read(themeModeControllerProvider), ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(SettingsPage))).brightness,
      Brightness.dark,
    );
    await _tapVisible(tester, find.text('取消'));
    expect(find.byType(ThemeModeDialog), findsNothing);
    expect(host.preferences.getString('theme_mode'), 'dark');

    await _openTheme(tester);
    expect(
      tester.widget<Semantics>(_option(ThemeMode.dark)).properties.selected,
      isTrue,
    );
    await _chooseTheme(tester, ThemeMode.system);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ThemeModeDialog), findsNothing);
    expect(host.preferences.getString('theme_mode'), 'dark');
    expect(tester.takeException(), isNull);
  });

  testWidgets('明暗预览使用 AppTheme 的真实语义色，选项独立排列且间距至少 8dp', (tester) async {
    await _pumpSettings(tester, size: const Size(720, 1100));
    await _openTheme(tester);
    ThemeData swatchTheme(String name) {
      final finder = find.descendant(
        of: find.byType(ThemeModeDialog),
        matching: find.byKey(ValueKey('theme-swatch-$name')),
      );
      final element = tester.element(
        find.descendant(of: finder, matching: find.byType(ColoredBox)).first,
      );
      return Theme.of(element);
    }

    final light = swatchTheme('light');
    final dark = swatchTheme('dark');
    expect(light.colorScheme.surface, AppTheme.light().colorScheme.surface);
    expect(dark.colorScheme.surface, AppTheme.dark().colorScheme.surface);
    expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ThemeModeDialog),
        matching: find.byType(ListTile),
      ),
      findsNothing,
    );
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final previous = mode == ThemeMode.light
          ? ThemeMode.system
          : ThemeMode.light;
      expect(
        tester.getRect(_option(mode)).top -
            tester.getRect(_option(previous)).bottom,
        greaterThanOrEqualTo(8),
      );
    }
    for (final theme in [light, dark]) {
      expect(
        _contrast(theme.colorScheme.onSurface, theme.colorScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('品牌和版本信息如实显示，服务商入口跳转现有路径', (tester) async {
    final host = await _pumpSettings(tester);
    expect(find.text('相月'), findsOneWidget);
    expect(find.text('你的多模型 AI 对话助手'), findsNothing);
    expect(find.text('主题模式').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.text('版本 1.0.0+1'));
    await tester.pumpAndSettle();
    expect(find.text('开发预览版'), findsOneWidget);
    expect(find.textContaining('0.1.0'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    await _tapVisible(tester, find.text('服务商配置'));
    expect(find.text('服务商配置目的页'), findsOneWidget);
    expect(
      GoRouterState.of(tester.element(find.text('服务商配置目的页'))).uri.path,
      '/settings/providers',
    );
    expect(host.router.canPop(), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(320, 760), scale: 1.3, keyboard: 0.0),
    (size: const Size(360, 800), scale: 1.3, keyboard: 0.0),
    (size: const Size(320, 760), scale: 2.0, keyboard: 0.0),
    (size: const Size(360, 800), scale: 2.0, keyboard: 0.0),
    (size: const Size(800, 360), scale: 2.0, keyboard: 160.0),
  ]) {
    testWidgets('窄屏/键盘可滚动选择、应用和取消主题：$scenario', (tester) async {
      final host = await _pumpSettings(
        tester,
        size: scenario.size,
        scale: scenario.scale,
        keyboard: scenario.keyboard,
        initialMode: ThemeMode.light,
      );
      await _openTheme(tester);
      await _chooseTheme(tester, ThemeMode.dark);
      expect(host.preferences.getString('theme_mode'), 'light');
      await _tapVisible(tester, find.byKey(const ValueKey('apply-theme')));
      expect(host.preferences.getString('theme_mode'), 'dark');
      expect(find.byType(ThemeModeDialog), findsNothing);
      expect(tester.takeException(), isNull);

      await _openTheme(tester);
      await _chooseTheme(tester, ThemeMode.light);
      await _tapVisible(tester, find.text('取消'));
      expect(host.preferences.getString('theme_mode'), 'dark');
      expect(find.byType(ThemeModeDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

Finder _option(ThemeMode mode) =>
    find.byKey(ValueKey('theme-option-${mode.name}'));

Future<void> _openTheme(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('主题模式'),
    120,
    scrollable: find
        .descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.text('主题模式'));
}

Future<void> _chooseTheme(WidgetTester tester, ThemeMode mode) async {
  await _tapVisible(
    tester,
    find.descendant(
      of: _option(mode),
      matching: find.text(themeModeLabel(mode)),
    ),
  );
  expect(tester.widget<Semantics>(_option(mode)).properties.selected, isTrue);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  if (finder.hitTestable().evaluate().isNotEmpty) {
    await tester.tap(finder);
  } else {
    // 极矮视口（键盘 + 大字号 + 横屏）下元素可能高于视口，中心点永远
    // 不可见；ensureVisible 顶对齐后点击其可见顶部。
    final rect = tester.getRect(finder);
    await tester.tapAt(Offset(rect.center.dx, rect.top + 8));
  }
  await tester.pumpAndSettle();
}

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
}

Future<
  ({
    SharedPreferences preferences,
    ProviderContainer container,
    GoRouter router,
  })
>
_pumpSettings(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  double keyboard = 0,
  ThemeMode initialMode = ThemeMode.system,
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
  SharedPreferences.setMockInitialValues({'theme_mode': initialMode.name});
  final preferences = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/settings/providers',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('服务商配置目的页'))),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWith((ref) => preferences)],
      child: _SettingsTestApp(router: router, scale: scale),
    ),
  );
  await tester.pumpAndSettle();
  return (
    preferences: preferences,
    container: ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    ),
    router: router,
  );
}

class _SettingsTestApp extends ConsumerWidget {
  const _SettingsTestApp({required this.router, required this.scale});

  final GoRouter router;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeControllerProvider),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      routerConfig: router,
    );
  }
}
