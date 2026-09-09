import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/theme/brand_colors.dart';
import 'package:phase/core/widgets/app_background.dart';
import 'package:phase/core/widgets/app_bottom_bar.dart';
import 'package:phase/core/widgets/app_card.dart';
import 'package:phase/core/widgets/app_empty_state.dart';
import 'package:phase/core/widgets/app_icon_badge.dart';
import 'package:phase/core/widgets/app_scaffold.dart';
import 'package:phase/core/widgets/app_section.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
    ('plain', ThemeData()),
    ('plain-dark', ThemeData(brightness: Brightness.dark)),
  ]) {
    for (final (width, scale) in [(320.0, 2.0), (360.0, 1.3)]) {
      testWidgets('$name ${width}dp ${scale}x 页面、卡片和分区窄屏交互', (tester) async {
        var tapped = 0;
        await _pumpPage(
          tester,
          size: Size(width, 760),
          theme: theme,
          textScale: scale,
          home: Builder(
            builder: (context) => AppScaffold(
              title: '服务商与模型管理的长页面标题',
              subtitle: '说明仅占一行，不挤占操作空间',
              actions: [
                IconButton(
                  tooltip: '新增服务商',
                  onPressed: () {},
                  icon: const Icon(Symbols.add),
                ),
              ],
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppSection(
                    title: '连接与模型配置',
                    subtitle: '保存真实配置后才开始使用',
                    action: TextButton(
                      onPressed: () {},
                      child: const Text('管理全部模型'),
                    ),
                    child: AppCard(
                      tint: context.brandColors.teal,
                      onTap: () => tapped++,
                      child: const Row(
                        children: [
                          AppIconBadge(icon: Symbols.hub, tone: AppTone.teal),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'example-provider/very-long-model-name-with-reasoning',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppBadge(label: '当前默认模型'),
                      AppBadge(label: '连接功能', tone: AppTone.teal),
                      AppBadge(label: '推理与次级信息', tone: AppTone.lavender),
                      AppBadge(label: '置顶', tone: AppTone.gold),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        expect(find.byType(AppBackground), findsOneWidget);
        expect(find.byType(IgnorePointer), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(AppCard));
        await tester.tap(find.byType(AppCard));
        await tester.pump();
        expect(tapped, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
    ('plain', ThemeData()),
  ]) {
    testWidgets('$name 空状态在小高度和大文字下能滚到真实操作', (tester) async {
      var opened = false;
      await _pumpPage(
        tester,
        size: const Size(320, 300),
        textScale: 2,
        theme: theme,
        home: Scaffold(
          body: AppEmptyState(
            icon: Symbols.chat_bubble,
            title: '开始一段新的对话',
            message: '先添加服务商与真实模型。这里不展示虚构的连接、用量或助手。',
            tone: AppTone.gold,
            action: FilledButton(
              onPressed: () => opened = true,
              child: const Text('配置服务商'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('配置服务商'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('配置服务商'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final keyboard in [0.0, 280.0]) {
    for (final wrapped in [false, true]) {
      testWidgets('固定底栏 keyboard=$keyboard wrapped=$wrapped 安全区只占一次', (
        tester,
      ) async {
        const footer = SizedBox(height: 48, key: ValueKey('footer'));
        await _pumpPage(
          tester,
          size: const Size(360, 640),
          keyboard: keyboard,
          theme: AppTheme.light(),
          home: AppScaffold(
            title: '编辑',
            body: const SizedBox.expand(key: ValueKey('body')),
            bottomBar: wrapped ? const AppBottomBar(child: footer) : footer,
          ),
        );
        final body = tester.getRect(find.byKey(const ValueKey('body')));
        final bar = tester.getRect(find.byType(AppBottomBar));
        final content = tester.getRect(find.byKey(const ValueKey('footer')));
        expect(body.top, closeTo(24 + 64, 0.01));
        expect(body.bottom, closeTo(bar.top, 0.01));
        expect(bar.bottom, closeTo(640 - keyboard, 0.01));
        expect(
          content.bottom,
          closeTo(640 - keyboard - (keyboard == 0 ? 24 : 0) - 16, 0.01),
        );
        expect(find.byType(AppBottomBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('宽屏 body 限宽且无底栏时保留底部安全区', (tester) async {
    await _pumpPage(
      tester,
      size: const Size(1000, 700),
      home: const AppScaffold(
        title: '设置',
        body: SizedBox.expand(key: ValueKey('body')),
      ),
    );
    final body = tester.getRect(find.byKey(const ValueKey('body')));
    expect(body.width, 720);
    expect(body.left, 140);
    expect(body.bottom, 700 - 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('顶栏分隔线默认保留，页面可显式关闭', (tester) async {
    const defaultBar = AppTopBar(title: Text('默认'));
    const defaultScaffold = AppScaffold(title: '默认', body: SizedBox.shrink());
    expect(defaultBar.showDivider, isTrue);
    expect(defaultScaffold.showAppBarDivider, isTrue);

    await _pumpPage(
      tester,
      size: const Size(360, 640),
      home: const AppScaffold(
        title: '无分隔线',
        showAppBarDivider: false,
        body: SizedBox.shrink(),
      ),
    );
    final bar = tester.widget<AppTopBar>(find.byType(AppTopBar));
    expect(bar.showDivider, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('普通 MaterialApp 中顶栏返回与背景后的操作均可点击', (tester) async {
    await _pumpPage(
      tester,
      size: const Size(360, 640),
      home: Builder(
        builder: (context) => AppScaffold(
          title: '主页',
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      const AppScaffold(title: '第二页', body: Text('可返回的内容')),
                ),
              ),
              child: const Text('打开第二页'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开第二页'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Symbols.arrow_back), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('主页'), findsOneWidget);
    expect(find.text('可返回的内容'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required Widget home,
  required Size size,
  ThemeData? theme,
  double textScale = 1,
  double keyboard = 0,
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
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}
