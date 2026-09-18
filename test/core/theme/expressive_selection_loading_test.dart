import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_loading_indicator/loading_indicator.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:phase/core/theme/app_motion.dart';
import 'package:phase/core/theme/app_radius.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_choice_chip.dart';
import 'package:phase/core/widgets/app_interactive_surface.dart';
import 'package:phase/core/widgets/app_loading_indicator.dart';

void main() {
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('${theme.brightness} 选择片大字换行、取消不改选、键盘切换且禁用不提交', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      var selected = false;
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Wrap(
                      children: [
                        AppChoiceChip(
                          label: '允许工具调用和图片输入',
                          icon: Symbols.build,
                          selected: selected,
                          onSelected: enabled
                              ? (value) => setState(() => selected = value)
                              : null,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      final chip = find.byType(AppChoiceChip);
      final rect = tester.getRect(chip);
      expect(rect.width, lessThanOrEqualTo(288));
      expect(rect.height, greaterThanOrEqualTo(48));
      final press = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 150));
      await press.cancel();
      await tester.pumpAndSettle();
      expect(selected, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(find.byIcon(Symbols.check_circle), findsOneWidget);
      expect(tester.getRect(chip), rect);
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text('允许工具调用和图片输入')),
        matchesSemantics(
          label: '允许工具调用和图片输入',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          isFocused: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      update(() => enabled = false);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('普通入口按压收敛、取消恢复且不声明选择状态', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppInteractiveSurface(
            radius: AppRadius.extraLarge,
            onTap: () => calls++,
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Text('打开设置'),
            ),
          ),
        ),
      ),
    );
    final entry = find.byType(AppInteractiveSurface);
    final rect = tester.getRect(entry);
    final press = await tester.startGesture(rect.center);
    await tester.pumpAndSettle();
    Material surface() => tester.widget<Material>(
      find.descendant(of: entry, matching: find.byType(Material)),
    );
    expect(surface().borderRadius, AppRadius.smallAll);
    expect(tester.getRect(entry), rect);
    await press.cancel();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(surface().borderRadius, AppRadius.extraLargeAll);
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('打开设置')),
      matchesSemantics(
        label: '打开设置',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('加载指示沿用按钮前景色，减少动画与离屏暂停并保留组件', (tester) async {
    var reduced = false;
    var visible = true;
    late StateSetter update;
    final theme = AppTheme.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: TickerMode(
                enabled: visible,
                child: Scaffold(
                  body: FilledButton.icon(
                    onPressed: () {},
                    icon: const AppLoadingIndicator.small(
                      semanticsLabel: '正在保存',
                    ),
                    label: const Text('保存中'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final indicator = find.byType(LoadingIndicator);
    final state = tester.state(indicator);
    expect(
      tester.widget<LoadingIndicator>(indicator).activeIndicatorColor,
      theme.colorScheme.onPrimary,
    );
    await tester.pump(AppMotion.effects);
    expect(tester.hasRunningAnimations, isTrue);
    update(() => reduced = true);
    await tester.pumpAndSettle();
    expect(TickerMode.valuesOf(tester.element(indicator)).enabled, isFalse);
    expect(tester.hasRunningAnimations, isFalse);
    update(() {
      reduced = false;
      visible = false;
    });
    await tester.pumpAndSettle();
    expect(TickerMode.valuesOf(tester.element(indicator)).enabled, isFalse);
    update(() => visible = true);
    await tester.pump();
    expect(tester.state(indicator), same(state));
    expect(TickerMode.valuesOf(tester.element(indicator)).enabled, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
