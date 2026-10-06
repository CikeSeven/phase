import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_loading_indicator.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/tools/tool_card.dart';
import 'package:phase/features/tools/tool_diff_view.dart';
import 'package:phase/features/tools/tool_presentation.dart';

void main() {
  ToolCallRecord createRecord({
    String id = 'tool-test',
    String toolName = 'shell',
    ToolCallStatus status = ToolCallStatus.succeeded,
    Map<String, dynamic> arguments = const {'command': 'echo "Hello Phase"'},
    String? result = 'Hello Phase\n',
    String? errorCode,
    List<String> artifacts = const [],
  }) {
    return ToolCallRecord(
      id: id,
      runId: 'run-1',
      assistantMessageId: 'msg-1',
      toolName: toolName,
      arguments: arguments,
      channel: ExecutionChannel.app,
      defaultPolicy: ToolPolicy.ask,
      status: status,
      result: result,
      errorCode: errorCode,
      artifacts: artifacts,
      createdAt: DateTime(2026, 10, 7),
    );
  }

  Widget buildHarness({required Widget child, bool dark = false}) {
    return MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(
        body: ListView(padding: const EdgeInsets.all(16), children: [child]),
      ),
    );
  }

  testWidgets('状态药丸徽标在各生命周期状态下的正确呈现', (tester) async {
    for (final (status, expectedLabel, hasLoading) in [
      (ToolCallStatus.executing, '执行中', true),
      (ToolCallStatus.succeeded, '已完成', false),
      (ToolCallStatus.failed, '已失败', false),
      (ToolCallStatus.cancelled, '已取消', false),
      (ToolCallStatus.rejected, '已拒绝', false),
    ]) {
      final record = createRecord(status: status);
      await tester.pumpWidget(buildHarness(child: ToolCard(record: record)));
      await tester.pump();

      final statusFinder = find.byKey(ValueKey('tool-status-${record.id}'));
      expect(statusFinder, findsOneWidget);
      expect(tester.widget<Text>(statusFinder).data, expectedLabel);

      if (hasLoading) {
        expect(find.byType(AppLoadingIndicator), findsOneWidget);
      } else {
        expect(find.byType(AppLoadingIndicator), findsNothing);
      }
    }
  });

  testWidgets('单卡与连续组卡片的表面和圆角契约', (tester) async {
    final record = createRecord();

    // 单卡模式：带有 RoundedRectangleBorder
    await tester.pumpWidget(
      buildHarness(child: ToolCard(record: record, grouped: false)),
    );
    await tester.pump();
    final singleMaterial = tester.widget<Material>(
      find.byKey(ValueKey('tool-card-${record.id}')),
    );
    expect(singleMaterial.shape, isA<RoundedRectangleBorder>());

    // 连续组卡片模式：shape 为 null，圆角由外层组控制
    await tester.pumpWidget(
      buildHarness(child: ToolCard(record: record, grouped: true)),
    );
    await tester.pump();
    final groupedMaterial = tester.widget<Material>(
      find.byKey(ValueKey('tool-card-${record.id}')),
    );
    expect(groupedMaterial.shape, isNull);
  });

  testWidgets('shell 命令的双视窗解耦（输入命令视窗与输出结果视窗）', (tester) async {
    final record = createRecord(
      toolName: 'shell',
      arguments: {'command': 'cat /etc/os-release', 'cwd': '/workspace'},
      result: 'NAME="Ubuntu"\nVERSION="24.04 LTS"\n',
    );

    await tester.pumpWidget(buildHarness(child: ToolCard(record: record)));
    await tester.pump();

    final toggle = find.byKey(ValueKey('tool-toggle-${record.id}'));
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));

    // 默认折叠：不显示输入与输出滚动区域
    expect(find.byKey(ValueKey('tool-arguments-${record.id}')), findsNothing);
    expect(find.byKey(ValueKey('tool-result-${record.id}')), findsNothing);

    // 点击展开
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // 输入视窗：包含终端命令标签、复制命令按钮与等宽命令行
    expect(find.text('终端命令'), findsOneWidget);
    expect(find.byTooltip('复制命令'), findsOneWidget);
    final inputWidget = find.byKey(PageStorageKey('tool-input-${record.id}'));
    expect(inputWidget, findsOneWidget);
    expect(tester.getSize(inputWidget).height, lessThanOrEqualTo(240));
    expect(find.textContaining('cat /etc/os-release'), findsWidgets);

    // 输出视窗：包含执行结果标签、复制输出按钮与输出文本
    expect(find.text('执行结果'), findsOneWidget);
    final copyOutput = find.byTooltip('复制输出');
    expect(copyOutput, findsOneWidget);
    expect(tester.getSize(copyOutput).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(copyOutput).height, greaterThanOrEqualTo(48));

    final outputWidget = find.byKey(PageStorageKey('tool-output-${record.id}'));
    expect(outputWidget, findsOneWidget);
    expect(tester.getSize(outputWidget).height, lessThanOrEqualTo(240));
    expect(find.textContaining('NAME="Ubuntu"'), findsOneWidget);

    // 测试复制输出交互反馈
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

    await tester.tap(copyOutput);
    await tester.pumpAndSettle();
    expect(copied, ['NAME="Ubuntu"\nVERSION="24.04 LTS"\n']);
    expect(find.text('已复制输出'), findsOneWidget);
  });

  testWidgets('执行失败时输出视窗明确标记为「错误输出」并采用错误色彩', (tester) async {
    final record = createRecord(
      toolName: 'shell',
      status: ToolCallStatus.failed,
      arguments: {'command': 'exit 1'},
      result: 'Process exited with code 1\n',
    );

    await tester.pumpWidget(
      buildHarness(child: ToolCard(record: record), dark: true),
    );
    await tester.pump();

    await tester.tap(find.byKey(ValueKey('tool-toggle-${record.id}')));
    await tester.pumpAndSettle();

    expect(find.text('错误输出'), findsOneWidget);
    final resultText = tester.widget<Text>(
      find.byKey(ValueKey('tool-result-${record.id}')),
    );
    expect(resultText.style?.color, isNotNull);
  });

  testWidgets('文件 Diff 视窗与统计徽标正确呈现', (tester) async {
    final record = createRecord(
      toolName: 'edit_file',
      arguments: {
        'path': 'lib/main.dart',
        'edits': [
          {'oldText': 'int a = 1;\n', 'newText': 'int a = 2;\n'},
        ],
      },
      result: '已替换 1 处文本。',
    );

    await tester.pumpWidget(buildHarness(child: ToolCard(record: record)));
    await tester.pump();

    await tester.tap(find.byKey(ValueKey('tool-toggle-${record.id}')));
    await tester.pumpAndSettle();

    expect(find.byType(ToolDiffView), findsOneWidget);
    // 验证头部右侧具有红绿区分的增删行数数字
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('−1'), findsOneWidget);
    // 验证已删除展开区内的多余操作栏和复制差异按钮
    expect(find.byTooltip('复制差异'), findsNothing);
  });

  testWidgets('存储错误告警横幅（storageError）结构化展示', (tester) async {
    final record = createRecord(
      status: ToolCallStatus.failed,
      errorCode: 'storageError',
      result: '{"ok": false}',
    );

    await tester.pumpWidget(buildHarness(child: ToolCard(record: record)));
    await tester.pump();

    await tester.tap(find.byKey(ValueKey('tool-toggle-${record.id}')));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.circleAlert), findsWidgets);
    expect(find.text(ToolPresentation.storageFailureMessage), findsOneWidget);
  });

  testWidgets('附件按钮点击能正确触发 onOpenArtifact 回调', (tester) async {
    final artifact = Attachment(
      id: 'doc-1',
      conversationId: 'conv-1',
      kind: AttachmentKind.artifact,
      name: 'report.txt',
      mimeType: 'text/plain',
      size: 1024,
      localPath: '/tmp/report.txt',
      createdAt: DateTime(2026),
    );

    final record = createRecord(artifacts: [artifact.id]);

    Attachment? opened;
    await tester.pumpWidget(
      buildHarness(
        child: ToolCard(
          record: record,
          artifacts: [artifact],
          onOpenArtifact: (a) => opened = a,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(ValueKey('tool-toggle-${record.id}')));
    await tester.pumpAndSettle();

    final artifactButton = find.byKey(ValueKey('tool-artifact-${artifact.id}'));
    expect(artifactButton, findsOneWidget);
    expect(find.text('report.txt'), findsOneWidget);

    await tester.tap(artifactButton);
    await tester.pumpAndSettle();
    expect(opened?.id, 'doc-1');
  });

  testWidgets('深色模式与浅色模式无异常且触区符合规范', (tester) async {
    for (final dark in [false, true]) {
      final record = createRecord(id: 'tool-mode-$dark');
      await tester.pumpWidget(
        buildHarness(
          child: ToolCard(record: record),
          dark: dark,
        ),
      );
      await tester.pump();

      final toggle = find.byKey(ValueKey('tool-toggle-${record.id}'));
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      final copyButton = find.byTooltip('复制命令');
      expect(tester.getSize(copyButton).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(copyButton).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('文件预览与执行结果直接平铺无嵌套卡片，并具有代码语法高亮', (tester) async {
    const fileCode =
        'import "dart:async";\n\nvoid main() {\n  final x = 42;\n}\n';
    final record = createRecord(
      id: 'tool-read-1',
      toolName: 'read_file',
      arguments: {'path': 'lib/main.dart'},
      result: fileCode,
    );
    await tester.pumpWidget(buildHarness(child: ToolCard(record: record)));
    await tester.pump();

    // 展开卡片
    await tester.tap(find.byKey(ValueKey('tool-toggle-${record.id}')));
    await tester.pumpAndSettle();

    // 验证标题为「文件内容」
    expect(find.text('文件内容'), findsOneWidget);

    // 验证代码高亮组件存在
    final codeFinder = find.byKey(ValueKey('tool-result-${record.id}'));
    expect(codeFinder, findsOneWidget);

    final codeWidget = tester.widget<HighlightedCodeText>(codeFinder);
    expect(codeWidget.highlightSpan, isA<TextSpan>());
    final span = codeWidget.highlightSpan as TextSpan;
    // 关键字 import, void, final 等应着色
    final hasSyntaxColor =
        span.children?.any((c) => c.style?.color != null) ?? false;
    expect(hasSyntaxColor, isTrue);

    // 验证内部没有嵌套具有 BoxDecoration 边框背景的子卡片 Container
    // 在 tool-output 单滚动视窗周围直接展示代码，充分释放手机屏幕宽度
    final outputScrollFinder = find.byKey(
      PageStorageKey('tool-output-${record.id}'),
    );
    expect(outputScrollFinder, findsOneWidget);
  });
}
