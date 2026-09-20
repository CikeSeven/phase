import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/providers/openai_responses/responses_decoder.dart';

void main() {
  test('真实短回复未返回 reasoning 时不制造思考，也不影响独立首轮的四段摘要', () async {
    Future<List<ChatChunk>> decode(String name) => ResponsesSseDecoder.decode(
      File('test/fixtures/providers/$name').openRead(),
    ).toList();
    final short = await decode('astra_no_reasoning.sse');
    expect(short.whereType<ReasoningDelta>(), isEmpty);
    expect(
      short.whereType<PartEnd>().map((c) => c.part).whereType<ReasoningPart>(),
      isEmpty,
    );
    expect(short.whereType<ResponseEnd>().single.complete, isTrue);
    expect(short.whereType<UsageChunk>().single.usage.reasoningTokens, 0);

    final first = await decode('astra_first_turn_reasoning.sse');
    final parts = first
        .whereType<PartEnd>()
        .map((c) => c.part)
        .whereType<ReasoningPart>()
        .toList();
    expect(parts.where((p) => p.publicText.isNotEmpty), hasLength(4));
    expect(parts.where((p) => p.providerData?['item'] != null), hasLength(2));
    expect(first.whereType<ResponseEnd>().single.complete, isTrue);
    expect(first.whereType<UsageChunk>().single.usage.reasoningTokens, 1034);
    expect(parts.map((p) => p.publicText.length), [26, 34, 0, 40, 16, 0]);
  });
}
