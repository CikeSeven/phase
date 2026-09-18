import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_loading_indicator/loading_indicator.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:phase/core/theme/app_motion.dart';
import 'package:phase/core/theme/app_radius.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/features/chat/chat_send_button.dart';

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? '深色' : '浅色';

    testWidgets('$mode 40dp 色面和 24dp 图标保留 56dp 触区，按压取消与边缘点击正确', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        dark: dark,
        child: ChatSendButton(isGenerating: false, onPressed: () => calls++),
      );
      final button = find.byType(ChatSendButton);
      final rect = tester.getRect(button);
      expect(rect.size, const Size.square(56));
      expect(tester.getSize(_surface()), const Size.square(40));
      expect(
        tester.getSize(find.byIcon(Symbols.arrow_upward)),
        const Size.square(24),
      );

      final press = await tester.startGesture(rect.center);
      await tester.pump();
      await tester.pump(AppMotion.effects);
      expect(calls, 0);
      expect(tester.getRect(button), rect);
      expect(tester.getSize(_surface()), const Size.square(40));
      expect(
        (tester.widget<Material>(_surface()).shape! as RoundedRectangleBorder)
            .borderRadius,
        AppRadius.extraSmallAll,
      );
      await press.cancel();
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(tester.widget<Material>(_surface()).shape, isA<StadiumBorder>());

      // 色面之外的留白仍由原生按钮命中，不只让中心 40dp 可点。
      final edge = Offset(rect.left + 1, rect.center.dy);
      expect(tester.getRect(_surface()).contains(edge), isFalse);
      await tester.tapAt(edge);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.getRect(button), rect);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode 发送与生成指示双向过渡，动画中立即响应停止且触区稳定', (tester) async {
      var generating = false;
      var sends = 0;
      var stops = 0;
      await _pump(
        tester,
        dark: dark,
        child: StatefulBuilder(
          builder: (context, setState) => ChatSendButton(
            isGenerating: generating,
            onPressed: () => setState(() {
              if (generating) {
                stops++;
              } else {
                sends++;
              }
              generating = !generating;
            }),
          ),
        ),
      );
      final button = find.byType(ChatSendButton);
      final rect = tester.getRect(button);
      await tester.tap(find.byTooltip('发送'));
      await tester.pump();
      expect(sends, 1);
      expect(stops, 0);
      expect(find.byTooltip('停止生成'), findsOneWidget);
      expect(tester.getSemantics(find.byType(IconButton)).tooltip, '停止生成');
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).isSelected,
        isNull,
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byIcon(Symbols.arrow_upward), findsOneWidget);
      expect(find.byType(LoadingIndicator), findsOneWidget);
      expect(find.byIcon(Symbols.stop), findsNothing);
      expect(
        tester.getSize(find.byType(LoadingIndicator)),
        const Size.square(40),
      );
      final fades = tester.widgetList<FadeTransition>(
        find.descendant(of: button, matching: find.byType(FadeTransition)),
      );
      expect(fades, hasLength(2));
      for (final fade in fades) {
        expect(fade.opacity.value, inExclusiveRange(0, 1));
      }
      final scales = tester.widgetList<ScaleTransition>(
        find.descendant(of: button, matching: find.byType(ScaleTransition)),
      );
      expect(scales, hasLength(2));
      expect(
        scales.any((scale) => (scale.scale.value - 1).abs() > 0.001),
        isTrue,
      );
      expect(tester.getRect(button), rect);

      // 无需等待箭头退场就能停止，不重放发送回调。
      await tester.tap(find.byTooltip('停止生成'));
      await tester.pump();
      expect(sends, 1);
      expect(stops, 1);
      expect(tester.getSemantics(find.byType(IconButton)).tooltip, '发送');
      await tester.pumpAndSettle();
      expect(find.byIcon(Symbols.arrow_upward), findsOneWidget);
      expect(find.byType(LoadingIndicator), findsNothing);
      expect(tester.getRect(button), rect);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode 生成图案随主题明暗变化，容器反衬且停止后恢复发送配色', (tester) async {
      var generating = false;
      await _pump(
        tester,
        dark: dark,
        child: StatefulBuilder(
          builder: (context, setState) => ChatSendButton(
            isGenerating: generating,
            onPressed: () => setState(() => generating = !generating),
          ),
        ),
      );
      final sendBackground = tester.widget<Material>(_surface()).color;
      final sendForeground = IconTheme.of(
        tester.element(find.byIcon(Symbols.arrow_upward)),
      ).color;
      await tester.tap(find.byTooltip('发送'));
      await tester.pump();
      await tester.pump(AppMotion.effects);

      final background = tester.widget<Material>(_surface()).color!;
      final foreground = tester
          .widget<LoadingIndicator>(find.byType(LoadingIndicator))
          .activeIndicatorColor!;
      final colors = Theme.of(tester.element(find.byType(ChatSendButton)))
          .colorScheme;
      expect(background, dark ? colors.primary : colors.onPrimaryContainer);
      expect(foreground, dark ? colors.onPrimary : colors.primaryContainer);
      expect(foreground, isNot(Colors.white));
      final light = (dark ? background : foreground).computeLuminance();
      final deep = (dark ? foreground : background).computeLuminance();
      expect(light, greaterThan(deep));
      expect((light + 0.05) / (deep + 0.05), greaterThanOrEqualTo(4.5));

      await tester.tap(find.byTooltip('停止生成'));
      await tester.pumpAndSettle();
      expect(tester.widget<Material>(_surface()).color, sendBackground);
      expect(
        IconTheme.of(tester.element(find.byIcon(Symbols.arrow_upward))).color,
        sendForeground,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final accessible in [false, true]) {
    testWidgets('切换减少动画偏好立即清理退场图标（辅助导航：$accessible）', (tester) async {
      var reduced = false;
      var generating = false;
      late StateSetter update;
      await _pump(
        tester,
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduced && !accessible,
                accessibleNavigation: reduced && accessible,
              ),
              child: ChatSendButton(
                isGenerating: generating,
                onPressed: () => setState(() => generating = !generating),
              ),
            );
          },
        ),
      );
      final buttonElement = tester.element(find.byType(IconButton));
      await tester.tap(find.byTooltip('发送'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byIcon(Symbols.arrow_upward), findsOneWidget);
      update(() => reduced = true);
      await tester.pump();
      expect(find.byType(AnimatedSwitcher), findsNothing);
      expect(find.byIcon(Symbols.arrow_upward), findsNothing);
      expect(find.byType(LoadingIndicator), findsOneWidget);
      expect(tester.element(find.byType(IconButton)), same(buttonElement));
      expect(
        tester.widget<Material>(_surface()).animationDuration,
        Duration.zero,
      );
      expect(
        TickerMode.valuesOf(tester.element(find.byType(LoadingIndicator)))
            .enabled,
        isFalse,
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);

      await tester.tap(find.byTooltip('停止生成'));
      await tester.pump();
      expect(generating, isFalse);
      expect(find.byType(LoadingIndicator), findsNothing);
      expect(find.byIcon(Symbols.arrow_upward), findsOneWidget);
      update(() => reduced = false);
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(IconButton)), same(buttonElement));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('生成指示持续运动，离屏暂停、返回恢复，停止后释放 ticker', (tester) async {
    var generating = false;
    var visible = true;
    late StateSetter update;
    await _pump(
      tester,
      child: StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return TickerMode(
            enabled: visible,
            child: ChatSendButton(
              isGenerating: generating,
              onPressed: () => setState(() => generating = !generating),
            ),
          );
        },
      ),
    );
    expect(find.byType(LoadingIndicator), findsNothing);
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final indicatorState = tester.state(find.byType(LoadingIndicator));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    update(() => visible = false);
    await tester.pumpAndSettle();
    expect(
      TickerMode.valuesOf(tester.element(find.byType(LoadingIndicator)))
          .enabled,
      isFalse,
    );
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.state(find.byType(LoadingIndicator)), same(indicatorState));

    update(() => visible = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    expect(tester.state(find.byType(LoadingIndicator)), same(indicatorState));
    await tester.tap(find.byTooltip('停止生成'));
    await tester.pumpAndSettle();
    expect(generating, isFalse);
    expect(find.byType(LoadingIndicator), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('键盘激活与禁用语义保留，禁用时没有按压形变或动作', (tester) async {
    var enabled = true;
    var calls = 0;
    late StateSetter update;
    await _pump(
      tester,
      child: StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return ChatSendButton(
            isGenerating: false,
            onPressed: enabled ? () => calls++ : null,
          );
        },
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(calls, 1);
    update(() => enabled = false);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(IconButton)),
      matchesSemantics(tooltip: '发送', isButton: true, hasEnabledState: true),
    );
    final press = await tester.startGesture(
      tester.getCenter(find.byType(ChatSendButton)),
    );
    await tester.pump(AppMotion.effects);
    expect(tester.widget<Material>(_surface()).shape, isA<StadiumBorder>());
    await press.up();
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}

Finder _surface() => find.descendant(
  of: find.byType(ChatSendButton),
  matching: find.byType(Material),
);

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  bool dark = false,
}) async {
  tester.view.physicalSize = const Size(320, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}
