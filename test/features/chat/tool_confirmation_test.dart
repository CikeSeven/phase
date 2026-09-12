import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_spacing.dart';
import 'package:phase/core/widgets/app_sheet.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/chat/tool_confirmation_sheet.dart';
import 'package:phase/features/tools/tool_executor.dart';

/// 确认面板：工具、目标、真实参数、通道与剩余时间，三个动作各自返回决定。
void main() {
  ToolCallRecord record({
    String toolName = 'write_file',
    Map<String, dynamic> arguments = const {
      'path': 'summary.md',
      'content': '# 摘要\n第一条',
    },
    ExecutionChannel channel = ExecutionChannel.app,
  }) {
    return ToolCallRecord(
      id: 'tool-1',
      runId: 'run-1',
      assistantMessageId: 'msg-1',
      toolName: toolName,
      arguments: arguments,
      target: '写入文件「summary.md」（10 字，新文件）',
      channel: channel,
      defaultPolicy: ToolPolicy.ask,
      status: ToolCallStatus.awaitingConfirmation,
      createdAt: DateTime(2026, 9, 12, 10),
    );
  }

  ToolConfirmationRequest request({
    ToolCallRecord? toolCall,
    Duration remaining = const Duration(seconds: 60),
  }) {
    final value = toolCall ?? record();
    return ToolConfirmationRequest(
      record: value,
      summary: value.target ?? '执行动作',
      policy: ToolPolicy.ask,
      expiresAt: DateTime.now().add(remaining),
    );
  }

  /// 打开面板并记录它返回的结果。
  Future<ValueNotifier<ToolConfirmationOutcome?>> openSheet(
    WidgetTester tester, {
    required ToolConfirmationRequest confirmation,
  }) async {
    final outcome = ValueNotifier<ToolConfirmationOutcome?>(null);
    addTearDown(outcome.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                outcome.value = await showToolConfirmationSheet(
                  context,
                  confirmation,
                );
              },
              child: const Text('打开确认面板'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开确认面板'));
    await tester.pumpAndSettle();
    return outcome;
  }

  String parameterText(WidgetTester tester, String name) {
    return tester
            .widget<SelectableText>(
              find.byKey(ValueKey('tool-parameter-$name')),
            )
            .data ??
        '';
  }

  testWidgets('面板展示工具名、动作摘要、真实参数、执行通道与剩余时间', (tester) async {
    await openSheet(tester, confirmation: request());

    expect(find.text('写入文件'), findsOneWidget);
    expect(find.text('写入文件「summary.md」（10 字，新文件）'), findsOneWidget);
    expect(find.textContaining('执行通道：应用内'), findsOneWidget);
    expect(find.textContaining('策略：需要确认'), findsOneWidget);
    expect(find.textContaining('目标：写入文件'), findsOneWidget);
    // 参数展示真实值，不是「某些参数」的占位说明。
    expect(parameterText(tester, 'path'), 'summary.md');
    expect(parameterText(tester, 'content'), '# 摘要\n第一条');
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('tool-confirmation-countdown')),
          )
          .data,
      contains('剩余'),
    );
    expect(find.byKey(const ValueKey('tool-confirm-allow')), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-confirm-reject')), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-confirm-stop')), findsOneWidget);
    // 面板不展示模型的原始参数 JSON。
    expect(find.textContaining('{"path"'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('三个动作各占一行，停止任务在最上且是红色，拖动杆只有一根', (tester) async {
    // 手机尺寸的视口：面板 footer 有 32% 高度上限，过矮的窗口里它自身会滚动，
    // 量出来的位置就不代表真机上的排版。
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openSheet(tester, confirmation: request());

    final stop = tester.getRect(
      find.byKey(const ValueKey('tool-confirm-stop')),
    );
    final reject = tester.getRect(
      find.byKey(const ValueKey('tool-confirm-reject')),
    );
    final allow = tester.getRect(
      find.byKey(const ValueKey('tool-confirm-allow')),
    );
    // 自上而下：停止任务 → 拒绝 → 允许一次，每个各占一整行。
    expect(stop.bottom, lessThanOrEqualTo(reject.top));
    expect(reject.bottom, lessThanOrEqualTo(allow.top));
    expect(reject.left, closeTo(stop.left, 0.5));
    expect(allow.width, closeTo(stop.width, 0.5));
    expect(stop.width, greaterThan(200));

    // 停止任务用错误色：这是不可撤销的收尾动作。
    final colors = AppTheme.light().colorScheme;
    final style = tester
        .widget<OutlinedButton>(find.byKey(const ValueKey('tool-confirm-stop')))
        .style;
    expect(style?.foregroundColor?.resolve({}), colors.error);

    // 按钮再往上一截：贴着面板下沿容易误触（footer 内边距 + 这一段留白）。
    final sheetBottom = tester.getRect(find.byType(AppSheet)).bottom;
    expect(sheetBottom - allow.bottom, greaterThanOrEqualTo(AppSpacing.l * 2));

    // 拖动杆只有 AppSheet 自己画的那一根：框架再画一根会变成上下两根。
    final handles = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (container) =>
              container.constraints?.maxWidth == AppSpacing.xxl &&
              container.constraints?.maxHeight == AppSpacing.xs,
        );
    expect(handles, hasLength(1));
  });

  testWidgets('未登记的工具也逐条展示真实参数', (tester) async {
    await openSheet(
      tester,
      confirmation: request(
        toolCall: record(
          toolName: 'http_request',
          arguments: const {
            'url': 'https://example.com/a?b=1',
            'method': 'POST',
            'headers': {'X-Trace': 'abc'},
            'body': '{"q":1}',
          },
        ),
      ),
    );

    expect(find.text('HTTP 请求'), findsOneWidget);
    expect(parameterText(tester, 'url'), 'https://example.com/a?b=1');
    expect(parameterText(tester, 'method'), 'POST');
    expect(parameterText(tester, 'headers'), contains('"X-Trace": "abc"'));
    // 请求正文在长参数之后：滚动到底部再断言它的真实取值。
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('tool-parameter-body')),
      find.byKey(const ValueKey('tool-confirmation-body')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(parameterText(tester, 'body'), '{"q":1}');
  });

  testWidgets('超长正文按上限预览并说明总字数', (tester) async {
    final content = 'x' * 2000;
    await openSheet(
      tester,
      confirmation: request(
        toolCall: record(arguments: {'path': 'big.md', 'content': content}),
      ),
    );

    final preview = parameterText(tester, 'content');
    expect(preview, startsWith('x' * 100));
    expect(preview, contains('……（共 2000 字，以上为前 1200 字）'));
    expect(preview.length, lessThan(content.length));
  });

  testWidgets('允许一次返回对应决定并关闭面板', (tester) async {
    final outcome = await openSheet(tester, confirmation: request());
    await tester.tap(find.byKey(const ValueKey('tool-confirm-allow')));
    await tester.pumpAndSettle();
    expect(outcome.value, ToolConfirmationOutcome.allowOnce);
    expect(find.byKey(const ValueKey('tool-confirmation-body')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拒绝返回对应决定并关闭面板', (tester) async {
    final outcome = await openSheet(tester, confirmation: request());
    await tester.tap(find.byKey(const ValueKey('tool-confirm-reject')));
    await tester.pumpAndSettle();
    expect(outcome.value, ToolConfirmationOutcome.reject);
    expect(find.byKey(const ValueKey('tool-confirmation-body')), findsNothing);
  });

  testWidgets('停止任务返回对应决定并关闭面板', (tester) async {
    final outcome = await openSheet(tester, confirmation: request());
    await tester.tap(find.byKey(const ValueKey('tool-confirm-stop')));
    await tester.pumpAndSettle();
    expect(outcome.value, ToolConfirmationOutcome.stopTask);
    expect(find.byKey(const ValueKey('tool-confirmation-body')), findsNothing);
  });

  testWidgets('关闭面板视为未决定，不返回批准', (tester) async {
    final outcome = await openSheet(tester, confirmation: request());
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(outcome.value, ToolConfirmationOutcome.expired);
    expect(find.byKey(const ValueKey('tool-confirmation-body')), findsNothing);
  });

  testWidgets('已过期的请求不再等待，直接按未决定收口', (tester) async {
    final outcome = await openSheet(
      tester,
      confirmation: request(remaining: const Duration(seconds: -1)),
    );
    await tester.pumpAndSettle();
    expect(outcome.value, ToolConfirmationOutcome.expired);
    expect(find.byKey(const ValueKey('tool-confirmation-body')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
