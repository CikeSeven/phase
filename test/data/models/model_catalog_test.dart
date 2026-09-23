import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/model_catalog.dart';

/// 目录精简、查找与优先级解析：用户手填始终优先，未编目走本地默认。
void main() {
  final apiJson = <String, dynamic>{
    'anthropic': {
      'id': 'anthropic',
      'models': {
        'claude-haiku-4-5': {
          'id': 'claude-haiku-4-5',
          'limit': {'context': 200000, 'output': 64000},
        },
        'claude-no-limit': {'id': 'claude-no-limit'},
      },
    },
    'openrouter': {
      'id': 'openrouter',
      'models': {
        'openai/gpt-5': {
          'limit': {'context': 400000, 'output': 128000},
        },
        'azure/gpt-5': {
          'limit': {'context': 272000, 'output': 64000},
        },
      },
    },
    // 无映射的服务商不进目录。
    'deepinfra': {
      'models': {
        'tencent/Hy3': {
          'limit': {'context': 131072, 'output': 8192},
        },
      },
    },
  };

  group('slimFromModelsDevJson', () {
    test('只保留映射服务商与有上限的模型', () {
      final catalog = ModelCatalog.slimFromModelsDevJson(apiJson);
      expect(catalog.providers.keys, containsAll(['anthropic', 'openrouter']));
      expect(catalog.providers.keys, isNot(contains('deepinfra')));
      expect(
        catalog.providers['anthropic']!.keys,
        contains('claude-haiku-4-5'),
      );
      // 没有 limit 的模型不进目录，查找返回 null。
      expect(catalog.providers['anthropic']!.keys, hasLength(1));
      expect(catalog.lookup('anthropic', 'claude-no-limit'), isNull);
    });

    test('零、负数、非有限数和非数字不作为有效上限', () {
      for (final invalid in [
        0,
        -1,
        double.nan,
        double.infinity,
        '8192',
        null,
      ]) {
        final catalog = ModelCatalog.slimFromModelsDevJson({
          'openai': {
            'models': {
              'partial': {
                'limit': {'context': 200000, 'output': invalid},
              },
              'invalid': {
                'limit': {'context': invalid, 'output': invalid},
              },
            },
          },
        });
        expect(catalog.modelCount, 1);
        expect(catalog.lookup('openai', 'partial')?.contextWindow, 200000);
        expect(catalog.lookup('openai', 'partial')?.maxOutputTokens, isNull);
        expect(catalog.lookup('openai', 'invalid'), isNull);
      }
    });

    test('limit 字段数字容忍 double 编码', () {
      final catalog = ModelCatalog.slimFromModelsDevJson({
        'anthropic': {
          'models': {
            'x': {
              'limit': {'context': 200000.0, 'output': 64000.5},
            },
          },
        },
      });
      final entry = catalog.lookup('anthropic', 'x');
      expect(entry?.contextWindow, 200000);
      expect(entry?.maxOutputTokens, 64000);
    });
  });

  group('lookup', () {
    final catalog = ModelCatalog.slimFromModelsDevJson(apiJson);

    test('精确 id 命中', () {
      final entry = catalog.lookup('anthropic', 'claude-haiku-4-5');
      expect(entry?.contextWindow, 200000);
      expect(entry?.maxOutputTokens, 64000);
    });

    test('未映射 preset 返回 null', () {
      expect(catalog.lookup('custom', 'claude-haiku-4-5'), isNull);
      expect(catalog.lookup('ollama', 'claude-haiku-4-5'), isNull);
    });

    test('裸 id 匹配命名空间目录条目', () {
      // openrouter 下 azure/gpt-5 与 openai/gpt-5 末段相同，
      // 按 key 排序取首个（azure/gpt-5），保证确定性。
      final entry = catalog.lookup('openrouter', 'gpt-5');
      expect(entry?.contextWindow, 272000);
    });

    test('命名空间 id 匹配裸目录条目', () {
      const namespaced = ModelCatalog(
        providers: {
          'alibaba': {'qwen3-max': ModelCatalogEntry(contextWindow: 262144)},
        },
      );
      expect(
        namespaced.lookup('qwen', 'dashscope/qwen3-max')?.contextWindow,
        262144,
      );
    });

    test('精确全 id 优先于末段匹配', () {
      const catalog = ModelCatalog(
        providers: {
          'openrouter': {
            'openai/gpt-5': ModelCatalogEntry(contextWindow: 400000),
            'gpt-5': ModelCatalogEntry(contextWindow: 999000),
          },
        },
      );
      expect(catalog.lookup('openrouter', 'gpt-5')?.contextWindow, 999000);
    });

    test('未知模型返回 null', () {
      expect(catalog.lookup('anthropic', 'gpt-5'), isNull);
    });
  });

  group('toJson/tryParse 往返', () {
    test('完整往返', () {
      final fetchedAt = DateTime.utc(2026, 9, 23, 12);
      final catalog = ModelCatalog.slimFromModelsDevJson(
        apiJson,
        fetchedAt: fetchedAt,
      );
      final parsed = ModelCatalog.tryParse(jsonEncode(catalog.toJson()));
      expect(parsed, isNotNull);
      expect(parsed!.fetchedAt, fetchedAt);
      expect(parsed.providers.keys, catalog.providers.keys);
      expect(
        parsed.lookup('anthropic', 'claude-haiku-4-5')?.contextWindow,
        200000,
      );
    });

    test('内置快照无 fetchedAt', () {
      final catalog = ModelCatalog.slimFromModelsDevJson(apiJson);
      final parsed = ModelCatalog.tryParse(jsonEncode(catalog.toJson()));
      expect(parsed?.fetchedAt, isNull);
    });

    test('损坏输入返回 null', () {
      expect(ModelCatalog.tryParse('not json'), isNull);
      expect(ModelCatalog.tryParse('{"v":1,"providers":{}}'), isNull);
      expect(
        ModelCatalog.tryParse(
          '{"v":1,"providers":{"openai":{"x":{"c":0,"o":-1}}}}',
        ),
        isNull,
      );
      expect(
        ModelCatalog.tryParse(
          jsonEncode({
            ...ModelCatalog.slimFromModelsDevJson(apiJson).toJson(),
            'fetchedAt': 'corrupt',
          }),
        ),
        isNull,
      );
      expect(ModelCatalog.tryParse('{"v":2,"providers":{}}'), isNull);
      expect(ModelCatalog.tryParse('{"v":1}'), isNull);
      expect(ModelCatalog.tryParse('[1,2]'), isNull);
      expect(
        ModelCatalog.tryParse('{"v":1,"providers":{"a":{"b":"x"}}}'),
        isNull,
      );
    });
  });

  group('resolveContextLimits', () {
    final catalog = ModelCatalog.slimFromModelsDevJson(apiJson);

    test('用户手填窗口优先，目录输出上限仍可用于预留', () {
      final resolved = resolveContextLimits(
        presetId: 'anthropic',
        modelId: 'claude-haiku-4-5',
        userContextWindow: 65536,
        userMaxOutputTokens: null,
        catalog: catalog,
      );
      expect(resolved.contextWindow, 65536);
      expect(resolved.source, ContextWindowSource.user);
      expect(resolved.catalogMaxOutputTokens, 64000);
    });

    test('目录命中时窗口与输出上限都来自目录', () {
      final resolved = resolveContextLimits(
        presetId: 'anthropic',
        modelId: 'claude-haiku-4-5',
        userContextWindow: null,
        userMaxOutputTokens: null,
        catalog: catalog,
      );
      expect(resolved.contextWindow, 200000);
      expect(resolved.source, ContextWindowSource.catalog);
      expect(resolved.catalogMaxOutputTokens, 64000);
    });

    test('用户已设输出上限时不携带目录输出上限', () {
      final resolved = resolveContextLimits(
        presetId: 'anthropic',
        modelId: 'claude-haiku-4-5',
        userContextWindow: null,
        userMaxOutputTokens: 8192,
        catalog: catalog,
      );
      expect(resolved.contextWindow, 200000);
      expect(resolved.catalogMaxOutputTokens, isNull);
    });

    test('未编目走本地默认 128000', () {
      final resolved = resolveContextLimits(
        presetId: 'custom',
        modelId: 'whatever',
        userContextWindow: null,
        userMaxOutputTokens: null,
        catalog: catalog,
      );
      expect(resolved.contextWindow, ModelCatalog.localDefaultWindow);
      expect(resolved.source, ContextWindowSource.localDefault);
      expect(resolved.catalogMaxOutputTokens, isNull);
    });

    test('目录只有输出上限时窗口走默认、预留仍用目录', () {
      const catalog = ModelCatalog(
        providers: {
          'groq': {'llama-x': ModelCatalogEntry(maxOutputTokens: 16384)},
        },
      );
      final resolved = resolveContextLimits(
        presetId: 'groq',
        modelId: 'llama-x',
        userContextWindow: null,
        userMaxOutputTokens: null,
        catalog: catalog,
      );
      expect(resolved.contextWindow, ModelCatalog.localDefaultWindow);
      expect(resolved.source, ContextWindowSource.localDefault);
      expect(resolved.catalogMaxOutputTokens, 16384);
    });
  });
}
