import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_scaffold.dart';
import 'package:phase/core/widgets/app_dropdown.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/assistant.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/skill_repository.dart';
import 'package:phase/features/assistants/assistant_edit_page.dart';
import 'package:phase/features/assistants/assistants_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_secure_storage.dart';

void main() {
  late Directory temp;
  late AppDatabase db;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('phase_assistants');
    // widget 测试的 fake-async 无法驱动后台 isolate：同 isolate 打开加密库。
    db = openAppDatabase(
      path: p.join(temp.path, 'phase.sqlite'),
      hexKey: '0123456789abcdef' * 4,
      background: false,
    );
  });

  tearDown(() async {
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// 预置一个带系统提示词与默认模型的助手。
  Future<Assistant> seedAssistant({
    String name = '代码助手',
    String prompt = '只回答与代码有关的问题。',
    ModelSelection? selection,
  }) async {
    final repository = AssistantRepository(db);
    final assistant = Assistant(
      id: 'a-$name',
      name: name,
      systemPrompt: prompt,
      defaultModelSelection: selection,
      createdAt: DateTime(2026),
    );
    await repository.save(assistant);
    return assistant;
  }

  Future<({ProviderContainer container, GoRouter router})> pumpHost(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    String initialLocation = '/assistants',
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => preferences),
        appDatabaseProvider.overrideWith((ref) => db),
        skillRepositoryProvider.overrideWith(
          (ref) => SkillRepository(db, Directory(p.join(temp.path, 'skills'))),
        ),
        secureKeyStorageProvider.overrideWith(
          (ref) => SecureKeyStorage(FakeSecureStorage()),
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/assistants',
          builder: (context, state) => const AssistantsPage(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const AssistantEditPage(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  AssistantEditPage(assistantId: state.pathParameters['id']),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container: container, router: router);
  }

  /// 收尾：拆组件树 → 关容器 → 关库（drift 的流清理计时器需要这一步）。
  Future<void> closeHost(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    var closed = false;
    unawaited(db.close().then((_) => closed = true));
    for (var i = 0; i < 40 && !closed; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(closed, isTrue, reason: '数据库未在预期时间内关闭');
  }

  testWidgets('列出真实助手：名称、系统提示词与默认模型，并标记当前', (tester) async {
    await seedAssistant();
    final seeded = await seedAssistant(
      name: '写作助手',
      prompt: '',
      selection: const ModelSelection(
        profileId: 'p1',
        modelId: 'deepseek-chat',
      ),
    );
    final host = await pumpHost(tester);

    expect(find.text('代码助手'), findsOneWidget);
    expect(find.text('只回答与代码有关的问题。'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('assistant-${seeded.id}')),
        matching: find.text('未设置系统提示词'),
      ),
      findsOneWidget,
    );
    expect(find.text('默认模型：deepseek-chat'), findsOneWidget);
    // 列表里第一个助手是当前助手（内置默认排在更前，这里只有一个「当前」）。
    expect(
      find.byKey(const ValueKey('assistant-current-badge')),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('assistant-${seeded.id}')), findsOneWidget);

    await closeHost(tester, host.container);
  });

  testWidgets('点击助手进入编辑页，新建入口打开空白编辑页', (tester) async {
    await seedAssistant();
    final host = await pumpHost(tester);

    await tester.tap(find.byKey(const ValueKey('assistant-a-代码助手')));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantEditPage), findsOneWidget);
    expect(find.text('编辑助手'), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-assistant')), findsOneWidget);
    final topBar = find.byType(AppTopBar);
    for (final (key, tooltip) in [
      ('delete-assistant', '删除助手'),
      ('save-assistant', '保存助手'),
    ]) {
      final action = find.descendant(
        of: topBar,
        matching: find.byKey(ValueKey(key)),
      );
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.widget<IconButton>(action).tooltip, tooltip);
      expect(tester.getSize(action).shortestSide, greaterThanOrEqualTo(48));
    }
    expect(
      tester.widget<AppScaffold>(find.byType(AppScaffold)).bottomBar,
      isNull,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-assistant')));
    await tester.pumpAndSettle();
    expect(find.text('新建助手'), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-assistant')), findsNothing);
    expect(find.byKey(const ValueKey('save-assistant')), findsOneWidget);

    await closeHost(tester, host.container);
  });

  testWidgets('默认相月可编辑和保存，改名后再次打开仍没有删除入口', (tester) async {
    final host = await pumpHost(tester);
    final row = find.byKey(const ValueKey('assistant-$defaultAssistantId'));
    expect(find.text('相月'), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-assistant')), findsNothing);
    expect(find.byTooltip('保存助手').hitTestable(), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('assistant-name')),
      '我的助手',
    );
    await tester.tap(find.byKey(const ValueKey('save-assistant')));
    await tester.pumpAndSettle();
    expect(
      (await AssistantRepository(db).getById(defaultAssistantId))!.name,
      '我的助手',
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-assistant')), findsNothing);
    expect(find.byTooltip('保存助手').hitTestable(), findsOneWidget);
    await closeHost(tester, host.container);
  });

  testWidgets('窄屏与大字号下列表与底部入口可用', (tester) async {
    await seedAssistant(
      name: '很长很长的助手名称用于验证窄屏省略',
      prompt: '这是一段很长的系统提示词，用于验证两行省略不会溢出，也不会把卡片撑破。',
    );
    final host = await pumpHost(tester, size: const Size(320, 760), scale: 2);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('add-assistant')), findsOneWidget);
    expect(find.byIcon(Symbols.add), findsWidgets);

    await closeHost(tester, host.container);
  });

  testWidgets('自建同名相月保留删除入口，取消不删除，确认后列表更新', (tester) async {
    final assistant = await seedAssistant(name: '相月');
    final host = await pumpHost(tester);

    await tester.tap(find.byKey(ValueKey('assistant-${assistant.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-assistant')));
    await tester.pumpAndSettle();
    expect(find.text('删除助手'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cancel-delete-assistant')));
    await tester.pumpAndSettle();
    expect(await AssistantRepository(db).getById(assistant.id), isNotNull);
    await tester.tap(find.byKey(const ValueKey('delete-assistant')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('confirm-delete-assistant')));
    await tester.pumpAndSettle();

    // 回到列表：该助手已不在列表里（内置默认助手仍在）。
    expect(find.byKey(ValueKey('assistant-${assistant.id}')), findsNothing);
    expect(find.text('相月'), findsOneWidget);
    expect(find.byType(AppScaffold), findsOneWidget);

    await closeHost(tester, host.container);
  });

  Future<void> changeWritePolicy(WidgetTester tester, String label) async {
    final field = find.byKey(const ValueKey('tool-policy-write_file'));
    await tester.scrollUntilVisible(
      field,
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('assistant-edit-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, label));
    await tester.pumpAndSettle();
  }

  testWidgets('工具策略编辑取消不保存，确认后保存且重新打开一致', (tester) async {
    final assistant = await seedAssistant();
    final host = await pumpHost(tester);
    await tester.tap(find.byKey(ValueKey('assistant-${assistant.id}')));
    await tester.pumpAndSettle();
    await changeWritePolicy(tester, '禁止使用');
    expect(
      (await AssistantRepository(db).getById(assistant.id))!
          .toolPolicy
          .policies['write_file'],
      ToolPolicy.ask,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('assistant-${assistant.id}')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppDropdown<ToolPolicy>>(
            find.byKey(const ValueKey('tool-policy-write_file')),
          )
          .value,
      ToolPolicy.ask,
    );
    await changeWritePolicy(tester, '禁止使用');
    await tester.tap(find.byKey(const ValueKey('save-assistant')));
    await tester.pumpAndSettle();
    expect(
      (await AssistantRepository(db).getById(assistant.id))!
          .toolPolicy
          .policies['write_file'],
      ToolPolicy.deny,
    );
    await tester.tap(find.byKey(ValueKey('assistant-${assistant.id}')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppDropdown<ToolPolicy>>(
            find.byKey(const ValueKey('tool-policy-write_file')),
          )
          .value,
      ToolPolicy.deny,
    );
    await closeHost(tester, host.container);
  });

  testWidgets('工具策略保存失败保留草稿，修复存储后可重试', (tester) async {
    final assistant = await seedAssistant();
    final host = await pumpHost(tester);
    await tester.tap(find.byKey(ValueKey('assistant-${assistant.id}')));
    await tester.pumpAndSettle();
    await changeWritePolicy(tester, '直接执行');
    await db.customStatement(
      "CREATE TRIGGER reject_policy BEFORE UPDATE ON assistants BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await tester.tap(find.byKey(const ValueKey('save-assistant')));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantEditPage), findsOneWidget);
    expect(
      tester
          .widget<AppDropdown<ToolPolicy>>(
            find.byKey(const ValueKey('tool-policy-write_file')),
          )
          .value,
      ToolPolicy.allow,
    );
    expect(
      (await AssistantRepository(db).getById(assistant.id))!
          .toolPolicy
          .policies['write_file'],
      ToolPolicy.ask,
    );
    await db.customStatement('DROP TRIGGER reject_policy');
    await tester.tap(find.byKey(const ValueKey('save-assistant')));
    await tester.pumpAndSettle();
    expect(
      (await AssistantRepository(db).getById(assistant.id))!
          .toolPolicy
          .policies['write_file'],
      ToolPolicy.allow,
    );
    await closeHost(tester, host.container);
  });

  testWidgets('320dp 两倍字号工具策略可滚动选择，保存仍可达', (tester) async {
    final assistant = await seedAssistant();
    final host = await pumpHost(tester, size: const Size(320, 760), scale: 2);
    await tester.tap(find.byKey(ValueKey('assistant-${assistant.id}')));
    await tester.pumpAndSettle();
    await changeWritePolicy(tester, '禁止使用');
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('save-assistant')).hitTestable(),
      findsOneWidget,
    );
    await closeHost(tester, host.container);
  });
}
