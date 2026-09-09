import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/core/widgets/app_dialog.dart';
import 'package:phase/data/models/ai_model.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/openai_compat.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/features/providers_config/provider_preset_sheet.dart';
import 'package:phase/features/providers_config/providers_page.dart';
import 'package:phase/providers/presets/provider_preset.dart';

import 'provider_test_harness.dart';

void main() {
  late ProviderTestHarness harness;

  setUp(() => harness = ProviderTestHarness());
  tearDown(() async => harness.dispose());

  testWidgets('新增、搜索、添加校验、推理、默认、可见移除与获取模型都写回真实仓库', (tester) async {
    harness.provider.listModelsHandler = () async => const [
      AiModel(id: 'remote-chat'),
      AiModel(id: 'remote-chat'),
      AiModel(id: 'Remote-Chat'),
    ];
    await harness.pump(tester);
    expect(find.text('暂无服务商'), findsOneWidget);
    expect(keyed('add-provider').hitTestable(), findsOneWidget);
    await tapProviderControl(tester, keyed('add-provider'));
    await choosePreset(tester, 'deepseek');
    await fillProviderField(tester, keyed('provider-name'), '我的 DeepSeek');
    await fillProviderField(tester, keyed('provider-api-key'), 'fake-new-key');

    await tapProviderControl(tester, keyed('add-provider-model'));
    await tapProviderControl(tester, keyed('confirm-add-model'));
    expect(find.text('请输入模型 ID'), findsOneWidget);
    await fillProviderField(tester, keyed('new-model-id'), 'manual-private');
    await tapProviderControl(tester, keyed('new-model-reasoning'));
    await tapProviderControl(tester, keyed('confirm-add-model'));
    expect(
      tester.widget<Text>(keyed('default-model-summary')).data,
      'manual-private',
    );

    await tapProviderControl(tester, keyed('add-provider-model'));
    await fillProviderField(tester, keyed('new-model-id'), ' manual-private ');
    await tapProviderControl(tester, keyed('confirm-add-model'));
    expect(find.text('该模型 ID 已存在'), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);
    await tapProviderControl(tester, find.text('取消'));

    await addModel(tester, 'temporary-model');
    await searchModels(tester, 'temporary');
    await tapProviderControl(tester, keyed('remove-temporary-model'));
    await tapProviderControl(tester, find.text('取消'));
    expect(keyed('provider-model-temporary-model'), findsOneWidget);
    await tapProviderControl(tester, keyed('remove-temporary-model'));
    await tapProviderControl(tester, keyed('confirm-remove-model'));
    expect(keyed('provider-model-temporary-model'), findsNothing);

    await tapProviderControl(tester, keyed('test-provider'));
    expect(find.text('已获取 2 个模型'), findsOneWidget);
    expect(find.textContaining('连接成功'), findsNothing);
    expect(harness.provider.listModelsCount, 1);
    expect(harness.requests.single.apiKey, 'fake-new-key');
    expect(
      harness.requests.single.profile.protocol,
      ApiProtocol.openaiCompletions,
    );
    await searchModels(tester, 'remote-chat');
    await tapProviderControl(tester, keyed('reasoning-remote-chat'));
    await tapProviderControl(tester, keyed('default-remote-chat'));
    expect(
      tester.widget<Text>(keyed('default-model-summary')).data,
      'remote-chat',
    );
    await tapProviderControl(tester, keyed('save-provider'));
    expect(find.byType(ProvidersPage), findsOneWidget);

    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(saved.name, '我的 DeepSeek');
    expect(saved.baseUrl, presetById('deepseek').baseUrl);
    expect(saved.presetId, 'deepseek');
    expect(saved.protocol, ApiProtocol.openaiCompletions);
    expect(saved.defaultModel, 'remote-chat');
    expect(
      saved.models.map((model) => model.id),
      unorderedEquals(['manual-private', 'remote-chat', 'Remote-Chat']),
    );
    expect(
      saved.models
          .singleWhere((model) => model.id == 'manual-private')
          .supportsReasoning,
      isTrue,
    );
    expect(
      saved.models
          .singleWhere((model) => model.id == 'remote-chat')
          .supportsReasoning,
      isTrue,
    );
    expect(await harness.repository.readApiKey(saved.id), 'fake-new-key');
    expect(harness.keyStorage.deleteCount, 0);
  });

  testWidgets('编辑保留独立协议、兼容项、手动模型、推理标记和列表外默认模型', (tester) async {
    const compat = OpenAiCompat(
      maxTokensField: 'max_tokens',
      supportsDeveloperRole: false,
      thinkingFormat: ThinkingFormat.qwen,
    );
    await harness.seed(
      tester,
      presetId: 'openai',
      protocol: ApiProtocol.anthropicMessages,
      compatOverrides: compat,
      defaultModel: 'legacy/reasoner',
      models: const [
        ProfileModel(id: 'manual-model'),
        ProfileModel(id: 'gpt-5', supportsReasoning: false),
      ],
      apiKey: 'fake-old-key',
    );
    harness.provider.listModelsHandler = () async => const [
      AiModel(id: 'gpt-5'),
      AiModel(id: 'remote-r1'),
      AiModel(id: 'remote-r1'),
    ];
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    expect(
      tester
          .widget<DropdownButtonFormField<ApiProtocol>>(
            find.byType(DropdownButtonFormField<ApiProtocol>),
          )
          .initialValue,
      ApiProtocol.anthropicMessages,
    );
    await fillProviderField(tester, keyed('provider-name'), '重命名的连接');
    await fillProviderField(tester, keyed('provider-api-key'), '');
    expect(find.textContaining('留空保留并使用原密钥'), findsOneWidget);
    await tapProviderControl(tester, keyed('test-provider'));
    expect(harness.requests.single.apiKey, 'fake-old-key');
    expect(
      harness.requests.single.profile.protocol,
      ApiProtocol.anthropicMessages,
    );
    expect(
      harness.requests.single.profile.compatOverrides!.toJson(),
      compat.toJson(),
    );
    await searchModels(tester, 'gpt-5');
    expect(tester.widget<Switch>(keyed('reasoning-gpt-5')).value, isFalse);
    await searchModels(tester, 'legacy');
    expect(keyed('provider-model-legacy/reasoner'), findsOneWidget);
    expect(find.text('默认'), findsOneWidget);
    expect(
      tester.widget<Text>(keyed('default-model-summary')).data,
      'legacy/reasoner',
    );
    await tapProviderControl(tester, keyed('save-provider'));
    final saved = (await tester.runAsync(
      () => harness.repository.getProfile('p1'),
    ))!;
    expect(saved.name, '重命名的连接');
    expect(saved.protocol, ApiProtocol.anthropicMessages);
    expect(saved.compatOverrides!.toJson(), compat.toJson());
    expect(saved.presetId, 'openai');
    expect(saved.defaultModel, 'legacy/reasoner');
    expect(
      saved.models.map((model) => model.id),
      unorderedEquals([
        'manual-model',
        'gpt-5',
        'legacy/reasoner',
        'remote-r1',
      ]),
    );
    expect(
      saved.models
          .singleWhere((model) => model.id == 'gpt-5')
          .supportsReasoning,
      isFalse,
    );
    expect(
      saved.models
          .singleWhere((model) => model.id == 'remote-r1')
          .supportsReasoning,
      isTrue,
    );
    expect(await harness.repository.readApiKey('p1'), 'fake-old-key');
  });

  testWidgets('读取凭证失败时禁止空表单覆盖，重试后正常编辑保存', (tester) async {
    await harness.seed(tester, name: '受保护的配置', apiKey: 'fake-existing-key');
    harness.keyStorage.readError = const UnknownFailure('fake read failure');
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    expect(find.text('无法读取服务商配置'), findsOneWidget);
    expect(keyed('provider-name'), findsNothing);
    expect(keyed('save-provider'), findsNothing);
    final before = await tester.runAsync(
      () => harness.repository.getProfile('p1'),
    );
    expect(before!.name, '受保护的配置');

    harness.keyStorage.readError = null;
    await tapProviderControl(tester, find.text('重新加载'));
    expect(find.text('无法读取服务商配置'), findsNothing);
    await fillProviderField(tester, keyed('provider-name'), '重试后编辑');
    await tapProviderControl(tester, keyed('save-provider'));
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(saved.id, 'p1');
    expect(saved.name, '重试后编辑');
    expect(await harness.repository.readApiKey('p1'), 'fake-existing-key');
  });

  testWidgets('不存在的配置也显示可重试状态，不允许新增覆盖原 id', (tester) async {
    await harness.pump(tester);
    harness.router.push('/settings/providers/missing');
    await settleProviderUi(tester);
    expect(find.text('无法读取服务商配置'), findsOneWidget);
    expect(keyed('save-provider'), findsNothing);
    expect((await tester.runAsync(harness.repository.listProfiles))!, isEmpty);
    await harness.seed(tester, id: 'missing', name: '恢复的配置');
    await tapProviderControl(tester, find.text('重新加载'));
    await fillProviderField(tester, keyed('provider-name'), '恢复后保存');
    await tapProviderControl(tester, keyed('save-provider'));
    expect(
      (await tester.runAsync(harness.repository.listProfiles))!.single.name,
      '恢复后保存',
    );
  });

  testWidgets('协议可独立选择并保存，预设仍使用真实注册表', (tester) async {
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('add-provider'));
    await choosePreset(tester, 'openai');
    await chooseProtocol(tester, ApiProtocol.openaiCompletions);
    await tapProviderControl(tester, keyed('save-provider'));
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(saved.presetId, 'openai');
    expect(saved.protocol, ApiProtocol.openaiCompletions);
    expect(saved.baseUrl, presetById('openai').baseUrl);
  });

  testWidgets('切换 Ollama 隐藏密钥后，获取模型不发送也不删除原密钥', (tester) async {
    await harness.seed(
      tester,
      presetId: 'openai',
      apiKey: 'fake-other-provider-key',
    );
    harness.provider.listModelsHandler = () async => const [
      AiModel(id: 'local'),
    ];
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    await choosePreset(tester, 'ollama');
    expect(keyed('provider-api-key'), findsNothing);
    expect(find.text('无需 API Key · 原有密钥保留'), findsOneWidget);
    await tapProviderControl(tester, keyed('test-provider'));
    expect(harness.requests.single.apiKey, isEmpty);
    expect(
      harness.requests.single.profile.baseUrl,
      presetById('ollama').baseUrl,
    );
    await tapProviderControl(tester, keyed('save-provider'));
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(saved.presetId, 'ollama');
    expect(saved.models.single.id, 'local');
    expect(
      await harness.repository.readApiKey('p1'),
      'fake-other-provider-key',
    );
    expect(harness.keyStorage.writeCount, 1);
    expect(harness.keyStorage.deleteCount, 0);
  });

  for (final field in ['URL', '协议', 'Key']) {
    testWidgets('修改$field使请求快照过期，旧结果与旧错误不覆盖新草稿', (tester) async {
      await harness.seed(
        tester,
        apiKey: 'fake-original-key',
        models: const [ProfileModel(id: 'manual')],
      );
      final oldRequest = Completer<List<AiModel>>();
      final newRequest = Completer<List<AiModel>>();
      harness.provider.listModelsHandler = () =>
          harness.provider.listModelsCount == 1
          ? oldRequest.future
          : newRequest.future;
      await harness.pump(tester);
      await tapProviderControl(tester, keyed('provider-p1'));
      await tapProviderControl(tester, keyed('test-provider'), settle: false);
      expect(harness.requests, hasLength(1));
      switch (field) {
        case 'URL':
          await fillProviderField(
            tester,
            baseUrlField,
            'https://new.example/v1',
          );
        case '协议':
          await chooseProtocol(
            tester,
            ApiProtocol.openaiResponses,
            pendingRequest: true,
          );
        case 'Key':
          await fillProviderField(
            tester,
            keyed('provider-api-key'),
            'fake-new-key',
          );
      }
      await tapProviderControl(tester, keyed('test-provider'), settle: false);
      expect(harness.requests, hasLength(2));
      expect(harness.requests.first.profile.baseUrl, 'https://example.com/v1');
      expect(harness.requests.first.apiKey, 'fake-original-key');
      if (field == 'Key') {
        oldRequest.completeError(const NetworkFailure('stale failure'));
      } else {
        oldRequest.complete(const [AiModel(id: 'stale-remote')]);
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('已获取'), findsNothing);
      expect(find.text(const NetworkFailure('').userMessage), findsNothing);
      expect(
        tester.widget<FilledButton>(keyed('test-provider')).onPressed,
        isNull,
      );
      newRequest.complete(const [AiModel(id: 'fresh-remote')]);
      await settleProviderUi(tester);
      expect(find.text('已获取 1 个模型'), findsOneWidget);
      await fillProviderField(tester, keyed('provider-name'), '最新草稿');
      expect(find.textContaining('已获取'), findsNothing);
      await tapProviderControl(tester, keyed('save-provider'));
      final saved = (await tester.runAsync(harness.repository.listProfiles))!
          .single;
      expect(saved.name, '最新草稿');
      expect(
        saved.models.map((model) => model.id),
        unorderedEquals(['manual', 'fresh-remote']),
      );
      if (field == 'URL') {
        expect(saved.baseUrl, 'https://new.example/v1');
        expect(harness.requests.last.profile.baseUrl, saved.baseUrl);
      } else if (field == '协议') {
        expect(saved.protocol, ApiProtocol.openaiResponses);
        expect(harness.requests.last.profile.protocol, saved.protocol);
      } else {
        expect(harness.requests.last.apiKey, 'fake-new-key');
        expect(await harness.repository.readApiKey('p1'), 'fake-new-key');
      }
    });
  }

  testWidgets('保存中锁定重复操作，安全存储失败后重试不重复创建配置', (tester) async {
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('add-provider'));
    await choosePreset(tester, 'openai');
    await fillProviderField(
      tester,
      keyed('provider-api-key'),
      'fake-key-to-save',
    );
    final gate = Completer<void>();
    harness.keyStorage.writeGate = gate;
    harness.keyStorage.writeError = StateError('fake write failure');
    await tapProviderControl(tester, keyed('save-provider'), settle: false);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.text('保存中…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(keyed('save-provider')).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextFormField>(keyed('provider-name')).enabled,
      isFalse,
    );
    await tester.tap(keyed('save-provider'));
    await tapProviderControl(
      tester,
      keyed('choose-provider-preset'),
      settle: false,
    );
    expect(find.byType(ProviderPresetSheet), findsNothing);
    expect(harness.keyStorage.writeCount, 1);
    expect(
      (await tester.runAsync(harness.repository.listProfiles))!,
      hasLength(1),
    );
    gate.complete();
    await settleProviderUi(tester);
    expect(find.text('保存失败，请重试。'), findsOneWidget);
    harness.keyStorage.writeGate = null;
    harness.keyStorage.writeError = null;
    await tapProviderControl(tester, keyed('save-provider'));
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(await harness.repository.readApiKey(saved.id), 'fake-key-to-save');
    expect(harness.keyStorage.writeCount, 2);
  });
}
