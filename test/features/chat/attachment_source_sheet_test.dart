import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/features/chat/attachment_source_sheet.dart';

void main() {
  for (final dark in [false, true]) {
    for (final (size, scale) in [
      (const Size(320, 720), 1.0),
      (const Size(360, 780), 1.3),
      (const Size(320, 720), 2.0),
      (const Size(680, 320), 2.0),
    ]) {
      testWidgets('附件面板 ${dark ? '深' : '浅'}色 $size ${scale}x 紧凑可滚动且来源可达', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        AttachmentSource? result;
        var resolved = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showAttachmentSourceSheet(context);
                    resolved++;
                  },
                  child: const Text('附件'),
                ),
              ),
            ),
          ),
        );
        for (final source in AttachmentSource.values) {
          await tester.tap(find.text('附件'));
          await tester.pumpAndSettle();
          expect(find.text('添加附件'), findsOneWidget);
          expect(find.byTooltip('关闭'), findsOneWidget);
          expect(
            tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
            isTrue,
          );
          for (final icon in [
            Symbols.photo_camera_rounded,
            Symbols.photo_library_rounded,
            Symbols.folder_open_rounded,
          ]) {
            expect(tester.widget<Icon>(find.byIcon(icon)).fill, 1);
          }
          if (scale == 1) {
            expect(
              tester.getSize(find.byType(BottomSheet)).height,
              lessThan(size.height * 0.5),
            );
          }
          final choice = find.byKey(ValueKey('attach-${source.name}'));
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          expect(tester.getSize(choice).shortestSide, greaterThanOrEqualTo(48));
          final tapPosition = tester.getCenter(choice);
          await tester.tap(choice);
          await tester.tapAt(tapPosition);
          await tester.pumpAndSettle();
          expect(result, source);
          expect(resolved, source.index + 1);
          expect(find.byType(AttachmentSourceSheet), findsNothing);
          expect(find.text('附件'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        for (final cancel in ['close', 'back', 'barrier']) {
          await tester.tap(find.text('附件'));
          await tester.pumpAndSettle();
          if (cancel == 'close') {
            await tester.ensureVisible(find.byTooltip('关闭'));
            await tester.tap(find.byTooltip('关闭'));
          } else if (cancel == 'back') {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tapAt(const Offset(8, 8));
          }
          await tester.pumpAndSettle();
          expect(result, isNull);
          expect(find.byType(AttachmentSourceSheet), findsNothing);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
