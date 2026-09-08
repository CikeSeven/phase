import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/providers/presets/provider_preset.dart';

void main() {
  test('预设 id 唯一', () {
    final ids = providerPresets.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('协议均为合法 ApiProtocol，baseUrl 形态正确', () {
    for (final preset in providerPresets) {
      expect(ApiProtocol.values, contains(preset.protocol));
      if (preset.id == 'custom') {
        expect(preset.baseUrl, isEmpty);
      } else {
        expect(preset.baseUrl, startsWith('http'));
      }
    }
  });

  test('关键预设的协议与地址', () {
    expect(presetById('openai').protocol, ApiProtocol.openaiResponses);
    expect(presetById('anthropic').protocol, ApiProtocol.anthropicMessages);
    expect(presetById('google').protocol, ApiProtocol.googleGenerativeAi);
    expect(presetById('deepseek').protocol, ApiProtocol.openaiCompletions);
    expect(presetById('xai').protocol, ApiProtocol.openaiResponses);
  });

  test('ollama 不需要 API Key', () {
    expect(presetById('ollama').requiresApiKey, isFalse);
    expect(presetById('openai').requiresApiKey, isTrue);
  });

  test('未知 id 回退 custom', () {
    expect(presetById('不存在的').id, 'custom');
  });
}
