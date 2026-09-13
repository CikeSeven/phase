import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/application_access_policy.dart';
import 'package:phase/data/models/assistant.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/features/assistants/assistant_tool_policy_section.dart';
import 'package:phase/features/execution/application_policy_sheet.dart';
import 'package:phase/features/tools/tool_registry.dart';

import '../../support/fake_channel_driver.dart';
import 'application_access_test.dart' show app;

void main() {
  for (final dark in [false, true]) {
    testWidgets('名单面板保留独立选择、系统放行和取消语义 ${dark ? '深色' : '浅色'}', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ApplicationAccessPolicy? result;
      const initial = ApplicationAccessPolicy();
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showApplicationPolicySheet(
                    context,
                    applications: [
                      app('third', label: '第三方', size: 90),
                      app('system', label: '系统设置', system: true, size: 10),
                    ],
                    initialPolicy: initial,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final scrolling = find
          .descendant(
            of: find.byKey(const ValueKey('application-list-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      Future<void> reveal(Finder finder) async {
        tester.state<ScrollableState>(scrolling).position.jumpTo(0);
        await tester.pump();
        await tester.scrollUntilVisible(finder, 180, scrollable: scrolling);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
      }

      final system = find.byKey(const ValueKey('application-policy-system'));
      final third = find.byKey(const ValueKey('application-policy-third'));
      await reveal(system);
      expect(tester.widget<CheckboxListTile>(system).value, isTrue);
      await tester.tap(system);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(system).value, isFalse);
      await reveal(third);
      await tester.tap(third);
      await tester.pump();
      final mode = find.byKey(const ValueKey('application-list-mode'));
      await reveal(mode);
      await tester.tap(mode);
      await tester.pumpAndSettle();
      await tester.tap(find.text('白名单').last);
      await tester.pumpAndSettle();
      await reveal(system);
      expect(tester.widget<CheckboxListTile>(system).value, isFalse);
      await tester.tap(system);
      await tester.pump();
      final filter = find.byKey(const ValueKey('application-list-filter'));
      await reveal(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('第三方应用').last);
      await tester.pumpAndSettle();
      await reveal(third);
      expect(system, findsNothing);
      final confirm = find.byKey(const ValueKey('confirm-application-policy'));
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result!.mode, AppListMode.whitelist);
      expect(result!.blacklist, {'third'});
      expect(result!.whitelist, {'system'});
      expect(result!.allowedSystemApps, {'system'});
      expect(initial.blacklist, isEmpty);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('助手中应用操作只显示一个策略开关并控制全部应用工具', (tester) async {
    final driver = FakeChannelDriver();
    addTearDown(driver.dispose);
    final registry = buildBuiltInRegistry(
      httpFetch: (_) => throw StateError('unused'),
      platform: () => driver,
    );
    var policy = const ToolPolicyConfig(
      policies: {applicationOperationsPolicyKey: ToolPolicy.ask},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, update) => AssistantToolPolicySection(
                tools: registry.tools.toList(),
                policy: policy,
                onChanged: (value) => update(() => policy = value),
              ),
            ),
          ),
        ),
      ),
    );
    final group = find.byKey(const ValueKey('tool-policy-app_operations'));
    expect(group, findsOneWidget);
    for (final name in applicationOperationTools) {
      expect(find.byKey(ValueKey('tool-policy-$name')), findsNothing);
    }
    await tester.ensureVisible(group);
    await tester.pumpAndSettle();
    await tester.tap(group);
    await tester.pumpAndSettle();
    await tester.tap(find.text('直接执行').last);
    await tester.pumpAndSettle();
    expect(policy.overrides, {
      applicationOperationsPolicyKey: ToolPolicy.allow,
    });
    expect(
      registry
          .definitionsFor(policy.enabledTools, policy.overrides)
          .map((tool) => tool.name)
          .toSet(),
      applicationOperationTools,
    );
  });
}
