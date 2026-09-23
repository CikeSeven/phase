import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phase/core/error/failure.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/data/datasources/local/model_catalog_cache.dart';
import 'package:phase/data/models/model_catalog.dart';

/// 目录缓存落盘：读写往返、损坏与缺失都按无缓存处理。
void main() {
  late Directory tempDir;
  late ModelCatalogCache cache;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('phase_model_catalog');
    cache = ModelCatalogCache(Directory(p.join(tempDir.path, 'catalog')));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  const catalog = ModelCatalog(
    providers: {
      'anthropic': {
        'claude-haiku-4-5': ModelCatalogEntry(
          contextWindow: 200000,
          maxOutputTokens: 64000,
        ),
      },
    },
  );

  test('缺失文件返回 null', () async {
    expect(await cache.read(), isNull);
  });

  test('写入后可读回，etag 一并保存', () async {
    final fetched = ModelCatalog(
      providers: catalog.providers,
      fetchedAt: DateTime.utc(2026, 9, 23),
    );
    await cache.write(CachedModelCatalog(catalog: fetched, etag: '"abc"'));
    final restored = await cache.read();
    expect(restored, isNotNull);
    expect(restored!.etag, '"abc"');
    expect(restored.catalog.fetchedAt, DateTime.utc(2026, 9, 23));
    expect(
      restored.catalog.lookup('anthropic', 'claude-haiku-4-5')?.contextWindow,
      200000,
    );
  });

  test('损坏 JSON 返回 null 且不抛异常', () async {
    final file = File(p.join(tempDir.path, 'catalog', 'catalog.json'));
    await file.parent.create(recursive: true);
    await file.writeAsString('{broken');
    expect(await cache.read(), isNull);
  });

  test('clear 删除缓存', () async {
    await cache.write(const CachedModelCatalog(catalog: catalog));
    expect(await cache.read(), isNotNull);
    await cache.clear();
    expect(await cache.read(), isNull);
  });
  test('并发写入不混用目录与 ETag，也不留下暂存文件', () async {
    final next = ModelCatalog(
      providers: catalog.providers,
      fetchedAt: DateTime.utc(2026, 9, 24),
    );
    await Future.wait([
      cache.write(const CachedModelCatalog(catalog: catalog, etag: 'first')),
      cache.write(CachedModelCatalog(catalog: next, etag: 'second')),
    ]);
    final restored = (await cache.read())!;
    expect(
      restored.catalog.fetchedAt,
      restored.etag == 'first' ? null : next.fetchedAt,
    );
    expect(cache.root.listSync().map((e) => p.basename(e.path)), [
      'catalog.json',
    ]);
  });

  test('文件写入失败映射 StorageFailure，不伪装成功', () async {
    await File(cache.root.path).writeAsString('not a directory');
    await expectLater(
      cache.write(const CachedModelCatalog(catalog: catalog)),
      throwsA(isA<StorageFailure>()),
    );
  });

  testWidgets('首次读取等待缓存初始化，已有缓存优先于内置快照', (tester) async {
    await tester.runAsync(() async {
      final cached = ModelCatalog(
        providers: const {
          'anthropic': {
            'claude-haiku-4-5': ModelCatalogEntry(contextWindow: 300000),
          },
        },
        fetchedAt: DateTime.utc(2026, 9, 23),
      );
      await cache.write(CachedModelCatalog(catalog: cached, etag: 'cache'));
      final gate = Completer<ModelCatalogCache>();
      final container = ProviderContainer(
        overrides: [
          modelCatalogCacheProvider.overrideWith((ref) => gate.future),
        ],
      );
      try {
        var completed = false;
        final pending = container.read(modelCatalogProvider.future).then((
          value,
        ) {
          completed = true;
          return value;
        });
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(completed, isFalse);
        gate.complete(cache);
        final actual = await pending;
        expect(
          actual.lookup('anthropic', 'claude-haiku-4-5')?.contextWindow,
          300000,
        );
        expect(actual.fetchedAt, cached.fetchedAt);
      } finally {
        container.dispose();
      }
    });
  });

  testWidgets('损坏缓存和缓存初始化失败都回退内置快照', (tester) async {
    await tester.runAsync(() async {
      await cache.root.create(recursive: true);
      await File(p.join(cache.root.path, 'catalog.json'))
          .writeAsString('{broken');
    });
    for (final unavailable in [false, true]) {
      final container = ProviderContainer(
        overrides: [
          modelCatalogCacheProvider.overrideWith((ref) async {
            if (unavailable) throw const StorageFailure('fixture');
            return cache;
          }),
        ],
      );
      try {
        container.read(modelCatalogProvider);
        for (
          var i = 0;
          i < 200 && container.read(modelCatalogProvider).isLoading;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 10));
        }
        final actual = container.read(modelCatalogProvider).requireValue;
        expect(
          actual.lookup('anthropic', 'claude-haiku-4-5')?.contextWindow,
          200000,
        );
        expect(actual.fetchedAt, isNull);
        expect(
          actual.providers.values
              .expand((models) => models.values)
              .every(
                (entry) =>
                    (entry.contextWindow == null || entry.contextWindow! > 0) &&
                    (entry.maxOutputTokens == null ||
                        entry.maxOutputTokens! > 0),
              ),
          isTrue,
        );
      } finally {
        container.dispose();
      }
    }
  });
}
