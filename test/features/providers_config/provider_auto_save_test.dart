import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/widgets/app_bottom_bar.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/features/providers_config/provider_edit_page.dart';

import 'provider_test_harness.dart';

void main() {
  late ProviderTestHarness harness;

  setUp(() => harness = ProviderTestHarness());
  tearDown(() async => harness.dispose());

  testWidgets('文本停顿后保存最新输入，保留焦点和创建时间，无底部保存栏', (tester) async {
    await harness.seed(tester, apiKey: 'fake-original-key');
    final original = await tester.runAsync(
      () => harness.repository.getProfile('p1'),
    );
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    expect(keyed('save-provider'), findsNothing);
    expect(find.byType(AppBottomBar), findsNothing);
    expect(find.byTooltip('删除服务商').hitTestable(), findsOneWidget);

    await tester.enterText(keyed('provider-name'), '第一次修改');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(keyed('provider-name'), '最终名称');
    expect(
      (await tester.runAsync(() => harness.repository.getProfile('p1')))!.name,
      '我的服务商',
    );
    await settleProviderAutoSave(tester);
    final saved = (await tester.runAsync(
      () => harness.repository.getProfile('p1'),
    ))!;
    expect(saved.name, '最终名称');
    expect(saved.createdAt, original!.createdAt);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.byType(ProviderEditPage), findsOneWidget);
    expect(harness.keyStorage.writeCount, 1);
    expect(harness.requests, isEmpty);
  });

  testWidgets('无效输入不覆盖已保存配置，修正后自动保存', (tester) async {
    await harness.seed(tester);
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    await fillProviderField(tester, baseUrlField, 'invalid-url');
    expect(find.text('请输入完整的 http 或 https 地址'), findsOneWidget);
    expect(
      (await tester.runAsync(() => harness.repository.getProfile('p1')))!
          .baseUrl,
      'https://example.com/v1',
    );
    await fillProviderField(tester, baseUrlField, 'https://changed.example/v1');
    await settleProviderAutoSave(tester);
    expect(
      (await tester.runAsync(() => harness.repository.getProfile('p1')))!
          .baseUrl,
      'https://changed.example/v1',
    );
    expect(find.text('未保存'), findsNothing);
  });

  testWidgets('返回立即保存尚未触发防抖的修改', (tester) async {
    await harness.seed(tester);
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    await tester.enterText(keyed('provider-name'), '返回前最后输入');
    await tester.binding.handlePopRoute();
    await settleProviderUi(tester);
    expect(find.byType(ProviderEditPage), findsNothing);
    expect(
      (await tester.runAsync(() => harness.repository.getProfile('p1')))!.name,
      '返回前最后输入',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('写入中仍能编辑，返回后按顺序保存最新配置与凭据', (tester) async {
    await harness.seed(tester, apiKey: 'fake-original-key');
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    final gate = Completer<void>();
    harness.keyStorage.writeGate = gate;
    await fillProviderField(
      tester,
      keyed('provider-api-key'),
      'fake-first-key',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await settleProviderUi(tester);
    expect(harness.keyStorage.writeCount, 2);
    expect(
      tester.widget<TextFormField>(keyed('provider-name')).enabled,
      isTrue,
    );
    await fillProviderField(tester, keyed('provider-name'), '继续修改的名称');
    await fillProviderField(
      tester,
      keyed('provider-api-key'),
      'fake-latest-key',
    );
    await tester.binding.handlePopRoute();
    await settleProviderUi(tester);
    gate.complete();
    await settleProviderUi(tester);
    expect(find.byType(ProviderEditPage), findsNothing);
    expect(
      (await tester.runAsync(() => harness.repository.getProfile('p1')))!.name,
      '继续修改的名称',
    );
    expect(await harness.repository.readApiKey('p1'), 'fake-latest-key');
    expect(harness.keyStorage.writeCount, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自动保存失败保留输入并可重试，清空 Key 后使用最新已保存凭据', (tester) async {
    await harness.seed(tester, apiKey: 'fake-original-key');
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    harness.keyStorage.writeError = StateError('fake write failure');
    await fillProviderField(
      tester,
      keyed('provider-api-key'),
      'fake-updated-key',
    );
    await settleProviderAutoSave(tester);
    expect(find.text('未保存'), findsOneWidget);
    await revealProviderControl(tester, keyed('retry-save-provider'));
    expect(find.text('自动保存失败，请重试。'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(keyed('provider-api-key')).controller!.text,
      'fake-updated-key',
    );
    harness.keyStorage.writeError = null;
    await tapProviderControl(tester, keyed('retry-save-provider'));
    await settleProviderAutoSave(tester);
    expect(await harness.repository.readApiKey('p1'), 'fake-updated-key');
    await fillProviderField(tester, keyed('provider-api-key'), '');
    await settleProviderAutoSave(tester);
    await tapProviderControl(tester, keyed('test-provider'));
    expect(harness.requests.single.apiKey, 'fake-updated-key');
    expect(await harness.repository.readApiKey('p1'), 'fake-updated-key');
    expect(
      (await tester.runAsync(harness.repository.listProfiles))!,
      hasLength(1),
    );
  });

  testWidgets('离开编辑页后写入失败仍显示错误', (tester) async {
    await harness.seed(tester);
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    final gate = Completer<void>();
    harness.keyStorage.writeGate = gate;
    harness.keyStorage.writeError = StateError('fake write failure');
    await fillProviderField(
      tester,
      keyed('provider-api-key'),
      'fake-failed-key',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await settleProviderUi(tester);
    await tester.binding.handlePopRoute();
    await settleProviderUi(tester);
    gate.complete();
    await settleProviderUi(tester);
    expect(find.text('自动保存失败，请重试。'), findsOneWidget);
    expect(find.byType(ProviderEditPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除可取消，确认后清除配置、模型和凭据且不影响其他服务商', (tester) async {
    await harness.seed(
      tester,
      apiKey: 'fake-delete-key',
      models: const [ProfileModel(id: 'model')],
    );
    await harness.seed(
      tester,
      id: 'p2',
      name: '保留的服务商',
      apiKey: 'fake-keep-key',
    );
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    await tapProviderControl(tester, keyed('delete-provider'));
    await tapProviderControl(tester, find.text('取消'));
    expect(
      await tester.runAsync(() => harness.repository.getProfile('p1')),
      isNotNull,
    );
    expect(harness.keyStorage.deleteCount, 0);
    await tapProviderControl(tester, keyed('delete-provider'));
    await tapProviderControl(tester, keyed('confirm-delete-provider'));
    expect(find.byType(ProviderEditPage), findsNothing);
    expect(
      await tester.runAsync(() => harness.repository.getProfile('p1')),
      isNull,
    );
    expect(await harness.repository.readApiKey('p1'), isNull);
    expect(
      await tester.runAsync(
        () => harness.database.select(harness.database.models).get(),
      ),
      isEmpty,
    );
    expect(
      (await tester.runAsync(harness.repository.listProfiles))!.single.id,
      'p2',
    );
    expect(await harness.repository.readApiKey('p2'), 'fake-keep-key');
  });

  testWidgets('删除等待已派发的保存，丢弃后续修改和迟到模型结果', (tester) async {
    await harness.seed(tester, apiKey: 'fake-original-key');
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    final gate = Completer<void>();
    harness.keyStorage.writeGate = gate;
    await fillProviderField(
      tester,
      keyed('provider-api-key'),
      'fake-inflight-key',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await settleProviderUi(tester);
    expect(harness.keyStorage.writeCount, 2);
    await fillProviderField(tester, keyed('provider-name'), '待保存的名称');
    final request = Completer<List<ProfileModel>>();
    harness.provider.listModelsHandler = () => request.future;
    await tapProviderControl(tester, keyed('test-provider'), settle: false);
    await tapProviderControl(tester, keyed('delete-provider'), settle: false);
    await tapProviderControl(
      tester,
      keyed('confirm-delete-provider'),
      settle: false,
    );
    expect(
      tester.widget<IconButton>(keyed('delete-provider')).onPressed,
      isNull,
    );
    gate.complete();
    request.complete(const [ProfileModel(id: 'late-model')]);
    await settleProviderUi(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await settleProviderUi(tester);
    expect((await tester.runAsync(harness.repository.listProfiles))!, isEmpty);
    expect(await harness.repository.readApiKey('p1'), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('凭据删除部分失败可重试，期间禁止编辑重新创建配置', (tester) async {
    await harness.seed(tester, apiKey: 'fake-delete-key');
    await harness.pump(tester);
    await tapProviderControl(tester, keyed('provider-p1'));
    harness.keyStorage.deleteError = StateError('fake delete failure');
    await tapProviderControl(tester, keyed('delete-provider'));
    await tapProviderControl(tester, keyed('confirm-delete-provider'));
    expect(find.text('删除服务商失败，请重试。'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(keyed('provider-name')).enabled,
      isFalse,
    );
    expect(
      await tester.runAsync(() => harness.repository.getProfile('p1')),
      isNull,
    );
    expect(await harness.repository.readApiKey('p1'), 'fake-delete-key');
    harness.keyStorage.deleteError = null;
    await tapProviderControl(tester, keyed('retry-delete-provider'));
    expect(find.byType(ProviderEditPage), findsNothing);
    expect(await harness.repository.readApiKey('p1'), isNull);
    expect(harness.keyStorage.deleteCount, 2);
    expect((await tester.runAsync(harness.repository.listProfiles))!, isEmpty);
  });
}
