import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/model_catalog_cache.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/model_catalog.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/repositories/model_request_repository.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/context/context_preview.dart';
import 'package:phase/features/tools/tool.dart';

import '../../tools/run_recovery_fixture.dart';
import '../../tools/tool_loop_harness.dart';

const _catalog = ModelCatalog(
  providers: {
    'openai': {
      'model-a': ModelCatalogEntry(
        contextWindow: 200000,
        maxOutputTokens: 64000,
      ),
    },
  },
);

void main() {
  for (final protocol in ApiProtocol.values) {
    test('${protocol.name} 目录解析进入运行和请求预算，不注入协议输出参数', () async {
      final h = await ToolLoopHarness.create(
        registry: ToolRegistry([]),
        protocol: protocol,
        presetId: 'openai',
        catalog: _catalog,
      );
      h.provider.turns.add(textTurn('回答'));
      await h.controller().send('任务');
      final run = await h.latestRun();
      expect(run.status, RunStatus.completed);
      expect(run.configuration.contextWindow, 200000);
      expect(
        run.configuration.resolvedWindowSource,
        ContextWindowSource.catalog,
      );
      expect(run.configuration.catalogMaxOutputTokens, 64000);
      expect(run.configuration.modelSelection.maxOutputTokens, isNull);
      final request = h.provider.requests.single;
      expect(request.maxOutputTokens, isNull);
      final payload = request.preparedPayload!;
      final records = await (await h.container.read(
        modelRequestRepositoryProvider.future,
      )).list(h.conversationId()!);
      final measurement = records.single.contextSnapshot;
      expect(measurement['windowSource'], 'catalog');
      expect(measurement['windowTokens'], 200000);
      if (protocol == ApiProtocol.anthropicMessages) {
        expect(payload['max_tokens'], 8192);
        expect(measurement['outputReserveTokens'], 8192);
        expect(measurement['outputReserveSource'], 'protocol');
      } else {
        expect(payload.containsKey('max_tokens'), isFalse);
        expect(payload.containsKey('max_completion_tokens'), isFalse);
        expect(payload.containsKey('max_output_tokens'), isFalse);
        expect(
          (payload['generationConfig'] as Map?)?.containsKey(
                'maxOutputTokens',
              ) ??
              false,
          isFalse,
        );
        expect(measurement['outputReserveTokens'], 64000);
        expect(measurement['outputReserveSource'], 'catalog');
      }
    });
  }

  test('工具轮间刷新不改变既有快照，空闲预览和新运行使用新目录', () async {
    var catalog = _catalog;
    final tool = RecordingTool(name: 'echo');
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([tool]),
      presetId: 'openai',
      readCatalog: () => catalog,
    );
    tool.executeAsync = (_, _) async {
      catalog = const ModelCatalog(
        providers: {
          'openai': {
            'model-a': ModelCatalogEntry(
              contextWindow: 300000,
              maxOutputTokens: 8192,
            ),
          },
        },
      );
      h.container.invalidate(modelCatalogProvider);
      await h.container.read(modelCatalogProvider.future);
      return const ToolOutcome.success('目录已刷新');
    };
    h.provider.turns.addAll([
      toolTurn(callId: 'call', toolName: 'echo', arguments: '{}'),
      textTurn('完成'),
    ]);
    await h.controller().send('任务');
    final original = await h.latestRun();
    expect(original.configuration.contextWindow, 200000);
    expect(original.configuration.catalogMaxOutputTokens, 64000);
    final records = await (await h.container.read(
      modelRequestRepositoryProvider.future,
    )).list(h.conversationId()!);
    expect(records, hasLength(2));
    for (final record in records) {
      expect(record.contextSnapshot['windowTokens'], 200000);
      expect(record.contextSnapshot['outputReserveTokens'], 64000);
    }
    final previewProvider = contextPreviewProvider(h.conversationId()!);
    final subscription = h.container.listen(previewProvider, (_, _) {});
    addTearDown(subscription.close);
    var preview = (await h.container.read(previewProvider.future))!;
    expect(preview.measurement!.windowTokens, 300000);
    expect(preview.measurement!.outputReserveTokens, 8192);
    // 空闲时刷新还必须使已存在的预览订阅重建。
    catalog = const ModelCatalog(
      providers: {
        'openai': {
          'model-a': ModelCatalogEntry(
            contextWindow: 400000,
            maxOutputTokens: 16384,
          ),
        },
      },
    );
    h.container.invalidate(modelCatalogProvider);
    preview = (await h.container.read(previewProvider.future))!;
    expect(preview.measurement!.windowTokens, 400000);
    h.provider.turns.add(textTurn('下一次'));
    await h.controller().send('继续');
    final next = await h.latestRun();
    expect(next.configuration.contextWindow, 400000);
    expect(next.configuration.catalogMaxOutputTokens, 16384);
    expect(
      (await (await h.runs()).getById(original.id))!
          .configuration
          .contextWindow,
      200000,
    );
  });

  test('目录输出上限也不改变摘要请求参数', () async {
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([]),
      presetId: 'openai',
      catalog: const ModelCatalog(
        providers: {
          'openai': {
            'model-a': ModelCatalogEntry(
              contextWindow: 200000,
              maxOutputTokens: 1000,
            ),
          },
        },
      ),
    );
    h.provider.turns.addAll([
      textTurn('旧背景 ' * 1000),
      textTurn('最近回答'),
      textTurn('简短摘要'),
    ]);
    await h.controller().send('旧任务');
    await h.controller().send('当前任务');
    await h.controller().compactContext(h.conversationId()!);
    expect(h.provider.requests, hasLength(3));
    final summary = h.provider.requests.last;
    expect(summary.systemPrompt, contains('累计摘要'));
    expect(summary.maxOutputTokens, 4096);
    final records = await (await h.container.read(
      modelRequestRepositoryProvider.future,
    )).list(h.conversationId()!);
    expect(
      records.map((r) => r.contextSnapshot['outputReserveTokens']),
      containsAll([1000, 4096]),
    );
  });

  test('恢复运行只读持久化快照，不读取当前目录', () async {
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([]),
      readCatalog: () {
        throw StateError('恢复不应解析目录');
      },
    );
    final run = await seedInterrupted(
      h,
      <ToolCallStatus>[],
      configuration: RunConfiguration(
        connection: RunConnection(
          profileId: h.profile.id,
          protocol: h.profile.protocol.name,
          baseUrl: h.profile.baseUrl,
          requiresKey: false,
        ),
        modelSelection: ModelSelection(
          profileId: h.profile.id,
          modelId: 'model-a',
        ),
        systemPrompt: '',
        contextWindow: 200000,
        contextWindowSource: 'catalog',
        catalogMaxOutputTokens: 64000,
      ),
    );
    h.provider.turns.add(textTurn('继续完成'));
    await h.controller().resumeRun(run.id);
    final stored = (await (await h.runs()).getById(run.id))!;
    expect(stored.status, RunStatus.completed);
    expect(stored.configuration.contextWindow, 200000);
    final requests = await (await h.container.read(
      modelRequestRepositoryProvider.future,
    )).list(run.conversationId);
    expect(requests.single.contextSnapshot['outputReserveTokens'], 64000);
    expect(requests.single.contextSnapshot['windowSource'], 'catalog');
  });

  test('目录输出占满窗口时明确失败，不发请求或偷偷缩小预留；手填输出可修正', () async {
    const noBudget = ModelCatalog(
      providers: {
        'openai': {
          'model-a': ModelCatalogEntry(
            contextWindow: 8192,
            maxOutputTokens: 8192,
          ),
        },
      },
    );
    final h = await ToolLoopHarness.create(
      registry: ToolRegistry([]),
      presetId: 'openai',
      catalog: noBudget,
    );
    await h.controller().send('任务');
    expect(h.provider.requests, isEmpty);
    expect((await h.latestRun()).finishReason, RunFinishReason.contextLimit);
    expect((await h.branch()).last.text, contains('窗口 8192，输出预留 8192'));

    await (await h.container.read(providerProfileRepositoryProvider.future))
        .saveProfile(
          h.profile.copyWith(
            models: const [ProfileModel(id: 'model-a', maxOutputTokens: 1000)],
          ),
        );
    h.provider.turns.add(textTurn('完成'));
    await h.controller().send('重试');
    expect((await h.latestRun()).status, RunStatus.completed);
    expect((await h.latestRun()).configuration.catalogMaxOutputTokens, isNull);
    expect(h.provider.requests.single.maxOutputTokens, 1000);
  });
}
