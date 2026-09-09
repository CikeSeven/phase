import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_bottom_bar.dart';
import 'package:phase/core/widgets/app_dialog.dart';
import 'package:phase/data/models/profile_model.dart';

import 'provider_test_harness.dart';

void main() {
  for (final (name, size, scale, keyboard, theme) in [
    ('浅色 320 大字', const Size(320, 800), 2.0, 260.0, AppTheme.light()),
    ('深色 320 大字', const Size(320, 800), 2.0, 240.0, AppTheme.dark()),
    ('浅色 360 大字', const Size(360, 800), 2.0, 280.0, AppTheme.light()),
    ('深色 360 大字', const Size(360, 800), 2.0, 260.0, AppTheme.dark()),
    ('浅色 360 放大', const Size(360, 720), 1.3, 240.0, AppTheme.light()),
    ('深色横屏', const Size(640, 360), 2.0, 100.0, AppTheme.dark()),
  ]) {
    testWidgets('$name 长 URL、长 ID、多模型、键盘和固定保存的完整交互无溢出', (tester) async {
      final harness = ProviderTestHarness();
      addTearDown(harness.dispose);
      final longId =
          'private/${List.filled(16, 'long-model-id').join('-')}/reasoner';
      final longUrl =
          'https://long.example.com/${List.filled(20, 'gateway').join('/')}/v1';
      await harness.seed(
        tester,
        name: '很长的自定义网关名称 · 专注模型与推理的连接',
        baseUrl: longUrl,
        defaultModel: longId,
        models: [
          for (var i = 0; i < 220; i++)
            ProfileModel(id: 'model-${i.toString().padLeft(3, '0')}'),
        ],
        apiKey: 'fake-layout-key',
      );
      await harness.pump(tester, theme: theme, size: size, scale: scale);
      expect(tester.takeException(), isNull);
      await fillProviderField(tester, keyed('provider-search'), 'long.example');
      await tapProviderControl(
        tester,
        keyed('provider-p1'),
        alignment: const Alignment(0, -0.85),
      );
      expect(tester.takeException(), isNull);
      expect(keyed('provider-model-model-219'), findsNothing);
      expect(keyed('save-provider').hitTestable(), findsOneWidget);
      final barBefore = tester.getRect(find.byType(AppBottomBar));

      await searchModels(tester, 'long-model-id');
      await tapProviderControl(tester, keyed('reasoning-$longId'));
      expect(tester.widget<Switch>(keyed('reasoning-$longId')).value, isFalse);
      expect(tester.getRect(find.byType(AppBottomBar)), barBefore);
      expect(tester.takeException(), isNull);

      await searchModels(tester, 'model-219');
      await tapProviderControl(tester, keyed('reasoning-model-219'));
      await tapProviderControl(tester, keyed('default-model-219'));
      expect(
        tester.widget<Text>(keyed('default-model-summary')).data,
        'model-219',
      );
      setKeyboard(tester, keyboard);
      await settleProviderUi(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(AppBottomBar)).bottom,
        closeTo(size.height - keyboard, 0.1),
      );
      expect(keyed('save-provider').hitTestable(), findsOneWidget);

      await tapProviderControl(tester, keyed('add-provider-model'));
      expect(find.byType(AppDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await fillProviderField(tester, keyed('new-model-id'), 'added/$longId');
      await tapProviderControl(tester, keyed('new-model-reasoning'));
      await tapProviderControl(tester, keyed('confirm-add-model'));
      expect(find.byType(AppDialog), findsNothing);
      expect(tester.takeException(), isNull);
      expect(keyed('save-provider').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(keyed('save-provider')).bottom,
        lessThanOrEqualTo(size.height - keyboard),
      );
      await tapProviderControl(tester, keyed('save-provider'));
      expect(tester.takeException(), isNull);
      final saved = (await tester.runAsync(harness.repository.listProfiles))!
          .single;
      expect(saved.baseUrl, longUrl);
      expect(saved.defaultModel, 'model-219');
      expect(saved.models, hasLength(222));
      expect(
        saved.models
            .singleWhere((model) => model.id == longId)
            .supportsReasoning,
        isFalse,
      );
      expect(
        saved.models
            .singleWhere((model) => model.id == 'model-219')
            .supportsReasoning,
        isTrue,
      );
      expect(
        saved.models
            .singleWhere((model) => model.id == 'added/$longId')
            .supportsReasoning,
        isFalse,
      );
      expect(await harness.repository.readApiKey(saved.id), 'fake-layout-key');
    });
  }

  testWidgets('320 大字键盘下预设面板仍可搜索、选择并保存真实配置', (tester) async {
    final harness = ProviderTestHarness();
    addTearDown(harness.dispose);
    await harness.pump(
      tester,
      size: const Size(320, 720),
      scale: 2,
      theme: AppTheme.dark(),
    );
    await tapProviderControl(tester, keyed('add-provider'));
    setKeyboard(tester, 260);
    await settleProviderUi(tester);
    await choosePreset(tester, 'anthropic');
    expect(tester.takeException(), isNull);
    await tapProviderControl(tester, keyed('save-provider'));
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(saved.presetId, 'anthropic');
    expect(tester.takeException(), isNull);
  });
}
