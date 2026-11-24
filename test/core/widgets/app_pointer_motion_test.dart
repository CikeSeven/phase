import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/widgets/app_pointer_motion.dart';

void main() {
  for (final showcase in [false, true]) {
    testWidgets('鼠标移向右上角后移开，控件恢复原位（展示卡：$showcase）', (tester) async {
      const target = ValueKey('surface');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AppPointerMotion(
              showcase: showcase,
              child: const SizedBox(key: target, width: 160, height: 100),
            ),
          ),
        ),
      );
      final control = find.byKey(target);
      final home = tester.getCenter(control);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(home + const Offset(60, -28));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getCenter(control).dy, lessThan(home.dy));
      if (!showcase) expect(tester.getCenter(control).dx, greaterThan(home.dx));
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect((tester.getCenter(control) - home).distance, lessThan(.01));
    });
  }
}
