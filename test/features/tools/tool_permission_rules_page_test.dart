import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_dialog.dart';
import 'package:phase/core/widgets/app_dropdown.dart';
import 'package:phase/core/widgets/app_menu_anchor.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/mcp_server_profile.dart';
import 'package:phase/data/models/tool_permission.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/tool_source.dart';
import 'package:phase/data/repositories/mcp_server_repository.dart';
import 'package:phase/features/tools/tool_permission_rules_controller.dart';
import 'package:phase/features/tools/tool_permission_rules_page.dart';
import 'package:riverpod_annotation/experimental/scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

@Dependencies([ToolPermissionRulesController])
void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    List<ToolPermissionRule> rules = const [],
    List<McpServerEntry> servers = const [],
    ThemeData? theme,
    double scale = 1,
    String? payload,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'tool_permission_rules_v1':
          payload ?? jsonEncode(rules.map((rule) => rule.toJson()).toList()),
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        mcpServersProvider.overrideWith((_) => Stream.value(servers)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: const ToolPermissionRulesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is AppDropdown && widget.label == label,
  );
  Future<void> choose(WidgetTester tester, String label, String choice) async {
    final finder = field(label);
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppMenuItemButton, choice));
    await tester.pumpAndSettle();
  }

  testWidgets('规则可设置、覆盖和恢复模式默认，HTTP 方法独立保存', (tester) async {
    final container = await pump(tester);
    await choose(tester, 'HTTP · POST', '禁止执行');
    final saved = container
        .read(settingsStorageProvider)
        .readToolPermissionRules()
        .single;
    expect(saved.action, 'POST');
    expect(saved.policy, ToolPolicy.deny);
    expect(saved.sourceKind, ToolSourceKind.builtIn);
    await tester.scrollUntilVisible(
      field('HTTP · GET'),
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<AppDropdown>(field('HTTP · GET')).options.values,
      contains('跟随模式'),
    );
    await choose(tester, 'HTTP · POST', '每次确认');
    expect(
      container
          .read(settingsStorageProvider)
          .readToolPermissionRules()
          .single
          .policy,
      ToolPolicy.ask,
    );
    await choose(tester, 'HTTP · POST', '跟随模式');
    expect(
      container.read(settingsStorageProvider).readToolPermissionRules(),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shell 直接允许需明确确认范围，取消不保存，确认才提交', (tester) async {
    final container = await pump(tester);
    await choose(tester, '执行命令', '直接允许');
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.textContaining('此规则不限制文件、网络或子进程访问'), findsOneWidget);
    expect(
      container.read(settingsStorageProvider).readToolPermissionRules(),
      isEmpty,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      container.read(settingsStorageProvider).readToolPermissionRules(),
      isEmpty,
    );
    await choose(tester, '执行命令', '直接允许');
    await tester.tap(find.widgetWithText(FilledButton, '直接允许'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(settingsStorageProvider)
          .readToolPermissionRules()
          .single
          .policy,
      ToolPolicy.allow,
    );
  });

  testWidgets('MCP 允许规则绑定当前修订，旧允许规则失效可重新授权', (tester) async {
    final profile = McpServerProfile(
      id: 'server',
      name: 'Fixture',
      endpoint: 'https://example.com/mcp',
      definitionRevision: 'connection',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final tool = mcpToolSnapshot(profile, {
      'name': 'read_sample',
      'description': 'Read',
      'inputSchema': {'type': 'object'},
    });
    final old = ToolPermissionRule(
      sourceKind: ToolSourceKind.mcp,
      sourceId: profile.id,
      toolName: tool.source.originalName,
      definitionRevision: 'old',
      policy: ToolPolicy.allow,
    );
    final container = await pump(
      tester,
      rules: [old],
      servers: [
        McpServerEntry(profile: profile, tools: [tool]),
      ],
    );
    await choose(tester, 'Fixture · read_sample', '直接允许');
    expect(find.textContaining('此版本 MCP 工具的所有参数调用'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '直接允许'));
    await tester.pumpAndSettle();
    final saved = container
        .read(settingsStorageProvider)
        .readToolPermissionRules()
        .single;
    expect(saved.definitionRevision, tool.source.definitionRevision);
    expect(saved.sourceId, profile.id);
    expect(saved.toolName, tool.source.originalName);
    expect(find.text('工具定义已更新，旧允许规则不再生效'), findsNothing);
  });

  testWidgets('非法配置显示读取失败，不提供默认允许，可重试', (tester) async {
    final container = await pump(tester, payload: '{broken');
    expect(find.text('无法读取工具规则'), findsOneWidget);
    expect(
      container.read(toolPermissionRulesControllerProvider).error,
      isNotNull,
    );
    expect(find.byType(AppDropdown), findsNothing);
    await container
        .read(sharedPreferencesProvider)
        .setString('tool_permission_rules_v1', '[]');
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('无法读取工具规则'), findsNothing);
    expect(field('时间与时区'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('窄屏和大字号 $dark 可滚动，无规则字段溢出', (tester) async {
      await pump(
        tester,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        scale: 1.8,
      );
      await choose(tester, 'HTTP · DELETE', '禁止执行');
      expect(tester.takeException(), isNull);
      await choose(tester, '虚拟屏 · 关闭虚拟屏', '每次确认');
      expect(tester.takeException(), isNull);
    });
  }
}
