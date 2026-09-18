import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/features/workspace/workspace_controller.dart';
import 'package:phase/features/workspace/workspaces_page.dart';

import '../tools/tool_loop_harness.dart';
import 'local_process_driver.dart';

const capture = bool.fromEnvironment('CAPTURE_WORKSPACE');
void main() {
  setUpAll(() async {
    if (!capture) return;
    final bytes = await File('build/ui-preview/NotoSansCJKsc-Regular.otf')
        .readAsBytes();
    for (final family in ['Roboto', 'Ahem', 'sans-serif']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      if (!(entry['family'] as String).toLowerCase().contains('material')) {
        continue;
      }
      final loader = FontLoader(entry['family'] as String);
      for (final font
          in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  for (final (size, scale, dark) in [
    (const Size(360, 800), 1.0, false),
    (const Size(360, 800), 1.0, true),
    (const Size(320, 700), 2.0, false),
    (const Size(800, 360), 2.0, true),
  ]) {
    testWidgets(
      'workspace creation dialog, cancellation and layout $size/$scale/$dark',
      (tester) async {
        late ToolLoopHarness h;
        await tester.runAsync(() async {
          final processes = LocalProcessDriver();
          addTearDown(processes.dispose);
          h = await ToolLoopHarness.create(processes: processes);
          await (await h.container.read(workspaceRepositoryProvider.future))
              .create('论文与月相观测的长期工作区');
        });
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (_, state) => MaterialPage(
                key: state.pageKey,
                child: const WorkspacesPage(),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: MaterialApp.router(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(key: boundary, child: child!),
              ),
            ),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        final install = find.widgetWithText(FilledButton, '安装环境');
        expect(tester.widget<FilledButton>(install).onPressed, isNotNull);
        final label = tester.element(
          find.descendant(of: install, matching: find.text('安装环境')),
        );
        expect(
          DefaultTextStyle.of(label).style.color,
          Theme.of(label).colorScheme.onPrimary,
        );
        if (capture && scale == 1) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/e3_ui').create(recursive: true);
            await File('build/e3_ui/workspaces-${dark ? 'dark' : 'light'}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.scrollUntilVisible(
          find.text('新建'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('新建'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.enterText(find.byType(TextField), '取消的草稿');
        await tester.ensureVisible(find.text('取消'));
        await tester.tap(find.text('取消'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('取消的草稿'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
