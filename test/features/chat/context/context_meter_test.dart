import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/model_request_record.dart';
import 'package:phase/data/models/model_catalog.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/data/models/token_usage.dart';
import 'package:phase/providers/request_plan.dart';
import 'package:phase/features/chat/context/context_meter.dart';

ProviderProfile profile(ApiProtocol protocol) => ProviderProfile(
  id: 'p',
  name: 'test',
  protocol: protocol,
  baseUrl: 'https://fixture.test',
  createdAt: DateTime(2026),
  models: const [ProfileModel(id: 'm', supportsReasoning: true)],
);
ResolvedMessage text(
  String id,
  String value, {
  ChatRole role = ChatRole.user,
}) => ResolvedMessage(
  sourceMessageId: id,
  role: role,
  parts: [ResolvedText(value)],
);

void main() {
  const meter = ContextMeter();
  test('实际输入基准加回放增量，不另加输出/推理；正常追加不使基准失效', () async {
    final p = profile(ApiProtocol.openaiResponses);
    final original = ChatRequest(modelId: 'm', messages: [text('u', '原任务')]);
    final plan = await planRequest(p, original);
    final measured = await meter.measure(
      conversationId: 'c',
      plan: plan,
      generation: 'original',
      requests: [],
    );
    expect(
      measured.toSnapshot()['configuration'],
      containsPair('protocol', 'openaiResponses'),
    );
    expect(measured.toSnapshot().toString(), isNot(contains('原任务')));
    final record = ModelRequestRecord(
      id: 'r',
      conversationId: 'c',
      assistantMessageId: 'a',
      profileId: 'p',
      protocol: p.protocol.name,
      requestedModelId: 'm',
      createdAt: DateTime(2026),
      startedAt: DateTime(2026),
      status: ModelRequestStatus.completed,
      usage: const TokenUsage(
        promptTokens: 70,
        outputTokens: 500,
        reasoningTokens: 450,
      ),
      contextSnapshot: measured.toSnapshot(),
    );
    final nextPlan = await planRequest(
      p,
      original.copyWith(
        messages: [
          ...original.messages,
          text('a', '实际回放正文', role: ChatRole.assistant),
        ],
      ),
    );
    final next = await meter.measure(
      conversationId: 'c',
      plan: nextPlan,
      generation: 'original',
      requests: [record],
    );
    expect(next.anchorRequestId, 'r');
    expect(
      next.estimatedInputTokens,
      70 + nextPlan.estimatedInputTokens - plan.estimatedInputTokens,
    );
    final compact = await meter.measure(
      conversationId: 'c',
      plan: nextPlan,
      generation: 'summary',
      requests: [record],
    );
    expect(compact.anchorRequestId, isNull);
    expect(compact.estimatedInputTokens, nextPlan.estimatedInputTokens);
    final editedPlan = await planRequest(
      p,
      original.copyWith(
        messages: [
          text('u', '改过的原任务'),
          text('a', '实际回放正文', role: ChatRole.assistant),
        ],
      ),
    );
    expect(
      (await meter.measure(
        conversationId: 'c',
        plan: editedPlan,
        generation: 'original',
        requests: [record],
      )).anchorRequestId,
      isNull,
    );
    final changed = await planRequest(
      p.copyWith(baseUrl: 'https://different.test'),
      nextPlan.request,
    );
    expect(
      (await meter.measure(
        conversationId: 'c',
        plan: changed,
        generation: 'original',
        requests: [record],
      )).anchorRequestId,
      isNull,
    );
  });

  test('Anthropic 采用真实默认输出与 thinking 最低预留，其他协议不偷偷加参数', () async {
    final request = ChatRequest(modelId: 'm', messages: [text('u', '任务')]);
    final p = profile(ApiProtocol.anthropicMessages);
    expect((await planRequest(p, request)).effectiveOutputTokens, 8192);
    final high = await planRequest(
      p,
      ChatRequest(
        modelId: 'm',
        messages: request.messages,
        reasoningEffort: ReasoningEffort.high,
        maxOutputTokens: 1000,
      ),
    );
    expect(high.effectiveOutputTokens, 17408);
    expect(high.prepared.preparedPayload!['max_tokens'], 17408);
    final completions = await planRequest(
      profile(ApiProtocol.openaiCompletions),
      request,
    );
    expect(completions.effectiveOutputTokens, isNull);
    expect(completions.payload.containsKey('max_completion_tokens'), isFalse);
    final m = await meter.measure(
      conversationId: 'c',
      plan: completions,
      generation: 'original',
      requests: [],
    );
    expect(m.outputReserveSource, OutputReserveSource.localDefault);
    expect(m.outputReserveTokens, 4096);
  });

  test('窗口来源三态：目录/用户/本地默认，目录输出上限只进预留', () async {
    final p = profile(ApiProtocol.openaiCompletions);
    final request = ChatRequest(modelId: 'm', messages: [text('u', '任务')]);
    final plan = await planRequest(p, request);

    // 未编目、未手填 → 本地默认 128000。
    final fallback = await meter.measure(
      conversationId: 'c',
      plan: plan,
      generation: 'original',
      requests: [],
    );
    expect(fallback.windowTokens, ModelCatalog.localDefaultWindow);
    expect(fallback.windowSource, ContextWindowSource.localDefault);
    expect(fallback.outputReserveSource, OutputReserveSource.localDefault);

    // 目录窗口进入测量，目录输出上限填充预留。
    final catalog = await meter.measure(
      conversationId: 'c',
      plan: plan,
      generation: 'original',
      requests: [],
      contextWindow: 200000,
      windowSource: ContextWindowSource.catalog,
      catalogMaxOutputTokens: 64000,
    );
    expect(catalog.windowTokens, 200000);
    expect(catalog.windowSource, ContextWindowSource.catalog);
    expect(catalog.outputReserveTokens, 64000);
    expect(catalog.outputReserveSource, OutputReserveSource.catalog);
    expect(catalog.triggerTokens, ((200000 - 64000 - 1024) * 0.8).floor());

    // 用户手填优先于目录（调用方传解析值，此处模拟用户来源）。
    final user = await meter.measure(
      conversationId: 'c',
      plan: plan,
      generation: 'original',
      requests: [],
      contextWindow: 65536,
      windowSource: ContextWindowSource.user,
      catalogMaxOutputTokens: 64000,
    );
    expect(user.windowTokens, 65536);
    expect(user.windowSource, ContextWindowSource.user);
    expect(user.outputReserveTokens, 64000);
  });

  test('估算忽略未回放思考，缺失图片按实际占位文本计量', () async {
    final p = profile(ApiProtocol.openaiResponses);
    final plain = await planRequest(
      p,
      ChatRequest(
        modelId: 'm',
        messages: [text('a', '正文', role: ChatRole.assistant)],
      ),
    );
    final noReplay = await planRequest(
      p,
      const ChatRequest(
        modelId: 'm',
        messages: [
          ResolvedMessage(
            role: ChatRole.assistant,
            sourceMessageId: 'a',
            parts: [ResolvedText('正文'), ResolvedReasoning('不具备可回放 item 的公开思考')],
          ),
        ],
      ),
    );
    expect(noReplay.estimatedInputTokens, plain.estimatedInputTokens);
    final missingImage = await planRequest(
      p,
      ChatRequest(
        modelId: 'm',
        messages: [
          ResolvedMessage(
            role: ChatRole.user,
            parts: [
              ResolvedImage(
                Attachment(
                  id: 'missing',
                  kind: AttachmentKind.image,
                  name: 'x.png',
                  mimeType: 'image/png',
                  size: 100,
                  localPath: '/fixture/does-not-exist.png',
                  createdAt: DateTime(2026),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    expect(missingImage.imageTokens, 0);
    expect(missingImage.payload.toString(), contains('图片文件已丢失'));
  });
}
