import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/experimental/scope.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/tool_permission.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/tool_source.dart';
import 'package:phase/features/tools/tool_permission_rules_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

@Dependencies([ToolPermissionRulesController])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _GatedSettings settings;
  const target = ToolPermissionRule(
    sourceKind: ToolSourceKind.builtIn,
    sourceId: 'builtIn',
    toolName: 'shell',
    policy: ToolPolicy.ask,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = _GatedSettings(await SharedPreferences.getInstance());
    container = ProviderContainer(
      overrides: [settingsStorageProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);
    addTearDown(
      container.listen(toolPermissionRulesControllerProvider, (_, _) {}).close,
    );
    await container.read(toolPermissionRulesControllerProvider.future);
  });

  test('设置、覆盖、删除规则持久化，来源 key 唯一', () async {
    final controller = container.read(
      toolPermissionRulesControllerProvider.notifier,
    );
    await controller.setRule(target, ToolPolicy.ask);
    await controller.setRule(target, ToolPolicy.deny);
    expect(
      container
          .read(toolPermissionRulesControllerProvider)
          .requireValue
          .single
          .policy,
      ToolPolicy.deny,
    );
    expect(settings.readToolPermissionRules().single.policy, ToolPolicy.deny);
    await controller.setRule(target, null);
    expect(settings.readToolPermissionRules(), isEmpty);
    expect(
      container.read(toolPermissionRulesControllerProvider).requireValue,
      isEmpty,
    );
  });

  test('保存失败保持已保存状态，解除故障后可重试', () async {
    final controller = container.read(
      toolPermissionRulesControllerProvider.notifier,
    );
    await controller.setRule(target, ToolPolicy.ask);
    settings.failure = const StorageFailure('fixture');
    await expectLater(
      controller.setRule(target, ToolPolicy.allow),
      throwsA(isA<StorageFailure>()),
    );
    expect(
      container
          .read(toolPermissionRulesControllerProvider)
          .requireValue
          .single
          .policy,
      ToolPolicy.ask,
    );
    settings.failure = null;
    await controller.setRule(target, ToolPolicy.allow);
    expect(settings.readToolPermissionRules().single.policy, ToolPolicy.allow);
  });

  test('未提交的保存不发布状态，重复提交拒绝，完成后允许再保存', () async {
    final controller = container.read(
      toolPermissionRulesControllerProvider.notifier,
    );
    settings.gate = Completer<void>();
    final writing = controller.setRule(target, ToolPolicy.ask);
    expect(
      container.read(toolPermissionRulesControllerProvider).requireValue,
      isEmpty,
    );
    await expectLater(
      controller.setRule(target, ToolPolicy.deny),
      throwsA(isA<OperationFailure>()),
    );
    settings.gate!.complete();
    await writing;
    expect(
      container
          .read(toolPermissionRulesControllerProvider)
          .requireValue
          .single
          .policy,
      ToolPolicy.ask,
    );
    settings.gate = null;
    await controller.setRule(target, ToolPolicy.deny);
    expect(settings.readToolPermissionRules().single.policy, ToolPolicy.deny);
  });

  test('销毁页面后迟到保存只提交持久化，不操作已销毁 provider', () async {
    final controller = container.read(
      toolPermissionRulesControllerProvider.notifier,
    );
    settings.gate = Completer<void>();
    final writing = controller.setRule(target, ToolPolicy.ask);
    container.dispose();
    settings.gate!.complete();
    await writing;
    expect(settings.readToolPermissionRules().single.policy, ToolPolicy.ask);
  });
}

class _GatedSettings extends SettingsStorage {
  _GatedSettings(super.prefs);
  Completer<void>? gate;
  Failure? failure;
  @override
  Future<void> writeToolPermissionRules(List<ToolPermissionRule> rules) async {
    if (gate != null) await gate!.future;
    if (failure case final error?) throw error;
    await super.writeToolPermissionRules(rules);
  }
}
