import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_radius.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/theme/frosted_surface.dart';
import 'package:phase/features/chat/chat_input_surface.dart';

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? '深色' : '浅色';
    final theme = dark ? AppTheme.dark() : AppTheme.light();

    Future<void> pumpSurface(
      WidgetTester tester, {
      bool reduced = false,
      bool accessible = false,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            accessibleNavigation: accessible,
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ChatInputSurface(focused: false, child: Text('输入消息…')),
            ),
          ),
        ),
      ),
    );

    Material surfaceMaterial(WidgetTester tester) => tester.widget<Material>(
      find.descendant(
        of: find.byType(FrostedSurface),
        matching: find.byType(Material),
      ),
    );

    testWidgets('$mode 输入栏仅在圆角内部模糊，高光不覆盖文字和 ink 反馈', (tester) async {
      await pumpSurface(tester);
      final filter = find.byType(BackdropFilter);
      expect(filter, findsOneWidget);
      final clip = tester.widget<ClipRRect>(
        find.ancestor(of: filter, matching: find.byType(ClipRRect)),
      );
      expect(clip.borderRadius, AppRadius.largeAll);
      expect(clip.clipBehavior, Clip.antiAlias);
      expect(tester.getSize(filter), tester.getSize(find.byType(ClipRRect)));
      expect(surfaceMaterial(tester).color!.a, inExclusiveRange(0.55, 0.7));

      final ink = find.byType(Ink);
      expect(
        tester.element(ink).findAncestorWidgetOfExactType<Material>(),
        same(surfaceMaterial(tester)),
      );
      expect(
        find.descendant(of: ink, matching: find.text('输入消息…')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode 减少动态或辅助导航时关闭模糊并使用实底', (tester) async {
      for (final (reduced, accessible) in [(true, false), (false, true)]) {
        await pumpSurface(tester, reduced: reduced, accessible: accessible);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(surfaceMaterial(tester).color!.a, 1);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
