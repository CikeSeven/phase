import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/context_summary.dart';
import 'package:phase/features/chat/context/context_builder.dart';

ResolvedMessage message(String id, ChatRole role, String text) =>
    ResolvedMessage(
      sourceMessageId: id,
      role: role,
      parts: [ResolvedText(text)],
    );
List<ResolvedMessage> group(
  String id, {
  bool readOnly = true,
  bool error = false,
}) => [
  ResolvedMessage(
    sourceMessageId: 'a$id',
    role: ChatRole.assistant,
    parts: [
      ResolvedToolCall(
        callId: 'repeated',
        recordId: 'r$id',
        toolName: 'read_file',
        arguments: const {'path': 'out.txt'},
        historyReadOnly: readOnly,
      ),
    ],
  ),
  ResolvedMessage(
    sourceMessageId: 't$id',
    role: ChatRole.tool,
    parts: [
      ResolvedToolResult(
        callId: 'repeated',
        recordId: 'r$id',
        content: '资料' * 300,
        status: error ? 'rejected' : 'succeeded',
        isError: error,
        artifactIds: ['artifact$id'],
      ),
    ],
  ),
];
void main() {
  const builder = ContextBuilder();
  ContextSummary summary(
    List<ResolvedMessage> prefix, {
    String id = 's',
    String? parent,
  }) => ContextSummary(
    id: id,
    conversationId: 'c',
    runId: 'r',
    branchEndId: 'tail',
    coveredMessageIds: prefix.map((m) => m.sourceMessageId!).toList(),
    fingerprint: builder.fingerprint(prefix),
    sourceModel: 'fixture',
    createdAt: DateTime(2026),
    status: SummaryStatus.completed,
    adoption: SummaryAdoption.applied,
    text: '来源结论',
    parentSummaryId: parent,
  );

  test('一次用户任务按完整工具组切分，重复 provider ID 不串组', () {
    final h = [
      message('u', ChatRole.user, '当前任务'),
      ...group('1'),
      ...group('2'),
      ...group('3'),
    ];
    final source = builder.summarySource(
      h,
      protectedIds: {'u'},
      recentTokens: 2000,
      canReadHistory: true,
    )!;
    expect(source.coveredIds, ['a1', 't1', 'a2', 't2']);
    final s = summary(source.prefix);
    final compact = builder.select(
      messages: h,
      summary: s,
      summaries: [s],
      protectedIds: {'u'},
      canReadHistory: true,
    );
    expect(
      compact.map((m) => m.sourceMessageId),
      containsAll(['u', 'a3', 't3']),
    );
    expect(
      compact.expand((m) => m.parts).whereType<ResolvedToolCall>(),
      hasLength(1),
    );
    expect(
      compact.expand((m) => m.parts).whereType<ResolvedToolResult>(),
      hasLength(1),
    );
    expect(
      (compact.first.parts.single as ResolvedText).text,
      contains('artifact1'),
    );
    expect(h, hasLength(7));
  });

  test('外部动作、拒绝、未收口组不进入淘汰区间', () {
    final h = [
      message('u', ChatRole.user, '任务'),
      ...group('1', readOnly: false),
      ...group('2', error: true),
      ...group('3'),
      group('4').first,
    ];
    final source = builder.summarySource(
      h,
      protectedIds: {'u'},
      recentTokens: 0,
      canReadHistory: true,
    )!;
    expect(source.coveredIds, ['a3', 't3']);
    final s = summary(source.prefix);
    final compact = builder.select(
      messages: h,
      summary: s,
      summaries: [s],
      protectedIds: {'u'},
      canReadHistory: true,
    );
    expect(
      compact.map((m) => m.sourceMessageId),
      containsAll(['a1', 't1', 'a2', 't2', 'a4']),
    );
  });

  test('未启用历史读取时仅压缩助手叙述，用户与工具原文保留', () {
    final h = [
      message('u', ChatRole.user, '旧约束'),
      message('a', ChatRole.assistant, '长说明' * 500),
      ...group('1'),
      message('new', ChatRole.user, '新任务'),
    ];
    final source = builder.summarySource(h, recentTokens: 1)!;
    expect(source.coveredIds, ['a']);
  });

  test('滚动父链沿后代/共享前缀复用，编辑与缺失父链失效', () {
    final first = group('1');
    final second = group('2');
    final a = summary(first, id: 'a');
    final b = summary(second, id: 'b', parent: 'a');
    final h = [...first, ...second, ...group('3')];
    expect(builder.coverage(b, [b, a], h), {'a1', 't1', 'a2', 't2'});
    expect(builder.coverage(b, [b], h), isNull);
    expect(
      builder.coverage(b, [b, a], [...group('1', error: true), ...second]),
      isNull,
    );
    expect(
      builder.active([b, a], [...h, message('later', ChatRole.user, '后代')])?.id,
      'b',
    );
    expect(builder.coverage(b, [b, a], [h.first, ...second]), isNull);
  });

  test('单助手多个调用的结果未齐全时不能切开', () {
    const call = ResolvedMessage(
      sourceMessageId: 'a',
      role: ChatRole.assistant,
      parts: [
        ResolvedToolCall(
          callId: 'x',
          toolName: 'read_file',
          arguments: {},
          historyReadOnly: true,
        ),
        ResolvedToolCall(
          callId: 'y',
          toolName: 'read_file',
          arguments: {},
          historyReadOnly: true,
        ),
      ],
    );
    final h = [
      call,
      const ResolvedMessage(
        sourceMessageId: 'x',
        role: ChatRole.tool,
        parts: [ResolvedToolResult(callId: 'x', content: 'x')],
      ),
      message('tail', ChatRole.user, '任务'),
    ];
    expect(builder.groups(h).single.closed, isFalse);
    expect(
      builder.summarySource(h, recentTokens: 0, canReadHistory: true),
      isNull,
    );
  });
}
