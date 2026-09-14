import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:phase/core/theme/app_control_style.dart';
import 'package:phase/core/theme/app_motion.dart';
import 'package:phase/core/theme/app_radius.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_selection_surface.dart';

void main() {
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('${theme.brightness} 按钮按压形变但触区不动，释放才执行', (tester) async {
      var calls = 0;
      await _pumpHost(
        tester,
        theme: theme,
        child: FilledButton(
          onPressed: () => calls++,
          child: const Text('确认选择'),
        ),
      );
      final button = find.byType(FilledButton);
      final rect = tester.getRect(button);
      expect(rect.height, AppControlStyle.mediumHeight);
      expect(_material(tester, button).shape, isA<StadiumBorder>());
      final press = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(AppMotion.effects);
      expect(calls, 0);
      expect(tester.getRect(button), rect);
      expect(
        (_material(tester, button).shape! as RoundedRectangleBorder)
            .borderRadius,
        AppRadius.controlAll,
      );
      await press.up();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(_material(tester, button).shape, isA<StadiumBorder>());

      await _pumpHost(
        tester,
        theme: theme,
        child: const FilledButton(onPressed: null, child: Text('保存中')),
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(_material(tester, button).shape, isA<StadiumBorder>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('${theme.brightness} 窄屏大字按钮可换行，滑杆仍选择原来的离散值', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 700);
      addTearDown(tester.view.reset);
      var value = 0.0;
      await _pumpHost(
        tester,
        theme: theme,
        scale: 2,
        child: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(onPressed: () {}, child: const Text('确认并保存当前配置')),
              Slider(
                value: value,
                max: 4,
                divisions: 4,
                label: '$value',
                onChanged: (next) => setState(() => value = next),
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(FilledButton)).width,
        lessThanOrEqualTo(280),
      );
      expect(theme.sliderTheme.thumbShape, isA<HandleThumbShape>());
      expect(theme.sliderTheme.trackShape, isA<GappedSliderTrackShape>());
      final track = tester.getRect(find.byType(Slider));
      await tester.tapAt(Offset(track.right - 25, track.center.dy));
      await tester.pumpAndSettle();
      expect(value, 4);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('图标按钮保留选中语义与键盘激活，选中形状不同于普通态', (tester) async {
    var calls = 0;
    await _pumpHost(
      tester,
      child: IconButton.filledTonal(
        isSelected: true,
        tooltip: '选中项',
        onPressed: () => calls++,
        icon: const Icon(Symbols.check),
      ),
    );
    final button = find.byType(IconButton);
    expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(48));
    expect(
      (_material(tester, button).shape! as RoundedRectangleBorder).borderRadius,
      AppRadius.controlAll,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选择面弹簧响应快速改选、取消按压，布局稳定且卸载释放动画', (tester) async {
    var selected = false;
    late StateSetter update;
    await _pumpHost(
      tester,
      child: StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return AppSelectionSurface(
            selected: selected,
            onTap: () => setState(() => selected = !selected),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择模型'),
            ),
          );
        },
      ),
    );
    final surface = find.byType(AppSelectionSurface);
    final rect = tester.getRect(surface);
    expect(_material(tester, surface).borderRadius, AppRadius.mediumAll);
    final press = await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 50));
    expect(selected, isFalse);
    expect(_material(tester, surface).borderRadius, isNot(AppRadius.mediumAll));
    await press.cancel();
    await tester.pumpAndSettle();
    expect(selected, isFalse);
    expect(_material(tester, surface).borderRadius, AppRadius.mediumAll);

    update(() => selected = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    update(() => selected = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    update(() => selected = true);
    await tester.pumpAndSettle();
    expect(tester.getRect(surface), rect);
    expect(_material(tester, surface).borderRadius, AppRadius.largeAll);
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('选择模型')),
      matchesSemantics(
        label: '选择模型',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();

    update(() => selected = false);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final accessible in [false, true]) {
    testWidgets('减少动画（accessibleNavigation: $accessible）立即改变形状并保留主题', (
      tester,
    ) async {
      var selected = false;
      late StateSetter update;
      await _pumpHost(
        tester,
        disableAnimations: !accessible,
        accessibleNavigation: accessible,
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return AppSelectionSurface(
              selected: selected,
              onTap: () {},
              child: FilledButton(onPressed: () {}, child: const Text('应用')),
            );
          },
        ),
      );
      final button = find.byType(FilledButton);
      final theme = Theme.of(tester.element(button));
      expect(theme.colorScheme, AppTheme.light().colorScheme);
      expect(theme.filledButtonTheme.style!.animationDuration, Duration.zero);
      expect(theme.iconButtonTheme.style!.animationDuration, Duration.zero);
      final surfaceMaterial = find
          .descendant(
            of: find.byType(AppSelectionSurface),
            matching: find.byType(Material),
          )
          .first;
      update(() => selected = true);
      await tester.pump();
      expect(
        tester.widget<Material>(surfaceMaterial).borderRadius,
        AppRadius.largeAll,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('动画中切换无障碍偏好立即收尾且保留草稿与组件身份', (tester) async {
    var reduced = false;
    var selected = false;
    late StateSetter updateMedia;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => StatefulBuilder(
          builder: (context, setState) {
            updateMedia = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: AppMotionTheme(child: child!),
            );
          },
        ),
        home: Scaffold(
          body: Column(
            children: [
              const TextField(),
              StatefulBuilder(
                builder: (context, setState) => AppSelectionSurface(
                  selected: selected,
                  onTap: () => setState(() => selected = !selected),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('更改选择'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '尚未提交的草稿');
    final surface = find.byType(AppSelectionSurface);
    final originalState = tester.state(surface);
    await tester.tap(find.text('更改选择'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    updateMedia(() => reduced = true);
    await tester.pump();
    expect(_material(tester, surface).borderRadius, AppRadius.largeAll);
    expect(tester.state(surface), same(originalState));
    expect(find.text('尚未提交的草稿'), findsOneWidget);
    updateMedia(() => reduced = false);
    await tester.pumpAndSettle();
    expect(tester.state(surface), same(originalState));
    expect(find.text('尚未提交的草稿'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Material _material(WidgetTester tester, Finder parent) =>
    tester.widget<Material>(
      find.descendant(of: parent, matching: find.byType(Material)),
    );

Future<void> _pumpHost(
  WidgetTester tester, {
  required Widget child,
  ThemeData? theme,
  double scale = 1,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: disableAnimations,
          accessibleNavigation: accessibleNavigation,
        ),
        child: AppMotionTheme(child: child!),
      ),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
