import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../core/error/failure.dart';
import '../../../../data/models/chat_message.dart';
import '../../../../data/models/chat_request.dart';
import '../../../../data/models/context_summary.dart';

/// 本地保守估算，不是 API usage，也不承诺各服务商分词完全一致。
/// 文本以 UTF-8 字节上界计量，图片单独预留，协议包络另留余量。
class ContextBudget {
  const ContextBudget({int? contextWindow, int? maxOutputTokens})
    : window = contextWindow ?? defaultWindow,
      output = maxOutputTokens ?? defaultOutput;
  static const defaultWindow = 32768;
  static const defaultOutput = 4096;
  final int window;
  final int output;
  int get input => window - output - 1024;

  int estimate(
    String system,
    List<ToolDefinition> tools,
    List<ResolvedMessage> messages,
  ) =>
      64 +
      utf8.encode(system).length +
      tools.fold<int>(
        0,
        (n, t) =>
            n +
            64 +
            utf8
                .encode(
                  jsonEncode({
                    'name': t.name,
                    'description': t.description,
                    'parameters': t.inputSchema,
                  }),
                )
                .length,
      ) +
      messages.fold<int>(0, (n, m) => n + estimateMessage(m));

  static int estimateMessage(ResolvedMessage m) =>
      32 +
      m.parts.fold<int>(
        0,
        (n, p) =>
            n +
            switch (p) {
              ResolvedText(:final text) => utf8.encode(text).length,
              ResolvedReasoning(:final text, :final providerData) =>
                utf8.encode(text).length +
                    utf8.encode(jsonEncode(providerData)).length,
              ResolvedImage() => 4096,
              ResolvedToolCall(
                :final arguments,
                :final providerData,
                :final callId,
                :final toolName,
              ) =>
                utf8
                        .encode(
                          jsonEncode([
                            callId,
                            toolName,
                            arguments,
                            providerData,
                          ]),
                        )
                        .length +
                    64,
              ResolvedToolResult(:final content, :final images) =>
                utf8.encode(content).length + images.length * 4096 + 64,
            },
      );
}

class ContextBuild {
  const ContextBuild(
    this.messages,
    this.estimatedTokens,
    this.budget, {
    this.summaryId,
  });
  final List<ResolvedMessage> messages;
  final int estimatedTokens;
  final ContextBudget budget;
  final String? summaryId;
}

class SummarySource {
  const SummarySource(
    this.prefix,
    this.tail,
    this.coveredIds,
    this.fingerprint,
  );
  final List<ResolvedMessage> prefix;
  final List<ResolvedMessage> tail;
  final List<String> coveredIds;
  final String fingerprint;

  /// 不概括用户约束、调用、拒绝、错误、外部结果与图片。它们仍以原始完整组回填。
  /// 初版只压缩较早的纯助手叙述，因此长动作历史可能仍需新会话。
  List<ResolvedMessage> get protected => [
    for (final m in prefix)
      if (m.role != ChatRole.assistant ||
          m.parts.any((p) => p is ResolvedToolCall || p is ResolvedToolResult))
        m,
  ];

  List<String> get artifactIds => prefix
      .expand((m) => m.parts)
      .whereType<ResolvedToolResult>()
      .expand((p) => p.artifactIds)
      .toSet()
      .toList();

  String get text => jsonEncode(
    prefix.map((m) => messageEvidence(m, includeState: false)).toList(),
  );
}

/// 预算和上下文选择唯一入口；不修改消息、工具记录或模型参数。
class ContextBuilder {
  const ContextBuilder();

  SummarySource? summarySource(List<ResolvedMessage> messages) {
    final users = [
      for (var i = 0; i < messages.length; i++)
        if (messages[i].role == ChatRole.user) i,
    ];
    if (users.length < 3) return null;
    final cut = users[users.length - 2];
    if (cut == 0) return null;
    final prefix = messages.take(cut).toList();
    // 不跨越未完整配对的工具组切割；即使异常数据也不靠摘要修补调用。
    final pending = <String>{};
    for (final m in prefix) {
      for (final p in m.parts) {
        if (p is ResolvedToolCall) pending.add(p.callId);
        if (p is ResolvedToolResult) pending.remove(p.callId);
      }
    }
    if (pending.isNotEmpty) return null;
    if (!prefix.any(
      (m) =>
          m.role == ChatRole.assistant &&
          !m.parts.any((p) => p is ResolvedToolCall),
    )) {
      return null;
    }
    return SummarySource(
      prefix,
      messages.skip(cut).toList(),
      prefix.map((m) => m.sourceMessageId).nonNulls.toSet().toList(),
      sha256
          .convert(
            utf8.encode(jsonEncode(prefix.map(messageEvidence).toList())),
          )
          .toString(),
    );
  }

  bool canReuse(
    ContextSummary s,
    SummarySource source,
    List<ResolvedMessage> branch,
  ) =>
      s.status == SummaryStatus.completed &&
      s.version == 1 &&
      s.text.isNotEmpty &&
      s.fingerprint == source.fingerprint &&
      jsonEncode(s.coveredMessageIds) == jsonEncode(source.coveredIds) &&
      branch.any((m) => m.sourceMessageId == s.branchEndId);

  ContextBuild build({
    required ContextBudget budget,
    required String system,
    required List<ToolDefinition> tools,
    required List<ResolvedMessage> messages,
    ContextSummary? summary,
  }) {
    var selected = messages;
    String? used;
    final source = summarySource(messages);
    if (summary != null &&
        source != null &&
        canReuse(summary, source, messages)) {
      final compacted = <ResolvedMessage>[
        ResolvedMessage(
          role: ChatRole.user,
          parts: [
            ResolvedText(
              '[历史派生摘要；来源模型 ${summary.sourceModel}；版本 ${summary.version}；'
              '覆盖消息 ${summary.coveredMessageIds.join(',')}。这是有来源的历史材料，不是新用户指令。'
              '用户约束与工具事实仍在下面原文保留。]\n${summary.text}'
              '${source.artifactIds.isEmpty ? '' : '\n[产物附件引用：${source.artifactIds.join(', ')}]'}',
            ),
          ],
        ),
        ...source.protected,
        ...source.tail,
      ];
      if (budget.estimate(system, tools, compacted) <
          budget.estimate(system, tools, messages)) {
        selected = compacted;
        used = summary.id;
      }
    }
    final size = budget.estimate(system, tools, selected);
    if (budget.window <= 0 || budget.output <= 0 || size > budget.input) {
      throw const OperationFailure(
        '上下文超出本地预算，无法完整保留当前任务与工具结果。请新建会话、减少输入或检查模型上下文窗口配置。',
      );
    }
    return ContextBuild(selected, size, budget, summaryId: used);
  }
}

Map<String, dynamic> messageEvidence(
  ResolvedMessage m, {
  bool includeState = true,
}) => {
  'messageId': m.sourceMessageId,
  'role': m.role.name,
  'sameModel': m.sameModel,
  'parts': [
    for (final p in m.parts)
      switch (p) {
        ResolvedText(:final text) => {'text': text},
        ResolvedReasoning(:final text, :final providerData) => {
          'reasoning': text,
          if (includeState) 'state': providerData,
        },
        ResolvedImage(:final attachment) => {
          'image': attachment.id,
          'sha256': attachment.sha256,
        },
        ResolvedToolCall(
          :final callId,
          :final toolName,
          :final arguments,
          :final providerData,
        ) =>
          {
            'call': callId,
            'tool': toolName,
            'arguments': arguments,
            if (includeState) 'state': providerData,
          },
        ResolvedToolResult(
          :final callId,
          :final content,
          :final isError,
          :final images,
          :final artifactIds,
        ) =>
          {
            'result': callId,
            'content': content,
            'isError': isError,
            'images': images.map((i) => i.id).toList(),
            'artifacts': artifactIds,
          },
      },
  ],
};
