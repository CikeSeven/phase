import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/openai_compat.dart';

import 'provider_test_harness.dart';

import 'package:phase/features/providers_config/provider_ui.dart';

void main() {
  late ProviderTestHarness harness;

  setUp(() => harness = ProviderTestHarness());
  tearDown(() async => harness.dispose());

  testWidgets('编辑时切换预设不覆盖独立协议，显式选择协议后保留兼容项保存', (tester) async {
    const compat = OpenAiCompat(thinkingFormat: ThinkingFormat.openrouter);
    await harness.seed(
      tester,
      presetId: 'openai',
      protocol: ApiProtocol.googleGenerativeAi,
      compatOverrides: compat,
    );
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    await choosePreset(tester, 'deepseek');
    expect(
      currentProtocolLabel(tester),
      ProviderUi.protocolLabel(ApiProtocol.googleGenerativeAi),
    );
    await chooseProtocol(tester, ApiProtocol.openaiCompletions);
    await settleProviderAutoSave(tester);
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(saved.presetId, 'deepseek');
    expect(saved.protocol, ApiProtocol.openaiCompletions);
    expect(saved.compatOverrides!.toJson(), compat.toJson());
  });

  testWidgets('获取失败可重试，失败和空列表都不抹掉已有模型', (tester) async {
    await harness.seed(
      tester,
      defaultModel: 'manual',
      models: const [ProfileModel(id: 'manual', supportsReasoning: true)],
    );
    harness.provider.listModelsHandler = () async {
      throw const AuthFailure('fake authentication failure');
    };
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    await tapProviderControl(tester, keyed('test-provider'));
    expect(find.text(const AuthFailure('').userMessage), findsOneWidget);
    expect(
      tester.widget<FilledButton>(keyed('test-provider')).onPressed,
      isNotNull,
    );
    harness.provider.listModelsHandler = () async => const [];
    await tapProviderControl(tester, keyed('test-provider'));
    expect(find.text('已获取 0 个模型'), findsOneWidget);
    await searchModels(tester, 'manual');
    expect(tester.widget<Checkbox>(keyed('enabled-manual')).value, isTrue);
    await settleProviderAutoSave(tester);
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(saved.defaultModel, 'manual');
    expect(saved.models.single.id, 'manual');
    expect(saved.models.single.supportsReasoning, isTrue);
  });

  testWidgets('添加弹窗期间完成拉取仍做实时重复校验，并保留随后添加的模型', (tester) async {
    await harness.seed(tester, models: const [ProfileModel(id: 'seeded')]);
    final request = Completer<List<ProfileModel>>();
    harness.provider.listModelsHandler = () => request.future;
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    await tapProviderControl(tester, keyed('test-provider'), settle: false);
    await tapProviderControl(
      tester,
      keyed('add-provider-model'),
      settle: false,
    );
    request.complete(const [ProfileModel(id: 'race-id')]);
    await settleProviderUi(tester);
    await fillProviderField(tester, keyed('new-model-id'), 'race-id');
    await tapProviderControl(tester, keyed('confirm-add-model'));
    expect(find.text('该模型 ID 已存在'), findsOneWidget);
    await fillProviderField(
      tester,
      keyed('new-model-id'),
      'manual-after-fetch',
    );
    // 推理默认开启，直接确认。
    await tapProviderControl(tester, keyed('confirm-add-model'));
    await settleProviderAutoSave(tester);
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(
      saved.models.map((model) => model.id),
      unorderedEquals(['seeded', 'race-id', 'manual-after-fetch']),
    );
    expect(saved.defaultModel, 'manual-after-fetch');
    expect(
      saved.models
          .singleWhere((model) => model.id == 'manual-after-fetch')
          .supportsReasoning,
      isTrue,
    );
  });

  testWidgets('请求期间返回页面，迟到结果不再更新或自动保存', (tester) async {
    await harness.seed(tester, models: const [ProfileModel(id: 'manual')]);
    final request = Completer<List<ProfileModel>>();
    harness.provider.listModelsHandler = () => request.future;
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    await tapProviderControl(tester, keyed('test-provider'), settle: false);
    await tester.binding.handlePopRoute();
    await settleProviderUi(tester);
    request.complete(const [ProfileModel(id: 'late-model')]);
    await settleProviderUi(tester);
    expect(tester.takeException(), isNull);
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(saved.models.single.id, 'manual');
  });
}
