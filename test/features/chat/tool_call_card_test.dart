import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/tool_call_repository.dart';
import 'package:phase/features/chat/chat_transcript.dart';
import 'package:phase/features/chat/tool_call_card.dart';
import 'package:phase/features/tools/tool_card.dart';

/// 聊天流里的工具卡片：记录从仓储读，产物按文件真实内容查看。
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('phase_tool_card');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  ToolCallRecord record({
    List<String> artifacts = const [],
    ToolCallStatus status = ToolCallStatus.succeeded,
    String? result = '已创建「summary.md」（8 字）',
    String toolName = 'write_file',
    String? errorCode,
  }) {
    return ToolCallRecord(
      id: 'tool-1',
      runId: 'run-1',
      assistantMessageId: 'msg-1',
      toolName: toolName,
      arguments: const {'path': 'summary.md', 'content': '# 摘要'},
      target: toolName == 'read_file'
          ? '读取文件：notes.txt'
          : '写入文件「summary.md」（8 字，新文件）',
      channel: ExecutionChannel.app,
      defaultPolicy: ToolPolicy.ask,
      status: status,
      decision: ToolDecision.approved,
      result: result,
      errorCode: errorCode,
      artifacts: artifacts,
      createdAt: DateTime(2026, 9, 12, 10),
    );
  }

  Attachment artifact({
    required String name,
    required String path,
    String mimeType = 'text/markdown',
    AttachmentKind kind = AttachmentKind.artifact,
    int size = 12,
  }) {
    return Attachment(
      id: 'attach-1',
      conversationId: 'c1',
      kind: kind,
      name: name,
      mimeType: mimeType,
      size: size,
      localPath: path,
      createdAt: DateTime(2026, 9, 12, 10),
    );
  }

  /// 卡片只通过仓储读记录：界面不持有业务副本。
  Future<void> pumpCard(
    WidgetTester tester, {
    required ToolCallRecord? stored,
    Map<String, Attachment> attachments = const {},
    bool expanded = false,
    double trailingSpace = 0,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          toolCallRepositoryProvider.overrideWith(
            (ref) => _FakeToolCalls(stored),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: [
                ToolCallCard(toolCallId: 'tool-1', attachments: attachments),
                if (trailingSpace > 0) SizedBox(height: trailingSpace),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (expanded) {
      await tester.tap(find.byKey(const ValueKey('tool-toggle-tool-1')));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('卡片默认紧凑收起，点击展开详情，再次点击收起', (tester) async {
    await pumpCard(tester, stored: record(), attachments: const {});

    expect(find.text('写入文件'), findsOneWidget);
    expect(find.text('写入文件「summary.md」（8 字，新文件）'), findsNothing);
    expect(find.text('已创建「summary.md」（8 字）'), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('tool-status-tool-1')))
          .data,
      '已完成',
    );
    final toggle = find.byKey(const ValueKey('tool-toggle-tool-1'));
    final collapsedHeight = tester.getSize(find.byType(ToolCard)).height;
    expect(tester.getSize(toggle).height, 48);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('写入文件「summary.md」（8 字，新文件）'), findsNothing);
    expect(find.text('已创建「summary.md」（8 字）'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ToolCard)).height,
      greaterThan(collapsedHeight),
    );
    // 参数与结果留在记录里：卡片不展示参数 JSON。
    expect(find.textContaining('"path"'), findsNothing);
    expect(find.textContaining('{"'), findsNothing);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('已创建「summary.md」（8 字）'), findsNothing);
    expect(tester.getSize(find.byType(ToolCard)).height, collapsedHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('记录不存在时不渲染卡片', (tester) async {
    await pumpCard(tester, stored: null);
    expect(find.text('写入文件'), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final status in [ToolCallStatus.succeeded, ToolCallStatus.failed]) {
    testWidgets('$status 长输出完整保留并可滚到末尾，收起再展开保留位置', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final result = List.generate(
        100,
        (index) => '第 $index 行：工具返回的完整文本',
      ).join('\n');
      await pumpCard(
        tester,
        stored: record(toolName: 'read_file', status: status, result: result),
        expanded: true,
      );
      final output = find.byKey(const ValueKey('tool-result-tool-1'));
      expect(tester.widget<Text>(output).data, result);
      expect(find.text('读取文件：notes.txt'), findsNothing);
      final scroll = find.byKey(const PageStorageKey('tool-output-tool-1'));
      final controller = tester
          .widget<SingleChildScrollView>(scroll)
          .controller!;
      expect(tester.getSize(scroll).height, lessThanOrEqualTo(240));
      expect(controller.position.extentAfter, greaterThan(0));
      await tester.drag(scroll, const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(controller.position.extentAfter, lessThan(1));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: output, matching: find.byType(RichText)),
      );
      final lastLine = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: result.lastIndexOf('\n') + 1,
          extentOffset: result.length,
        ),
      );
      final viewport = tester.getRect(scroll);
      for (final box in lastLine) {
        expect(
          viewport.contains(paragraph.localToGlobal(box.toRect().center)),
          isTrue,
        );
      }
      final offset = controller.offset;
      final toggle = find.byKey(const ValueKey('tool-toggle-tool-1'));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(scroll, findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(offset, 0.5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('输出滚到边界后继续拖动可以滚动外层列表', (tester) async {
    await pumpCard(
      tester,
      stored: record(result: '工具输出\n' * 100),
      expanded: true,
      trailingSpace: 1000,
    );
    final inner = find.byKey(const PageStorageKey('tool-output-tool-1'));
    final innerController = tester
        .widget<SingleChildScrollView>(inner)
        .controller!;
    final outer = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    await tester.drag(inner, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(innerController.offset, greaterThan(0));
    expect(outer.pixels, 0);
    await tester.drag(inner, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(innerController.position.extentAfter, lessThan(1));
    expect(outer.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('文件结构化输出保留完整正文和元信息，不替换成摘要', (tester) async {
    final result = jsonEncode({
      'name': 'notes.txt',
      'text': '${'完整正文\n' * 80}文件末尾',
      'totalLines': 81,
    });
    await pumpCard(
      tester,
      stored: record(toolName: 'read_file', result: result),
      expanded: true,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('tool-result-tool-1')))
          .data,
      result,
    );
    expect(find.text('已读取「notes.txt」'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final expanded in [false, true]) {
    testWidgets('手动${expanded ? '展开' : '收起'}跨记录更新与滚动回看保留，切换不抢阅读位置', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final updates = StreamController<ToolCallRecord>();
      addTearDown(updates.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            toolCallRecordProvider('tool-1').overrideWith((ref) async* {
              yield record(status: ToolCallStatus.executing, result: null);
              yield* updates.stream;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: ChatTranscript(
                conversationId: 'c1',
                messages: [
                  for (var i = 0; i < 30; i++)
                    ChatMessage(
                      id: 'history-$i',
                      conversationId: 'c1',
                      role: ChatRole.user,
                      parts: [TextPart(text: '历史消息 $i\n用于回看与滚动')],
                      createdAt: DateTime(2026),
                    ),
                  ChatMessage(
                    id: 'msg-1',
                    conversationId: 'c1',
                    role: ChatRole.assistant,
                    parts: const [
                      ToolCallPart(toolCallId: 'tool-1'),
                      TextPart(text: '正在处理文件'),
                    ],
                    createdAt: DateTime(2026),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('tool-toggle-tool-1'));
      final before = tester.getTopLeft(toggle).dy;
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(toggle).dy, closeTo(before, 0.5));
      expect(find.text('正在执行'), findsOneWidget);
      if (!expanded) {
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(toggle).dy, closeTo(before, 0.5));
      }
      final state = tester.state(find.byType(ToolCard));
      await tester.dragFrom(const Offset(180, 120), const Offset(0, 1800));
      await tester.pumpAndSettle();
      expect(find.byTooltip('回到底部'), findsOneWidget);
      updates.add(record());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('回到底部'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ToolCard)), same(state));
      expect(find.text('已完成'), findsOneWidget);
      expect(
        find.text('已创建「summary.md」（8 字）'),
        expanded ? findsOneWidget : findsNothing,
      );
      // 快速重复切换后仍回到原状态，不留下隐藏的附件触区。
      for (var i = 0; i < 4; i++) {
        await tester.tap(toggle);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(
        find.text('已创建「summary.md」（8 字）'),
        expanded ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('读取失败保留完整工具输出，包括文件名与原因', (tester) async {
    final result = jsonEncode({
      'uri': 'content://fixture/tree/root/document/notes.txt',
      'name': 'notes.txt',
      'reason': '未能读取「notes.txt」的内容。',
    });
    await pumpCard(
      tester,
      stored: record(
        toolName: 'read_file',
        status: ToolCallStatus.failed,
        errorCode: 'fileReadFailed',
        result: result,
      ),
      expanded: true,
    );
    expect(find.text(result), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('实际记录保存失败另行说明对话未保存，保留已有工具输出', (tester) async {
    final stored = record(
      status: ToolCallStatus.failed,
      errorCode: 'storageError',
      result: jsonEncode({
        'uri': 'content://fixture/file',
        'actionAccepted': true,
      }),
    );
    await pumpCard(tester, stored: stored, expanded: true);
    expect(find.text('相月未能保存这次对话，任务已停止。'), findsOneWidget);
    expect(find.textContaining('自动重发'), findsNothing);
    expect(find.textContaining('当前状态'), findsNothing);
    expect(find.text(stored.result!), findsOneWidget);
    expect(stored.result, contains('actionAccepted'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('产物 chip 打开文本内容', (tester) async {
    final file = File(p.join(tempDir.path, 'summary.md'));
    file.writeAsStringSync('# 摘要\n第一条');
    final stored = artifact(name: 'summary.md', path: file.path);
    await pumpCard(
      tester,
      stored: record(artifacts: [stored.id]),
      attachments: {stored.id: stored},
      expanded: true,
    );

    await tester.tap(find.byKey(ValueKey('tool-artifact-${stored.id}')));
    await _settle(tester);
    final content = find.descendant(
      of: find.byKey(const ValueKey('tool-artifact-content')),
      matching: find.byType(SelectableText),
    );
    expect(content, findsOneWidget);
    expect(tester.widget<SelectableText>(content).data, '# 摘要\n第一条');
  });

  testWidgets('图片产物显示缩略图', (tester) async {
    final file = File(p.join(tempDir.path, 'shot.png'));
    file.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
        'z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      ),
    );
    final stored = artifact(
      name: 'shot.png',
      path: file.path,
      mimeType: 'image/png',
      kind: AttachmentKind.image,
      size: file.lengthSync(),
    );
    await pumpCard(
      tester,
      stored: record(artifacts: [stored.id]),
      attachments: {stored.id: stored},
      expanded: true,
    );

    await tester.tap(find.byKey(ValueKey('tool-artifact-${stored.id}')));
    await _settle(tester);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('shot.png'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('产物文件不存在时给出明确文案', (tester) async {
    final stored = artifact(
      name: 'gone.md',
      path: p.join(tempDir.path, 'gone.md'),
    );
    await pumpCard(
      tester,
      stored: record(artifacts: [stored.id]),
      attachments: {stored.id: stored},
      expanded: true,
    );

    await tester.tap(find.byKey(ValueKey('tool-artifact-${stored.id}')));
    await _settle(tester);
    expect(find.text('产物文件不存在，可能已被删除或移动。'), findsOneWidget);
    expect(find.text('gone.md'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('二进制产物不按文本预览', (tester) async {
    final file = File(p.join(tempDir.path, 'data.bin'));
    file.writeAsBytesSync(const [0, 159, 146, 150]);
    final stored = artifact(
      name: 'data.bin',
      path: file.path,
      mimeType: 'application/octet-stream',
      size: 4,
    );
    await pumpCard(
      tester,
      stored: record(artifacts: [stored.id]),
      attachments: {stored.id: stored},
      expanded: true,
    );

    await tester.tap(find.byKey(ValueKey('tool-artifact-${stored.id}')));
    await _settle(tester);
    expect(find.text('这是二进制文件，不能按文本预览。'), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-artifact-content')), findsNothing);
  });
}

/// 有界推进 UI 与真实异步：读文件与面板动画都要走真实事件循环。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

class _FakeToolCalls implements ToolCallRepository {
  _FakeToolCalls(this.record);

  final ToolCallRecord? record;

  @override
  Stream<ToolCallRecord> watchById(String id) {
    final value = record;
    return value == null
        ? const Stream<ToolCallRecord>.empty()
        : Stream<ToolCallRecord>.value(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('卡片测试只用 watchById');
}
