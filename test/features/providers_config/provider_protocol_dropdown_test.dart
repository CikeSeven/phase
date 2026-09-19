import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_dropdown.dart';
import 'package:phase/core/widgets/app_sheet.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/openai_compat.dart';
import 'package:phase/features/providers_config/provider_edit_page.dart';
import 'package:phase/features/providers_config/provider_ui.dart';

import 'provider_test_harness.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('协议使用共享 Expressive 下拉，窄屏大字可选全部协议且选择后自动保存配置 $dark', (
      tester,
    ) async {
      final harness = ProviderTestHarness();
      addTearDown(harness.dispose);
      const compat = OpenAiCompat(thinkingFormat: ThinkingFormat.openrouter);
      await harness.seed(
        tester,
        presetId: 'openai',
        compatOverrides: compat,
        apiKey: 'fake-protocol-key',
      );
      await harness.pump(
        tester,
        size: const Size(320, 760),
        scale: 2,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
      );
      await tapProviderControl(tester, keyed('provider-p1'));
      for (final protocol in ApiProtocol.values) {
        await tapProviderControl(tester, keyed('choose-protocol'));
        expect(find.byType(AppDropdown<ApiProtocol>), findsOneWidget);
        expect(find.byType(AppSheet), findsNothing);
        expect(find.byType(MenuItemButton), findsNWidgets(4));
        expect(tester.testTextInput.isVisible, isFalse);
        final current = find.widgetWithText(
          MenuItemButton,
          currentProtocolLabel(tester),
        );
        final semantics = tester.ensureSemantics();
        expect(
          tester
              .getSemantics(current)
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        semantics.dispose();
        final option = find.widgetWithText(
          MenuItemButton,
          ProviderUi.protocolLabel(protocol),
        );
        await tapProviderControl(tester, option);
        expect(
          currentProtocolLabel(tester),
          ProviderUi.protocolLabel(protocol),
        );
        expect(find.byType(MenuItemButton), findsNothing);
        await settleProviderAutoSave(tester);
        expect(
          (await tester.runAsync(harness.repository.listProfiles))!
              .single
              .protocol,
          protocol,
        );
        expect(tester.takeException(), isNull);
      }
      await settleProviderAutoSave(tester);
      final saved = (await tester.runAsync(harness.repository.listProfiles))!
          .single;
      expect(saved.protocol, ApiProtocol.googleGenerativeAi);
      expect(saved.presetId, 'openai');
      expect(saved.baseUrl, 'https://example.com/v1');
      expect(saved.compatOverrides!.toJson(), compat.toJson());
      expect(
        await harness.repository.readApiKey(saved.id),
        'fake-protocol-key',
      );
      expect(harness.requests, isEmpty);
    });
  }

  testWidgets('协议菜单不唤起键盘，系统返回先关菜单，返回保留自动保存的修改', (tester) async {
    final harness = ProviderTestHarness();
    addTearDown(harness.dispose);
    await harness.seed(tester);
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    await fillProviderField(tester, keyed('provider-name'), '自动保存的名称');
    expect(tester.testTextInput.isVisible, isTrue);
    await tapProviderControl(tester, keyed('choose-protocol'));
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.binding.handlePopRoute();
    await settleProviderUi(tester);
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.byType(ProviderEditPage), findsOneWidget);
    expect(
      currentProtocolLabel(tester),
      ProviderUi.protocolLabel(ApiProtocol.openaiCompletions),
    );
    await chooseProtocol(tester, ApiProtocol.anthropicMessages);
    await tester.binding.handlePopRoute();
    await settleProviderUi(tester);
    expect(find.byType(ProviderEditPage), findsNothing);
    final saved = (await tester.runAsync(harness.repository.listProfiles))!
        .single;
    expect(saved.protocol, ApiProtocol.anthropicMessages);
    expect(saved.name, '自动保存的名称');
  });
}
