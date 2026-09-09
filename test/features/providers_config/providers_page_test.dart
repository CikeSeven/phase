import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/features/providers_config/provider_edit_page.dart';
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
    expect(find.text('你的模型入口'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
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
    await tapProviderControl(tester, keyed('save-provider'));
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
    await tapProviderControl(tester, keyed('save-provider'));
    expect(
      (await tester.runAsync(harness.repository.listProfiles))!.single.name,
      '恢复并保存',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('11 个真实预设均可搜索选择，新配置跟随默认协议并可保存自定义地址', (tester) async {
    final harness = ProviderTestHarness();
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('add-provider'));
    expect(providerPresets, hasLength(11));
    for (final preset in providerPresets) {
      await choosePreset(tester, preset.id);
      expect(
        tester
            .widget<DropdownButtonFormField<ApiProtocol>>(
              find.byType(DropdownButtonFormField<ApiProtocol>),
            )
            .initialValue,
        preset.protocol,
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
}
