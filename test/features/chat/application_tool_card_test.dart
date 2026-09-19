import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/tool_source.dart';
import 'package:phase/features/chat/message_bubble.dart';
import 'package:phase/features/chat/thinking_panel.dart';
import 'package:phase/features/chat/tool_artifact_viewer.dart';
import 'package:phase/features/chat/tool_call_card.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/execution_setup_controller.dart';
import 'package:phase/features/tools/resolved_tool_card.dart';

const _package = 'fixture.calendar';

ToolCallRecord _record(
  String name, {
  String id = 'call',
  Map<String, dynamic> args = const {},
  Map<String, dynamic> result = const {},
  ToolCallStatus status = ToolCallStatus.succeeded,
  List<String> artifacts = const [],
  ToolSource? source,
}) => ToolCallRecord(
  id: id,
  runId: 'run',
  assistantMessageId: 'answer',
  toolName: name,
  arguments: args,
  result: jsonEncode(result),
  channel: ExecutionChannel.accessibility,
  defaultPolicy: ToolPolicy.ask,
  status: status,
  artifacts: artifacts,
  createdAt: DateTime(2026),
  source: source,
);

class _Applications extends ExecutionSetupApi {
  int calls = 0;
  Future<List<InstalledApplication>> Function()? load;

  @override
  Future<List<InstalledApplication>> installedApplications() async {
    calls++;
    return load != null
        ? await load!()
        : [
            InstalledApplication(
              packageName: _package,
              label: '日历',
              isSystem: false,
              installedAtMs: 1,
              launchable: true,
            ),
          ];
  }
}

Future<void> _pump(
  WidgetTester tester,
  ToolCallRecord record, {
  _Applications? api,
  List<Attachment> artifacts = const [],
  bool expanded = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        executionSetupApiProvider.overrideWithValue(api ?? _Applications()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ListView(
              children: [
                ResolvedToolCard(
                  record: record,
                  artifacts: artifacts,
                  onOpenArtifact: (a) => showToolArtifact(context, a),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (expanded) {
    for (final artifact in artifacts.where((a) => a.isImage)) {
      await tester.runAsync(
        () => precacheImage(
          ResizeImage(FileImage(File(artifact.localPath)), width: 600),
          tester.element(find.byType(Scaffold)),
        ),
      );
    }
    await tester.tap(find.byKey(ValueKey('tool-toggle-${record.id}')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('点击控件使用系统应用名和控件 ID，输入输出字体区分，保留画面未变化', (tester) async {
    final stored = _record(
      'click_node',
      args: {
        'packageName': _package,
        'snapshotId': 'internal-snapshot',
        'nodeId': 'n7',
      },
      result: {
        'actionAccepted': true,
        'observationChanged': false,
        'snapshot': {
          'nodes': List.filled(30, {'text': '无关控件'}),
        },
      },
    );
    final original = stored.result;
    await _pump(tester, stored);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('控件 n7'), findsOneWidget);
    expect(find.textContaining(_package), findsNothing);
    expect(find.textContaining('internal-snapshot'), findsNothing);
    expect(find.textContaining('无关控件'), findsNothing);
    expect(find.text('系统已接受动作，界面未变化'), findsOneWidget);
    final input = tester.widget<Text>(
      find.byKey(const ValueKey('tool-arguments-call')),
    );
    final output = tester.widget<Text>(
      find.byKey(const ValueKey('tool-result-call')),
    );
    expect(input.style!.fontFamily, 'monospace');
    expect(output.style!.fontFamily, isNot(input.style!.fontFamily));
    expect(stored.result, original);
  });

  testWidgets('截图直接显示记录对应应用与图片，点击可查看大图', (tester) async {
    final directory = Directory.systemTemp.createTempSync('tool-screenshot');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/capture.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 90, height: 160)));
    final attachment = Attachment(
      id: 'image',
      name: 'screen-call.png',
      kind: AttachmentKind.artifact,
      mimeType: 'image/png',
      localPath: file.path,
      size: file.lengthSync(),
      createdAt: DateTime(2026),
    );
    await _pump(
      tester,
      _record(
        'capture_screen',
        result: {
          'screenshot': {
            'packageName': _package,
            'windowId': 12,
            'screenshotId': 'internal',
            'imageWidth': 90,
            'imageHeight': 160,
            'rotation': 0,
          },
        },
        artifacts: ['image'],
      ),
      artifacts: [attachment],
    );
    final preview = find.byKey(const ValueKey('tool-screenshot-image'));
    expect(
      tester
          .widget<RawImage>(
            find.descendant(of: preview, matching: find.byType(RawImage)),
          )
          .image,
      isNotNull,
    );
    expect(find.text('日历'), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-screenshot-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-result-call')), findsNothing);
    expect(find.textContaining('windowId'), findsNothing);
    expect(find.text('screen-call.png'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tool-artifact-image')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('组合手势展示步数、应用、坐标，停止后保留已完成与已派发信息', (tester) async {
    await _pump(
      tester,
      _record(
        'perform_gestures',
        status: ToolCallStatus.cancelled,
        args: {
          'packageName': _package,
          'coordinateSpace': 'image_pixels',
          'imageWidth': 360,
          'imageHeight': 800,
          'actions': [
            {'type': 'tap', 'x': 120.0, 'y': 240.0},
            {'type': 'wait', 'durationMs': 500},
            {
              'type': 'swipe',
              'x': 180,
              'y': 600,
              'endX': 180,
              'endY': 200,
              'durationMs': 400,
            },
          ],
        },
        result: {
          'completedCount': 2,
          'activeStep': 2,
          'activeStepDispatched': true,
          'completedSteps': [
            {'actionAccepted': true},
          ],
          'coordinateSpace': 'screen_pixels',
        },
      ),
    );
    expect(find.text('执行 3 步手势'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expect(
      find.text(
        '图片坐标（360 × 800）\n1. 点击 (120, 240)\n2. 等待 500 毫秒\n'
        '3. 滑动 (180, 600) → (180, 200) · 400 毫秒',
      ),
      findsOneWidget,
    );
    expect(find.text('已完成 2/3 步\n第 3 步已派发'), findsOneWidget);
    expect(find.text('已取消'), findsOneWidget);
    expect(find.textContaining('completedSteps'), findsNothing);
  });

  testWidgets('应用列表与界面观察按名称和控件整理，不显示内部字段', (tester) async {
    await _pump(
      tester,
      _record(
        'list_apps',
        args: {'query': '日历'},
        result: {
          'applications': [
            {
              'name': '日历',
              'packageName': _package,
              'installedAtMs': 0,
              'sizeBytes': 12345,
            },
          ],
          'total': 10,
          'nextOffset': 1,
        },
      ),
    );
    expect(find.text('搜索「日历」'), findsOneWidget);
    expect(find.text('日历\n还有更多应用'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(
      tester,
      _record(
        'inspect_ui',
        args: {'packageName': _package},
        result: {
          'snapshot': {
            'id': 'internal',
            'windowId': 88,
            'truncated': true,
            'nodes': [
              {
                'id': 'n1',
                'text': '新建日程',
                'clickable': true,
                'bounds': [0, 0, 40, 40],
              },
              {'id': 'n2', 'description': '返回'},
            ],
          },
        },
      ),
    );
    expect(find.text('控件 n1 · 新建日程\n控件 n2 · 返回\n控件列表已截断'), findsOneWidget);
    expect(find.textContaining('windowId'), findsNothing);
  });

  testWidgets('滚动与文字输入只显示控件、方向或文字，同时保留真实失败原因', (tester) async {
    for (final (tool, extra, expected) in [
      ('scroll', {'direction': 'backward'}, '控件 n7 · 向后滚动'),
      ('input_text', {'text': '下周一开会'}, '控件 n7\n下周一开会'),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(
        tester,
        _record(
          tool,
          status: ToolCallStatus.failed,
          args: {
            'packageName': _package,
            'snapshotId': 'internal',
            'nodeId': 'n7',
            ...extra,
          },
          result: {'actionAccepted': false, 'reason': '目标控件已改变'},
        ),
      );
      expect(find.text(expected), findsOneWidget);
      expect(find.text('系统未接受动作\n目标控件已改变'), findsOneWidget);
    }
  });

  testWidgets('名称读取失败不伪造应用名，不影响查看调用', (tester) async {
    final api = _Applications()
      ..load = () async =>
          throw PlatformException(code: 'applicationListPermissionRequired');
    await _pump(
      tester,
      _record('open_app', args: {'packageName': _package}),
      api: api,
    );
    expect(find.text('应用名称不可用'), findsOneWidget);
    expect(find.textContaining(_package), findsNothing);
    expect(find.text('已完成'), findsOneWidget);
    expect(api.calls, 1);
  });

  testWidgets('第三方同名工具保持原数据，也不查询系统应用', (tester) async {
    final api = _Applications();
    await _pump(
      tester,
      _record(
        'capture_screen',
        args: {'packageName': _package},
        result: {'providerField': 'must remain'},
        source: const ToolSource(
          kind: ToolSourceKind.mcp,
          id: 'server',
          originalName: 'capture_screen',
          definitionRevision: '1',
        ),
      ),
      api: api,
    );
    expect(find.textContaining('providerField'), findsOneWidget);
    expect(api.calls, 0);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('实际消息内工具卡片与思考面板左右对齐（$width）', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final stored = _record(
        'shell',
        args: {'command': 'echo done'},
        result: {'stdout': 'done', 'stderr': '', 'exitCode': 0},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            toolCallRecordProvider('call')
                .overrideWith((ref) => Stream.value(stored)),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: ListView(
                children: [
                  MessageBubble(
                    message: ChatMessage(
                      id: 'answer',
                      conversationId: 'c',
                      role: ChatRole.assistant,
                      createdAt: DateTime(2026),
                      parts: const [
                        ReasoningPart(publicText: '先执行命令'),
                        ToolCallPart(toolCallId: 'call'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final thinking = tester.getRect(find.byType(ThinkingPanel));
      final card = tester.getRect(find.byKey(const ValueKey('tool-card-call')));
      expect(card.left, thinking.left);
      expect(card.right, thinking.right);
    });
  }
}
