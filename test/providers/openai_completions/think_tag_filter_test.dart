import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/providers/openai_completions/think_tag_filter.dart';

void main() {
  /// 把若干 content 增量过一遍状态机，返回 (正文, 思考) 的聚合结果。
  Future<(String, String)> run(List<String> deltas) async {
    var content = '';
    var reasoning = '';
    final chunks = await splitThinkTags(
      Stream.fromIterable([for (final d in deltas) ChatChunk(delta: d)]),
    ).toList();
    for (final chunk in chunks) {
      content += chunk.delta;
      reasoning += chunk.reasoningDelta ?? '';
    }
    return (content, reasoning);
  }

  test('完整 think 块拆分为 reasoning', () async {
    final (content, reasoning) = await run(['<think>想一下</think>正文']);
    expect(reasoning, '想一下');
    expect(content, '正文');
  });

  test('开标签横跨多个 chunk', () async {
    final (content, reasoning) = await run([
      '<th',
      'ink>想一',
      '下</th',
      'ink>答',
      '案',
    ]);
    expect(reasoning, '想一下');
    expect(content, '答案');
  });

  test('逐字符到达也能正确拆分', () async {
    final (content, reasoning) = await run([
      for (final unit in '<think>思</think>正'.split('')) unit,
    ]);
    expect(reasoning, '思');
    expect(content, '正');
  });

  test('正文中的非开头 think 字样不误判', () async {
    final (content, reasoning) = await run(['你好 <think>这不是思考</think>']);
    expect(reasoning, isEmpty);
    expect(content, '你好 <think>这不是思考</think>');
  });

  test('think 块结束后正文里的标签原样保留', () async {
    final (content, reasoning) = await run([
      '<think>想</think>正文提到 <think> 字样',
    ]);
    expect(reasoning, '想');
    expect(content, '正文提到 <think> 字样');
  });

  test('只有 <think> 没有 </think> 的截断情况整块算 reasoning', () async {
    final (content, reasoning) = await run(['<think>没想完']);
    expect(reasoning, '没想完');
    expect(content, isEmpty);
  });

  test('流末尾的半截开标签按正文处理', () async {
    final (content, reasoning) = await run(['<th']);
    expect(reasoning, isEmpty);
    expect(content, '<th');
  });

  test('打头的空 chunk（只有 role 的增量）不影响判定', () async {
    final (content, reasoning) = await run(['', '<think>想</think>正']);
    expect(reasoning, '想');
    expect(content, '正');
  });

  test('chunk 自带 reasoningDelta 时优先透传', () async {
    final chunks = await splitThinkTags(
      Stream.fromIterable([
        const ChatChunk(delta: '', reasoningDelta: '字段思考'),
        const ChatChunk(delta: '<think>标签思考</think>正文'),
      ]),
    ).toList();
    final reasoning = chunks.map((c) => c.reasoningDelta ?? '').join();
    final content = chunks.map((c) => c.delta).join();
    expect(reasoning, '字段思考标签思考');
    expect(content, '正文');
  });

  test('普通正文原样通过', () async {
    final (content, reasoning) = await run(['你好', '，世界']);
    expect(reasoning, isEmpty);
    expect(content, '你好，世界');
  });

  test('done 与 usage 标记透传', () async {
    final chunks = await splitThinkTags(
      Stream.fromIterable([
        const ChatChunk(delta: '<think>想</think>正'),
        const ChatChunk(
          delta: '',
          done: true,
          usage: TokenUsage(totalTokens: 10),
        ),
      ]),
    ).toList();
    final last = chunks.last;
    expect(last.done, isTrue);
    expect(last.usage?.totalTokens, 10);
  });
}
