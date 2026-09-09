import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_radius.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/theme/frosted_surface.dart';
import 'package:phase/core/widgets/app_card.dart';

void main() {
  testWidgets('无 MediaQuery 时可用，blur 0 不创建滤镜', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: AppTheme.light(),
          child: const FrostedSurface(
            blur: 0,
            padding: EdgeInsets.all(16),
            child: Text('玻璃内容'),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(Material), findsOneWidget);
    expect(find.byType(ClipRRect), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('系统减少动态或辅助导航更新后禁用模糊并变为实底', (tester) async {
    for (final (reduced, accessible) in [
      (false, false),
      (true, false),
      (false, true),
      (false, false),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduced,
              accessibleNavigation: accessible,
            ),
            child: child!,
          ),
          home: const Center(
            child: FrostedSurface(child: SizedBox(width: 200, height: 100)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FrostedSurface),
          matching: find.byType(Material),
        ),
      );
      final opaque = reduced || accessible;
      expect(
        find.byType(BackdropFilter),
        opaque ? findsNothing : findsOneWidget,
      );
      expect(material.color!.a, opaque ? 1 : closeTo(0.88, 0.01));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('卡片点击使用自身 Material 和裁剪，不向外部表面投射 ink', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: AppCard(
                onTap: () => tapped++,
                child: const Text('可点击卡片', key: ValueKey('card-content')),
              ),
            ),
          ),
        ),
      ),
    );
    final surface = find.descendant(
      of: find.byType(AppCard),
      matching: find.byType(Material),
    );
    expect(surface, findsOneWidget);
    final localMaterial = tester
        .element(find.byKey(const ValueKey('card-content')))
        .findAncestorWidgetOfExactType<Material>();
    expect(localMaterial, same(tester.widget(surface)));
    final clip = tester.widget<ClipRRect>(
      find.descendant(
        of: find.byType(AppCard),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(clip.borderRadius, AppRadius.largeAll);
    expect(clip.clipBehavior, isNot(Clip.none));
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tap(find.text('可点击卡片'));
    await tester.pump();
    expect(tapped, 1);
    expect(tester.takeException(), isNull);
  });
}
