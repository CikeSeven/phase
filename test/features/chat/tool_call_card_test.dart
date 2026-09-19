import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/tool_source.dart';
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
    Map<String, dynamic> arguments = const {
      'path': 'summary.md',
      'content': '# 摘要',
    },
    ToolSource? source,
  }) {
    return ToolCallRecord(
      id: 'tool-1',
      runId: 'run-1',
      assistantMessageId: 'msg-1',
      toolName: toolName,
      arguments: arguments,
      source: source,
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
    expect(find.text('输入参数'), findsOneWidget);
    expect(find.text('输出内容'), findsOneWidget);
    expect(find.text('path: summary.md\n\ncontent: # 摘要'), findsOneWidget);
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

  testWidgets('命令卡片展示实际参数、两路输出和退出码，去除执行封装', (tester) async {
    final stored = record(
      toolName: 'shell',
      status: ToolCallStatus.failed,
      arguments: const {
        'command': 'printf "first\\nsecond\\n"; missing-command',
        'cwd': '/workspace/project',
        'timeoutMs': 3000,
      },
      result: jsonEncode({
        'environment': '24.04-arm64',
        'workspace': '测试空间',
        'cwd': '/workspace/project',
        'stdout': 'first\nsecond\n',
        'stderr': '/bin/sh: missing-command: not found\n',
        'exitCode': 127,
        'signal': null,
        'cancelled': false,
        'timedOut': false,
        'outputLimitExceeded': false,
        'stdoutBytes': 13,
        'stderrBytes': 41,
        'previewTruncated': false,
        'artifactIds': ['internal-artifact-id'],
        'importedFiles': [],
        'knownEffects': '已收集输出；工作区中的文件变化保留，失败或停止不代表撤销',
      }),
    );
    await pumpCard(tester, stored: stored, expanded: true);
    expect(
      find.text(
        'command: printf "first\\nsecond\\n"; missing-command\n\n'
        'cwd: /workspace/project\n\ntimeoutMs: 3000',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'stdout\nfirst\nsecond\n\n\n'
        'stderr\n/bin/sh: missing-command: not found\n\n\n退出码：127',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('knownEffects'), findsNothing);
    expect(find.textContaining('internal-artifact-id'), findsNothing);
    // 展示转换不能修改仓储里的完整回执。
    expect(jsonDecode(stored.result!)['environment'], '24.04-arm64');
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (
      status: ToolCallStatus.cancelled,
      flags: {'cancelled': true},
      hint: '命令已停止',
    ),
    (status: ToolCallStatus.failed, flags: {'timedOut': true}, hint: '命令执行超时'),
    (
      status: ToolCallStatus.failed,
      flags: {'outputLimitExceeded': true},
      hint: '输出达到上限，进程已停止',
    ),
  ]) {
    testWidgets('命令${scenario.hint}时保留部分输出、截断提示与实际错误', (tester) async {
      await pumpCard(
        tester,
        stored: record(
          toolName: 'shell',
          arguments: const {'command': 'long-command'},
          status: scenario.status,
          result: jsonEncode({
            'stdout': '已完成第一步\n',
            'stderr': '',
            'signal': 15,
            'previewTruncated': true,
            'error': '命令输出文件保存失败',
            ...scenario.flags,
          }),
        ),
        expanded: true,
      );
      final text = tester
          .widget<Text>(find.byKey(const ValueKey('tool-result-tool-1')))
          .data!;
      expect(text, contains('stdout\n已完成第一步\n'));
      expect(text, contains(scenario.hint));
      expect(text, contains('终止信号：15'));
      expect(text, contains('输出预览已截断'));
      expect(text, contains('命令输出文件保存失败'));
      expect(text, isNot(contains('完整输出见附件')));
    });
  }

  testWidgets('无输出命令与派发前错误如实显示，原始异常文本不丢失', (tester) async {
    await pumpCard(
      tester,
      stored: record(
        toolName: 'shell',
        arguments: const {'command': 'true'},
        result: '{"stdout":"","stderr":"","exitCode":0}',
      ),
      expanded: true,
    );
    expect(find.text('（无输出）\n\n退出码：0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpCard(
      tester,
      stored: record(
        toolName: 'shell',
        status: ToolCallStatus.failed,
        result: '请先准备 Ubuntu 环境并绑定工作区',
      ),
      expanded: true,
    );
    expect(find.text('请先准备 Ubuntu 环境并绑定工作区'), findsOneWidget);
  });

  testWidgets('MCP 参数保留空值与结构，结果不套用内置命令的过滤规则', (tester) async {
    final result = {
      'stdout': '工具返回的正文',
      'stderr': '',
      'environment': {'name': '服务端业务数据'},
      'knownEffects': '工具定义的返回字段',
    };
    await pumpCard(
      tester,
      stored: record(
        toolName: 'shell',
        source: const ToolSource(
          kind: ToolSourceKind.mcp,
          id: 'server',
          originalName: 'shell',
          definitionRevision: 'revision',
        ),
        arguments: const {
          'empty': '',
          'unset': null,
          'options': {'enabled': false, 'limit': 0},
        },
        result: jsonEncode(result),
      ),
      expanded: true,
    );
    expect(
      find.text(
        'empty: ""\n\nunset: null\n\noptions: {\n  "enabled": false,\n  "limit": 0\n}',
      ),
      findsOneWidget,
    );
    final output = tester
        .widget<Text>(find.byKey(const ValueKey('tool-result-tool-1')))
        .data!;
    expect(jsonDecode(output), result);
  });

  testWidgets('Skill 直接展示资源正文和续读位置', (tester) async {
    await pumpCard(
      tester,
      stored: record(
        toolName: 'read_skill',
        arguments: const {'skillId': 'skill', 'relativePath': 'SKILL.md'},
        result: jsonEncode({
          'skillId': 'skill',
          'name': 'fixture',
          'revision': 'digest',
          'source': 'import',
          'relativePath': 'SKILL.md',
          'offset': 0,
          'nextOffset': 4000,
          'content': '# 指导\n\n资源内容',
        }),
      ),
      expanded: true,
    );
    expect(
      find.text('# 指导\n\n资源内容\n\noffset: 0\n\nnextOffset: 4000'),
      findsOneWidget,
    );
  });

  testWidgets('长输入可滚到末尾并完整复制，收起后恢复输入位置', (tester) async {
    final content = '${'文件内容\n' * 300}末尾内容';
    await pumpCard(
      tester,
      stored: record(arguments: {'path': 'notes.txt', 'content': content}),
      expanded: true,
    );
    final input = find.byKey(const PageStorageKey('tool-input-tool-1'));
    final controller = tester.widget<SingleChildScrollView>(input).controller!;
    expect(tester.getSize(input).height, lessThanOrEqualTo(160));
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final offset = controller.offset;
    final toggle = find.byKey(const ValueKey('tool-toggle-tool-1'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(offset, 0.5));
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.byTooltip('复制输入参数'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('复制输出内容'));
    await tester.pumpAndSettle();
    expect(copied, [
      'path: notes.txt\n\ncontent: $content',
      '已创建「summary.md」（8 字）',
    ]);
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

  testWidgets('文件结构化输出直接展示完整正文与分页信息', (tester) async {
    final content = '${'完整正文\n' * 80}文件末尾';
    final result = jsonEncode({
      'name': 'notes.txt',
      'text': content,
      'startLine': 1,
      'endLine': 81,
      'truncated': true,
      'nextOffset': 82,
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
      '$content\n\nstartLine: 1\n\nendLine: 81\n\ntruncated: true\n\nnextOffset: 82',
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
    final output = tester
        .widget<Text>(find.byKey(const ValueKey('tool-result-tool-1')))
        .data!;
    expect(jsonDecode(output), jsonDecode(result));
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
    final output = tester
        .widget<Text>(find.byKey(const ValueKey('tool-result-tool-1')))
        .data!;
    expect(jsonDecode(output), jsonDecode(stored.result!));
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
