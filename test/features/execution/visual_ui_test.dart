import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/chat/tool_artifact_viewer.dart';
import 'package:phase/features/chat/tool_confirmation_sheet.dart';
import 'package:phase/features/tools/tool_card.dart';
import 'package:phase/features/tools/tool_executor.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('截图产物能打开图像，组合确认可取消且无布局异常（${dark ? '深' : '浅'}色 320dp 2x）', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final temp = await tester.runAsync(
        () => Directory.systemTemp.createTemp('visual-ui'),
      );
      addTearDown(() => temp!.delete(recursive: true));
      final bytes = img.encodePng(img.Image(width: 30, height: 60));
      final file = File('${temp!.path}/screen.png');
      await tester.runAsync(() => file.writeAsBytes(bytes));
      final attachment = Attachment(
        id: 'image',
        kind: AttachmentKind.artifact,
        name: 'screen.png',
        mimeType: 'image/png',
        size: bytes.length,
        localPath: file.path,
        createdAt: DateTime(2026),
      );
      final record = ToolCallRecord(
        id: 'capture',
        runId: 'run',
        assistantMessageId: 'answer',
        toolName: 'capture_screen',
        arguments: const {},
        channel: ExecutionChannel.accessibility,
        defaultPolicy: ToolPolicy.ask,
        status: ToolCallStatus.succeeded,
        result: jsonEncode({
          'screenshot': {'imageWidth': 30, 'imageHeight': 60},
        }),
        artifacts: const ['image'],
        createdAt: DateTime(2026),
      );
      final gestures = ToolCallRecord(
        id: 'gesture',
        runId: 'run',
        assistantMessageId: 'answer',
        toolName: 'perform_gestures',
        arguments: const {
          'packageName': 'fixture',
          'coordinateSpace': 'image_pixels',
          'imageWidth': 30,
          'imageHeight': 60,
          'actions': [
            {'type': 'tap', 'x': 10, 'y': 20},
            {'type': 'swipe', 'x': 10, 'y': 40, 'endX': 10, 'endY': 10},
          ],
        },
        channel: ExecutionChannel.accessibility,
        defaultPolicy: ToolPolicy.ask,
        status: ToolCallStatus.awaitingConfirmation,
        createdAt: DateTime(2026),
      );
      ToolConfirmationOutcome? outcome;
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ListView(
                children: [
                  ToolCard(
                    record: record,
                    artifacts: [attachment],
                    onOpenArtifact: (value) => showToolArtifact(context, value),
                  ),
                  TextButton(
                    onPressed: () async {
                      outcome = await showToolConfirmationSheet(
                        context,
                        ToolConfirmationRequest(
                          record: gestures,
                          summary: '执行两步手势组合',
                          policy: ToolPolicy.ask,
                          expiresAt: DateTime.now().add(
                            const Duration(seconds: 60),
                          ),
                        ),
                      );
                    },
                    child: const Text('确认组合'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('30 × 60'), findsOneWidget);
      expect(find.textContaining('screenshotId'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tool-artifact-image')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认组合'));
      await tester.pumpAndSettle();
      expect(find.text('执行手势组合'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('tool-confirm-reject')),
      );
      await tester.tap(find.byKey(const ValueKey('tool-confirm-reject')));
      await tester.pumpAndSettle();
      expect(outcome, ToolConfirmationOutcome.reject);
      expect(tester.takeException(), isNull);
    });
  }
}
