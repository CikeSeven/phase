import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/reasoning_effort.dart';

void main() {
  group('decodeProfileModels 兼容读取', () {
    test('老格式纯字符串列表自动转换并启发式预填推理标记', () {
      final models = decodeProfileModels(
        '["deepseek-chat","deepseek-reasoner","gpt-5"]',
      );
      expect(models, hasLength(3));
      expect(models[0].id, 'deepseek-chat');
      expect(models[0].supportsReasoning, isFalse);
      expect(models[1].supportsReasoning, isTrue);
      expect(models[2].supportsReasoning, isTrue);
    });

    test('新格式对象列表完整还原', () {
      final models = decodeProfileModels(
        '[{"id":"a","supportsReasoning":true},{"id":"b","supportsReasoning":false}]',
      );
      expect(models[0].supportsReasoning, isTrue);
      expect(models[1].supportsReasoning, isFalse);
    });

    test('非法 JSON 与空数组返回空列表', () {
      expect(decodeProfileModels('{oops'), isEmpty);
      expect(decodeProfileModels('[]'), isEmpty);
    });

    test('encode/decode 往返', () {
      const original = [
        ProfileModel(id: 'x', supportsReasoning: true),
        ProfileModel(id: 'y'),
      ];
      final roundTrip = decodeProfileModels(encodeProfileModels(original));
      expect(roundTrip[0].id, 'x');
      expect(roundTrip[0].supportsReasoning, isTrue);
      expect(roundTrip[1].supportsReasoning, isFalse);
    });
  });

  group('推理等级范围', () {
    test('缺省与空列表表示不限制，未知等级名被忽略', () {
      const open = ProfileModel(id: 'a', supportsReasoning: true);
      expect(open.reasoningEfforts, isEmpty);
      expect(open.allowedEfforts, ReasoningEffort.levels);

      const limited = ProfileModel(
        id: 'b',
        supportsReasoning: true,
        reasoningEfforts: ['low', 'bogus'],
      );
      expect(limited.allowedEfforts, [ReasoningEffort.low]);
    });

    test('老数据缺 reasoningEfforts 字段解码为不限制，新字段随往返保留', () {
      final legacy = decodeProfileModels(
        '[{"id":"a","supportsReasoning":true}]',
      );
      expect(legacy[0].reasoningEfforts, isEmpty);
      expect(legacy[0].allowedEfforts, ReasoningEffort.levels);

      const original = [
        ProfileModel(
          id: 'x',
          supportsReasoning: true,
          reasoningEfforts: ['low', 'high'],
        ),
      ];
      final roundTrip = decodeProfileModels(encodeProfileModels(original));
      expect(roundTrip[0].reasoningEfforts, ['low', 'high']);
      expect(roundTrip[0].allowedEfforts, [
        ReasoningEffort.low,
        ReasoningEffort.high,
      ]);
    });

    test('normalizeLevels 全选记为空列表，off 不参与存储', () {
      expect(ReasoningEffort.normalizeLevels(ReasoningEffort.values), isEmpty);
      expect(ReasoningEffort.normalizeLevels(ReasoningEffort.levels), isEmpty);
      expect(
        ReasoningEffort.normalizeLevels([
          ReasoningEffort.high,
          ReasoningEffort.off,
          ReasoningEffort.low,
        ]),
        ['low', 'high'],
      );
    });

    test('nearestAllowedEffort 就近降级，没有更低等级时取最近的更高等级', () {
      const limited = ProfileModel(
        id: 'a',
        supportsReasoning: true,
        reasoningEfforts: ['low', 'high', 'max'],
      );
      // 已允许与 off 原样返回。
      expect(
        limited.nearestAllowedEffort(ReasoningEffort.high),
        ReasoningEffort.high,
      );
      expect(
        limited.nearestAllowedEffort(ReasoningEffort.off),
        ReasoningEffort.off,
      );
      // 超高 → 降级为高，中 → 降级为低。
      expect(
        limited.nearestAllowedEffort(ReasoningEffort.xhigh),
        ReasoningEffort.high,
      );
      expect(
        limited.nearestAllowedEffort(ReasoningEffort.medium),
        ReasoningEffort.low,
      );
      // 没有更低等级时取最近的更高等级。
      const onlyHigh = ProfileModel(
        id: 'b',
        supportsReasoning: true,
        reasoningEfforts: ['high'],
      );
      expect(
        onlyHigh.nearestAllowedEffort(ReasoningEffort.low),
        ReasoningEffort.high,
      );
    });
  });

  group('guessSupportsReasoning', () {
    test('推理模型命名命中', () {
      for (final id in [
        'deepseek-reasoner',
        'r1-distill',
        'o1-mini',
        'o3',
        'gpt-5-pro',
        'qwq-32b',
        'claude-sonnet-4',
        'gemini-2.5-pro',
        'gemini-3-pro',
        'kimi-thinking-preview',
      ]) {
        expect(guessSupportsReasoning(id), isTrue, reason: id);
      }
    });

    test('普通模型不命中', () {
      for (final id in ['gpt-4o', 'deepseek-chat', 'llama3.1', 'qwen2.5']) {
        expect(guessSupportsReasoning(id), isFalse, reason: id);
      }
    });
  });
}
