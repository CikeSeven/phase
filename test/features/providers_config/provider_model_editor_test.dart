import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/datasources/local/model_catalog_cache.dart';
import 'package:phase/data/models/model_catalog.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/features/providers_config/provider_model_editor.dart';

import 'provider_test_harness.dart';

/// 编辑器的目录感知：命中 models.dev 显示目录值，未命中回退本地默认；
/// 目录值只进提示与校验基线，绝不回写用户输入。
void main() {
  late Directory cacheDir;

  setUp(() {
    cacheDir = Directory.systemTemp.createTempSync('phase_model_editor');
  });

  tearDown(() {
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    required List<ProfileModel> models,
    required void Function(ProfileModel) onModelChanged,
    String presetId = 'anthropic',
    ModelCatalog? catalog,
    ModelCatalog Function()? readCatalog,
    Future<ModelCatalog> Function()? loadCatalog,
    bool settle = true,
    Size size = const Size(420, 2400),
    double scale = 1,
    ThemeData? theme,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelCatalogCacheProvider.overrideWith(
            (ref) async => ModelCatalogCache(cacheDir),
          ),
          if (catalog != null || readCatalog != null || loadCatalog != null)
            modelCatalogProvider.overrideWith(
              (ref) async => loadCatalog != null
                  ? await loadCatalog()
                  : readCatalog?.call() ?? catalog!,
            ),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                ProviderModelEditor(
                  presetId: presetId,
                  models: models,
                  enabled: true,
                  onAdd: () {},
                  onModelChanged: onModelChanged,
                  onRemove: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProviderModelEditor)),
    );
    if (settle) {
      await pumpProviderUntil(
        tester,
        () => !container.read(modelCatalogProvider).isLoading,
      );
    }
  }

  String? hintOf(WidgetTester tester, String key) =>
      tester.widget<TextField>(keyed(key)).decoration?.hintText;

  String? helperOf(WidgetTester tester, String key) =>
      tester.widget<TextField>(keyed(key)).decoration?.helperText;

  Future<void> fillField(WidgetTester tester, String key, String text) async {
    final field = keyed(key);
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.enterText(field, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('命中内置快照显示 models.dev 提示，未命中回退本地默认', (tester) async {
    await pumpEditor(
      tester,
      models: const [
        ProfileModel(id: 'claude-haiku-4-5'),
        ProfileModel(id: 'my-private-model'),
      ],
      onModelChanged: (_) {},
    );

    expect(
      hintOf(tester, 'context-window-claude-haiku-4-5'),
      'models.dev 200000',
    );
    expect(hintOf(tester, 'max-output-claude-haiku-4-5'), 'models.dev 64000');
    expect(hintOf(tester, 'context-window-my-private-model'), '本地默认 128000');
    expect(hintOf(tester, 'max-output-my-private-model'), '本地默认 4096');
    expect(
      helperOf(tester, 'context-window-claude-haiku-4-5'),
      contains('models.dev 目录'),
    );
  });

  testWidgets('校验按目录窗口判定边界，窗口足够时放行', (tester) async {
    const entry = ModelCatalogEntry(contextWindow: 8192, maxOutputTokens: 4096);
    final catalog = ModelCatalog(
      providers: {
        'anthropic': {'haiku-mini': entry},
      },
    );
    final changed = <ProfileModel>[];
    await pumpEditor(
      tester,
      models: const [ProfileModel(id: 'haiku-mini')],
      onModelChanged: changed.add,
      catalog: catalog,
    );
    expect(hintOf(tester, 'context-window-haiku-mini'), 'models.dev 8192');

    // 目录窗口 8192：输出上限 7168 只差 1024，不足 1024 → 报错且不落值。
    await fillField(tester, 'max-output-haiku-mini', '7168');
    expect(find.text('窗口至少 2048，且需大于输出预留加 1024；输出上限须为正整数'), findsOneWidget);
    expect(changed, isEmpty);

    // 输出上限 1000：8192 > 2024 → 放行；窗口留空时按目录值参与校验。
    await fillField(tester, 'max-output-haiku-mini', '1000');
    expect(find.text('窗口至少 2048，且需大于输出预留加 1024；输出上限须为正整数'), findsNothing);
    expect(changed.single.maxOutputTokens, 1000);
    expect(changed.single.contextWindow, isNull);
  });

  testWidgets('目录值只作提示，绝不回写用户输入', (tester) async {
    const entry = ModelCatalogEntry(contextWindow: 8192, maxOutputTokens: 4096);
    final catalog = ModelCatalog(
      providers: {
        'anthropic': {'haiku-mini': entry},
      },
    );
    final changed = <ProfileModel>[];
    await pumpEditor(
      tester,
      models: const [ProfileModel(id: 'haiku-mini')],
      onModelChanged: changed.add,
      catalog: catalog,
    );

    await fillField(tester, 'context-window-haiku-mini', '50000');
    expect(changed.single.contextWindow, 50000);
    expect(changed.single.maxOutputTokens, isNull);
    expect(
      tester
          .widget<TextField>(keyed('context-window-haiku-mini'))
          .controller!
          .text,
      '50000',
    );
    // 未填的输出上限不被目录值预填，提示仍是目录值。
    expect(
      tester.widget<TextField>(keyed('max-output-haiku-mini')).controller!.text,
      '',
    );
    expect(hintOf(tester, 'max-output-haiku-mini'), 'models.dev 4096');
  });
  testWidgets('刷新目录只更新提示，不改变手填草稿或触发保存', (tester) async {
    var catalog = const ModelCatalog(
      providers: {
        'anthropic': {
          'm': ModelCatalogEntry(contextWindow: 200000, maxOutputTokens: 64000),
        },
      },
    );
    final changed = <ProfileModel>[];
    await pumpEditor(
      tester,
      models: const [ProfileModel(id: 'm')],
      readCatalog: () => catalog,
      onModelChanged: changed.add,
    );
    await tester.enterText(keyed('context-window-m'), '123456');
    catalog = const ModelCatalog(
      providers: {
        'anthropic': {
          'm': ModelCatalogEntry(contextWindow: 300000, maxOutputTokens: 8192),
        },
      },
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProviderModelEditor)),
    );
    container.invalidate(modelCatalogProvider);
    await tester.pumpAndSettle();
    expect(hintOf(tester, 'context-window-m'), 'models.dev 300000');
    expect(hintOf(tester, 'max-output-m'), 'models.dev 8192');
    expect(
      tester.widget<TextField>(keyed('context-window-m')).controller!.text,
      '123456',
    );
    expect(
      tester.widget<TextField>(keyed('max-output-m')).controller!.text,
      isEmpty,
    );
    expect(changed, isEmpty);
  });

  testWidgets('自定义服务商不借用同名模型目录，默认窗口允许大于旧默认的输出', (tester) async {
    final changed = <ProfileModel>[];
    await pumpEditor(
      tester,
      presetId: 'custom',
      models: const [ProfileModel(id: 'claude-haiku-4-5')],
      catalog: const ModelCatalog(
        providers: {
          'anthropic': {
            'claude-haiku-4-5': ModelCatalogEntry(
              contextWindow: 200000,
              maxOutputTokens: 64000,
            ),
          },
        },
      ),
      onModelChanged: changed.add,
    );
    expect(hintOf(tester, 'context-window-claude-haiku-4-5'), '本地默认 128000');
    expect(hintOf(tester, 'max-output-claude-haiku-4-5'), '本地默认 4096');
    await fillField(tester, 'max-output-claude-haiku-4-5', '64000');
    expect(changed.single.contextWindow, isNull);
    expect(changed.single.maxOutputTokens, 64000);
  });
  testWidgets('目录加载期间提交也等待真实目录校验，不用临时默认误放行', (tester) async {
    final gate = Completer<ModelCatalog>();
    final changed = <ProfileModel>[];
    await pumpEditor(
      tester,
      models: const [ProfileModel(id: 'm')],
      loadCatalog: () => gate.future,
      settle: false,
      onModelChanged: changed.add,
    );
    await fillField(tester, 'max-output-m', '10000');
    expect(changed, isEmpty);
    gate.complete(
      const ModelCatalog(
        providers: {
          'anthropic': {
            'm': ModelCatalogEntry(contextWindow: 8192, maxOutputTokens: 4096),
          },
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('窗口至少 2048，且需大于输出预留加 1024；输出上限须为正整数'), findsOneWidget);
    expect(changed, isEmpty);
    await fillField(tester, 'max-output-m', '1000');
    expect(changed.single.maxOutputTokens, 1000);
  });

  for (final dark in [false, true]) {
    testWidgets('目录提示在 320dp / 2x 字号 ${dark ? '深色' : '浅色'} 下可编辑且无溢出', (
      tester,
    ) async {
      final changed = <ProfileModel>[];
      await pumpEditor(
        tester,
        models: const [ProfileModel(id: 'm')],
        size: const Size(320, 640),
        scale: 2,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        catalog: const ModelCatalog(
          providers: {
            'anthropic': {
              'm': ModelCatalogEntry(
                contextWindow: 200000,
                maxOutputTokens: 64000,
              ),
            },
          },
        ),
        onModelChanged: changed.add,
      );
      await fillField(tester, 'max-output-m', '8192');
      expect(changed.last.maxOutputTokens, 8192);
      expect(changed.last.contextWindow, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
