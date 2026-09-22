import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/providers/openai_completions/sse_decoder.dart';
import 'package:phase/providers/openai_completions/think_tag_filter.dart';

void main() {
  /// 把若干 content 增量过一遍状态机，返回 (正文, 思考) 的聚合结果。
  (String, String) run(List<String> deltas) {
    final splitter = ThinkTagSplitter();
    var content = '';
    var reasoning = '';
    for (final delta in deltas) {
      final split = splitter.push(delta);
      content += split.content;
      reasoning += split.reasoning;
    }
    final tail = splitter.flush();
    return (content + tail.content, reasoning + tail.reasoning);
  }

  test('完整 think 块拆分为 reasoning', () {
    final (content, reasoning) = run(['<think>想一下</think>正文']);
    expect(reasoning, '想一下');
    expect(content, '正文');
  });

  test('开标签横跨多个片段', () {
    final (content, reasoning) = run(['<th', 'ink>想一', '下</th', 'ink>答', '案']);
    expect(reasoning, '想一下');
    expect(content, '答案');
  });

  test('逐字符到达也能正确拆分', () {
    final (content, reasoning) = run([
      for (final unit in '<think>思</think>正'.split('')) unit,
    ]);
    expect(reasoning, '思');
    expect(content, '正');
  });

  test('正文中的非开头 think 字样不误判', () {
    final (content, reasoning) = run(['你好 <think>这不是思考</think>']);
    expect(reasoning, isEmpty);
    expect(content, '你好 <think>这不是思考</think>');
  });

  test('think 块结束后正文里的标签原样保留', () {
    final (content, reasoning) = run(['<think>想</think>正文提到 <think> 字样']);
    expect(reasoning, '想');
    expect(content, '正文提到 <think> 字样');
  });

  test('只有 <think> 没有 </think> 的截断情况整块算 reasoning', () {
    final (content, reasoning) = run(['<think>没想完']);
    expect(reasoning, '没想完');
    expect(content, isEmpty);
  });

  test('流末尾的半截开标签按正文处理', () {
    final (content, reasoning) = run(['<th']);
    expect(reasoning, isEmpty);
    expect(content, '<th');
  });

  test('打头的空片段（只有 role 的增量）不影响判定', () {
    final (content, reasoning) = run(['', '<think>想</think>正']);
    expect(reasoning, '想');
    expect(content, '正');
  });

  test('普通正文原样通过', () {
    final (content, reasoning) = run(['你好', '，世界']);
    expect(reasoning, isEmpty);
    expect(content, '你好，世界');
  });

  group('经适配器输出为 reasoning 通道事件', () {
    test('think 内容走 reasoning 增量与 ReasoningPart', () async {
      final chunks = await OpenAiSseDecoder.decode(
        Stream.value(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"<think>先想</think>答"}}]}\n\n'
            'data: [DONE]\n\n',
          ),
        ),
      ).toList();

      expect(chunks.whereType<PartStart>().map((chunk) => chunk.kind), [
        PartKind.reasoning,
        PartKind.text,
      ]);
      expect(
        chunks.whereType<ReasoningDelta>().map((chunk) => chunk.text).join(),
        '先想',
      );
      expect(
        chunks.whereType<TextDelta>().map((chunk) => chunk.text).join(),
        '答',
      );
      final reasoningPart = chunks
          .whereType<PartEnd>()
          .map((chunk) => chunk.part)
          .whereType<ReasoningPart>()
          .single;
      expect(reasoningPart.publicText, '先想');
      // 标签拆分的思考没有协议状态，不带 providerData。
      expect(reasoningPart.providerData, isNull);
    });

    test('协议字段的思考与标签思考按到达顺序进入同一通道', () async {
      final chunks = await OpenAiSseDecoder.decode(
        Stream.value(
          utf8.encode(
            'data: {"choices":[{"delta":{"reasoning_content":"字段思考"}}]}\n\n'
            'data: {"choices":[{"delta":{"content":"<think>标签思考</think>正文"}}]}\n\n'
            'data: [DONE]\n\n',
          ),
        ),
      ).toList();
      expect(
        chunks.whereType<ReasoningDelta>().map((chunk) => chunk.text).join(),
        '字段思考标签思考',
      );
      expect(
        chunks.whereType<TextDelta>().map((chunk) => chunk.text).join(),
        '正文',
      );
      // 两个思考来源归并到同一个 reasoning 块。
      expect(
        chunks.whereType<ReasoningDelta>().map((chunk) => chunk.partId).toSet(),
        {'reasoning_0'},
      );
    });

    test('think 块与 usage 收口在同一响应内', () async {
      final chunks = await OpenAiSseDecoder.decode(
        Stream.value(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"<think>想</think>正"}}]}\n\n'
            'data: {"choices":[],"usage":{"prompt_tokens":1,"completion_tokens":2}}\n\n'
            'data: [DONE]\n\n',
          ),
        ),
      ).toList();
      final usage = chunks.whereType<UsageChunk>().single.usage;
      expect(usage.promptTokens, 1);
      expect(usage.outputTokens, 2);
      expect(chunks.whereType<ResponseEnd>(), hasLength(1));
      expect(chunks.last, isA<ResponseEnd>());
    });

    test('收尾时未闭合的 think 内容仍作为思考交付', () async {
      final chunks = await OpenAiSseDecoder.decode(
        Stream.value(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"<think>没想完"}}]}\n\n',
          ),
        ),
      ).toList();
      expect(
        chunks.whereType<ReasoningDelta>().map((chunk) => chunk.text).join(),
        '没想完',
      );
      expect(chunks.whereType<TextDelta>(), isEmpty);
      expect(chunks.last, isA<ResponseEnd>());
    });
  });
}
