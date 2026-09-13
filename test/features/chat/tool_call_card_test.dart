import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/tool_call_repository.dart';
import 'package:phase/features/chat/tool_call_card.dart';

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
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('卡片显示状态、动作摘要与结果，不显示模型的原始参数 JSON', (tester) async {
    await pumpCard(tester, stored: record(), attachments: const {});

    expect(find.text('写入文件'), findsOneWidget);
    expect(find.text('写入文件「summary.md」（8 字，新文件）'), findsOneWidget);
    expect(find.text('已创建「summary.md」（8 字）'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('tool-status-tool-1')))
          .data,
      '已完成',
    );
    // 参数与结果留在记录里：卡片不展示参数 JSON。
    expect(find.textContaining('"path"'), findsNothing);
    expect(find.textContaining('{"'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('记录不存在时不渲染卡片', (tester) async {
    await pumpCard(tester, stored: null);
    expect(find.text('写入文件'), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('读取失败显示文件名与原因，不直接显示工具 JSON', (tester) async {
    await pumpCard(
      tester,
      stored: record(
        toolName: 'read_file',
        status: ToolCallStatus.failed,
        errorCode: 'fileReadFailed',
        result: jsonEncode({
          'uri': 'content://fixture/tree/root/document/notes.txt',
          'name': 'notes.txt',
          'reason': '未能读取「notes.txt」的内容。',
        }),
      ),
    );
    expect(find.text('未能读取「notes.txt」的内容。'), findsOneWidget);
    expect(find.textContaining('content://'), findsNothing);
    expect(find.textContaining('"reason"'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('实际记录保存失败明确说明对话未保存，不显示 AI 恢复规则', (tester) async {
    final stored = record(
      status: ToolCallStatus.failed,
      errorCode: 'storageError',
      result: jsonEncode({
        'uri': 'content://fixture/file',
        'actionAccepted': true,
      }),
    );
    await pumpCard(tester, stored: stored);
    expect(find.text('相月未能保存这次对话，任务已停止。'), findsOneWidget);
    expect(find.textContaining('自动重发'), findsNothing);
    expect(find.textContaining('当前状态'), findsNothing);
    expect(find.textContaining('actionAccepted'), findsNothing);
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
