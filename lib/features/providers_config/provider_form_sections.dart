import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_section.dart';
import '../../../data/models/api_protocol.dart';
import '../../../providers/presets/provider_preset.dart';
import 'provider_ui.dart';

/// 服务商身份、连接与凭证分区；草稿和异步操作由编辑页持有。
class ProviderFormSections extends StatelessWidget {
  const ProviderFormSections({
    required this.preset,
    required this.protocol,
    required this.nameController,
    required this.baseUrlController,
    required this.apiKeyController,
    required this.baseUrlFieldKey,
    required this.apiKeyVisible,
    required this.hasSavedKey,
    required this.hasCompatOverrides,
    required this.enabled,
    required this.testing,
    required this.onChoosePreset,
    required this.onProtocolChanged,
    required this.onConnectionChanged,
    required this.onToggleKeyVisibility,
    required this.onTest,
    super.key,
    this.testedModelCount,
    this.testError,
  });

  final ProviderPreset preset;
  final ApiProtocol protocol;
  final TextEditingController nameController;
  final TextEditingController baseUrlController;
  final TextEditingController apiKeyController;
  final GlobalKey<FormFieldState<String>> baseUrlFieldKey;
  final bool apiKeyVisible;
  final bool hasSavedKey;
  final bool hasCompatOverrides;
  final bool enabled;
  final bool testing;
  final int? testedModelCount;
  final String? testError;
  final VoidCallback onChoosePreset;
  final ValueChanged<ApiProtocol> onProtocolChanged;
  final VoidCallback onConnectionChanged;
  final VoidCallback onToggleKeyVisibility;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSection(
          title: '服务商',
          subtitle: '从预设开始，也可以接入自己的网关。',
          child: AppCard(
            key: const ValueKey('choose-provider-preset'),
            onTap: enabled ? onChoosePreset : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AppIconBadge(
                      icon: ProviderUi.icon(preset.id),
                      tone: ProviderUi.tone(preset.id),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text('选择服务商预设', style: secondaryStyle),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    const Icon(Symbols.expand_more),
                  ],
                ),
                if (preset.note != null) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text(preset.note!, style: secondaryStyle),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          title: '连接',
          subtitle: '协议与服务商独立，按实际接口配置。',
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('provider-name'),
                  controller: nameController,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    hintText: '给这个连接起个名字',
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => onConnectionChanged(),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请输入服务商名称' : null,
                ),
                const SizedBox(height: AppSpacing.l),
                DropdownButtonFormField<ApiProtocol>(
                  key: ValueKey(protocol),
                  initialValue: protocol,
                  isExpanded: true,
                  icon: const Icon(Symbols.expand_more),
                  decoration: const InputDecoration(labelText: 'API 协议'),
                  items: [
                    for (final value in ApiProtocol.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          ProviderUi.protocolLabel(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: enabled
                      ? (value) {
                          if (value != null) onProtocolChanged(value);
                        }
                      : null,
                ),
                const SizedBox(height: AppSpacing.s),
                Text(ProviderUi.protocolHint(protocol), style: secondaryStyle),
                if (hasCompatOverrides) ...[
                  const SizedBox(height: AppSpacing.s),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppBadge(label: '保留自定义兼容设置'),
                  ),
                ],
                const SizedBox(height: AppSpacing.l),
                TextFormField(
                  key: baseUrlFieldKey,
                  controller: baseUrlController,
                  enabled: enabled,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://example.com/v1',
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => onConnectionChanged(),
                  validator: (value) {
                    final url = value?.trim() ?? '';
                    if (url.isEmpty) return '请输入 Base URL';
                    final uri = Uri.tryParse(url);
                    if (uri == null ||
                        !['http', 'https'].contains(uri.scheme) ||
                        uri.host.isEmpty) {
                      return '请输入完整的 http 或 https 地址';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s),
                Text('填写 API 基础地址，不包含具体的生成端点。', style: secondaryStyle),
                const SizedBox(height: AppSpacing.l),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('test-provider'),
                    onPressed: enabled && !testing ? onTest : null,
                    icon: testing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Symbols.cloud_download),
                    label: Text(testing ? '获取中…' : '获取模型'),
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Text('同时测试模型列表接口，不代表对话生成已验证。', style: secondaryStyle),
                if (testError != null || testedModelCount != null) ...[
                  const SizedBox(height: AppSpacing.m),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          testError == null
                              ? Symbols.check_circle
                              : Symbols.error,
                          size: 20,
                          color: testError == null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: Text(
                            testError ?? '已获取 $testedModelCount 个模型，已合并到下方列表。',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: testError == null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          title: '凭证',
          subtitle: '仅保存在本机安全存储中。',
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (preset.requiresApiKey) ...[
                  TextFormField(
                    key: const ValueKey('provider-api-key'),
                    controller: apiKeyController,
                    enabled: enabled,
                    obscureText: !apiKeyVisible,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      suffixIcon: IconButton(
                        tooltip: apiKeyVisible ? '隐藏密钥' : '显示密钥',
                        onPressed: enabled ? onToggleKeyVisibility : null,
                        icon: Icon(
                          apiKeyVisible
                              ? Symbols.visibility_off
                              : Symbols.visibility,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => onConnectionChanged(),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    hasSavedKey
                        ? '留空会保留已存密钥，获取模型时也使用该密钥；填写新值则替换。'
                        : '留空不会写入密钥；需要鉴权的服务请填写 API Key。',
                    style: secondaryStyle,
                  ),
                ] else
                  Text(
                    '此预设不使用 API Key，获取模型时不会发送密钥。已有密钥仍保留在安全存储中。',
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
