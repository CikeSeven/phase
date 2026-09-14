import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_dropdown.dart';

enum _Choice { first, second }

void main() {
  testWidgets('禁用下拉不可开启，展开时禁用会关闭菜单且不派发迟到选择', (tester) async {
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);
    var changes = 0;
    late BuildContext routeContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            routeContext = context;
            return Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: ValueListenableBuilder(
                  valueListenable: enabled,
                  builder: (_, active, _) => AppDropdown(
                    label: '测试选择',
                    value: _Choice.first,
                    options: const {
                      _Choice.first: '第一项',
                      _Choice.second: '第二项',
                    },
                    onChanged: active ? (_) => changes++ : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final field = find.byType(AppDropdown<_Choice>);
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('测试选择'))
            .getSemanticsData()
            .flagsCollection
            .isEnabled,
        Tristate.isFalse,
      );
    } finally {
      semantics.dispose();
    }
    enabled.value = true;
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(ModalRoute.of(routeContext)!.willHandlePopInternally, isTrue);
    final gesture = await tester.startGesture(
      tester.getCenter(find.widgetWithText(MenuItemButton, '第二项')),
    );
    enabled.value = false;
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(changes, 0);
    expect(find.byType(MenuItemButton), findsNothing);
    expect(ModalRoute.of(routeContext)!.willHandlePopInternally, isFalse);
    enabled.value = true;
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '第二项'));
    await tester.pumpAndSettle();
    expect(changes, 1);
    expect(tester.takeException(), isNull);
  });
}
