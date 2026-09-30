import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/theme/brand_colors.dart';
import 'package:phase/core/widgets/app_list_tile.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/execution_scope.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/execution_settings_page.dart';
import 'package:phase/features/execution/execution_setup_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_channel_driver.dart';

class _Driver extends FakeChannelDriver {
  int capabilityLoads = 0;
  Future<ExecutionCapabilities> Function()? capabilitiesHandler;

  @override
  Future<ExecutionCapabilities> queryCapabilities() async {
    capabilityLoads++;
    return await (capabilitiesHandler?.call() ?? super.queryCapabilities());
  }
}

class _SetupApi extends ExecutionSetupApi {
  int fileLoads = 0;
  int appLoads = 0;
  Future<void> Function()? permissionSettingsHandler;
  FileGrant? selected;
  final released = <String>[];
  final opened = <PermissionScreen>[];
  @override
  Future<List<FileGrant>> fileGrants() async {
    fileLoads++;
    return released.isNotEmpty
        ? []
        : [
            FileGrant(
              uri: 'content://fixture/root',
              name: '测试目录',
              directory: true,
              writable: true,
            ),
          ];
  }

  @override
  Future<List<InstalledApplication>> installedApplications() async {
    appLoads++;
    return [];
  }

  @override
  Future<FileGrant?> selectFile(bool directory) async => selected;
  @override
  Future<void> releaseFileGrant(String uri) async => released.add(uri);
  @override
  Future<void> openPermissionSettings(PermissionScreen screen) async {
    opened.add(screen);
    await permissionSettingsHandler?.call();
  }
}

void main() {
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<
    ({
      ProviderContainer container,
      SettingsStorage settings,
      _SetupApi api,
      _Driver driver,
    })
  >
  pump(
    WidgetTester tester, {
    _SetupApi? api,
    _Driver? driver,
    bool settle = true,
    bool largeText = true,
    bool dark = true,
    ExecutionScope scope = const ExecutionScope(),
  }) async {
    tester.view.physicalSize = largeText
        ? const Size(320, 800)
        : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStorage(prefs);
    await settings.writeExecutionScope(scope);
    api ??= _SetupApi();
    driver ??= _Driver();
    final setup = api;
    final channel = driver;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((_) => prefs),
        settingsStorageProvider.overrideWith((_) => settings),
        executionSetupApiProvider.overrideWith((_) => setup),
        channelDriverProvider.overrideWith((_) => channel),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await channel.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ExecutionSettingsPage(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }
    return (
      container: container,
      settings: settings,
      api: setup,
      driver: channel,
    );
  }

  for (final dark in [false, true]) {
    for (final largeText in [false, true]) {
      testWidgets('权限用图标和色面显示授权状态，返回系统设置后刷新 $dark $largeText', (tester) async {
        var notificationsAllowed = true;
        final driver = _Driver()
          ..capabilitiesHandler = () async => ExecutionCapabilities(
            actions: [],
            notificationsAllowed: notificationsAllowed,
            activityResumed: true,
            accessibilityConnected: !notificationsAllowed,
          );
        final h = await pump(
          tester,
          driver: driver,
          dark: dark,
          largeText: largeText,
        );
        final theme = dark ? AppTheme.dark() : AppTheme.light();
        final brand = theme.extension<BrandColors>()!;
        void expectStatus(String key, bool granted) {
          final status = find.byKey(ValueKey(key));
          expect(
            find.descendant(
              of: status,
              matching: find.text(granted ? '已授权' : '未授权'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: status,
              matching: find.byIcon(
                granted ? Symbols.check_circle : Symbols.error,
              ),
            ),
            findsOneWidget,
          );
          final background = tester.widget<DecoratedBox>(
            find.descendant(of: status, matching: find.byType(DecoratedBox)),
          );
          expect(
            (background.decoration as BoxDecoration).color,
            granted ? brand.tealContainer : theme.colorScheme.errorContainer,
          );
          expect(
            tester.widget<Semantics>(status).properties.liveRegion,
            isTrue,
          );
        }

        expectStatus('notifications-permission-status', true);
        expectStatus('accessibility-permission-status', false);
        expect(find.text('截图观察'), findsNothing);
        expect(find.textContaining('模型支持图片'), findsNothing);
        expect(find.textContaining('授权文件与目录'), findsNothing);
        expect(find.text('选择文件'), findsNothing);
        expect(find.text('选择目录'), findsNothing);
        expect(find.text('应用名单'), findsNothing);
        expect(find.text('黑名单'), findsNothing);
        expect(find.text('白名单'), findsNothing);
        expect(
          find.byKey(const ValueKey('edit-application-policy')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('save-execution-scope')),
          findsNothing,
        );
        expect(find.text('保存执行设置'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is AppListTile && widget.selected != null,
          ),
          findsNothing,
        );
        expect(h.api.fileLoads, 0);
        expect(h.api.appLoads, 0);
        await tester.tap(find.text('任务通知'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('无障碍服务'));
        await tester.pumpAndSettle();
        expect(h.api.opened, [
          PermissionScreen.notifications,
          PermissionScreen.accessibility,
        ]);
        notificationsAllowed = false;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expectStatus('notifications-permission-status', false);
        expectStatus('accessibility-permission-status', true);
        expect(driver.capabilityLoads, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('权限读取缓慢不伪装未授权，不阻塞系统权限入口或返回，也不预取应用清单', (tester) async {
    final capabilities = Completer<ExecutionCapabilities>();
    const scope = ExecutionScope(fileUris: ['content://fixture/saved']);
    final h = await pump(
      tester,
      driver: _Driver()..capabilitiesHandler = () => capabilities.future,
      largeText: false,
      scope: scope,
      settle: false,
    );
    expect(find.text('读取中…'), findsNWidgets(2));
    expect(find.text('未授权'), findsNothing);
    expect(h.api.fileLoads, 0);
    expect(h.api.appLoads, 0);
    await tester.tap(find.text('任务通知'));
    await tester.pump();
    expect(h.api.opened, [PermissionScreen.notifications]);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    capabilities.complete(
      ExecutionCapabilities(
        actions: [],
        notificationsAllowed: true,
        activityResumed: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().toJson(), scope.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('权限读取失败不伪装未授权，重试只刷新权限且不改变文件授权', (tester) async {
    final capabilities = Completer<ExecutionCapabilities>();
    final driver = _Driver()..capabilitiesHandler = () => capabilities.future;
    final h = await pump(
      tester,
      driver: driver,
      largeText: false,
      settle: false,
    );
    capabilities.completeError(
      const ExecutionFailure(ExecutionFailureCode.timeout),
    );
    await tester.pumpAndSettle();
    expect(find.text('读取失败'), findsNWidgets(2));
    expect(find.text('未授权'), findsNothing);
    expect(find.byKey(const ValueKey('capabilities-error')), findsOneWidget);
    driver.capabilitiesHandler = null;
    await reveal(tester, find.text('重试'));
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(driver.capabilityLoads, 2);
    expect(h.api.fileLoads, 0);
    expect(h.api.appLoads, 0);
    expect(find.text('已授权'), findsOneWidget);
    expect(find.text('未授权'), findsOneWidget);
    expect(
      h.settings.readExecutionScope().toJson(),
      const ExecutionScope().toJson(),
    );
  });

  testWidgets('权限加载去重，前后台往返不查询应用清单或改变已有文件范围', (tester) async {
    final capabilities = Completer<ExecutionCapabilities>();
    final driver = _Driver()..capabilitiesHandler = () => capabilities.future;
    const scope = ExecutionScope(fileUris: ['content://fixture/saved']);
    final h = await pump(
      tester,
      driver: driver,
      largeText: false,
      scope: scope,
      settle: false,
    );
    final controller = h.container.read(
      executionSetupControllerProvider.notifier,
    );
    final refreshes = [controller.load(), controller.load()];
    expect(driver.capabilityLoads, 1);
    capabilities.complete(
      ExecutionCapabilities(
        actions: [ExecutionAction.captureScreen],
        notificationsAllowed: true,
        activityResumed: true,
        accessibilityConnected: true,
      ),
    );
    await Future.wait(refreshes);
    await tester.pumpAndSettle();
    expect(find.text('已授权'), findsNWidgets(2));
    expect(find.text('截图观察'), findsNothing);
    driver.capabilitiesHandler = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(h.api.fileLoads, 0);
    expect(driver.capabilityLoads, 2);
    expect(h.api.appLoads, 0);
    expect(h.settings.readExecutionScope().toJson(), scope.toJson());

    expect(h.settings.readExecutionScope().fileUris, scope.fileUris);
  });

  testWidgets('系统权限设置失败显示安全错误，重试不改变文件授权', (tester) async {
    const scope = ExecutionScope(fileUris: ['content://fixture/saved']);
    final api = _SetupApi()
      ..permissionSettingsHandler = () async => throw PlatformException(
        code: 'unavailable',
        message: 'private platform details',
      );
    final h = await pump(tester, api: api, scope: scope, largeText: false);
    await tester.tap(find.text('无障碍服务'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        const ExecutionFailure(ExecutionFailureCode.unavailable).userMessage,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('private platform details'), findsNothing);
    api.permissionSettingsHandler = null;
    await tester.tap(find.text('任务通知'));
    await tester.pumpAndSettle();
    expect(api.opened, [
      PermissionScreen.accessibility,
      PermissionScreen.notifications,
    ]);
    expect(h.settings.readExecutionScope().toJson(), scope.toJson());
    expect(api.appLoads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('移除页面入口不改变底层文件授权的选择、解除与独立刷新', (tester) async {
    final grant = FileGrant(
      uri: 'content://fixture/root',
      name: '测试目录',
      directory: true,
      writable: true,
    );
    final api = _SetupApi()..selected = grant;
    final h = await pump(tester, api: api, largeText: false);
    final controller = h.container.read(
      executionSetupControllerProvider.notifier,
    );
    expect(await controller.chooseFile(true), grant);
    await tester.pumpAndSettle();
    expect(api.fileLoads, 1);
    expect(h.driver.capabilityLoads, 1);
    expect(api.appLoads, 0);
    await controller.release(grant.uri);
    await tester.pumpAndSettle();
    expect(api.released, [grant.uri]);
    expect(api.fileLoads, 2);
    expect(h.driver.capabilityLoads, 1);
    expect(h.settings.readExecutionScope().fileUris, isEmpty);
    expect(find.text('测试目录'), findsNothing);
  });

  testWidgets('页面销毁后权限迟到结果安全收尾', (tester) async {
    final capabilities = Completer<ExecutionCapabilities>();
    final h = await pump(
      tester,
      driver: _Driver()..capabilitiesHandler = () => capabilities.future,
      settle: false,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    h.container.dispose();
    capabilities.completeError(
      const ExecutionFailure(ExecutionFailureCode.unavailable),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
