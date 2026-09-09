import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/theme/frosted_surface.dart';
import 'package:phase/core/widgets/app_dialog.dart';
import 'package:phase/core/widgets/app_icon_badge.dart';
import 'package:phase/core/widgets/app_sheet.dart';

void main() {
  for (final (name, size, scale, keyboard, theme) in [
    ('窄屏浅色', const Size(320, 640), 1.3, 0.0, AppTheme.light()),
    ('窄屏深色大文字', const Size(360, 720), 2.0, 0.0, AppTheme.dark()),
    ('横屏键盘', const Size(640, 360), 2.0, 140.0, AppTheme.dark()),
    ('普通 MaterialApp', const Size(320, 640), 2.0, 240.0, ThemeData()),
  ]) {
    testWidgets('$name 弹窗可滚动输入并提交，动作间距与宽度符合规范', (tester) async {
      var confirmed = false;
      await _pumpHost(
        tester,
        size: size,
        scale: scale,
        keyboard: keyboard,
        theme: theme,
        open: (context) => showDialog<void>(
          context: context,
          builder: (dialogContext) => AppDialog(
            title: '添加真实服务商的模型',
            description: '长模型标识也可完整输入。填写后才执行保存，不虚构任何验证结果。',
            icon: Symbols.hub,
            tone: AppTone.teal,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 5; i++) ...[
                  TextField(
                    key: ValueKey('field-$i'),
                    decoration: InputDecoration(labelText: '配置字段 $i'),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('暂时取消'),
              ),
              FilledButton(
                onPressed: () {
                  confirmed = true;
                  Navigator.pop(dialogContext);
                },
                child: const Text('确认保存配置'),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final surface = tester.getRect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.byType(FrostedSurface),
        ),
      );
      expect(surface.width, lessThanOrEqualTo(440));
      expect(surface.left, greaterThanOrEqualTo(24));
      expect(surface.right, lessThanOrEqualTo(size.width - 24));
      expect(
        surface.bottom,
        lessThanOrEqualTo(size.height - keyboard - 24 + 0.1),
      );
      final actions = tester.widget<OverflowBar>(find.byType(OverflowBar));
      expect(actions.spacing, 8);
      expect(actions.overflowSpacing, 8);
      await tester.ensureVisible(find.byKey(const ValueKey('field-4')));
      await tester.enterText(
        find.byKey(const ValueKey('field-4')),
        'custom/model-2026',
      );
      await tester.pumpAndSettle();
      expect(find.text('custom/model-2026'), findsOneWidget);
      await tester.ensureVisible(find.text('确认保存配置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认保存配置'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      expect(find.byType(AppDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('弹窗惰性列表获得有界视口，不需要 intrinsic 或 shrinkWrap', (tester) async {
    var built = 0;
    var selected = -1;
    await _pumpHost(
      tester,
      size: const Size(360, 720),
      theme: AppTheme.light(),
      open: (context) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AppDialog(
          title: '选择模型',
          scrollableContent: true,
          content: ListView.builder(
            itemCount: 500,
            itemBuilder: (context, index) {
              built++;
              return ListTile(
                title: Text('候选模型 $index'),
                onTap: () {
                  selected = index;
                  Navigator.pop(dialogContext);
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(built, lessThan(50));
    expect(find.text('候选模型 499'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('候选模型 20'),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('候选模型 20'));
    await tester.pumpAndSettle();
    expect(selected, 20);
    expect(tester.takeException(), isNull);
  });

  for (final (name, size, scale, keyboard, theme) in [
    ('浅色标准', const Size(360, 760), 1.0, 0.0, AppTheme.light()),
    ('深色窄屏', const Size(320, 680), 2.0, 0.0, AppTheme.dark()),
    ('横屏键盘', const Size(640, 360), 2.0, 120.0, AppTheme.dark()),
    ('极短横屏', const Size(640, 320), 2.0, 180.0, AppTheme.dark()),
    ('普通主题', const Size(360, 720), 1.3, 0.0, ThemeData()),
  ]) {
    testWidgets('$name 底部面板支持真实搜索、惰性列表及可达确认操作', (tester) async {
      var built = 0;
      var confirmed = false;
      await _pumpHost(
        tester,
        size: size,
        scale: scale,
        keyboard: keyboard,
        theme: theme,
        open: (context) => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Theme.of(context).colorScheme.surface
              .withValues(alpha: 0),
          builder: (sheetContext) => AppSheet(
            title: '选择模型与推理能力',
            subtitle: '保留手动模型与原有设置',
            footer: FilledButton(
              key: const ValueKey('sheet-confirm'),
              onPressed: () {
                confirmed = true;
                Navigator.pop(sheetContext);
              },
              child: const Text('确认选择'),
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: TextField(
                    key: ValueKey('search'),
                    decoration: InputDecoration(hintText: '搜索模型'),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: 1000,
                    itemBuilder: (context, index) {
                      built++;
                      return ListTile(title: Text('远端模型 $index'));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final surfaceFinder = find.descendant(
        of: find.byType(AppSheet),
        matching: find.byType(FrostedSurface),
      );
      final surface = tester.getRect(surfaceFinder);
      expect(surface.width, lessThanOrEqualTo(720));
      expect(surface.width, lessThanOrEqualTo(size.width));
      expect(
        surface.height,
        lessThanOrEqualTo((size.height - keyboard) * 0.85 + 0.1),
      );
      expect(surface.bottom, closeTo(size.height - keyboard, 0.1));
      expect(built, lessThan(50));
      expect(find.text('远端模型 999'), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('search')));
      await tester.enterText(find.byKey(const ValueKey('search')), 'model');
      await tester.pumpAndSettle();
      expect(find.text('model'), findsOneWidget);
      if (scale == 1) {
        final footerTop = tester
            .getTopLeft(find.byKey(const ValueKey('sheet-confirm')))
            .dy;
        await tester.scrollUntilVisible(
          find.text('远端模型 20'),
          300,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('sheet-confirm'))).dy,
          footerTop,
        );
      }
      await tester.ensureVisible(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet-confirm')));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      expect(find.byType(AppSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('面板静态表单在极短视口下由内部整体滚动，关闭仍可达', (tester) async {
    await _pumpHost(
      tester,
      size: const Size(640, 320),
      scale: 2,
      keyboard: 150,
      theme: ThemeData(),
      open: (context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface
            .withValues(alpha: 0),
        builder: (context) => AppSheet(
          title: '编辑配置',
          scrollableChild: false,
          child: Column(
            children: List.generate(20, (index) => Text('表单说明 $index')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('表单说明 19'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required Size size,
  required Future<void> Function(BuildContext context) open,
  ThemeData? theme,
  double scale = 1,
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
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => open(context),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
