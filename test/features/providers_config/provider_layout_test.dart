import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_bottom_bar.dart';
import 'package:phase/core/widgets/app_dialog.dart';
import 'package:phase/data/models/profile_model.dart';

import 'package:phase/features/providers_config/provider_ui.dart';

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
    testWidgets('$name 长 URL、长 ID、多模型、键盘和顶栏删除的完整交互无溢出', (tester) async {
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
      expect(keyed('delete-provider').hitTestable(), findsOneWidget);
      expect(find.byType(AppBottomBar), findsNothing);
      final deleteBefore = tester.getRect(keyed('delete-provider'));

      await searchModels(tester, 'long-model-id');
      await tapProviderControl(tester, keyed('enabled-$longId'));
      expect(tester.widget<Checkbox>(keyed('enabled-$longId')).value, isFalse);
      expect(tester.getRect(keyed('delete-provider')), deleteBefore);
      expect(tester.takeException(), isNull);

      await searchModels(tester, 'model-219');
      await tapProviderControl(tester, keyed('enabled-model-219'));
      // 工具能力默认开启，点击后关闭。
      expect(
        tester.widget<CapabilityChip>(keyed('tools-model-219')).selected,
        isTrue,
      );
      await tapProviderControl(tester, keyed('tools-model-219'));
      expect(
        tester.widget<CapabilityChip>(keyed('tools-model-219')).selected,
        isFalse,
      );
      if (scale == 2 && size.width <= 360) {
        final temperature = keyed('temperature-model-219');
        final output = keyed('max-output-model-219');
        await tester.ensureVisible(temperature);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(output).dy,
          greaterThan(tester.getBottomLeft(temperature).dy),
        );
      }
      setKeyboard(tester, keyboard);
      await settleProviderUi(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(keyed('delete-provider')), deleteBefore);
      expect(keyed('delete-provider').hitTestable(), findsOneWidget);
      expect(find.byType(AppBottomBar), findsNothing);

      await tapProviderControl(tester, keyed('add-provider-model'));
      expect(find.byType(AppDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await fillProviderField(tester, keyed('new-model-id'), 'added/$longId');
      await tapProviderControl(tester, keyed('new-model-reasoning'));
      await tapProviderControl(tester, keyed('confirm-add-model'));
      expect(find.byType(AppDialog), findsNothing);
      expect(tester.takeException(), isNull);
      expect(keyed('delete-provider').hitTestable(), findsOneWidget);
      expect(find.byType(AppBottomBar), findsNothing);
      expect(
        tester.getRect(keyed('delete-provider')).bottom,
        lessThanOrEqualTo(size.height - keyboard),
      );
      await settleProviderAutoSave(tester);
      expect(tester.takeException(), isNull);
      final saved = (await tester.runAsync(harness.repository.listProfiles))!
          .single;
      expect(saved.baseUrl, longUrl);
      // 列表外默认模型原样保留（页面不再有默认模型操作）。
      expect(saved.defaultModel, longId);
      expect(saved.models, hasLength(222));
      expect(
        saved.models.singleWhere((model) => model.id == longId).enabled,
        isFalse,
      );
      // 推理能力默认关闭，只有显式声明支持的模型才下发推理参数。
      expect(
        saved.models
            .singleWhere((model) => model.id == longId)
            .supportsReasoning,
        isFalse,
      );
      expect(
        saved.models.singleWhere((model) => model.id == 'model-219').enabled,
        isFalse,
      );
      expect(
        saved.models
            .singleWhere((model) => model.id == 'model-219')
            .supportsTools,
        isFalse,
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
