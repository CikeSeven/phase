import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:phase/core/theme/app_theme.dart';

void main() {
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('${theme.brightness} 填色发送按钮图标保持可见对比度', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: IconButton.filled(
                tooltip: '发送',
                onPressed: () {},
                icon: const Icon(Symbols.arrow_upward),
              ),
            ),
          ),
        ),
      );
      final icon = find.byIcon(Symbols.arrow_upward);
      final label = tester.widget<RichText>(
        find.descendant(of: icon, matching: find.byType(RichText)),
      );
      final material = tester.widget<Material>(
        find.ancestor(of: icon, matching: find.byType(Material)).first,
      );
      final background = material.color!;
      final foreground = label.text.style!.color!;
      final front = Color.alphaBlend(foreground, background).computeLuminance();
      final back = background.computeLuminance();
      final ratio =
          (math.max(front, back) + 0.05) / (math.min(front, back) + 0.05);
      expect(ratio, greaterThanOrEqualTo(3));
    });
  }
}
