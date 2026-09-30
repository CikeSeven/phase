import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/execution_scope.dart';
import 'package:phase/data/models/permission_mode.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/platform_tools.dart';
import 'package:phase/features/tools/tool_registry.dart';
import 'package:phase/features/tools/tool_permission_policy.dart';

import '../../support/fake_channel_driver.dart';
import '../tools/tool_loop_harness.dart';

void main() {
  test('执行范围只保存文件授权，不再保存应用名单', () {
    const scope = ExecutionScope(fileUris: ['content://fixture/root']);
    final encoded = jsonEncode(scope.toJson());
    expect(jsonDecode(encoded), {
      'fileUris': ['content://fixture/root'],
    });
    final restored = ExecutionScope.fromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    expect(restored.fileUris, scope.fileUris);
  });

  test('模式统一控制应用操作；应用列表独立归入只读', () {
    final driver = FakeChannelDriver();
    addTearDown(driver.dispose);
    final registry = buildBuiltInRegistry(
      httpFetch: (_) => throw StateError('unused'),
      platform: () => driver,
    );
    final apps = registry.tools.where(
      (tool) => tool.policyKey == applicationOperationsPolicyKey,
    );
    expect(apps.map((t) => t.name).toSet(), applicationOperationTools);
    for (final tool in apps) {
      expect(policyForMode(PermissionMode.plan, tool), ToolPolicy.deny);
      expect(policyForMode(PermissionMode.basic, tool), ToolPolicy.ask);
      expect(policyForMode(PermissionMode.fullAccess, tool), ToolPolicy.allow);
    }
    final list = registry.byName('list_apps')!;
    for (final mode in PermissionMode.values) {
      expect(policyForMode(mode, list), ToolPolicy.allow);
    }
  });

  test('应用列表返回第三方和系统应用，经过只读权限与真实工具落库', () async {
    final h = await ToolLoopHarness.create();
    final driver = h.container.read(channelDriverProvider) as FakeChannelDriver;
    h.onConfirmation = (_) async =>
        throw StateError('list_apps must not request confirmation');
    driver.executeHandler = (request, _) async {
      expect(request.action, ExecutionAction.listApps);
      return ExecutionResult(
        toolCallId: request.toolCallId,
        status: ExecutionStatus.succeeded,
        result: {
          'applications': [
            {
              'packageName': 'third.installed',
              'name': 'Third party',
              'sizeBytes': 123,
              'isSystem': false,
            },
            {
              'packageName': 'com.android.settings',
              'name': 'Settings',
              'isSystem': true,
            },
          ],
          'total': 2,
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
      contains('third.installed'),
    );
    expect(
      (await h.recordsByCall())['apps']!.result,
      contains('com.android.settings'),
    );
    expect(h.provider.requests.first.systemPrompt, contains('list_apps'));
    final prompt = executionScopePrompt(
      const ExecutionScope(),
      applicationOperations: true,
    );
    expect(prompt, contains('list_apps'));
    expect(prompt, isNot(contains('名单')));
  });
}
