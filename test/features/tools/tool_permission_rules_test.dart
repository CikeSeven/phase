import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/command_channel.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/permission_mode.dart';
import 'package:phase/data/models/tool_permission.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/tool_source.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/features/execution/shizuku_display_tool.dart';
import 'package:phase/features/mcp/mcp_tool.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/tools/tool_permission_policy.dart';
import 'package:phase/features/tools/tool_registry.dart';

import '../../support/fake_channel_driver.dart';
import 'tool_loop_harness.dart';

void main() {
  late FakeChannelDriver driver;
  late ToolRegistry registry;
  setUp(() {
    driver = FakeChannelDriver();
    registry = buildBuiltInRegistry(
      platform: () => driver,
      httpFetch: (_) => throw StateError('Unexpected network access'),
    );
  });
  tearDown(() => driver.dispose());

  ToolPermissionRule rule(String name, ToolPolicy policy, {String? action}) =>
      ToolPermissionRule(
        sourceKind: ToolSourceKind.builtIn,
        sourceId: 'builtIn',
        toolName: name,
        action: action,
        policy: policy,
      );

  ToolPermissionDecision evaluate(
    String name, {
    PermissionMode mode = PermissionMode.basic,
    Map<String, dynamic> args = const {},
    List<ToolPermissionRule> rules = const [],
    ToolPolicy? snapshot,
  }) => evaluateToolPermission(
    mode: mode,
    tool: registry.byName(name)!,
    arguments: args,
    snapshotPolicy: snapshot ?? policyForMode(mode, registry.byName(name)!),
    rules: rules,
  );

  test('HTTP 方法省略和小写归一化，GET 不自动获得只读许可', () {
    expect(evaluate('http_request').request.action, 'GET');
    expect(evaluate('http_request').policy, ToolPolicy.ask);
    final allow = rule('http_request', ToolPolicy.allow, action: 'GET');
    for (final args in [
      <String, dynamic>{},
      {'method': 'get'},
    ]) {
      final result = evaluate('http_request', args: args, rules: [allow]);
      expect(result.policy, ToolPolicy.allow);
      expect(result.ruleKey, allow.key);
      expect(result.canApproveForRun, isFalse);
    }
    expect(
      evaluate('http_request', args: {'method': 'POST'}, rules: [allow]).policy,
      ToolPolicy.ask,
    );
    expect(
      evaluate('http_request', args: {'method': 42}, rules: [allow]).policy,
      ToolPolicy.ask,
    );
  });

  for (final mode in PermissionMode.values) {
    test('${mode.name} 显式拒绝优先，匹配顺序不改变限制', () {
      final allow = rule('read_file', ToolPolicy.allow, action: 'read_file');
      final ask = rule('read_file', ToolPolicy.ask);
      final deny = rule('read_file', ToolPolicy.deny);
      for (final rules in [
        [allow, ask, deny],
        [deny, ask, allow],
        [ask, allow, deny],
      ]) {
        expect(
          evaluate('read_file', mode: mode, rules: rules).policy,
          ToolPolicy.deny,
        );
      }
      expect(
        evaluate('read_file', mode: mode, rules: [allow, ask]).policy,
        ToolPolicy.ask,
      );
    });
  }

  test('计划限制、工具范围和宿主 deny 不被显式 allow 放宽', () {
    final allow = rule('shell', ToolPolicy.allow);
    expect(
      evaluate('shell', mode: PermissionMode.plan, rules: [allow]).policy,
      ToolPolicy.deny,
    );
    expect(
      evaluate('shell', rules: [allow], snapshot: ToolPolicy.deny).policy,
      ToolPolicy.deny,
    );
    final forbidden = RecordingTool(name: 'custom', policy: ToolPolicy.deny);
    expect(
      evaluateToolPermission(
        mode: PermissionMode.fullAccess,
        tool: forbidden,
        arguments: const {},
        snapshotPolicy: ToolPolicy.allow,
        rules: [rule('custom', ToolPolicy.allow)],
      ).policy,
      ToolPolicy.deny,
    );
  });

  test('假冒已知名称的未知实现按 unknown/ask，不用名称判只读', () {
    final unknown = RecordingTool(name: 'read_file');
    final result = evaluateToolPermission(
      mode: PermissionMode.basic,
      tool: unknown,
      arguments: const {},
      snapshotPolicy: ToolPolicy.allow,
    );
    expect(result.policy, ToolPolicy.ask);
    expect(result.request.effects, {ToolEffect.unknown});
    expect(policyForMode(PermissionMode.plan, unknown), ToolPolicy.deny);
  });

  test('文件、命令和设备工具按宿主实现描述效果，只有应用类别可批准本轮', () {
    expect(evaluate('read_file').request.effects, {ToolEffect.fileRead});
    expect(evaluate('write_file').request.effects, {ToolEffect.fileWrite});
    expect(evaluate('shell').request.effects, {ToolEffect.codeExecution});
    expect(evaluate('shell').canApproveForRun, isFalse);
    expect(evaluate('capture_screen').request.effects, {
      ToolEffect.deviceObservation,
    });
    expect(evaluate('click_node').request.effects, {
      ToolEffect.deviceInteraction,
    });
    expect(evaluate('open_app').canApproveForRun, isTrue);
    expect(
      evaluate(
        'open_app',
        rules: [rule('open_app', ToolPolicy.ask)],
      ).canApproveForRun,
      isFalse,
    );
    expect(
      evaluate(
        'open_app',
        mode: PermissionMode.fullAccess,
        rules: [rule('open_app', ToolPolicy.ask)],
      ).policy,
      ToolPolicy.ask,
    );
  });

  test('虚拟屏 capture/tap 使用各自实际 action 匹配规则', () {
    final tool = ShizukuDisplayTool(
      const CommandChannelSnapshot(
        channel: ExecutionChannel.shizuku,
        uid: 2000,
        revision: 'fixture',
      ),
      () => driver,
    );
    final captureRule = rule(tool.name, ToolPolicy.allow, action: 'capture');
    ToolPermissionDecision call(String action) => evaluateToolPermission(
      mode: PermissionMode.basic,
      tool: tool,
      arguments: {'action': action},
      snapshotPolicy: ToolPolicy.ask,
      rules: [captureRule],
    );
    expect(call('capture').policy, ToolPolicy.allow);
    expect(call('capture').request.effects, {ToolEffect.deviceObservation});
    expect(call('tap').policy, ToolPolicy.ask);
    expect(call('tap').request.effects, {ToolEffect.deviceInteraction});
  });

  test('MCP readOnly 标记不授予权限，规则精确绑定来源而不是模型工具名', () {
    const source = ToolSource(
      kind: ToolSourceKind.mcp,
      id: 'server-a',
      originalName: 'read_data',
      definitionRevision: 'revision-a',
      effectClass: ToolEffectClass.readOnly,
    );
    final tool = McpTool(
      definition: ToolSnapshot(
        name: 'mcp_renamed',
        description: 'Read',
        inputSchema: const {},
        source: source,
      ),
      serverName: 'Fixture',
    );
    final allow = ToolPermissionRule(
      sourceKind: source.kind,
      sourceId: source.id,
      toolName: source.originalName,
      definitionRevision: source.definitionRevision,
      policy: ToolPolicy.allow,
    );
    ToolPermissionDecision call(List<ToolPermissionRule> rules) =>
        evaluateToolPermission(
          mode: PermissionMode.basic,
          tool: tool,
          arguments: const {},
          snapshotPolicy: ToolPolicy.allow,
          rules: rules,
        );
    expect(call([]).policy, ToolPolicy.ask);
    expect(call([]).request.effects, {ToolEffect.unknown});
    expect(call([allow]).policy, ToolPolicy.allow);
    for (final field in [
      'sourceKind',
      'sourceId',
      'toolName',
      'definitionRevision',
    ]) {
      final json = allow.toJson();
      json[field] = field == 'sourceKind' ? 'builtIn' : 'different';
      expect(
        call([ToolPermissionRule.fromJson(json)]).policy,
        ToolPolicy.ask,
        reason: field,
      );
    }
    final changed = {...allow.toJson(), 'definitionRevision': 'different'};
    for (final policy in [ToolPolicy.ask, ToolPolicy.deny]) {
      changed['policy'] = policy.name;
      expect(call([ToolPermissionRule.fromJson(changed)]).policy, policy);
    }
  });

  test('规则和判定 JSON 往返，规则 key 不随策略/修订变化', () {
    final target = rule('http_request', ToolPolicy.ask, action: 'DELETE');
    final restored = ToolPermissionRule.fromJson(target.toJson());
    expect(restored.toJson(), target.toJson());
    expect(restored.withPolicy(ToolPolicy.deny).key, target.key);
    final decision = evaluate(
      'http_request',
      args: {'method': 'DELETE'},
      rules: [target],
    );
    expect(
      ToolPermissionDecision.fromJson(decision.toJson()).toJson(),
      decision.toJson(),
    );
    expect(
      () => decision.request.effects.add(ToolEffect.fileWrite),
      throwsUnsupportedError,
    );
    for (final json in [
      {...target.toJson(), 'policy': 'invalid'},
      {...target.toJson(), 'toolName': ''},
      {...target.toJson(), 'sourceId': ''},
      {...target.toJson(), 'action': ''},
      {...target.toJson(), 'definitionRevision': ''},
    ]) {
      expect(() => ToolPermissionRule.fromJson(json), throwsA(anything));
    }
  });

  test('运行 JSON 保存规则，旧快照缺少 permissionRules 仍可读取', () {
    final config = RunConfiguration(
      connection: const RunConnection(
        profileId: 'p',
        protocol: 'openaiCompletions',
        baseUrl: 'https://example.com',
        requiresKey: false,
      ),
      modelSelection: const ModelSelection(profileId: 'p', modelId: 'm'),
      systemPrompt: '',
      permissionRules: [
        rule('http_request', ToolPolicy.deny, action: 'DELETE'),
      ],
    );
    expect(
      RunConfiguration.fromJson(config.toJson()).permissionRules.single
          .toJson(),
      config.permissionRules.single.toJson(),
    );
    final legacy = config.toJson()..remove('permissionRules');
    expect(RunConfiguration.fromJson(legacy).permissionRules, isEmpty);
  });
}
