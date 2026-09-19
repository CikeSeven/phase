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
import 'package:phase/core/widgets/app_linear_progress_indicator.dart';
import 'package:phase/core/widgets/app_loading_indicator.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/features/workspace/process_api.g.dart';
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
    testWidgets('安装进度固定在应用栏下，实时更新、取消与失败 $size/$scale/$dark', (tester) async {
      final operation = _ControlledEnvironment();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentControllerProvider.overrideWith(() => operation),
            runtimeEnvironmentProvider.overrideWith(
              (_) => Stream.value(const RuntimeEnvironment()),
            ),
            linuxPlatformInfoProvider.overrideWith(
              (_) async => LinuxPlatformInfo(
                rootDirectory: '/test',
                abi: 'arm64-v8a',
                available: true,
                freeBytes: 1024 * 1024 * 1024,
              ),
            ),
            workspacesProvider.overrideWith(
              (_) => Stream.value([
                for (var i = 0; i < 20; i++)
                  Workspace(
                    id: '$i',
                    name: '工作区 $i',
                    rootPath: '/test/$i',
                    createdAt: DateTime(2026),
                  ),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: const WorkspacesPage(),
          ),
        ),
      );
      final indicator = find.byType(AppLinearProgressIndicator);
      expect(indicator, findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(indicator, findsNothing);

      operation.update(
        const EnvironmentOperation(
          busy: true,
          phase: EnvironmentPhase.downloading,
          bytes: 5 * 1048576,
          total: 20 * 1048576,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.widget<AppLinearProgressIndicator>(indicator).value, 0.25);
      expect(find.text('下载中 · 25%'), findsOneWidget);
      expect(find.text('未安装'), findsNothing);
      if (capture) {
        await _saveProgress(
          tester,
          boundary,
          'download-${dark ? 'dark' : 'light'}-${size.width}-$scale',
        );
      }
      await tester.scrollUntilVisible(
        find.text('5.0 / 20.0 MiB'),
        150,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();
      expect(find.text('5.0 / 20.0 MiB'), findsOneWidget);
      final rect = tester.getRect(indicator);
      expect(rect.width, size.width);
      expect(rect.height, 10);
      expect(
        rect.top,
        greaterThan(tester.getBottomLeft(find.text('环境与工作区')).dy),
      );
      expect(
        rect.bottom,
        lessThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getRect(indicator), rect);

      operation.update(
        const EnvironmentOperation(
          busy: true,
          phase: EnvironmentPhase.downloading,
          bytes: 15 * 1048576,
          total: 20 * 1048576,
        ),
      );
      await tester.pump();
      expect(tester.widget<AppLinearProgressIndicator>(indicator).value, 0.75);
      operation.update(
        const EnvironmentOperation(
          busy: true,
          phase: EnvironmentPhase.verifying,
        ),
      );
      await tester.pump();
      expect(
        tester.widget<AppLinearProgressIndicator>(indicator).value,
        isNull,
      );
      tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('取消安装'),
        150,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();
      await tester.tap(find.text('取消安装'));
      await tester.pumpAndSettle();
      expect(operation.cancelled, isTrue);
      expect(indicator, findsNothing);
      expect(find.text('已取消环境安装'), findsOneWidget);

      operation.update(const EnvironmentOperation(error: '下载失败，请重试'));
      await tester.pumpAndSettle();
      expect(indicator, findsNothing);
      expect(find.text('下载失败，请重试'), findsOneWidget);
      operation.update(const EnvironmentOperation());
      await tester.pumpAndSettle();
      expect(find.text('安装环境'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

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
        await tester.pumpAndSettle();
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

class _ControlledEnvironment extends EnvironmentController {
  bool cancelled = false;

  @override
  EnvironmentOperation build() => const EnvironmentOperation();

  void update(EnvironmentOperation value) => state = value;

  @override
  void cancel() {
    cancelled = true;
    state = const EnvironmentOperation(error: '已取消环境安装');
  }
}

Future<void> _saveProgress(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/environment-progress').create(recursive: true);
    await File('build/environment-progress/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
