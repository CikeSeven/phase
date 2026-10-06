import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/command_channel.dart';
import 'package:phase/data/models/permission_mode.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_permission.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/platform_tools.dart';
import 'package:phase/features/execution/shizuku_display_tool.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/tools/tool_permission_grants.dart';
import 'package:phase/features/tools/tool_permission_policy.dart';
import 'package:phase/features/tools/tool_registry.dart';

import '../../support/fake_channel_driver.dart';

void main() {
  late FakeChannelDriver driver;
  late ToolRegistry registry;
  late ToolPermissionGrants grants;
  late RunCancellation cancellation;
  setUp(() {
    driver = FakeChannelDriver();
    registry = buildBuiltInRegistry(
      platform: () => driver,
      httpFetch: (_) => throw StateError('Unexpected network'),
    );
    grants = ToolPermissionGrants();
    cancellation = RunCancellation();
    grants.bind('run', cancellation);
  });
  tearDown(() => driver.dispose());

  ToolCallRecord record(
    Tool tool, {
    String id = 'call',
    String runId = 'run',
    Map<String, dynamic>? arguments,
  }) => ToolCallRecord(
    id: id,
    runId: runId,
    assistantMessageId: 'message',
    toolName: tool.name,
    arguments: arguments ?? {'packageName': 'fixture.app'},
    channel: tool.channel,
    source: tool.source,
    defaultPolicy: tool.defaultPolicy,
    createdAt: DateTime(2026),
  );
  ToolPermissionDecision decision(Tool tool, {String? ruleKey}) =>
      ToolPermissionDecision(
        policy: ToolPolicy.ask,
        request: permissionRequestFor(tool, const {}),
        reason: 'fixture',
        ruleKey: ruleKey,
      );
  PermissionGrant issue(
    Tool tool, {
    PermissionGrantScope scope = PermissionGrantScope.run,
  }) => grants.issue(
    record: record(tool),
    tool: tool,
    decision: decision(tool),
    scope: scope,
    rulesRevision: 'rules',
    registry: registry,
    enabledTools: registry.tools.map((tool) => tool.name).toSet(),
  );
  bool covers(
    PermissionGrant grant,
    Tool tool, {
    ToolCallRecord? call,
    ToolPermissionDecision? permission,
    String revision = 'rules',
  }) => grants.covers(
    grant,
    record: call ?? record(tool),
    tool: tool,
    decision: permission ?? decision(tool),
    rulesRevision: revision,
  );

  test('一次授权精确绑定调用、参数、来源、定义和通道', () {
    final tool = registry.byName('open_app')!;
    final grant = issue(tool, scope: PermissionGrantScope.once);
    expect(covers(grant, tool), isTrue);
    expect(covers(grant, tool, call: record(tool, id: 'another')), isFalse);
    expect(covers(grant, tool, call: record(tool, runId: 'another')), isFalse);
    expect(
      covers(
        grant,
        tool,
        call: record(tool, arguments: {'packageName': 'other.app'}),
      ),
      isFalse,
    );
    final revised = _RevisedAppTool(driver);
    expect(covers(grant, revised), isFalse);
    expect(covers(grant, registry.byName('inspect_ui')!), isFalse);
    expect(covers(grant, tool, revision: 'changed'), isFalse);
    expect(
      grants.find(
        record: record(tool),
        tool: tool,
        decision: decision(tool),
        rulesRevision: 'rules',
      ),
      isNull,
    );
  });

  test('本轮授权覆盖已启用应用类别但不覆盖文件、命令或强制确认', () {
    final app = registry.byName('open_app')!;
    final grant = issue(app);
    for (final name in [
      'open_app',
      'inspect_ui',
      'click_node',
      'scroll',
      'input_text',
      'capture_screen',
      'perform_gestures',
    ]) {
      final tool = registry.byName(name)!;
      expect(
        covers(grant, tool, call: record(tool, id: name)),
        isTrue,
        reason: name,
      );
    }
    for (final name in ['write_file', 'shell', 'list_apps']) {
      expect(covers(grant, registry.byName(name)!), isFalse, reason: name);
    }
    expect(
      covers(grant, app, permission: decision(app, ruleKey: 'explicit-ask')),
      isFalse,
    );
    expect(() => grant.definitionRevisions.clear(), throwsUnsupportedError);
  });

  test('批准后才出现或未启用的工具不进入授权范围', () {
    final app = registry.byName('open_app')!;
    final grant = grants.issue(
      record: record(app),
      tool: app,
      decision: decision(app),
      scope: PermissionGrantScope.run,
      rulesRevision: 'rules',
      registry: registry,
      enabledTools: {'open_app'},
    );
    expect(covers(grant, app), isTrue);
    expect(covers(grant, registry.byName('inspect_ui')!), isFalse);
    final lateTool = ShizukuDisplayTool(
      const CommandChannelSnapshot(
        channel: ExecutionChannel.shizuku,
        uid: 2000,
        revision: 'new',
      ),
      () => driver,
    );
    expect(covers(grant, lateTool), isFalse);
  });

  test('取消和新驱动撤销授权，不能通过保存的 grant 对象恢复', () async {
    final app = registry.byName('open_app')!;
    final grant = issue(app);
    cancellation.cancel();
    expect(covers(grant, app), isFalse);
    await Future<void>.value();
    grants.bind('run', RunCancellation());
    expect(
      grants.find(
        record: record(app),
        tool: app,
        decision: decision(app),
        rulesRevision: 'rules',
      ),
      isNull,
    );
    expect(covers(grant, app), isFalse);
  });

  test('主动撤权和清理驱动不能恢复已有授权', () {
    final app = registry.byName('open_app')!;
    final grant = issue(app);
    grants.clear();
    grants.bind('run', cancellation);
    expect(covers(grant, app), isFalse);
  });

  test('规则修订变化丢弃本轮授权，恢复旧内容也不重新授予', () {
    final app = registry.byName('open_app')!;
    final grant = issue(app);
    expect(
      grants.find(
        record: record(app),
        tool: app,
        decision: decision(app),
        rulesRevision: 'changed',
      ),
      isNull,
    );
    expect(covers(grant, app), isFalse);
    expect(
      grants.find(
        record: record(app),
        tool: app,
        decision: decision(app),
        rulesRevision: 'rules',
      ),
      isNull,
    );
  });

  test('授权审计 JSON 保存来源但不会反序列化为可执行 grant', () {
    final app = registry.byName('open_app')!;
    final permission = decision(app).withGrant(issue(app));
    final restored = ToolPermissionDecision.fromJson(permission.toJson());
    expect(restored.grantScope, PermissionGrantScope.run);
    expect(restored.grantSourceCallId, 'call');
    expect(restored.toJson(), permission.toJson());
    expect(
      evaluateToolPermission(
        mode: PermissionMode.basic,
        tool: app,
        arguments: const {},
        snapshotPolicy: ToolPolicy.ask,
      ).policy,
      ToolPolicy.ask,
    );
  });
}

class _RevisedAppTool extends ApplicationTool {
  _RevisedAppTool(FakeChannelDriver driver)
    : super(ExecutionAction.openApp, () => driver);
  @override
  String get description => '${super.description} revised';
}
