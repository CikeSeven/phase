import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/profile_model.dart';

void main() {
  group('decodeProfileModels 兼容读取', () {
    test('老格式纯字符串列表自动转换，推理默认支持', () {
      final models = decodeProfileModels(
        '["deepseek-chat","deepseek-reasoner","gpt-5"]',
      );
      expect(models, hasLength(3));
      expect(models[0].id, 'deepseek-chat');
      for (final model in models) {
        expect(model.supportsReasoning, isTrue, reason: model.id);
      }
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
        ProfileModel(id: 'y', supportsReasoning: false),
        ProfileModel(
          id: 'z',
          enabled: false,
          supportsTools: true,
          supportsImages: true,
        ),
      ];
      final roundTrip = decodeProfileModels(encodeProfileModels(original));
      expect(roundTrip[0].id, 'x');
      expect(roundTrip[0].supportsReasoning, isTrue);
      expect(roundTrip[1].supportsReasoning, isFalse);
      expect(roundTrip[2].enabled, isFalse);
      expect(roundTrip[2].supportsTools, isTrue);
      expect(roundTrip[2].supportsImages, isTrue);
    });

    test('老数据缺能力字段解码为启用且默认支持工具与图片', () {
      final legacy = decodeProfileModels(
        '[{"id":"a","supportsReasoning":true}]',
      );
      expect(legacy[0].enabled, isTrue);
      expect(legacy[0].supportsTools, isTrue);
      expect(legacy[0].supportsImages, isTrue);
      // 缺推理标记同样按支持处理。
      expect(decodeProfileModels('[{"id":"b"}]')[0].supportsReasoning, isTrue);
    });
  });
}
