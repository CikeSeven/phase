import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_loading_indicator.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/skill_repository.dart';
import 'package:phase/features/assistants/assistant_edit_page.dart';
import 'package:phase/features/skills/skill_controller.dart';
import 'package:phase/features/skills/assistant_skills_section.dart';
import 'package:phase/features/skills/skill_detail_page.dart';
import 'package:phase/features/skills/skill_import_page.dart';
import 'package:phase/features/skills/skill_import_source.dart';
import 'package:phase/features/skills/skill_resource_page.dart';
import 'package:phase/features/skills/skills_page.dart';
import 'package:phase/features/tools/tool.dart';

import '../tools/tool_loop_harness.dart';
import 'skill_test_support.dart';

class _Source extends SkillImportSource {
  _Source(this.path);
  final String path;
  @override
  Future<PickedSkill?> pick(bool zip, RunCancellation cancellation) async =>
      PickedSkill(path, false, '整理文档');
}

const _capture = bool.fromEnvironment('CAPTURE_SKILLS');

void main() {
  setUpAll(() async {
    if (!_capture) return;
    final bytes = await File('build/ui-preview/NotoSansCJKsc-Regular.otf')
        .readAsBytes();
    for (final family in ['Roboto', 'Ahem', 'sans-serif']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final family = entry['family'] as String;
      if (!family.toLowerCase().contains('material')) continue;
      final loader = FontLoader(family);
      for (final font
          in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  for (final (size, scale, dark) in [
    (const Size(360, 800), 1.0, false),
    (const Size(360, 800), 1.0, true),
    (const Size(320, 700), 2.0, false),
    (const Size(800, 360), 2.0, true),
  ]) {
    testWidgets('Skill 导入、取消、安装和详情 $size / $scale / dark=$dark', (
      tester,
    ) async {
      late ToolLoopHarness h;
      late Directory source;
      await tester.runAsync(() async {
        h = await ToolLoopHarness.create();
        source = Directory('${h.tempDir.path}/source');
        await source.create();
        await File('${source.path}/SKILL.md').writeAsString(sampleSkill);
      });
      final container = ProviderContainer(
        parent: h.container,
        overrides: [
          skillImportSourceProvider.overrideWith((ref) => _Source(source.path)),
          // Scoped family uses the local import source in this UI test.
          skillImportControllerProvider.overrideWith2(
            (_) => SkillImportController(),
          ),
        ],
      );
      addTearDown(container.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/settings/extensions/skills',
        routes: [
          GoRoute(
            path: '/settings/extensions/skills',
            pageBuilder: (context, state) =>
                MaterialPage(key: state.pageKey, child: const SkillsPage()),
            routes: [
              GoRoute(
                path: 'import',
                pageBuilder: (context, state) => MaterialPage(
                  key: state.pageKey,
                  child: const SkillImportPage(),
                ),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => MaterialPage(
                  key: state.pageKey,
                  child: SkillDetailPage(id: state.pathParameters['id']!),
                ),
                routes: [
                  GoRoute(
                    path: 'resource',
                    pageBuilder: (context, state) => MaterialPage(
                      key: state.pageKey,
                      child: SkillResourcePage(
                        id: state.pathParameters['id']!,
                        path: state.uri.queryParameters['path']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp.router(
              routerConfig: router,
              debugShowCheckedModeBanner: false,
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final repository = await container.read(skillRepositoryProvider.future);
      router.push('/settings/extensions/skills/import');
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('pick-skill-directory')));
      });
      await _pumpUntil(
        tester,
        () =>
            container.read(skillImportControllerProvider(null)).package != null,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('整理文档'), 200);
      expect(find.text('整理文档'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(await repository.list(), isEmpty);
      router.push('/settings/extensions/skills/import');
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('pick-skill-zip')));
      });
      await _pumpUntil(
        tester,
        () =>
            container.read(skillImportControllerProvider(null)).package != null,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('install-skill')));
      });
      await _pumpUntil(
        tester,
        () => !container.read(skillImportControllerProvider(null)).busy,
      );
      await tester.pumpAndSettle();
      final skill = (await repository.list()).single;
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      router.push('/settings/extensions/skills/${skill.id}');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('skill-global-enabled')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      if (_capture && scale == 1) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('build/e2_skill_${dark ? 'dark' : 'light'}.png');
          await output.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.scrollUntilVisible(find.text('SKILL.md'), 200);
      await tester.runAsync(() async {
        await tester.tap(find.text('SKILL.md'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await _pumpUntil(
        tester,
        () =>
            find.byType(SkillResourcePage).evaluate().isNotEmpty &&
            find.byType(AppLoadingIndicator).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(SelectableText),
        100,
        scrollable: find
            .descendant(
              of: find.byType(SkillResourcePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byType(SelectableText), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await _pumpIo(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('skill-global-enabled')),
        -200,
      );
      await tester.tap(find.byKey(const ValueKey('skill-global-enabled')));
      await tester.pumpAndSettle();
      expect((await repository.get(skill.id))!.enabled, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpIo(tester);
    });
  }

  testWidgets('助手 Skill 选择仅改草稿，取消保留原值，保存默认询问', (tester) async {
    late ToolLoopHarness h;
    late String skillId;
    await tester.runAsync(() async {
      h = await ToolLoopHarness.create();
      final repository = await h.container.read(skillRepositoryProvider.future);
      final source = Directory('${h.tempDir.path}/source');
      await source.create();
      await File('${source.path}/SKILL.md').writeAsString(sampleSkill);
      final package = await repository.packages.prepare(
        source.path,
        zip: false,
        cancellation: RunCancellation(),
      );
      skillId = (await repository.install(package, RunCancellation())).id;
    });
    final assistants = (await tester.runAsync(
      () => h.container.read(assistantRepositoryProvider.future),
    ))!;
    final assistant = (await tester.runAsync(assistants.ensureDefault))!;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('助手列表')),
        ),
        GoRoute(
          path: '/edit',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: AssistantEditPage(assistantId: assistant.id),
          ),
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
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final save in [false, true]) {
      router.push('/edit');
      await _pumpIo(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(AssistantSkillsSection),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('assistant-edit-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await _pumpIo(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('skill-enable-$skillId')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('assistant-edit-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(ValueKey('skill-enable-$skillId')));
      await tester.pumpAndSettle();
      expect((await assistants.getById(assistant.id))!.skillIds, isEmpty);
      if (save) {
        await tester.tap(find.byKey(const ValueKey('save-assistant')));
        await _pumpIo(tester);
        await tester.pumpAndSettle();
      } else {
        router.pop();
        await tester.pumpAndSettle();
      }
      expect(
        (await assistants.getById(assistant.id))!.skillIds,
        save ? {skillId} : isEmpty,
      );
    }
    final saved = (await assistants.getById(assistant.id))!;
    expect(
      saved.toolPolicy.policies['read_skill'] ?? ToolPolicy.ask,
      ToolPolicy.ask,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpIo(tester);
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(condition(), isTrue, reason: '等待真实文件 IO 与 widget 更新');
}

Future<void> _pumpIo(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}
