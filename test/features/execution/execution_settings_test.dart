import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:phase/core/theme/brand_colors.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/application_access_policy.dart';
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
  bool emptyPlatformList = false;
  int fileLoads = 0;
  int appLoads = 0;
  Future<List<InstalledApplication>> Function()? applicationsHandler;
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
    if (applicationsHandler != null) return await applicationsHandler!();
    if (emptyPlatformList) {
      throw PlatformException(code: 'applicationListUnavailable');
    }
    return [
      InstalledApplication(
        packageName: 'fixture.new',
        label: '测试新 App',
        isSystem: false,
        installedAtMs: 1,
        launchable: true,
      ),
    ];
  }

  @override
  Future<void> updateApplicationPolicy(ApplicationPolicy policy) async {}
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

class _Settings extends SettingsStorage {
  _Settings(super.prefs);
  bool failSave = false;
  @override
  Future<void> writeExecutionScope(ExecutionScope scope) async {
    if (failSave) throw const OperationFailure('保存失败，可重试');
    await super.writeExecutionScope(scope);
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
      _Settings settings,
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
    final settings = _Settings(prefs);
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

  Future<void> editPolicy(WidgetTester tester, {bool confirm = true}) async {
    final entry = find.byKey(const ValueKey('edit-application-policy'));
    await reveal(tester, entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('测试新 App'),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('application-list-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('测试新 App'));
    final action = confirm
        ? find.byKey(const ValueKey('confirm-application-policy'))
        : find.byTooltip('关闭');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
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
        expect(find.byType(CheckboxListTile), findsNothing);
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

  testWidgets('名单确认仅更新草稿，再次打开取消保留草稿；窄屏大字保存保留已有文件范围', (tester) async {
    const scope = ExecutionScope(fileUris: ['content://fixture/saved']);
    final h = await pump(tester, scope: scope);
    await editPolicy(tester);
    expect(h.settings.readExecutionScope().toJson(), scope.toJson());
    await editPolicy(tester, confirm: false);
    await tester.tap(find.byKey(const ValueKey('save-execution-scope')));
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().appPolicy.blacklist, {
      'fixture.new',
    });
    expect(h.settings.readExecutionScope().fileUris, scope.fileUris);
    expect(h.api.fileLoads, 0);
    expect(h.api.released, isEmpty);
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存失败保留名单草稿，重试成功且不更改文件授权', (tester) async {
    const scope = ExecutionScope(fileUris: ['content://fixture/saved']);
    final h = await pump(tester, scope: scope);
    await editPolicy(tester);
    h.settings.failSave = true;
    await tester.tap(find.byKey(const ValueKey('save-execution-scope')));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，可重试'), findsOneWidget);
    expect(h.settings.readExecutionScope().toJson(), scope.toJson());
    h.settings.failSave = false;
    await tester.tap(find.byKey(const ValueKey('save-execution-scope')));
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().appPolicy.blacklist, {
      'fixture.new',
    });
    expect(h.settings.readExecutionScope().fileUris, scope.fileUris);
  });

  testWidgets('页面返回放弃应用名单草稿，不改已有授权', (tester) async {
    const scope = ExecutionScope(fileUris: ['content://fixture/saved']);
    final h = await pump(tester, scope: scope);
    await editPolicy(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().toJson(), scope.toJson());
  });

  testWidgets('系统应用清单读取失败显示明确错误，重试不重复查询权限或文件', (tester) async {
    final h = await pump(tester);
    h.api.emptyPlatformList = true;
    final entry = find.byKey(const ValueKey('edit-application-policy'));
    await reveal(tester, entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('系统未返回应用列表，请检查应用列表访问权限或稍后重试'), findsOneWidget);
    expect(h.api.appLoads, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-application-policy')),
          )
          .onPressed,
      isNull,
    );
    h.api.emptyPlatformList = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(h.api.appLoads, 2);
    expect(h.api.fileLoads, 0);
    expect(h.driver.capabilityLoads, 1);
    expect(
      find.byKey(const ValueKey('application-list-scroll')),
      findsOneWidget,
    );
  });

  for (final code in [
    'applicationListPermissionRequired',
    'applicationListRestricted',
  ]) {
    testWidgets('$code 明确提示授权，不展示受限名单；设置返回自动刷新并保留原策略', (tester) async {
      final api = _SetupApi()
        ..applicationsHandler = () async {
          throw PlatformException(
            code: code,
            message: 'private platform details',
          );
        };
      const scope = ExecutionScope(
        fileUris: ['content://fixture/saved'],
        appPolicy: ApplicationAccessPolicy(blacklist: {'fixture.saved'}),
      );
      final h = await pump(tester, api: api, scope: scope);
      final entry = find.byKey(const ValueKey('edit-application-policy'));
      await reveal(tester, entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('无法读取应用列表'), findsOneWidget);
      expect(
        find.textContaining(
          code == 'applicationListPermissionRequired'
              ? '未授权获取应用列表'
              : '应用列表访问受限',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('private platform'), findsNothing);
      expect(
        find.byKey(const ValueKey('application-list-scroll')),
        findsNothing,
      );
      final confirm = find.byKey(const ValueKey('confirm-application-policy'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      final authorize = find.byKey(
        const ValueKey('authorize-application-list'),
      );
      await tester.ensureVisible(authorize);
      await tester.tap(authorize);
      await tester.pumpAndSettle();
      expect(api.opened, [PermissionScreen.applications]);
      expect(api.appLoads, 1);
      api.applicationsHandler = null;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(api.appLoads, 2);
      expect(find.text('无法读取应用列表'), findsNothing);
      expect(
        find.byKey(const ValueKey('application-list-scroll')),
        findsOneWidget,
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-execution-scope')));
      await tester.pumpAndSettle();
      expect(h.settings.readExecutionScope().toJson(), scope.toJson());
      expect(api.fileLoads, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('授权设置失败可重试、防重复；拒绝后仍提示权限不足，不反复打开授权', (tester) async {
    final opened = Completer<void>();
    final api = _SetupApi()
      ..applicationsHandler = () async {
        throw PlatformException(code: 'applicationListPermissionRequired');
      }
      ..permissionSettingsHandler = () => opened.future;
    final h = await pump(tester, api: api, largeText: false);
    await tester.tap(find.byKey(const ValueKey('edit-application-policy')));
    await tester.pumpAndSettle();
    final authorize = find.byKey(const ValueKey('authorize-application-list'));
    await tester.tap(authorize);
    await tester.tap(authorize);
    await tester.pump();
    expect(api.opened, [PermissionScreen.applications]);
    expect(tester.widget<FilledButton>(authorize).onPressed, isNull);
    opened.completeError(
      PlatformException(
        code: 'unavailable',
        message: 'private settings failure',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('private settings'), findsNothing);
    expect(find.text('执行通道不可用，请返回相月后重试'), findsOneWidget);
    expect(tester.widget<FilledButton>(authorize).onPressed, isNotNull);
    api.permissionSettingsHandler = null;
    await tester.tap(authorize);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('未授权获取应用列表'), findsOneWidget);
    expect(api.appLoads, 2);
    expect(api.opened, [
      PermissionScreen.applications,
      PermissionScreen.applications,
    ]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(api.appLoads, 2);
    expect(api.opened, hasLength(2));
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().appPolicy.blacklist, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('授权设置尚未返回时关闭面板，迟到错误不会修改页面或原名单', (tester) async {
    final opened = Completer<void>();
    final api = _SetupApi()
      ..applicationsHandler = () async {
        throw PlatformException(code: 'applicationListPermissionRequired');
      }
      ..permissionSettingsHandler = () => opened.future;
    final h = await pump(tester, api: api, largeText: false);
    await tester.tap(find.byKey(const ValueKey('edit-application-policy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('authorize-application-list')));
    await tester.pump();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    opened.completeError(PlatformException(code: 'unavailable'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(api.appLoads, 1);
    expect(h.settings.readExecutionScope().appPolicy.blacklist, isEmpty);
    expect(find.textContaining('执行通道不可用'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('权限读取缓慢不伪装未授权，不阻塞权限入口和保存，也不预取应用清单', (tester) async {
    final capabilities = Completer<ExecutionCapabilities>();
    const scope = ExecutionScope(
      fileUris: ['content://fixture/saved'],
      appPolicy: ApplicationAccessPolicy(blacklist: {'fixture.saved'}),
    );
    final h = await pump(
      tester,
      driver: _Driver()..capabilitiesHandler = () => capabilities.future,
      largeText: false,
      scope: scope,
    );
    expect(find.text('读取中…'), findsNWidgets(2));
    expect(find.text('未授权'), findsNothing);
    expect(h.api.fileLoads, 0);
    expect(h.api.appLoads, 0);
    await tester.tap(find.text('任务通知'));
    await tester.pump();
    expect(h.api.opened, [PermissionScreen.notifications]);
    await tester.tap(find.byKey(const ValueKey('save-execution-scope')));
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

  testWidgets('权限读取失败不伪装未授权，名单草稿可编辑，重试只刷新权限', (tester) async {
    final capabilities = Completer<ExecutionCapabilities>();
    final driver = _Driver()..capabilitiesHandler = () => capabilities.future;
    final h = await pump(tester, driver: driver, largeText: false);
    capabilities.completeError(
      const ExecutionFailure(ExecutionFailureCode.timeout),
    );
    await tester.pumpAndSettle();
    expect(find.text('读取失败'), findsNWidgets(2));
    expect(find.text('未授权'), findsNothing);
    expect(find.byKey(const ValueKey('capabilities-error')), findsOneWidget);
    await editPolicy(tester);
    driver.capabilitiesHandler = null;
    await reveal(tester, find.text('重试'));
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(driver.capabilityLoads, 2);
    expect(h.api.fileLoads, 0);
    expect(h.api.appLoads, 1);
    expect(find.text('已授权'), findsOneWidget);
    expect(find.text('未授权'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-execution-scope')));
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().appPolicy.blacklist, {
      'fixture.new',
    });
  });

  testWidgets('权限加载去重，前后台往返保留名单草稿和已有文件范围', (tester) async {
    final capabilities = Completer<ExecutionCapabilities>();
    final driver = _Driver()..capabilitiesHandler = () => capabilities.future;
    const scope = ExecutionScope(fileUris: ['content://fixture/saved']);
    final h = await pump(
      tester,
      driver: driver,
      largeText: false,
      scope: scope,
    );
    final controller = h.container.read(
      executionSetupControllerProvider.notifier,
    );
    final refreshes = [controller.load(), controller.load()];
    expect(driver.capabilityLoads, 1);
    await editPolicy(tester);
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
    expect(h.api.appLoads, 1);
    expect(h.settings.readExecutionScope().toJson(), scope.toJson());
    await tester.tap(find.byKey(const ValueKey('save-execution-scope')));
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().appPolicy.blacklist, {
      'fixture.new',
    });
    expect(h.settings.readExecutionScope().fileUris, scope.fileUris);
  });

  testWidgets('应用清单按需加载，关闭无需等待，旧响应不覆盖重新打开的面板', (tester) async {
    final first = Completer<List<InstalledApplication>>();
    final second = Completer<List<InstalledApplication>>();
    final responses = [first, second];
    final api = _SetupApi()
      ..applicationsHandler = () => responses.removeAt(0).future;
    final h = await pump(tester, api: api, largeText: false);
    final entry = find.byKey(const ValueKey('edit-application-policy'));
    final confirm = find.byKey(const ValueKey('confirm-application-policy'));
    expect(api.appLoads, 0);
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(api.appLoads, 1);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(confirm, findsNothing);
    expect(h.settings.readExecutionScope().appPolicy.blacklist, isEmpty);
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(api.appLoads, 2);
    first.completeError(
      PlatformException(code: 'unavailable', message: 'private stale response'),
    );
    await tester.pump();
    expect(find.text('重试'), findsNothing);
    expect(find.textContaining('private stale response'), findsNothing);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    second.complete([
      InstalledApplication(
        packageName: 'fixture.current',
        label: '当前应用',
        isSystem: false,
        installedAtMs: 1,
        launchable: true,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.scrollUntilVisible(
      find.text('当前应用'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('application-list-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('当前应用'));
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().appPolicy.blacklist, isEmpty);
    expect(api.fileLoads, 0);
    expect(h.driver.capabilityLoads, 1);
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
