import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  bool fail = false;
  bool emptyPlatformList = false;
  int fileLoads = 0;
  int appLoads = 0;
  Future<List<FileGrant>> Function()? grantsHandler;
  Future<List<InstalledApplication>> Function()? applicationsHandler;
  FileGrant? selected;
  final released = <String>[];
  final opened = <PermissionScreen>[];
  @override
  Future<List<FileGrant>> fileGrants() async {
    fileLoads++;
    if (grantsHandler != null) return await grantsHandler!();
    if (fail) {
      throw PlatformException(
        code: 'unavailable',
        message: 'private fixture response',
      );
    }
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
    bool fail = false,
    _SetupApi? api,
    _Driver? driver,
    bool settle = true,
    bool largeText = true,
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
    api ??= _SetupApi()..fail = fail;
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
          theme: AppTheme.dark(),
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

  testWidgets('执行范围草稿取消不保存，选择器取消保留范围，保存按钮在窄屏大字下可达', (tester) async {
    final h = await pump(tester);
    final select = find.byKey(const ValueKey('edit-application-policy'));
    await reveal(tester, select);
    await tester.tap(select);
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
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm-application-policy')),
    );
    await tester.tap(find.byKey(const ValueKey('confirm-application-policy')));
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().appPolicy.blacklist, isEmpty);
    await reveal(tester, find.text('选择目录'));
    await tester.tap(find.text('选择目录'));
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().fileUris, isEmpty);
    final check = find.byType(CheckboxListTile);
    await reveal(tester, check);
    await tester.tap(check);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-execution-scope')));
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().appPolicy.blacklist, {
      'fixture.new',
    });
    expect(h.settings.readExecutionScope().fileUris, [
      'content://fixture/root',
    ]);
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载失败不伪装无授权，重试与权限入口真实调用；保存失败保留草稿', (tester) async {
    final h = await pump(tester, fail: true);
    expect(find.textContaining('private fixture'), findsNothing);
    await reveal(tester, find.text('重试'));
    expect(find.text('重试'), findsOneWidget);
    h.api.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('任务通知'));
    await tester.tap(find.text('任务通知'));
    await tester.pumpAndSettle();
    expect(h.api.opened, [PermissionScreen.notifications]);
    await reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    h.settings.failSave = true;
    await tester.tap(find.byKey(const ValueKey('save-execution-scope')));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，可重试'), findsOneWidget);
    expect(h.settings.readExecutionScope().fileUris, isEmpty);
    h.settings.failSave = false;
    await tester.tap(find.byKey(const ValueKey('save-execution-scope')));
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().fileUris, [
      'content://fixture/root',
    ]);
  });

  testWidgets('返回放弃目标 App 和文件范围草稿', (tester) async {
    final h = await pump(tester);
    await reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().fileUris, isEmpty);
  });

  testWidgets('系统应用清单不可读取时显示明确错误和重试，不伪装成零个应用', (tester) async {
    final h = await pump(tester);
    expect(h.api.appLoads, 0);
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
    expect(h.api.fileLoads, 1);
    expect(h.driver.capabilityLoads, 1);
    expect(
      find.byKey(const ValueKey('application-list-scroll')),
      findsOneWidget,
    );
  });

  testWidgets('文件授权缓慢不阻塞权限入口和保存，也不预取应用清单', (tester) async {
    final grants = Completer<List<FileGrant>>();
    final api = _SetupApi()..grantsHandler = () => grants.future;
    const scope = ExecutionScope(
      fileUris: ['content://fixture/saved'],
      appPolicy: ApplicationAccessPolicy(blacklist: {'fixture.saved'}),
    );
    final h = await pump(
      tester,
      api: api,
      settle: false,
      largeText: false,
      scope: scope,
    );
    expect(api.fileLoads, 1);
    expect(api.appLoads, 0);
    expect(h.driver.capabilityLoads, 1);
    expect(find.text('已允许'), findsOneWidget);
    expect(find.byKey(const ValueKey('file-grants-loading')), findsOneWidget);
    expect(find.text('暂无文件授权'), findsNothing);
    expect(
      find.byKey(const ValueKey('edit-application-policy')),
      findsOneWidget,
    );
    expect(find.textContaining('授权文件或屏幕内容'), findsNothing);
    expect(find.textContaining('助手的工具范围'), findsNothing);
    expect(find.textContaining('当前模型'), findsNothing);
    expect(find.textContaining('端点'), findsNothing);
    expect(find.textContaining('名单收紧'), findsNothing);
    await tester.tap(find.text('任务通知'));
    await tester.pump();
    expect(api.opened, [PermissionScreen.notifications]);
    await tester.tap(find.byKey(const ValueKey('save-execution-scope')));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(h.settings.readExecutionScope().toJson(), scope.toJson());
    grants.complete([]);
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().toJson(), scope.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('权限读取缓慢或失败不阻塞文件，重试只刷新权限状态', (tester) async {
    final capabilities = Completer<ExecutionCapabilities>();
    final driver = _Driver()..capabilitiesHandler = () => capabilities.future;
    final h = await pump(tester, driver: driver, largeText: false);
    expect(find.text('读取中…'), findsNWidgets(3));
    expect(find.text('未允许'), findsNothing);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(h.api.appLoads, 0);
    capabilities.completeError(
      const ExecutionFailure(ExecutionFailureCode.timeout),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capabilities-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('file-grants-error')), findsNothing);
    await tester.tap(find.byType(CheckboxListTile));
    driver.capabilitiesHandler = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(driver.capabilityLoads, 2);
    expect(h.api.fileLoads, 1);
    expect(h.api.appLoads, 0);
    expect(find.text('已允许'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
  });

  testWidgets('并行加载去重，完成顺序不覆盖其他分区，前后台往返保留草稿', (tester) async {
    final grants = Completer<List<FileGrant>>();
    final capabilities = Completer<ExecutionCapabilities>();
    final api = _SetupApi()..grantsHandler = () => grants.future;
    final driver = _Driver()..capabilitiesHandler = () => capabilities.future;
    final h = await pump(
      tester,
      api: api,
      driver: driver,
      settle: false,
      largeText: false,
    );
    final controller = h.container.read(
      executionSetupControllerProvider.notifier,
    );
    final refreshes = [controller.load(), controller.load()];
    expect(api.fileLoads, 1);
    expect(driver.capabilityLoads, 1);
    grants.complete([
      FileGrant(
        uri: 'content://fixture/root',
        name: '测试目录',
        directory: true,
        writable: true,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.text('读取中…'), findsNWidgets(3));
    await tester.tap(find.byType(CheckboxListTile));
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
    expect(find.text('可用 · 需模型支持图片与工具'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    api.grantsHandler = null;
    driver.capabilitiesHandler = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(api.fileLoads, 2);
    expect(driver.capabilityLoads, 2);
    expect(api.appLoads, 0);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    expect(h.settings.readExecutionScope().fileUris, isEmpty);
  });

  testWidgets('文件授权失败不隐藏权限和名单，重试不重复查询权限', (tester) async {
    final h = await pump(tester, fail: true, largeText: false);
    expect(find.text('已允许'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('edit-application-policy')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('file-grants-error')), findsOneWidget);
    expect(find.text('暂无文件授权'), findsNothing);
    h.api.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(h.api.fileLoads, 2);
    expect(h.driver.capabilityLoads, 1);
    expect(h.api.appLoads, 0);
    expect(find.byType(CheckboxListTile), findsOneWidget);
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
    expect(api.fileLoads, 1);
    expect(h.driver.capabilityLoads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选择和解除文件授权只刷新文件分区', (tester) async {
    final api = _SetupApi()
      ..selected = FileGrant(
        uri: 'content://fixture/root',
        name: '测试目录',
        directory: true,
        writable: true,
      );
    final h = await pump(tester, api: api, largeText: false);
    await tester.tap(find.text('选择目录'));
    await tester.pumpAndSettle();
    expect(api.fileLoads, 2);
    expect(h.driver.capabilityLoads, 1);
    expect(api.appLoads, 0);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    await tester.tap(find.byTooltip('解除授权'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('解除'));
    await tester.pumpAndSettle();
    expect(api.released, ['content://fixture/root']);
    expect(api.fileLoads, 3);
    expect(h.driver.capabilityLoads, 1);
    expect(api.appLoads, 0);
    expect(find.text('暂无文件授权'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-execution-scope')));
    await tester.pumpAndSettle();
    expect(h.settings.readExecutionScope().fileUris, isEmpty);
  });

  testWidgets('页面销毁后权限与文件迟到结果安全收尾', (tester) async {
    final grants = Completer<List<FileGrant>>();
    final capabilities = Completer<ExecutionCapabilities>();
    final h = await pump(
      tester,
      api: _SetupApi()..grantsHandler = () => grants.future,
      driver: _Driver()..capabilitiesHandler = () => capabilities.future,
      settle: false,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    h.container.dispose();
    grants.completeError(PlatformException(code: 'unavailable'));
    capabilities.completeError(
      const ExecutionFailure(ExecutionFailureCode.unavailable),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
