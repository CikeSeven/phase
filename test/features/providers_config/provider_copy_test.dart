import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/widgets/app_card.dart';
import 'package:phase/core/widgets/app_dialog.dart';
import 'package:phase/core/widgets/app_scaffold.dart';
import 'package:phase/core/widgets/app_sheet.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/openai_compat.dart';
import 'package:phase/features/providers_config/provider_form_sections.dart';

import 'provider_test_harness.dart';

void main() {
  testWidgets('服务商页面和弹层无冗余教学，必要安全提示及操作保留', (tester) async {
    final harness = ProviderTestHarness();
    addTearDown(harness.dispose);
    await harness.seed(
      tester,
      name: '精简连接',
      presetId: 'openai',
      protocol: ApiProtocol.openaiCompletions,
      compatOverrides: const OpenAiCompat(),
      models: const [ProfileModel(id: 'manual')],
      apiKey: 'fake-copy-key',
    );
    harness.provider.listModelsHandler = () async => const [
      ProfileModel(id: 'remote-model'),
    ];
    await harness.pump(tester);
    expect(
      tester.widget<AppScaffold>(find.byType(AppScaffold)).subtitle,
      isNull,
    );
    _expectNoTutorials();
    expect(find.text('1 个服务商 · 1 个模型'), findsOneWidget);
    await tapProviderControl(tester, keyed('provider-p1'));
    expect(
      find.descendant(
        of: find.byType(ProviderFormSections),
        matching: find.byType(AppCard),
      ),
      findsNothing,
    );
    _expectNoTutorials();
    expect(find.text('POST /chat/completions'), findsOneWidget);
    expect(find.text('保留自定义兼容设置'), findsOneWidget);
    expect(find.text('API 基础地址，不含生成端点'), findsOneWidget);
    expect(find.text('本机安全存储 · 留空保留并使用原密钥'), findsOneWidget);
    await tapProviderControl(tester, keyed('choose-provider-preset'));
    expect(tester.widget<AppSheet>(find.byType(AppSheet)).subtitle, isNull);
    _expectNoTutorials();
    await fillProviderField(tester, keyed('preset-search'), 'openai');
    await tapProviderControl(tester, keyed('preset-openai'));
    await searchModels(tester, 'manual');
    _expectNoTutorials();
    await tapProviderControl(tester, keyed('add-provider-model'));
    expect(
      tester.widget<AppDialog>(find.byType(AppDialog)).description,
      isNull,
    );
    _expectNoTutorials();
    await fillProviderField(tester, keyed('new-model-id'), 'added-model');
    await tapProviderControl(tester, keyed('new-model-reasoning'));
    await tapProviderControl(tester, keyed('confirm-add-model'));
    await tapProviderControl(tester, keyed('test-provider'));
    expect(find.text('已获取 1 个模型'), findsOneWidget);
    _expectNoTutorials();
    await settleProviderAutoSave(tester);
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(
      saved.models.map((model) => model.id),
      unorderedEquals(['manual', 'added-model', 'remote-model']),
    );
    expect(saved.compatOverrides, isNotNull);
    expect(await harness.repository.readApiKey(saved.id), 'fake-copy-key');
  });

  testWidgets('无旧凭证的免 Key 预设不显示虚假的密钥保留说明', (tester) async {
    final harness = ProviderTestHarness();
    addTearDown(harness.dispose);
    await harness.pump(tester);
    expect(find.text('暂无服务商'), findsOneWidget);
    _expectNoTutorials();
    await tapProviderControl(tester, keyed('add-provider'));
    expect(find.text('仅存于本机安全存储'), findsOneWidget);
    await choosePreset(tester, 'ollama');
    expect(find.text('无需 API Key'), findsOneWidget);
    expect(find.textContaining('原有密钥保留'), findsNothing);
    expect(keyed('provider-api-key'), findsNothing);
    await tapProviderControl(tester, keyed('save-provider'));
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(saved.presetId, 'ollama');
    expect(await harness.repository.readApiKey(saved.id), isNull);
  });
}

void _expectNoTutorials() {
  for (final phrase in [
    '管理连接与模型',
    '你的模型入口',
    '这里记录你的',
    '让喜欢的模型',
    '从预设开始',
    '协议与服务商独立',
    '选择服务商预设',
    '同时测试模型列表接口',
    '已合并到下方列表',
    '支持手动维护',
    '推理开关用于显示',
    '修改在保存后生效',
    '预设提供建议地址',
    '保存服务商后生效',
    '预填值可以手动调整',
  ]) {
    expect(find.textContaining(phrase, skipOffstage: false), findsNothing);
  }
}
