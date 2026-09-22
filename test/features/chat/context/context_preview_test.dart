import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/token_usage.dart';
import 'package:phase/features/chat/context/context_preview.dart';
import 'package:phase/features/chat/model_selection.dart'
    show modelSelectionProvider;
import 'package:phase/features/tools/tool.dart';

import '../../tools/tool_loop_harness.dart';

void main() {
  test('空白页不创建会话；空闲预览和下一请求共享配置，模型切换不借旧测量', () async {
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([]),
      models: const [
        ProfileModel(id: 'model-a'),
        ProfileModel(id: 'model-b', contextWindow: 65536),
      ],
    );
    expect(
      await h.container.read(contextPreviewProvider('missing').future),
      isNull,
    );
    expect(await h.database.select(h.database.conversations).get(), isEmpty);
    h.provider.turns.add(
      Stream.fromIterable([
        ...(await textTurn(
          'seed answer',
        ).toList()).where((c) => c is! ResponseEnd),
        const UsageChunk(
          usage: TokenUsage(promptTokens: 100, outputTokens: 20),
        ),
        const ResponseEnd(),
      ]),
    );
    await h.controller().send('seed task');
    final id = h.conversationId()!;
    final subscription = h.container.listen(
      contextPreviewProvider(id),
      (_, _) {},
    );
    addTearDown(subscription.close);
    final first = (await h.container.read(contextPreviewProvider(id).future))!;
    expect(first.measurement!.anchorRequestId, isNotNull);
    expect(first.messages.last.role, ChatRole.assistant);
    expect(
      first.preparedRequest!.systemPrompt,
      h.provider.requests.single.systemPrompt,
    );
    expect(
      first.preparedRequest!.tools.map((t) => t.name),
      h.provider.requests.single.tools.map((t) => t.name),
    );
    expect(
      first.messages
          .expand((m) => m.parts)
          .whereType<ResolvedText>()
          .map((p) => p.text)
          .join(),
      contains('seed answer'),
    );
    await h.container
        .read(modelSelectionProvider.notifier)
        .saveSelection(
          ModelSelection(profileId: h.profile.id, modelId: 'model-b'),
        );
    final changed = (await h.container.read(
      contextPreviewProvider(id).future,
    ))!;
    expect(changed.measurement!.windowTokens, 65536);
    expect(changed.measurement!.anchorRequestId, isNull);
    h.controller().startNewConversation();
    expect(await h.container.read(contextPreviewProvider(id).future), isNull);
    expect(h.provider.requests, hasLength(1));
  });
}
