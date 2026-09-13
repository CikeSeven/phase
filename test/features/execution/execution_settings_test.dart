import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/execution_scope.dart';
import 'package:phase/features/chat/model_selection.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/execution_settings_page.dart';
import 'package:phase/features/execution/execution_setup_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_channel_driver.dart';

class _NoModel extends ModelSelection {
  @override
  Future<ChatModelSelection?> build() async => null;
}

class _SetupApi extends ExecutionSetupApi {
  bool fail = false;
  bool emptyPlatformList = false;
  final opened = <PermissionScreen>[];
  @override
  Future<List<FileGrant>> fileGrants() async {
    if (fail) {
      throw PlatformException(
        code: 'unavailable',
        message: 'private fixture response',
      );
    }
    return [
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
  Future<FileGrant?> selectFile(bool directory) async => null;
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

  Future<({ProviderContainer container, _Settings settings, _SetupApi api})>
  pump(WidgetTester tester, {bool fail = false}) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = _Settings(prefs);
    final api = _SetupApi()..fail = fail;
    final driver = FakeChannelDriver();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((_) => prefs),
        settingsStorageProvider.overrideWith((_) => settings),
        executionSetupApiProvider.overrideWith((_) => api),
        channelDriverProvider.overrideWith((_) => driver),
        modelSelectionProvider.overrideWith(_NoModel.new),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await driver.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
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
    await tester.pumpAndSettle();
    return (container: container, settings: settings, api: api);
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
    h.api.emptyPlatformList = true;
    await h.container.read(executionSetupControllerProvider.notifier).load();
    await tester.pumpAndSettle();
    expect(find.text('系统未返回应用列表，请检查应用列表访问权限或稍后重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-application-policy')), findsNothing);
    h.api.emptyPlatformList = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(
      h.container.read(executionSetupControllerProvider).value!.applications,
      hasLength(1),
    );
  });
}
