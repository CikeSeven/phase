import 'package:phase/data/models/token_usage.dart';

import 'dart:async';

import 'package:phase/core/error/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/features/chat/context/summary_request.dart';
import 'package:phase/features/tools/tool.dart';

import '../../tools/tool_loop_harness.dart';

void main() {
  test('摘要进度异步落库失败关闭订阅，StorageFailure 不伪装完成或悬挂', () async {
    var cancelled = false;
    final stream = StreamController<ChatChunk>(
      onCancel: () {
        cancelled = true;
      },
    );
    final provider = ScriptedProvider(ApiProtocol.openaiCompletions)
      ..turns.add(stream.stream);
    final request = requestSummary(
      provider,
      const ChatRequest(modelId: 'model', messages: []),
      RunCancellation(),
      onProgress: (_, _, _, _) async {
        throw const StorageFailure('fixture');
      },
    );
    final assertion = expectLater(
      request.timeout(const Duration(seconds: 2)),
      throwsA(isA<StorageFailure>()),
    );
    stream.add(const TextDelta(partId: 't', text: 'partial'));
    await assertion;
    expect(cancelled, isTrue);
    await stream.close();
  });

  test('摘要以完成快照替换增量，正文、用量分离，丢弃终态后内容', () async {
    final provider = ScriptedProvider(ApiProtocol.openaiCompletions);
    provider.turns.add(
      Stream.fromIterable(const [
        PartStart(partId: 't', kind: PartKind.text, initialContent: '结'),
        TextDelta(partId: 't', text: '论'),
        PartEnd(
          partId: 't',
          part: TextPart(text: '结论完整'),
        ),
        UsageChunk(usage: TokenUsage(promptTokens: 10, outputTokens: 3)),
        ResponseEnd(),
        TextDelta(partId: 't', text: '迟到文字'),
      ]),
    );
    final result = await requestSummary(
      provider,
      const ChatRequest(modelId: 'model', messages: []),
      RunCancellation(),
    );
    expect(result.completed, isTrue);
    expect(result.text, '结论完整');
    expect(result.usage?.promptTokens, 10);
  });

  test('摘要请求拒绝工具响应与过量输出，不自动重试', () async {
    for (final response in [
      const [
        TextDelta(partId: 't', text: '正文'),
        PartStart(partId: 'tool', kind: PartKind.toolCall),
        ResponseEnd(),
      ],
      [TextDelta(partId: 't', text: 'x' * 20000), const ResponseEnd()],
      const [TextDelta(partId: 't', text: '未正常收口')],
    ]) {
      final provider = ScriptedProvider(ApiProtocol.openaiCompletions)
        ..turns.add(Stream.fromIterable(response));
      final result = await requestSummary(
        provider,
        const ChatRequest(modelId: 'model', messages: []),
        RunCancellation(),
      );
      expect(result.completed, isFalse);
      expect(provider.requests, hasLength(1));
      expect(result.text.length, lessThan(16100));
    }
  });
}
