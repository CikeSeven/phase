import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
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
    required this.onChooseProtocol,
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
  final VoidCallback onChooseProtocol;
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
          child: Material(
            color: theme.colorScheme.surface.withValues(alpha: 0),
            borderRadius: AppRadius.mediumAll,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('choose-provider-preset'),
              onTap: enabled ? onChoosePreset : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                child: Row(
                  children: [
                    AppIconBadge(
                      icon: ProviderUi.icon(preset.id),
                      tone: AppTone.teal,
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Text(
                        preset.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    const Icon(Symbols.expand_more),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          title: '连接',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('provider-name'),
                controller: nameController,
                enabled: enabled,
                decoration: const InputDecoration(labelText: '名称'),
                textInputAction: TextInputAction.next,
                onChanged: (_) => onConnectionChanged(),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入服务商名称' : null,
              ),
              const SizedBox(height: AppSpacing.l),
              // 不裁剪：InputDecorator 的浮动标签会越过圆角边界，裁剪会截断标签。
              Material(
                color: theme.colorScheme.surface.withValues(alpha: 0),
                borderRadius: AppRadius.mediumAll,
                child: InkWell(
                  key: const ValueKey('choose-protocol'),
                  borderRadius: AppRadius.mediumAll,
                  onTap: enabled ? onChooseProtocol : null,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'API 协议',
                      suffixIcon: Icon(Symbols.expand_more),
                    ),
                    child: Text(
                      ProviderUi.protocolLabel(protocol),
                      key: const ValueKey('protocol-label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
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
              Text('API 基础地址，不含生成端点', style: secondaryStyle),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          title: '凭证',
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
                const SizedBox(height: AppSpacing.s),
                Text(
                  hasSavedKey ? '本机安全存储 · 留空保留并使用原密钥' : '仅存于本机安全存储',
                  style: secondaryStyle,
                ),
              ] else
                Text(
                  hasSavedKey ? '无需 API Key · 原有密钥保留' : '无需 API Key',
                  style: theme.textTheme.bodyMedium,
                ),
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
                          testError ?? '已获取 $testedModelCount 个模型',
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
      ],
    );
  }
}
