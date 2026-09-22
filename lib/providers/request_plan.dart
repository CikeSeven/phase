import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/models/api_protocol.dart';
import '../data/models/chat_request.dart';
import '../data/models/openai_compat.dart';
import '../data/models/provider_profile.dart';
import '../data/models/tool_source.dart';
import 'attachment_encoder.dart';
import 'anthropic_messages/anthropic_decoder.dart';
import 'google_generative_ai/google_decoder.dart';
import 'openai_completions/openai_completions_provider.dart';
import 'openai_responses/responses_decoder.dart';

/// 复用适配器编码器；此负载也是随后真正发送的负载，计量不另写协议规则。
class RequestPlan {
  RequestPlan(this.request, this.payload, this.profile) {
    final input = <String, dynamic>{};
    for (final key in const [
      'system',
      'systemInstruction',
      'messages',
      'input',
      'contents',
      'tools',
    ]) {
      if (payload.containsKey(key)) input[key] = _project(payload[key]);
    }
    inputFingerprint = contextHash(input);
    final params = Map<String, dynamic>.of(payload)
      ..removeWhere((k, _) => input.containsKey(k));
    configurationFingerprint = contextHash({
      'profile': profile.id,
      'protocol': profile.protocol.name,
      'endpoint': profile.baseUrl,
      'images': modelSupportsImages(profile, request.modelId),
      'reasoning': modelSupportsReasoning(profile, request.modelId),
      'parameters': params,
      'system': request.systemPrompt,
      'tools': input['tools'],
    });
    final systemItems = <Object?>[];
    final messageItems = <Object?>[];
    for (final key in const ['system', 'systemInstruction']) {
      if (input[key] != null) systemItems.add(input[key]);
    }
    for (final key in const ['messages', 'input', 'contents']) {
      for (final item in input[key] as List? ?? []) {
        if (item is Map &&
            const ['system', 'developer'].contains(item['role'])) {
          systemItems.add(item);
        } else {
          messageItems.add(item);
        }
      }
    }
    systemTokens = _bytes(systemItems);
    toolTokens = input['tools'] == null ? 0 : _bytes(input['tools']);
    messageTokens = _bytes(messageItems) + 64;
    final generation = payload['generationConfig'];
    effectiveOutputTokens = switch (profile.protocol) {
      ApiProtocol.anthropicMessages => payload['max_tokens'] as int?,
      ApiProtocol.openaiResponses => payload['max_output_tokens'] as int?,
      ApiProtocol.openaiCompletions =>
        (payload['max_completion_tokens'] ?? payload['max_tokens']) as int?,
      ApiProtocol.googleGenerativeAi =>
        generation is Map ? generation['maxOutputTokens'] as int? : null,
    };
    configurationSnapshot = freezeJson({
      'protocol': profile.protocol.name,
      'parameters': params,
      'supportsImages': modelSupportsImages(profile, request.modelId),
      'supportsReasoning': modelSupportsReasoning(profile, request.modelId),
      'endpointFingerprint': contextHash(profile.baseUrl),
      'systemFingerprint': contextHash(systemItems),
      'toolsFingerprint': contextHash(input['tools']),
    });
  }
  final ChatRequest request;
  final ProviderProfile profile;
  final Map<String, dynamic> payload;
  late final String configurationFingerprint;
  late final Map<String, dynamic> configurationSnapshot;
  late final String inputFingerprint;
  late final int systemTokens;
  late final int toolTokens;
  late final int messageTokens;
  int imageTokens = 0;
  late final int? effectiveOutputTokens;
  int get estimatedInputTokens =>
      systemTokens + toolTokens + messageTokens + imageTokens;
  ChatRequest get prepared => request.copyWith(preparedPayload: payload);

  Object? _project(Object? value) {
    if (value is List) return value.map(_project).toList();
    if (value is Map) {
      final isImage =
          value['type'] == 'image_url' ||
          value['type'] == 'input_image' ||
          value['type'] == 'image' ||
          value.containsKey('inline_data') ||
          value.containsKey('inlineData');
      if (isImage) {
        imageTokens += 4096;
        return {'imageFingerprint': contextHash(value)};
      }
      return {
        for (final e in value.entries) e.key.toString(): _project(e.value),
      };
    }
    return value;
  }

  int _bytes(Object? value) => utf8.encode(jsonEncode(value)).length;
}

Future<RequestPlan> planRequest(
  ProviderProfile profile,
  ChatRequest request,
) async {
  final images = modelSupportsImages(profile, request.modelId);
  final reasoning = modelSupportsReasoning(profile, request.modelId);
  final payload = await switch (profile.protocol) {
    ApiProtocol.openaiCompletions => buildCompletionsPayload(
      request,
      compat: OpenAiCompat.resolve(profile.baseUrl, profile.compatOverrides),
      supportsImages: images,
      supportsReasoning: reasoning,
    ),
    ApiProtocol.openaiResponses => buildResponsesPayload(
      request,
      supportsImages: images,
      supportsReasoning: reasoning,
    ),
    ApiProtocol.anthropicMessages => buildAnthropicPayload(
      request,
      supportsImages: images,
      supportsReasoning: reasoning,
    ),
    ApiProtocol.googleGenerativeAi => buildGooglePayload(
      request,
      supportsImages: images,
      supportsReasoning: reasoning,
    ),
  };
  return RequestPlan(request, freezeJson(payload), profile);
}

/// 指纹仅在业务存储内使用；不保存原始负载、端点或密钥。
String contextHash(Object? value) {
  Object? canonical(Object? item) {
    if (item is List) return item.map(canonical).toList();
    if (item is Map) {
      final keys = item.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(item[key])};
    }
    return item;
  }

  return sha256.convert(utf8.encode(jsonEncode(canonical(value)))).toString();
}
