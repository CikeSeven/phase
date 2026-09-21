import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/context_summary.dart';
import 'package:phase/features/chat/context/context_builder.dart';
import 'package:phase/features/tools/tool.dart';

ResolvedMessage message(String id, ChatRole role, String text) =>
    ResolvedMessage(
      sourceMessageId: id,
      role: role,
      parts: [ResolvedText(text)],
    );

void main() {
  const builder = ContextBuilder();
  const budget = ContextBudget(contextWindow: 9000, maxOutputTokens: 1000);
  List<ResolvedMessage> history() => [
    message('u1', ChatRole.user, '约束：不要重新提交付款'),
    message('a1', ChatRole.assistant, '背景资料。' * 500),
    const ResolvedMessage(
      sourceMessageId: 'a2',
      role: ChatRole.assistant,
      parts: [
        ResolvedToolCall(
          callId: 'x',
          toolName: 'payment',
          arguments: {'id': '123'},
        ),
        ResolvedToolCall(
          callId: 'y',
          toolName: 'write_file',
          arguments: {'path': 'out.txt'},
        ),
      ],
    ),
    const ResolvedMessage(
      sourceMessageId: 't1',
      role: ChatRole.tool,
      parts: [
        ResolvedToolResult(callId: 'x', content: '用户拒绝，没有执行', isError: true),
      ],
    ),
    const ResolvedMessage(
      sourceMessageId: 't2',
      role: ChatRole.tool,
      parts: [
        ResolvedToolResult(
          callId: 'y',
          content: '已写文件',
          artifactIds: ['artifact-1'],
        ),
      ],
    ),
    message('u2', ChatRole.user, '继续分析'),
    message('a3', ChatRole.assistant, '最近完整交互'),
    message('u3', ChatRole.user, '当前任务：汇报，不要写入'),
  ];
  ContextSummary summary(List<ResolvedMessage> h) {
    final source = builder.summarySource(h)!;
    return ContextSummary(
      id: 'summary',
      conversationId: 'c',
      runId: 'r',
      branchEndId: h.last.sourceMessageId!,
      coveredMessageIds: source.coveredIds,
      fingerprint: source.fingerprint,
      sourceModel: 'profile/model',
      createdAt: DateTime(2026),
      text: '背景结论',
      status: SummaryStatus.completed,
    );
  }

  test('预算包含系统、工具定义与输出预留，不切断当前任务或工具组', () {
    final h = history();
    final tools = ToolRegistry([const SystemInfoTool()])
        .definitionsFor({'system_info'}, {});
    expect(
      budget.estimate('系统约束', tools, h),
      greaterThan(budget.estimate('', [], h)),
    );
    expect(
      () =>
          builder.build(budget: budget, system: '', tools: tools, messages: h),
      throwsA(isA<OperationFailure>()),
    );
    final compact = builder.build(
      budget: budget,
      system: '',
      tools: tools,
      messages: h,
      summary: summary(h),
    );
    expect(compact.estimatedTokens, lessThanOrEqualTo(budget.input));
    expect(compact.summaryId, 'summary');
    expect(
      compact.messages.first.parts.whereType<ResolvedText>().single.text,
      contains('artifact-1'),
    );
    expect(compact.messages.first.role, ChatRole.user);
    final parts = compact.messages.expand((m) => m.parts).toList();
    expect(parts.whereType<ResolvedToolCall>().map((p) => p.callId), [
      'x',
      'y',
    ]);
    expect(parts.whereType<ResolvedToolResult>().map((p) => p.callId), [
      'x',
      'y',
    ]);
    expect(parts.whereType<ResolvedToolResult>().first.isError, isTrue);
    expect(
      parts.whereType<ResolvedText>().map((p) => p.text).join(),
      contains('不要重新提交付款'),
    );
    expect(identical(compact.messages.last, h.last), isTrue);
    expect(
      compact.messages.map((m) => m.sourceMessageId),
      containsAll(['u1', 'a2', 't1', 't2', 'u2', 'a3', 'u3']),
    );
  });

  test('切分支、编辑覆盖原文或工具状态后不复用摘要', () {
    final h = history();
    final s = summary(h);
    expect(builder.canReuse(s, builder.summarySource(h)!, h), isTrue);
    final sibling = [
      ...h.take(h.length - 1),
      message('sibling', ChatRole.user, '另一个分支'),
    ];
    expect(
      builder.canReuse(s, builder.summarySource(sibling)!, sibling),
      isFalse,
    );
    final edited = [message('u1', ChatRole.user, '新的约束'), ...h.skip(1)];
    expect(
      builder.canReuse(s, builder.summarySource(edited)!, edited),
      isFalse,
    );
    final changed = [...h];
    changed[3] = const ResolvedMessage(
      sourceMessageId: 't1',
      role: ChatRole.tool,
      parts: [ResolvedToolResult(callId: 'x', content: '状态有变化')],
    );
    expect(
      builder.canReuse(s, builder.summarySource(changed)!, changed),
      isFalse,
    );
  });

  test('未配对调用不进入摘要候选；超大约束与输出预留明确失败', () {
    final h = history()..removeAt(3);
    expect(builder.summarySource(h), isNull);
    expect(
      () => builder.build(
        budget: const ContextBudget(contextWindow: 5000, maxOutputTokens: 5000),
        system: '',
        tools: [],
        messages: [],
      ),
      throwsA(isA<OperationFailure>()),
    );
    final full = history();
    expect(
      () => builder.build(
        budget: budget,
        system: '硬性规则' * 1000,
        tools: [],
        messages: full,
        summary: summary(full),
      ),
      throwsA(isA<OperationFailure>()),
    );
  });
}
