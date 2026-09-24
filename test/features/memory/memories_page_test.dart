import 'dart:ui' show Tristate;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_dropdown.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/models/assistant.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/memory_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/memory/memories_page.dart';

const _assistantId = 'assistant-writing';
const _assistantName = '阅读与长期偏好记录的写作助手';

void main() {
  late AppDatabase database;
  late MemoryRepository repository;
  late ProviderContainer container;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = MemoryRepository(database);
    await AssistantRepository(database).save(
      Assistant(
        id: _assistantId,
        name: _assistantName,
        systemPrompt: '',
        createdAt: DateTime(2026),
      ),
    );
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWith((ref) => database)],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(360, 800),
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const MemoriesPage(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await container.read(assistantsProvider.future);
      await container.read(memoriesProvider.future);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加记忆'));
    await tester.pumpAndSettle();
  }

  final scope = find.byType(AppDropdown<String>);
  final content = find.widgetWithText(TextField, '记忆内容');

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder.hitTestable());
    await tester.pumpAndSettle();
  }

  Future<void> chooseScope(WidgetTester tester, String label) async {
    await tap(tester, scope);
    await tap(tester, find.widgetWithText(MenuItemButton, label));
  }

  for (final (size, scale, dark) in [
    (const Size(360, 800), 1.0, false),
    (const Size(360, 800), 1.0, true),
    (const Size(320, 760), 1.3, false),
    (const Size(320, 760), 2.0, true),
    (const Size(800, 360), 2.0, true),
  ]) {
    testWidgets('所属范围使用共享菜单，返回保留弹窗，保存助手范围 $size/$scale/$dark', (tester) async {
      await pumpPage(tester, size: size, scale: scale, dark: dark);
      final semantics = tester.ensureSemantics();
      try {
        expect(scope, findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(tester.widget<AppDropdown<String>>(scope).value, '');

        await tap(tester, scope);
        expect(find.byType(MenuItemButton), findsNWidgets(3));
        expect(tester.testTextInput.isVisible, isFalse);
        expect(
          tester
              .getSemantics(find.widgetWithText(MenuItemButton, '全局'))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        await tap(tester, find.widgetWithText(MenuItemButton, _assistantName));
        expect(find.byType(MenuItemButton), findsNothing);
        expect(tester.widget<AppDropdown<String>>(scope).value, _assistantId);
        expect(await tester.runAsync(() => repository.watch().first), isEmpty);

        await tester.ensureVisible(content);
        await tester.enterText(content, '回答时优先使用简体中文');
        await tap(tester, scope);
        expect(
          tester
              .getSemantics(find.widgetWithText(MenuItemButton, _assistantName))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(find.byType(MemoryEditor), findsOneWidget);
        expect(tester.widget<AppDropdown<String>>(scope).value, _assistantId);
        expect(
          tester.widget<TextField>(content).controller!.text,
          '回答时优先使用简体中文',
        );

        await tap(tester, find.widgetWithText(FilledButton, '保存'));
        expect(find.byType(MemoryEditor), findsNothing);
        final saved = (await tester.runAsync(() => repository.watch().first))!
            .single;
        expect(saved.assistantId, _assistantId);
        expect(saved.content, '回答时优先使用简体中文');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('取消不保存所属范围，再次新建可切回全局并保存', (tester) async {
    await pumpPage(tester);
    await chooseScope(tester, _assistantName);
    await tester.enterText(content, '未保存的草稿');
    await tap(tester, find.widgetWithText(TextButton, '取消'));
    expect(find.byType(MemoryEditor), findsNothing);
    expect(await tester.runAsync(() => repository.watch().first), isEmpty);

    await tap(tester, find.byTooltip('添加记忆'));
    expect(tester.widget<AppDropdown<String>>(scope).value, '');
    expect(tester.widget<TextField>(content).controller!.text, isEmpty);
    await chooseScope(tester, _assistantName);
    await chooseScope(tester, '全局');
    await tester.enterText(content, '全局偏好');
    await tap(tester, find.widgetWithText(FilledButton, '保存'));
    final saved = (await tester.runAsync(() => repository.watch().first))!
        .single;
    expect(saved.assistantId, isNull);
    expect(saved.content, '全局偏好');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('保存失败保留所属范围，修正内容后可重试', (tester) async {
    await pumpPage(tester);
    await chooseScope(tester, _assistantName);
    await tap(tester, find.widgetWithText(FilledButton, '保存'));
    expect(find.text('记忆需要 1–2000 字的内容'), findsOneWidget);
    expect(tester.widget<AppDropdown<String>>(scope).value, _assistantId);
    expect(tester.widget<AppDropdown<String>>(scope).onChanged, isNotNull);
    expect(await tester.runAsync(() => repository.watch().first), isEmpty);

    await tester.enterText(content, '修正后的内容');
    await tap(tester, find.widgetWithText(FilledButton, '保存'));
    final saved = (await tester.runAsync(() => repository.watch().first))!
        .single;
    expect(saved.assistantId, _assistantId);
    expect(saved.content, '修正后的内容');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
