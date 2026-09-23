import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/core/error/provider_error.dart';
import 'package:phase/core/widgets/app_card.dart';
import 'package:phase/data/datasources/local/model_catalog_cache.dart';
import 'package:phase/data/datasources/remote/models_dev_client.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/model_catalog.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/features/providers_config/provider_edit_page.dart';
import 'package:phase/features/providers_config/provider_ui.dart';
import 'package:phase/providers/presets/provider_preset.dart';

import 'provider_test_harness.dart';

void main() {
  testWidgets('总览数量来自候选模型，支持本地搜索并按配置 id 打开正确编辑页', (tester) async {
    final harness = ProviderTestHarness();
    addTearDown(harness.dispose);
    await harness.seed(
      tester,
      id: 'alpha-id',
      name: 'Alpha 服务商',
      presetId: 'openai',
      protocol: ApiProtocol.openaiResponses,
      defaultModel: 'legacy-default',
      models: const [ProfileModel(id: 'alpha-chat')],
    );
    await harness.seed(
      tester,
      id: 'beta-id',
      name: 'Beta 服务商',
      presetId: 'google',
      protocol: ApiProtocol.googleGenerativeAi,
      models: const [ProfileModel(id: 'beta-chat')],
    );
    await harness.pump(tester);
    expect(keyed('provider-search'), findsOneWidget);
    expect(keyed('add-provider').hitTestable(), findsOneWidget);
    expect(find.text('2 个服务商 · 3 个模型'), findsOneWidget);
    expect(find.byType(AppCard), findsNothing);
    expect(
      tester.getTopLeft(keyed('provider-search')).dy,
      lessThan(tester.getTopLeft(keyed('provider-counts')).dy),
    );
    expect(find.textContaining('连接成功'), findsNothing);
    await fillProviderField(tester, keyed('provider-search'), 'legacy-default');
    expect(keyed('provider-alpha-id'), findsOneWidget);
    expect(keyed('provider-beta-id'), findsNothing);
    expect(find.text('2 个模型'), findsOneWidget);
    await fillProviderField(tester, keyed('provider-search'), 'Google');
    expect(keyed('provider-beta-id'), findsOneWidget);
    expect(keyed('provider-alpha-id'), findsNothing);
    await fillProviderField(
      tester,
      keyed('provider-search'),
      'no-such-provider',
    );
    expect(find.text('没有匹配的服务商'), findsOneWidget);
    await tapProviderControl(tester, find.text('显示全部服务商'));
    await fillProviderField(tester, keyed('provider-search'), 'Beta');
    await tapProviderControl(tester, keyed('provider-beta-id'));
    expect(find.byType(ProviderEditPage), findsOneWidget);
    expect(
      tester.widget<ProviderEditPage>(find.byType(ProviderEditPage)).profileId,
      'beta-id',
    );
    await fillProviderField(tester, keyed('provider-name'), 'Beta 已编辑');
    await settleProviderAutoSave(tester);
    final beta = await tester.runAsync(
      () => harness.repository.getProfile('beta-id'),
    );
    final alpha = await tester.runAsync(
      () => harness.repository.getProfile('alpha-id'),
    );
    expect(beta!.name, 'Beta 已编辑');
    expect(alpha!.name, 'Alpha 服务商');
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载状态下仍可从固定入口新增并持久化服务商', (tester) async {
    final loadGate = Completer<void>();
    late final ProviderTestHarness harness;
    harness = ProviderTestHarness(
      profileStream: () async* {
        await loadGate.future;
        yield* harness.repository.watchProfiles();
      },
    );
    addTearDown(harness.dispose);
    await harness.pump(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('正在读取配置'), findsOneWidget);
    await tapProviderControl(tester, keyed('add-provider'), settle: false);
    loadGate.complete();
    await settleProviderUi(tester);
    expect(find.byType(ProviderEditPage), findsOneWidget);
    await fillProviderField(tester, keyed('provider-name'), '加载时新增');
    await fillProviderField(tester, baseUrlField, 'https://example.com/v1');
    await tapProviderControl(tester, keyed('save-provider'));
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(saved.name, '加载时新增');
    expect(keyed('provider-${saved.id}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('错误状态提供重新加载，恢复后能编辑真实配置', (tester) async {
    var fail = true;
    late final ProviderTestHarness harness;
    harness = ProviderTestHarness(
      profileStream: () {
        if (fail) {
          return Stream<List<ProviderProfile>>.error(
            const NetworkFailure('fake list failure'),
          );
        }
        return harness.repository.watchProfiles();
      },
    );
    addTearDown(harness.dispose);
    await harness.seed(tester, name: '可恢复连接');
    await harness.pump(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('暂时无法读取服务商'), findsOneWidget);
    expect(keyed('add-provider').hitTestable(), findsOneWidget);
    fail = false;
    await tapProviderControl(tester, find.text('重新加载'));
    await tapProviderControl(tester, keyed('provider-p1'));
    await fillProviderField(tester, keyed('provider-name'), '恢复并保存');
    await settleProviderAutoSave(tester);
    expect(
      (await tester.runAsync(harness.repository.listProfiles))!.single.name,
      '恢复并保存',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('全部真实预设均可搜索选择，新配置跟随默认协议并可保存自定义地址', (tester) async {
    final harness = ProviderTestHarness();
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('add-provider'));
    expect(providerPresets, hasLength(greaterThanOrEqualTo(20)));
    expect(
      providerPresets.map((preset) => preset.id).toSet(),
      hasLength(providerPresets.length),
    );
    for (final preset in providerPresets) {
      await choosePreset(tester, preset.id);
      expect(
        currentProtocolLabel(tester),
        ProviderUi.protocolLabel(preset.protocol),
      );
      if (preset.baseUrl.isNotEmpty) {
        expect(
          tester.widget<TextFormField>(baseUrlField).controller!.text,
          preset.baseUrl,
        );
      }
    }
    await tapProviderControl(tester, keyed('choose-provider-preset'));
    await fillProviderField(tester, keyed('preset-search'), 'no-such-preset');
    expect(find.text('没有匹配的预设'), findsOneWidget);
    await tapProviderControl(tester, find.text('显示全部预设'));
    expect(keyed('preset-openai'), findsOneWidget);
    await tapProviderControl(tester, find.byTooltip('关闭'));
    await fillProviderField(tester, keyed('provider-name'), '自定义连接');
    await fillProviderField(tester, baseUrlField, 'https://custom.example/v1');
    await tapProviderControl(tester, keyed('save-provider'));
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(saved.presetId, 'custom');
    expect(saved.baseUrl, 'https://custom.example/v1');
    expect(saved.protocol, ApiProtocol.openaiCompletions);
    expect(tester.takeException(), isNull);
  });

  testWidgets('必填和非法地址校验不触发网络或保存，修正后才写入', (tester) async {
    final harness = ProviderTestHarness();
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('add-provider'));
    await tapProviderControl(tester, keyed('save-provider'));
    expect(find.text('请输入服务商名称'), findsOneWidget);
    expect(find.text('请输入 Base URL'), findsOneWidget);
    await fillProviderField(tester, keyed('provider-name'), '校验后的连接');
    await fillProviderField(tester, baseUrlField, 'not-a-url');
    await tapProviderControl(tester, keyed('test-provider'));
    expect(find.text('请输入完整的 http 或 https 地址'), findsOneWidget);
    expect(harness.provider.listModelsCount, 0);
    await tapProviderControl(tester, keyed('save-provider'));
    expect((await tester.runAsync(harness.repository.listProfiles))!, isEmpty);
    await fillProviderField(tester, baseUrlField, 'https://example.com/v1');
    await tapProviderControl(tester, keyed('save-provider'));
    expect(
      (await tester.runAsync(harness.repository.listProfiles))!,
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('模型目录初始显示内置快照，刷新成功后写入缓存并更新状态', (tester) async {
    final harness = ProviderTestHarness();
    addTearDown(harness.dispose);
    await harness.seed(tester);
    harness.modelsDev.handler = ({etag}) async {
      expect(etag, isNull);
      return ModelsDevFetched(
        catalog: ModelCatalog(
          providers: const {
            'groq': {
              'llama-x': ModelCatalogEntry(
                contextWindow: 131072,
                maxOutputTokens: 16384,
              ),
            },
          },
          fetchedAt: DateTime(2026, 9, 23, 12, 30),
        ),
        etag: '"tag-1"',
      );
    };
    await harness.pump(tester);
    expect(find.text('模型目录：内置快照'), findsOneWidget);
    // 刷新按钮的进度动画会卡死 pumpAndSettle，走定帧轮次。
    await tapProviderControl(
      tester,
      keyed('refresh-model-catalog'),
      settle: false,
    );
    await harness.settleCatalog(tester);
    expect(find.text('模型目录已更新（1 个服务商 / 1 个模型）'), findsOneWidget);
    expect(find.text('模型目录：更新于 2026-09-23 12:30'), findsOneWidget);
    expect(harness.modelsDev.fetchCount, 1);
    // ETag 落盘：二次刷新应带上它（304 路径由 busy 测试覆盖）。
    final cached = await tester.runAsync(
      () => ModelCatalogCache(harness.catalogDir).read(),
    );
    expect(cached?.etag, '"tag-1"');
    expect(cached?.catalog.fetchedAt, DateTime(2026, 9, 23, 12, 30));
    expect(find.text('模型目录：更新于 2026-09-23 12:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('目录刷新失败显示中文错误且不中断页面', (tester) async {
    final harness = ProviderTestHarness();
    addTearDown(harness.dispose);
    await harness.seed(tester);
    harness.modelsDev.handler = ({etag}) async =>
        throw const ProviderError(ProviderErrorCategory.network, '网络连接失败');
    await harness.pump(tester);
    await tapProviderControl(
      tester,
      keyed('refresh-model-catalog'),
      settle: false,
    );
    await harness.settleCatalog(tester);
    expect(harness.modelsDev.fetchCount, 1);
    expect(find.text('网络连接失败，请检查网络后重试'), findsOneWidget);
    expect(find.text('模型目录：内置快照'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('目录刷新进行中按钮禁用，完成后恢复', (tester) async {
    final harness = ProviderTestHarness();
    addTearDown(harness.dispose);
    await harness.seed(tester);
    final cache = ModelCatalogCache(harness.catalogDir);
    final previous = ModelCatalog(
      providers: const {
        'openai': {'x': ModelCatalogEntry(contextWindow: 200000)},
      },
      fetchedAt: DateTime(2026, 9, 23, 12, 30),
    );
    await tester.runAsync(
      () => cache.write(CachedModelCatalog(catalog: previous, etag: '"saved"')),
    );
    final gate = Completer<void>();
    harness.modelsDev.handler = ({etag}) async {
      expect(etag, '"saved"');
      await gate.future;
      return ModelsDevNotModified();
    };
    await harness.pump(tester);
    IconButton button() =>
        tester.widget<IconButton>(keyed('refresh-model-catalog'));
    expect(button().onPressed, isNotNull);
    await tapProviderControl(
      tester,
      keyed('refresh-model-catalog'),
      settle: false,
    );
    // 等缓存读取完成后进入 fetch，确认按钮处于禁用态。
    await pumpProviderUntil(tester, () => harness.modelsDev.fetchCount == 1);
    expect(button().onPressed, isNull);
    await tester.tap(keyed('refresh-model-catalog'));
    await tester.pump();
    expect(harness.modelsDev.fetchCount, 1);
    gate.complete();
    await harness.settleCatalog(tester);
    expect(button().onPressed, isNotNull);
    expect(find.text('模型目录已是最新'), findsOneWidget);
    expect(find.text('模型目录：更新于 2026-09-23 12:30'), findsOneWidget);
    expect(
      (await tester.runAsync(cache.read))!.catalog.fetchedAt,
      previous.fetchedAt,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('无服务商时首次刷新等待缓存初始化，显示目录状态且无需第二次点击', (tester) async {
    final gate = Completer<ModelCatalogCache>();
    final harness = ProviderTestHarness(openCatalogCache: () => gate.future);
    addTearDown(harness.dispose);
    harness.modelsDev.handler = ({etag}) async => ModelsDevFetched(
      catalog: ModelCatalog(
        providers: const {
          'openai': {'x': ModelCatalogEntry(contextWindow: 200000)},
        },
        fetchedAt: DateTime(2026, 9, 23, 12, 30),
      ),
    );
    await harness.pump(tester, settle: false);
    await settleProviderUi(tester);
    expect(find.text('暂无服务商'), findsOneWidget);
    expect(find.text('模型目录：读取中'), findsOneWidget);
    await tapProviderControl(
      tester,
      keyed('refresh-model-catalog'),
      settle: false,
    );
    expect(harness.modelsDev.fetchCount, 0);
    expect(
      tester.widget<IconButton>(keyed('refresh-model-catalog')).onPressed,
      isNull,
    );
    gate.complete(ModelCatalogCache(harness.catalogDir));
    await harness.settleCatalog(tester);
    expect(harness.modelsDev.fetchCount, 1);
    expect(find.text('模型目录：更新于 2026-09-23 12:30'), findsOneWidget);
    expect(find.text('模型目录已更新（1 个服务商 / 1 个模型）'), findsOneWidget);
  });

  testWidgets('缓存写入失败保留旧目录和 ETag，不提示更新成功', (tester) async {
    late final ProviderTestHarness harness;
    harness = ProviderTestHarness(
      openCatalogCache: () async => _ReadOnlyCatalogCache(harness.catalogDir),
    );
    addTearDown(harness.dispose);
    final cache = ModelCatalogCache(harness.catalogDir);
    await tester.runAsync(
      () => cache.write(
        CachedModelCatalog(
          catalog: ModelCatalog(
            providers: const {
              'openai': {'x': ModelCatalogEntry(contextWindow: 200000)},
            },
            fetchedAt: DateTime(2026, 9, 23, 12, 30),
          ),
          etag: 'old',
        ),
      ),
    );
    harness.modelsDev.handler = ({etag}) async => ModelsDevFetched(
      catalog: ModelCatalog(
        providers: const {
          'openai': {'x': ModelCatalogEntry(contextWindow: 300000)},
        },
        fetchedAt: DateTime(2026, 9, 24),
      ),
      etag: 'new',
    );
    await harness.pump(tester);
    await tapProviderControl(
      tester,
      keyed('refresh-model-catalog'),
      settle: false,
    );
    await harness.settleCatalog(tester);
    expect(find.text('数据读取或保存失败，请稍后重试'), findsOneWidget);
    expect(find.textContaining('模型目录已更新'), findsNothing);
    expect(find.text('模型目录：更新于 2026-09-23 12:30'), findsOneWidget);
    expect((await tester.runAsync(cache.read))!.etag, 'old');
  });

  testWidgets('缓存初始化失败立即回退内置快照，手动刷新可重新初始化', (tester) async {
    var opens = 0;
    late final ProviderTestHarness harness;
    harness = ProviderTestHarness(
      openCatalogCache: () async {
        if (++opens == 1) throw const StorageFailure('fixture');
        return ModelCatalogCache(harness.catalogDir);
      },
    );
    addTearDown(harness.dispose);
    harness.modelsDev.handler = ({etag}) async => ModelsDevFetched(
      catalog: ModelCatalog(
        providers: const {
          'openai': {'x': ModelCatalogEntry(contextWindow: 200000)},
        },
        fetchedAt: DateTime(2026, 9, 23, 12, 30),
      ),
    );
    await harness.pump(tester);
    expect(find.text('模型目录：内置快照'), findsOneWidget);
    expect(opens, 1);
    await tapProviderControl(
      tester,
      keyed('refresh-model-catalog'),
      settle: false,
    );
    await harness.settleCatalog(tester);
    expect(opens, 2);
    expect(find.text('模型目录：更新于 2026-09-23 12:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已开始的缓存写入在页面退出后仍同步生效目录', (tester) async {
    late final ProviderTestHarness harness;
    late final _DelayedCatalogCache cache;
    harness = ProviderTestHarness(openCatalogCache: () async => cache);
    cache = _DelayedCatalogCache(harness.catalogDir);
    addTearDown(harness.dispose);
    harness.modelsDev.handler = ({etag}) async => ModelsDevFetched(
      catalog: ModelCatalog(
        providers: const {
          'openai': {'fixture': ModelCatalogEntry(contextWindow: 300000)},
        },
        fetchedAt: DateTime(2026, 9, 23, 12, 30),
      ),
    );
    await harness.pump(tester);
    await tapProviderControl(
      tester,
      keyed('refresh-model-catalog'),
      settle: false,
    );
    await pumpProviderUntil(tester, () => cache.writing);
    await tester.pumpWidget(const SizedBox.shrink());
    cache.gate.complete();
    await pumpProviderUntil(
      tester,
      () =>
          harness.container.read(modelCatalogProvider).value?.fetchedAt != null,
    );
    expect(
      harness.container
          .read(modelCatalogProvider)
          .requireValue
          .lookup('openai', 'fixture')
          ?.contextWindow,
      300000,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('离开页面取消目录请求，迟到响应不写入缓存', (tester) async {
    final harness = ProviderTestHarness();
    addTearDown(harness.dispose);
    final gate = Completer<ModelsDevFetchResult>();
    harness.modelsDev.handler = ({etag}) => gate.future;
    await harness.pump(tester);
    await tapProviderControl(
      tester,
      keyed('refresh-model-catalog'),
      settle: false,
    );
    await pumpProviderUntil(tester, () => harness.modelsDev.fetchCount == 1);
    final cancellation = harness.modelsDev.lastCancellation!;
    expect(cancellation.isCancelled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(cancellation.isCancelled, isTrue);
    gate.complete(
      ModelsDevFetched(
        catalog: ModelCatalog(
          providers: const {
            'openai': {'x': ModelCatalogEntry(contextWindow: 200000)},
          },
          fetchedAt: DateTime(2026, 9, 23),
        ),
      ),
    );
    await tester.pump();
    expect(
      await tester.runAsync(() => ModelCatalogCache(harness.catalogDir).read()),
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}

class _ReadOnlyCatalogCache extends ModelCatalogCache {
  _ReadOnlyCatalogCache(super.root);

  @override
  Future<void> write(CachedModelCatalog value) async {
    throw const StorageFailure('fixture');
  }
}

class _DelayedCatalogCache extends ModelCatalogCache {
  _DelayedCatalogCache(super.root);
  final gate = Completer<void>();
  var writing = false;

  @override
  Future<void> write(CachedModelCatalog value) async {
    writing = true;
    await gate.future;
    await super.write(value);
  }
}
