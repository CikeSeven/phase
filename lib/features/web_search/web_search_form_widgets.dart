import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_icon_badge.dart';
import '../../data/models/web_search_settings.dart';

/// 针对数值参数优化的表单输入控件，提供范围校验、单位后缀与辅助说明。
class WebNumberField extends StatelessWidget {
  const WebNumberField({
    required this.controller,
    required this.label,
    required this.minimum,
    required this.maximum,
    required this.enabled,
    required this.onChanged,
    this.helperText,
    this.suffixText,
    this.prefixIcon,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final int minimum;
  final int maximum;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String? helperText;
  final String? suffixText;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText ?? '有效范围：$minimum–$maximum',
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
          suffixText: suffixText,
          suffixStyle: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        onChanged: onChanged,
        validator: (value) {
          final number = int.tryParse(value?.trim() ?? '');
          return number == null || number < minimum || number > maximum
              ? '请输入 $minimum 至 $maximum 的整数'
              : null;
        },
      ),
    );
  }
}

/// 网页搜索提供方的统一徽标，优先呈现专属品牌标识，单色与回退状态使用语义色调与 Lucide 图标。
class WebSearchProviderBadge extends StatelessWidget {
  const WebSearchProviderBadge({
    required this.kind,
    super.key,
    this.size = 40,
    this.iconSize = 20,
  });

  final WebSearchProviderKind kind;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (kind == WebSearchProviderKind.deepseek) {
      return ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.smallAll,
          ),
          child: SvgPicture.asset(
            'assets/provider_logos/deepseek.svg',
            width: iconSize,
            height: iconSize,
          ),
        ),
      );
    }
    final icon = switch (kind) {
      WebSearchProviderKind.duckDuckGo => LucideIcons.globe,
      WebSearchProviderKind.bing => LucideIcons.globe,
      WebSearchProviderKind.exa => LucideIcons.sparkles,
      WebSearchProviderKind.brave => LucideIcons.shield,
      WebSearchProviderKind.tavily => LucideIcons.compass,
      WebSearchProviderKind.perplexity => LucideIcons.bot,
      WebSearchProviderKind.searxng => LucideIcons.server,
      WebSearchProviderKind.bocha => LucideIcons.sparkles,
      WebSearchProviderKind.serper => LucideIcons.search,
      WebSearchProviderKind.jina => LucideIcons.compass,
      WebSearchProviderKind.deepseek => LucideIcons.search,
    };
    return AppIconBadge(
      icon: icon,
      tone: webSearchProviderTone(kind),
      size: size,
      iconSize: iconSize,
    );
  }
}

String webSearchProviderDescription(WebSearchProviderKind kind) =>
    switch (kind) {
      WebSearchProviderKind.duckDuckGo => '免 API Key，内置支持，开箱即用',
      WebSearchProviderKind.bing => '免 API Key，内置支持，基于 Bing 网页搜索',
      WebSearchProviderKind.deepseek => '基于 DeepSeek 模型的原生网络搜索能力',
      WebSearchProviderKind.exa => '专为 AI 优化的神经语义与关键词检索',
      WebSearchProviderKind.brave => '基于独立网页索引的高性能隐私搜索',
      WebSearchProviderKind.tavily => '专为 AI Agent 设计的实时网络搜索',
      WebSearchProviderKind.perplexity => '基于 Sonar 模型的联网大模型问答',
      WebSearchProviderKind.searxng => '开源私有化部署的多引擎聚合搜索',
      WebSearchProviderKind.bocha => '面向 AI Agent 打造的高性能多源搜索',
      WebSearchProviderKind.serper => '基于 Google 索引的高速实时网页检索',
      WebSearchProviderKind.jina => '面向大语言模型优化的实时网页检索',
    };

AppTone webSearchProviderTone(WebSearchProviderKind kind) => switch (kind) {
  WebSearchProviderKind.duckDuckGo => AppTone.teal,
  WebSearchProviderKind.bing => AppTone.teal,
  WebSearchProviderKind.deepseek => AppTone.teal,
  WebSearchProviderKind.exa => AppTone.lavender,
  WebSearchProviderKind.brave => AppTone.gold,
  WebSearchProviderKind.tavily => AppTone.teal,
  WebSearchProviderKind.perplexity => AppTone.lavender,
  WebSearchProviderKind.searxng => AppTone.primary,
  WebSearchProviderKind.bocha => AppTone.gold,
  WebSearchProviderKind.serper => AppTone.primary,
  WebSearchProviderKind.jina => AppTone.lavender,
};

/// 草稿离开时才询问；未完成的写入不能被返回动作误当作已保存。
class WebDraftBackGuard extends StatefulWidget {
  const WebDraftBackGuard({
    required this.dirty,
    required this.busy,
    required this.child,
    this.onBusyBack,
    super.key,
  });
  final bool dirty;
  final bool busy;
  final VoidCallback? onBusyBack;
  final Widget child;
  @override
  State<WebDraftBackGuard> createState() => _WebDraftBackGuardState();
}

class _WebDraftBackGuardState extends State<WebDraftBackGuard> {
  bool _leaving = false;
  bool _asking = false;
  Future<void> _back() async {
    if (_asking || _leaving) return;
    // AppDropdown 使用路由内部历史；返回优先关闭菜单，不丢弃页面草稿。
    if (ModalRoute.of(context)?.willHandlePopInternally == true) {
      Navigator.of(context).pop();
      return;
    }
    if (widget.busy) {
      widget.onBusyBack?.call();
      return;
    }
    _asking = true;
    try {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AppDialog(
          title: '放弃未保存的更改？',
          icon: LucideIcons.undo2,
          tone: AppTone.error,
          content: const SizedBox.shrink(),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续编辑'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放弃更改'),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) return;
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving || (!widget.dirty && !widget.busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: widget.child,
  );
}
