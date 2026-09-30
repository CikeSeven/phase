import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_motion.dart';
import 'package:phase/core/theme/app_radius.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_dropdown.dart';
import 'package:phase/core/widgets/app_sheet.dart';

enum _Sort { name, installedAt, size }

void main() {
  const dropdownKey = ValueKey('sort-dropdown');
  final dropdown = find.byKey(dropdownKey);

  Future<void> pump(
    WidgetTester tester, {
    bool dark = false,
    bool reduced = false,
    double scale = 1,
    Size size = const Size(320, 800),
    ValueChanged<_Sort>? onChanged,
    VoidCallback? onOutside,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var selected = _Sort.name;
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextButton(
                    onPressed: onOutside ?? () {},
                    child: const Text('外部操作'),
                  ),
                  const SizedBox(height: 24),
                  StatefulBuilder(
                    builder: (context, update) => AppDropdown(
                      key: dropdownKey,
                      label: '排序',
                      value: selected,
                      options: const {
                        _Sort.name: '名称',
                        _Sort.installedAt: '安装时间（新到旧）',
                        _Sort.size: '安装包大小（大到小）',
                      },
                      onChanged: (value) {
                        update(() => selected = value);
                        onChanged?.call(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Expressive 下拉保留选中语义、完整长标签和可达触区 $dark $scale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          final changes = <_Sort>[];
          await pump(tester, dark: dark, scale: scale, onChanged: changes.add);
          await tester.tap(dropdown);
          await tester.pumpAndSettle();
          expect(tester.testTextInput.isVisible, isFalse);
          final current = find.widgetWithText(MenuItemButton, '名称');
          expect(
            tester
                .getSemantics(current)
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            Tristate.isTrue,
          );
          for (final element in find.byType(MenuItemButton).evaluate()) {
            final rect = tester.getRect(find.byWidget(element.widget));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(320));
            expect(rect.height, greaterThanOrEqualTo(56));
          }
          final selectedMaterial = find
              .descendant(of: current, matching: find.byType(Material))
              .first;
          expect(
            (tester.widget<Material>(selectedMaterial).shape!
                    as RoundedRectangleBorder)
                .borderRadius,
            AppRadius.largeAll,
          );
          final press = await tester.startGesture(tester.getCenter(current));
          await tester.pump(AppMotion.effects);
          expect(
            (tester.widget<Material>(selectedMaterial).shape!
                    as RoundedRectangleBorder)
                .borderRadius,
            AppRadius.smallAll,
          );
          await press.cancel();
          await tester.pumpAndSettle();
          final size = find.widgetWithText(MenuItemButton, '安装包大小（大到小）');
          await tester.ensureVisible(size);
          await tester.tap(size);
          await tester.pumpAndSettle();
          expect(changes, [_Sort.size]);
          expect(find.byType(MenuItemButton), findsNothing);
          expect(find.text('安装包大小（大到小）'), findsOneWidget);
          await tester.tap(dropdown);
          await tester.pumpAndSettle();
          expect(
            tester
                .getSemantics(find.widgetWithText(MenuItemButton, '安装包大小（大到小）'))
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            Tristate.isTrue,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets('点击菜单外只关闭菜单，不触发底层动作或修改选择', (tester) async {
    var outside = 0;
    final changes = <_Sort>[];
    await pump(tester, onOutside: () => outside++, onChanged: changes.add);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('外部操作'));
    await tester.pumpAndSettle();
    expect(outside, 0);
    expect(changes, isEmpty);
    expect(find.byType(MenuItemButton), findsNothing);
    await tester.tap(find.text('外部操作'));
    expect(outside, 1);
  });

  testWidgets('键盘开启、方向键选择与 Escape 取消，不唤起软键盘', (tester) async {
    final changes = <_Sort>[];
    await pump(tester, onChanged: changes.add);
    final anchor = tester.widget<InkWell>(
      find.descendant(of: dropdown, matching: find.byType(InkWell)).first,
    );
    anchor.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(3));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changes, [_Sort.installedAt]);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(changes, hasLength(1));
  });

  testWidgets('短屏大字菜单可滚动，减少动画立即生效', (tester) async {
    final changes = <_Sort>[];
    await pump(
      tester,
      reduced: true,
      scale: 2,
      size: const Size(640, 320),
      onChanged: changes.add,
    );
    await tester.tap(dropdown);
    await tester.pump();
    expect(
      tester.widget<MenuAnchor>(find.byType(MenuAnchor)).animated,
      isFalse,
    );
    final size = find.widgetWithText(MenuItemButton, '安装包大小（大到小）');
    await tester.ensureVisible(size);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MenuItemButton>(size).style!.animationDuration,
      Duration.zero,
    );
    await tester.tap(size);
    await tester.pumpAndSettle();
    expect(changes, [_Sort.size]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('菜单快速开关可反向，展开时销毁组件不遗留导航状态', (tester) async {
    await pump(tester);
    final anchor = tester.widget<InkWell>(
      find.descendant(of: dropdown, matching: find.byType(InkWell)).first,
    );
    anchor.onTap!();
    await tester.pump(const Duration(milliseconds: 40));
    anchor.onTap!();
    await tester.pump(const Duration(milliseconds: 20));
    anchor.onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('系统返回先关闭下拉，第二次才取消所属面板', (tester) async {
    var selected = _Sort.name;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                await showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => AppSheet(
                    title: '选择项目',
                    child: StatefulBuilder(
                      builder: (context, update) => AppDropdown(
                        key: dropdownKey,
                        label: '排序',
                        value: selected,
                        options: const {_Sort.name: '名称', _Sort.size: '大小'},
                        onChanged: (value) => update(() => selected = value),
                      ),
                    ),
                  ),
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.byType(AppSheet), findsOneWidget);
    expect(closed, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(selected, _Sort.name);
  });
}
