import '../../data/models/api_protocol.dart';

/// 服务商预设：协议与 Base URL 的声明式数据。
///
/// 协议与服务商正交——预设只是「protocol + baseUrl + 展示信息」，
/// 不含任何分支逻辑。
class ProviderPreset {
  const ProviderPreset({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    this.requiresApiKey = true,
    this.note,
  });

  final String id;
  final String name;
  final ApiProtocol protocol;
  final String baseUrl;

  /// 本地服务（如 Ollama）不需要 API Key，表单隐藏 Key 输入。
  final bool requiresApiKey;
  final String? note;
}

/// 内置服务商预设。id 必须唯一。
const providerPresets = <ProviderPreset>[
  ProviderPreset(
    id: 'openai',
    name: 'OpenAI',
    protocol: ApiProtocol.openaiResponses,
    baseUrl: 'https://api.openai.com/v1',
  ),
  ProviderPreset(
    id: 'anthropic',
    name: 'Anthropic',
    protocol: ApiProtocol.anthropicMessages,
    baseUrl: 'https://api.anthropic.com',
  ),
  ProviderPreset(
    id: 'google',
    name: 'Google',
    protocol: ApiProtocol.googleGenerativeAi,
    baseUrl: 'https://generativelanguage.googleapis.com',
  ),
  ProviderPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    protocol: ApiProtocol.openaiCompletions,
    baseUrl: 'https://api.deepseek.com',
  ),
  ProviderPreset(
    id: 'moonshot',
    name: 'Moonshot',
    protocol: ApiProtocol.openaiCompletions,
    baseUrl: 'https://api.moonshot.cn/v1',
  ),
  ProviderPreset(
    id: 'zhipu',
    name: '智谱',
    protocol: ApiProtocol.openaiCompletions,
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
  ),
  ProviderPreset(
    id: 'openrouter',
    name: 'OpenRouter',
    protocol: ApiProtocol.openaiCompletions,
    baseUrl: 'https://openrouter.ai/api/v1',
  ),
  ProviderPreset(
    id: 'groq',
    name: 'Groq',
    protocol: ApiProtocol.openaiCompletions,
    baseUrl: 'https://api.groq.com/openai/v1',
  ),
  ProviderPreset(
    id: 'xai',
    name: 'xAI',
    protocol: ApiProtocol.openaiResponses,
    baseUrl: 'https://api.x.ai/v1',
  ),
  ProviderPreset(
    id: 'ollama',
    name: 'Ollama',
    protocol: ApiProtocol.openaiCompletions,
    baseUrl: 'http://localhost:11434/v1',
    requiresApiKey: false,
    note: '本地服务，无需 API Key',
  ),
  ProviderPreset(
    id: 'custom',
    name: '自定义（OpenAI 兼容）',
    protocol: ApiProtocol.openaiCompletions,
    baseUrl: '',
  ),
];

/// 按 id 查预设；未知 id 回退 custom（老数据行为）。
ProviderPreset presetById(String id) {
  for (final preset in providerPresets) {
    if (preset.id == id) {
      return preset;
    }
  }
  return providerPresets.last;
}
