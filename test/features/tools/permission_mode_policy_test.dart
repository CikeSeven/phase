import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/memory_entry.dart';
import 'package:phase/data/models/permission_mode.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/tool_permission.dart';
import 'package:phase/data/models/tool_source.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/memory_repository.dart';
import 'package:phase/data/repositories/skill_repository.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/chat/context/read_history_tool.dart';
import 'package:phase/data/repositories/tool_call_repository.dart';
import 'package:phase/features/memory/memory_tools.dart';
import 'package:phase/features/skills/read_skill_tool.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/tools/tool_permission_policy.dart';
import 'package:phase/features/tools/tool_registry.dart';
import 'package:phase/features/workspace/prepare_skill_tool.dart';
import 'package:phase/features/workspace/workspace_files.dart';

import '../../support/fake_channel_driver.dart';
import 'tool_loop_harness.dart';

void main() {
  test('真实内置工具三档矩阵；应用列表只读，命令与安装同组', () {
    final driver = FakeChannelDriver();
    addTearDown(driver.dispose);
    final registry = buildBuiltInRegistry(
      httpFetch: (_) => throw StateError('no network'),
      platform: () => driver,
    );
    const readOnly = {
      'system_info',
      'read_file',
      'list_files',
      'list_apps',
      'grep',
      'find',
    };
    const askInBasic = {
      'write_file',
      'edit_file',
      'shell',
      'install_packages',
      ...applicationOperationTools,
      'http_request',
    };
    for (final tool in registry.tools) {
      expect(
        policyForMode(PermissionMode.plan, tool),
        readOnly.contains(tool.name) ? ToolPolicy.allow : ToolPolicy.deny,
        reason: 'plan ${tool.name}',
      );
      expect(
        policyForMode(PermissionMode.basic, tool),
        askInBasic.contains(tool.name) ? ToolPolicy.ask : ToolPolicy.allow,
        reason: 'basic ${tool.name}',
      );
      expect(
        policyForMode(PermissionMode.fullAccess, tool),
        ToolPolicy.allow,
        reason: 'full ${tool.name}',
      );
    }
    expect(registry.byName('shell')!.policyKey, commandExecutionPolicyKey);
    expect(
      registry.byName('install_packages')!.policyKey,
      commandExecutionPolicyKey,
    );
  });

  test('调用级规则按实际动作匹配，deny/ask/allow 不被全权限越过', () {
    final driver = FakeChannelDriver();
    addTearDown(driver.dispose);
    final registry = buildBuiltInRegistry(
      httpFetch: (_) => throw StateError('no network'),
      platform: () => driver,
    );
    final http = registry.byName('http_request')!;
    final postRule = ToolPermissionRule(
      sourceKind: ToolSourceKind.builtIn,
      sourceId: 'builtIn',
      toolName: 'http_request',
      action: 'POST',
      policy: ToolPolicy.deny,
    );
    const getRule = ToolPermissionRule(
      sourceKind: ToolSourceKind.builtIn,
      sourceId: 'builtIn',
      toolName: 'http_request',
      action: 'GET',
      policy: ToolPolicy.ask,
    );
    final post = evaluateToolPermission(
      mode: PermissionMode.fullAccess,
      tool: http,
      arguments: {'url': 'https://example.com', 'method': 'POST'},
      snapshotPolicy: ToolPolicy.allow,
      rules: [postRule],
    );
    final get = evaluateToolPermission(
      mode: PermissionMode.fullAccess,
      tool: http,
      arguments: {'url': 'https://example.com', 'method': 'GET'},
      snapshotPolicy: ToolPolicy.allow,
      rules: [getRule],
    );
    expect(post.policy, ToolPolicy.deny);
    expect(post.reason, contains('禁止'));
    expect(get.policy, ToolPolicy.ask);
    expect(get.request.action, 'GET');
  });

  test('基础模式对通用 HTTP 默认询问，计划模式仍硬拒绝', () {
    final driver = FakeChannelDriver();
    addTearDown(driver.dispose);
    final registry = buildBuiltInRegistry(
      httpFetch: (_) => throw StateError('no network'),
      platform: () => driver,
    );
    final http = registry.byName('http_request')!;
    final basic = evaluateToolPermission(
      mode: PermissionMode.basic,
      tool: http,
      arguments: {'url': 'https://example.com', 'method': 'GET'},
      snapshotPolicy: ToolPolicy.ask,
    );
    final plan = evaluateToolPermission(
      mode: PermissionMode.plan,
      tool: http,
      arguments: {'url': 'https://example.com', 'method': 'GET'},
      snapshotPolicy: ToolPolicy.deny,
    );
    expect(basic.policy, ToolPolicy.ask);
    expect(basic.request.effects, contains(ToolEffect.networkRequest));
    expect(plan.policy, ToolPolicy.deny);
  });

  test('Skill 复制按文件写入确认；读取与记忆遵循模式，不能遗留助手 ask', () async {
    final h = await ToolLoopHarness.create(registry: ToolRegistry([]));
    final assistants = await h.container.read(
      assistantRepositoryProvider.future,
    );
    final assistant = await assistants.ensureDefault();
    final skills = await h.container.read(skillRepositoryProvider.future);
    final workspaceRepo = await h.container.read(
      workspaceRepositoryProvider.future,
    );
    final workspace = await workspaceRepo.create('fixture');
    final reader = ReadSkillTool(
      skills: const [],
      repository: skills,
      assistants: assistants,
      assistantId: assistant.id,
    );
    final copy = PrepareSkillTool(
      reader,
      await workspaceRepo.snapshot(workspace.id),
      WorkspaceFiles(workspaceRepo),
    );
    final tools = [
      reader,
      copy,
      ReadHistoryTool(
        await h.conversations(),
        await h.container.read(toolCallRepositoryProvider.future),
      ),
      for (final write in [false, true])
        MemoryTool(
          repository: await h.container.read(memoryRepositoryProvider.future),
          assistants: assistants,
          assistantId: assistant.id,
          scope: MemoryScope.assistant,
          sourceMessageId: 'source',
          write: write,
        ),
    ];
    for (final tool in tools) {
      final mutating = tool == copy || (tool is MemoryTool && tool.write);
      expect(
        policyForMode(PermissionMode.plan, tool),
        mutating ? ToolPolicy.deny : ToolPolicy.allow,
      );
      expect(
        policyForMode(PermissionMode.basic, tool),
        mutating ? ToolPolicy.ask : ToolPolicy.allow,
      );
      expect(policyForMode(PermissionMode.fullAccess, tool), ToolPolicy.allow);
    }
  });
}
