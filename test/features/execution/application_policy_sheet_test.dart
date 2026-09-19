import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_list_tile.dart';
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
                    loadApplications: () async => [
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
      expect(tester.widget<AppListTile>(system).selected, isTrue);
      await tester.tap(system);
      await tester.pump();
      expect(tester.widget<AppListTile>(system).selected, isFalse);
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
      expect(tester.widget<AppListTile>(system).selected, isFalse);
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

  for (final size in [
    const Size(320, 800),
    const Size(360, 800),
    const Size(640, 320),
  ]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('应用类型与排序同排，窄屏横屏大字下长选项可选择 $size $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        ApplicationAccessPolicy? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showApplicationPolicySheet(
                      context,
                      loadApplications: () async => [
                        app('third', label: '第三方'),
                      ],
                      initialPolicy: const ApplicationAccessPolicy(
                        blacklist: {'third'},
                      ),
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
        final filter = find.byKey(const ValueKey('application-list-filter'));
        final sort = find.byKey(const ValueKey('application-list-sort'));
        Future<void> choose(Finder field, String option) async {
          tester.state<ScrollableState>(scrolling).position.jumpTo(0);
          await tester.pump();
          await tester.scrollUntilVisible(field, 180, scrollable: scrolling);
          await tester.pumpAndSettle();
          await Scrollable.ensureVisible(tester.element(field), alignment: 0.5);
          await tester.pumpAndSettle();
          final filterRect = tester.getRect(filter);
          final sortRect = tester.getRect(sort);
          expect(filterRect.top, closeTo(sortRect.top, 0.01));
          expect(filterRect.right, lessThan(sortRect.left));
          expect(sortRect.right, lessThanOrEqualTo(size.width));
          await tester.tap(field);
          await tester.pumpAndSettle();
          for (final element in find.byType(MenuItemButton).evaluate()) {
            final rect = tester.getRect(find.byWidget(element.widget));
            expect(rect.width, greaterThanOrEqualTo(240));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
          }
          final item = find.widgetWithText(MenuItemButton, option);
          final itemRect = tester.getRect(item);
          expect(itemRect.width, greaterThanOrEqualTo(240));
          expect(itemRect.left, greaterThanOrEqualTo(0));
          expect(itemRect.right, lessThanOrEqualTo(size.width));
          await tester.ensureVisible(item);
          await tester.pumpAndSettle();
          await tester.tap(item);
          await tester.pumpAndSettle();
          expect(find.byType(MenuItemButton), findsNothing);
          expect(
            find.descendant(of: field, matching: find.text(option)),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }

        await choose(filter, '第三方应用');
        await choose(sort, '安装时间（新到旧）');
        await choose(sort, '安装包大小（大到小）');
        final confirm = find.byKey(
          const ValueKey('confirm-application-policy'),
        );
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(result!.blacklist, {'third'});
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final dark in [false, true]) {
    for (final size in [const Size(320, 800), const Size(640, 320)]) {
      testWidgets('应用列表授权提示在大字窄屏及横屏可读可操作 $dark $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var requests = 0;
        var loads = 0;
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
                  onPressed: () => showApplicationPolicySheet(
                    context,
                    loadApplications: () async {
                      loads++;
                      throw const ApplicationListFailure(
                        ApplicationListFailureCode.permissionRequired,
                      );
                    },
                    openPermissionSettings: () async {
                      requests++;
                    },
                    initialPolicy: const ApplicationAccessPolicy(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final authorize = find.byKey(
          const ValueKey('authorize-application-list'),
        );
        await tester.ensureVisible(authorize);
        await tester.pumpAndSettle();
        await tester.tap(authorize);
        await tester.pumpAndSettle();
        expect(requests, 1);
        final retry = find.text('重试');
        await tester.ensureVisible(retry);
        await tester.pumpAndSettle();
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(loads, 2);
        expect(find.byType(AppListTile), findsNothing);
        expect(find.textContaining('未授权获取应用列表'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('confirm-application-policy')),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('相月显示为普通第三方应用，可加入黑名单和白名单，取消不保存', (tester) async {
    const package = 'app.xiangyue.phase';
    var initial = const ApplicationAccessPolicy();
    ApplicationAccessPolicy? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showApplicationPolicySheet(
                  context,
                  loadApplications: () async => [app(package, label: '相月')],
                  initialPolicy: initial,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    final row = find.byKey(
      const ValueKey('application-policy-app.xiangyue.phase'),
    );
    Future<void> open() async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('application-list-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    await open();
    expect(tester.widget<AppListTile>(row).selected, isFalse);
    await tester.tap(row);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-application-policy')));
    await tester.pumpAndSettle();
    expect(result!.blacklist, {package});
    expect(result!.allows(package, isSystem: false), isFalse);
    expect(initial.blacklist, isEmpty);
    initial = const ApplicationAccessPolicy(mode: AppListMode.whitelist);
    await open();
    expect(tester.widget<AppListTile>(row).selected, isFalse);
    await tester.tap(row);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-application-policy')));
    await tester.pumpAndSettle();
    expect(result!.whitelist, {package});
    expect(result!.allows(package, isSystem: false), isTrue);
    await open();
    await tester.tap(row);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(initial.whitelist, isEmpty);
    expect(tester.takeException(), isNull);
  });

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
      'shell': ToolPolicy.ask,
      'install_packages': ToolPolicy.ask,
      applicationOperationsPolicyKey: ToolPolicy.allow,
    });
    expect(
      registry
          .definitionsFor(policy.enabledTools, policy.overrides)
          .map((tool) => tool.name)
          .toSet(),
      {'shell', 'install_packages', ...applicationOperationTools},
    );
  });

  testWidgets('Expressive 菜单筛选排序真实应用列表，不重载或丢失名单草稿', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var loads = 0;
    ApplicationAccessPolicy? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showApplicationPolicySheet(
                  context,
                  loadApplications: () async {
                    loads++;
                    return [
                      app('a', label: 'Alpha', installed: 10, size: 100),
                      app('b', label: 'Beta', installed: 30, size: 10),
                      app(
                        'c',
                        label: 'Gamma',
                        system: true,
                        installed: 20,
                        size: 50,
                      ),
                    ];
                  },
                  initialPolicy: const ApplicationAccessPolicy(),
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
    List<String?> names() => tester
        .widgetList<AppListTile>(find.byType(AppListTile))
        .map((row) => (row.title as Text).data)
        .toList();
    Future<void> choose(String key, String label) async {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, label));
      await tester.pumpAndSettle();
    }

    expect(names(), ['Alpha', 'Beta', 'Gamma']);
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await choose('application-list-sort', '安装时间（新到旧）');
    expect(names(), ['Beta', 'Gamma', 'Alpha']);
    await choose('application-list-sort', '安装包大小（大到小）');
    expect(names(), ['Alpha', 'Gamma', 'Beta']);
    await choose('application-list-filter', '第三方应用');
    expect(names(), ['Alpha', 'Beta']);
    await tester.enterText(
      find.byKey(const ValueKey('application-list-query')),
      'Beta',
    );
    await tester.pumpAndSettle();
    expect(names(), ['Beta']);
    await tester.tap(find.byKey(const ValueKey('confirm-application-policy')));
    await tester.pumpAndSettle();
    expect(result!.blacklist, {'a'});
    expect(loads, 1);
    expect(tester.takeException(), isNull);
  });
}
