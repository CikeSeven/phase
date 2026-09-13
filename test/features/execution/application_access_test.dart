import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/application_access_policy.dart';
import 'package:phase/data/models/assistant.dart';
import 'package:phase/data/models/execution_scope.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/features/execution/application_policy_sheet.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/platform_tools.dart';
import 'package:phase/features/tools/tool_registry.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';

import '../../support/fake_channel_driver.dart';
import '../tools/tool_loop_harness.dart';

InstalledApplication app(
  String package, {
  String? label,
  bool system = false,
  int installed = 1,
  int? size,
}) => InstalledApplication(
  packageName: package,
  label: label ?? package,
  isSystem: system,
  installedAtMs: installed,
  sizeBytes: size,
  launchable: true,
);

void main() {
  test('默认允许第三方，系统应用可在黑名单逐个放行；模式切换不覆盖另一份名单', () {
    const defaults = ApplicationAccessPolicy();
    expect(defaults.allows('third', isSystem: false), isTrue);
    expect(defaults.allows('system', isSystem: true), isFalse);
    final black = defaults
        .select('third', isSystem: false, selected: true)
        .select('system', isSystem: true, selected: false);
    expect(black.allows('third', isSystem: false), isFalse);
    expect(black.allows('system', isSystem: true), isTrue);
    final white = black
        .withMode(AppListMode.whitelist)
        .select('white', isSystem: false, selected: true);
    expect(white.allows('system', isSystem: true), isFalse);
    expect(white.allows('white', isSystem: false), isTrue);
    final restored = ApplicationAccessPolicy.fromJson(
      jsonDecode(jsonEncode(white.toJson())) as Map<String, dynamic>,
    ).withMode(AppListMode.blacklist);
    expect(restored.blacklist, {'third'});
    expect(restored.whitelist, {'white'});
    expect(restored.allowedSystemApps, {'system'});
    expect(restored.allows('system', isSystem: true), isTrue);
    expect(
      restored
          .select('system', isSystem: true, selected: true)
          .allows('system', isSystem: true),
      isFalse,
    );
  });

  test('应用列表按名称、首次安装时间和大小稳定排序，筛选和搜索不改变策略', () {
    final apps = [
      app('b', label: 'Beta', installed: 30, size: 10),
      app('a', label: 'Alpha', system: true, installed: 20, size: 90),
      app('c', label: 'Gamma', installed: 10),
    ];
    expect(filterApplications(apps).map((a) => a.packageName), ['a', 'b', 'c']);
    expect(
      filterApplications(
        apps,
        sort: ApplicationSort.installedAt,
      ).map((a) => a.packageName),
      ['b', 'a', 'c'],
    );
    expect(
      filterApplications(
        apps,
        sort: ApplicationSort.size,
      ).map((a) => a.packageName),
      ['a', 'b', 'c'],
    );
    expect(
      filterApplications(
        apps,
        filter: ApplicationFilter.system,
      ).map((a) => a.packageName),
      ['a'],
    );
    expect(
      filterApplications(
        apps,
        filter: ApplicationFilter.thirdParty,
        query: 'BETA',
      ).map((a) => a.packageName),
      ['b'],
    );
  });

  test('应用操作只有一个策略事实来源，不能用单工具覆盖绕过禁止', () {
    final driver = FakeChannelDriver();
    addTearDown(driver.dispose);
    final registry = buildBuiltInRegistry(
      httpFetch: (_) => throw StateError('unused'),
      platform: () => driver,
    );
    final appTools = registry.tools
        .where((tool) => tool.policyKey == applicationOperationsPolicyKey)
        .toList();
    expect(
      appTools.map((tool) => tool.name).toSet(),
      applicationOperationTools,
    );
    const config = ToolPolicyConfig(
      policies: {applicationOperationsPolicyKey: ToolPolicy.allow},
    );
    expect(config.enabledTools, applicationOperationTools);
    expect(
      registry
          .definitionsFor(config.enabledTools, config.overrides)
          .map((tool) => tool.name)
          .toSet(),
      applicationOperationTools,
    );
    for (final tool in appTools) {
      expect(
        registry.policyFor(tool, config.enabledTools, {
          applicationOperationsPolicyKey: ToolPolicy.deny,
          tool.name: ToolPolicy.allow,
        }),
        ToolPolicy.deny,
      );
      if (tool.name != 'list_apps') {
        expect(tool.inputSchema['required'], contains('packageName'));
      }
    }
    expect(const ToolPolicyConfig(policies: {}).enabledTools, isEmpty);
    expect(
      const ToolPolicyConfig(policies: {'click_node': ToolPolicy.allow})
          .enabledTools,
      isEmpty,
    );
  });

  test('获取应用列表经统一策略与真实工具落库，黑名单包名不会泄漏进模型提示词', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    await h.container
        .read(settingsStorageProvider)
        .writeExecutionScope(
          const ExecutionScope(
            appPolicy: ApplicationAccessPolicy(blacklist: {'private.blocked'}),
          ),
        );
    h.onConfirmation = (_) async => ToolDecision.approved;
    driver.executeHandler = (request, _) async {
      expect(request.action, ExecutionAction.listApps);
      return ExecutionResult(
        toolCallId: request.toolCallId,
        status: ExecutionStatus.succeeded,
        result: {
          'applications': [
            {
              'packageName': 'third.allowed',
              'name': 'Allowed',
              'sizeBytes': 123,
            },
          ],
          'total': 1,
        },
        artifacts: [],
      );
    };
    h.provider.turns.addAll([
      toolTurn(callId: 'apps', toolName: 'list_apps', arguments: '{}'),
      textTurn('已获取'),
    ]);
    await h.controller().send('获取应用列表');
    expect(driver.deviceTasks, [false]);
    expect(
      (await h.recordsByCall())['apps']!.result,
      contains('third.allowed'),
    );
    expect(
      h.provider.requests.first.systemPrompt,
      isNot(contains('private.blocked')),
    );
    expect(h.provider.requests.first.systemPrompt, contains('list_apps'));
    expect(
      executionScopePrompt(
        const ExecutionScope(
          appPolicy: ApplicationAccessPolicy(whitelist: {'hidden.excluded'}),
        ),
        applicationOperations: true,
      ),
      isNot(contains('hidden.excluded')),
    );
  });
}
