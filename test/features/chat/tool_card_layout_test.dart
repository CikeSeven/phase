import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/tools/tool_card.dart';

const _capture = bool.fromEnvironment('CAPTURE_TOOL_CARD');

void main() {
  setUpAll(() async {
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

  for (final dark in [false, true]) {
    for (final (size, scale) in [
      (const Size(360, 800), 1.0),
      (const Size(320, 640), 1.3),
      (const Size(320, 640), 2.0),
      (const Size(800, 360), 2.0),
    ]) {
      testWidgets('工具输入输出布局、复制触区与收起 $size/$scale/$dark', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        final record = ToolCallRecord(
          id: 'shell',
          runId: 'run',
          assistantMessageId: 'message',
          toolName: 'shell',
          arguments: const {
            'command': 'python scripts/moon_phase.py --date 2026-09-19',
            'cwd': '/workspace',
            'timeoutMs': 60000,
          },
          channel: ExecutionChannel.app,
          defaultPolicy: ToolPolicy.ask,
          status: ToolCallStatus.succeeded,
          result: jsonEncode({
            'stdout': '日期：2026-09-19\n月相：上弦月\n结果已保存到 output/moon.json\n',
            'stderr': '',
            'exitCode': 0,
            'environment': '24.04 ARM64',
            'knownEffects': '工作区中的文件变化保留',
          }),
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
                children: [
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('正在计算指定日期的月相。'),
                  ),
                  ToolCard(record: record),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.byKey(const ValueKey('tool-toggle-shell'));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (_capture && scale == 1) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('build/tool-card-ui').create(recursive: true);
            await File('build/tool-card-ui/${dark ? 'dark' : 'light'}.png')
                .writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        for (final title in ['输入参数', '输出内容']) {
          final copy = find.byTooltip('复制$title');
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
