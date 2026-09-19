import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:phase/data/models/attachment.dart';
import 'package:phase/features/chat/thinking_panel.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/tools/tool_card.dart';

const _capture = bool.fromEnvironment('CAPTURE_TOOL_CARD');

void main() {
  late Directory directory;
  late Attachment screenshot;
  setUpAll(() async {
    directory = Directory.systemTemp.createTempSync('tool-card-layout');
    final picture = img.Image(width: 240, height: 420);
    img.fill(picture, color: img.ColorRgb8(245, 247, 252));
    img.fillRect(
      picture,
      x1: 16,
      y1: 24,
      x2: 224,
      y2: 56,
      color: img.ColorRgb8(61, 90, 152),
    );
    for (var i = 0; i < 5; i++) {
      img.fillRect(
        picture,
        x1: 16,
        y1: 80 + i * 56,
        x2: 224,
        y2: 118 + i * 56,
        color: img.ColorRgb8(220, 226, 238),
      );
    }
    final file = File('${directory.path}/screen.png')
      ..writeAsBytesSync(img.encodePng(picture));
    screenshot = Attachment(
      id: 'screen',
      kind: AttachmentKind.artifact,
      name: 'screen.png',
      mimeType: 'image/png',
      size: file.lengthSync(),
      localPath: file.path,
      createdAt: DateTime(2026),
    );

    if (!_capture) return;
    final bytes = await File('build/ui-preview/NotoSansCJKsc-Regular.otf')
        .readAsBytes();
    for (final family in ['Roboto', 'Ahem', 'sans-serif', 'monospace']) {
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

  tearDownAll(() => directory.deleteSync(recursive: true));
  for (final tool in [
    'shell',
    'write_file',
    'edit_file',
    'click_node',
    'perform_gestures',
    'capture_screen',
  ]) {
    for (final dark in [false, true]) {
      for (final (size, scale) in [
        (const Size(360, 800), 1.0),
        (const Size(320, 640), 1.3),
        (const Size(320, 640), 2.0),
        (const Size(800, 360), 2.0),
      ]) {
        testWidgets('工具输入输出布局、复制触区与收起 $tool/$size/$scale/$dark', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final boundary = GlobalKey();
          final record = ToolCallRecord(
            id: tool,
            runId: 'run',
            assistantMessageId: 'message',
            toolName: tool,
            arguments: switch (tool) {
              'write_file' => const {
                'path': '/workspace/moon.py',
                'content': 'def moon_phase(date):\n    return "上弦月"\n\nprint(moon_phase("2026-09-19"))\n',
              },
              'edit_file' => const {
                'path': '/workspace/moon.py',
                'edits': [
                  {
                    'oldText': 'def moon_phase(date):\n    return "满月"\n',
                    'newText': 'def moon_phase(date):\n    return "上弦月"\n',
                  },
                ],
              },
              'click_node' => const {
                'packageName': 'fixture.calendar',
                'nodeId': 'n17',
                'snapshotId': 'snapshot',
              },
              'capture_screen' => const {},
              'perform_gestures' => const {
                'packageName': 'fixture.calendar',
                'actions': [
                  {'type': 'tap', 'x': 120, 'y': 240},
                  {
                    'type': 'swipe',
                    'x': 180,
                    'y': 600,
                    'endX': 180,
                    'endY': 200,
                  },
                ],
              },
              _ => const {
                'command': 'python scripts/moon_phase.py --date 2026-09-19',
                'cwd': '/workspace',
                'timeoutMs': 60000,
              },
            },
            channel: ExecutionChannel.app,
            defaultPolicy: ToolPolicy.ask,
            status: ToolCallStatus.succeeded,
            result: switch (tool) {
              'write_file' || 'edit_file' => '已写入「/workspace/moon.py」',
              'capture_screen' =>
                '{"screenshot":{"packageName":"fixture.calendar"}}',
              'perform_gestures' => '{"completedCount":2}',
              'click_node' =>
                '{"actionAccepted":true,"observationChanged":false}',
              _ => jsonEncode({
                'stdout': '日期：2026-09-19\n月相：上弦月\n结果已保存到 output/moon.json\n',
                'stderr': '',
                'exitCode': 0,
              }),
            },
            artifacts: tool == 'capture_screen' ? ['screen'] : [],
            createdAt: DateTime(2026, 9, 19),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: RepaintBoundary(key: boundary, child: child!),
              ),
              home: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('正在计算指定日期的月相。'),
                    ),
                    const ThinkingPanel(
                      reasoning: '先观察界面，再执行操作。',
                      streaming: false,
                    ),
                    ToolCard(
                      record: record,
                      appName: '日历',
                      artifacts: tool == 'capture_screen' ? [screenshot] : [],
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (tool == 'capture_screen') {
            await tester.runAsync(
              () => precacheImage(
                ResizeImage(FileImage(File(screenshot.localPath)), width: 600),
                tester.element(find.byType(Scaffold)),
              ),
            );
          }
          final toggle = find.byKey(ValueKey('tool-toggle-$tool'));
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (tool == 'write_file' || tool == 'edit_file') {
            final added = tester.widget<ColoredBox>(
              find.byKey(
                ValueKey(
                  tool == 'write_file' ? 'diff-added-0' : 'diff-added-2',
                ),
              ),
            );
            expect(added.color.g, greaterThan(added.color.r));
            final foreground = Theme.of(tester.element(find.byType(ToolCard)))
                .colorScheme
                .onSurface;
            final luminances = [
              added.color.computeLuminance(),
              foreground.computeLuminance(),
            ]..sort();
            expect(
              (luminances.last + 0.05) / (luminances.first + 0.05),
              greaterThanOrEqualTo(4.5),
            );
            if (tool == 'edit_file') {
              final removed = tester.widget<ColoredBox>(
                find.byKey(const ValueKey('diff-removed-1')),
              );
              expect(removed.color.r, greaterThan(removed.color.g));
            }
          }
          if (tool == 'capture_screen') {
            final preview = find.byKey(
              const ValueKey('tool-screenshot-screen'),
            );
            expect(
              tester
                  .widget<RawImage>(
                    find.descendant(
                      of: preview,
                      matching: find.byType(RawImage),
                    ),
                  )
                  .image,
              isNotNull,
            );
          }
          if (_capture && scale == 1) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 2);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('build/tool-card-ui').create(recursive: true);
              await File(
                'build/tool-card-ui/$tool-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          for (final tooltip in switch (tool) {
            'shell' => ['复制命令'],
            'write_file' => ['复制文件内容'],
            'edit_file' => ['复制差异'],
            'click_node' || 'perform_gestures' => ['复制调用'],
            _ => <String>[],
          }) {
            final copy = find.byTooltip(tooltip);
            await tester.ensureVisible(copy);
            await tester.pumpAndSettle();
            expect(copy.hitTestable(), findsOneWidget);
            expect(tester.getSize(copy).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(copy).height, greaterThanOrEqualTo(48));
          }
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(find.text('输入参数'), findsNothing);
          expect(find.text('输出内容'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
