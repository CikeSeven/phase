import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/profile_model.dart';

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
