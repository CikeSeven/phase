import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/assistant.dart';
import 'package:phase/data/models/mcp_server_profile.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/mcp_server_repository.dart';
import 'package:phase/features/mcp/assistant_mcp_section.dart';
import 'package:phase/features/mcp/mcp_edit_page.dart';
import 'package:phase/features/mcp/mcp_servers_page.dart';

import '../tools/tool_loop_harness.dart';
import 'mcp_memory_transport.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(640, 360)]) {
    testWidgets('MCP 表单 $size / 2x 字号，取消不保存，提交后可编辑', (tester) async {
      late ToolLoopHarness h;
      await tester.runAsync(() async {
        h = await ToolLoopHarness.create();
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/mcp',
        routes: [
          GoRoute(
            path: '/mcp',
            pageBuilder: (context, state) =>
                MaterialPage(key: state.pageKey, child: const McpServersPage()),
          ),
          GoRoute(
            path: '/new',
            pageBuilder: (context, state) =>
                MaterialPage(key: state.pageKey, child: const McpEditPage()),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/new');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('mcp-name')), '草稿');
      router.pop();
      await tester.pumpAndSettle();
      final repository = await h.container.read(
        mcpServerRepositoryProvider.future,
      );
      expect(await repository.list(), isEmpty);
      router.push('/new');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('mcp-name')), '样本服务');
      await tester.ensureVisible(find.byKey(const ValueKey('mcp-endpoint')));
      await tester.enterText(
        find.byKey(const ValueKey('mcp-endpoint')),
        'https://mcp.test/mcp',
      );
      await tester.tap(find.byKey(const ValueKey('mcp-save')));
      await tester.pumpAndSettle();
      expect((await repository.list()).single.profile.name, '样本服务');
      expect(find.text('样本服务'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('第三方工具默认关闭，启用默认询问，编辑草稿不提前保存', (tester) async {
    late ToolLoopHarness h;
    await tester.runAsync(() async {
      h = await ToolLoopHarness.create();
    });
    final repository = await h.container.read(
      mcpServerRepositoryProvider.future,
    );
    final fixture = McpMemoryTransport();
    final profile = await repository.save(fixture.profile());
    final tool = mcpToolSnapshot(profile, fixture.tool());
    await repository.saveCatalog(profile, [tool], '2025-06-18');
    var policy = const ToolPolicyConfig();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: AssistantMcpSection(
                  policy: policy,
                  onChanged: (value) => setState(() => policy = value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(ValueKey('mcp-enable-${tool.name}')),
          )
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(ValueKey('mcp-enable-${tool.name}')));
    await tester.pumpAndSettle();
    expect(policy.policies[tool.name], ToolPolicy.ask);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
