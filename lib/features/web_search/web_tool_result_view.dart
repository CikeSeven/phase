import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/external_web_link.dart';
import '../../data/models/web_search_result.dart';

/// 来源结构直接来自已保存结果；重开会话不会重新搜索或从 Markdown 猜来源。
class WebToolResultView extends StatelessWidget {
  const WebToolResultView({this.search, this.fetch, super.key});
  final WebSearchResult? search;
  final WebFetchResult? fetch;

  String _time(DateTime value) {
    final time = value.toLocal();
    String two(int number) => '$number'.padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final result = search;
    final page = fetch;
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result != null) ...[
          Text(
            '${result.sources.length} 个来源 · ${_time(result.retrievedAt)}',
            style: secondary,
          ),
          if (result.sources.isEmpty && result.answers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.m),
              child: Text('没有找到匹配来源'),
            ),
          if (result.sources.isEmpty && result.answers.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.m),
              child: Text('未返回可核实的来源'),
            ),
          for (final (index, source) in result.sources.indexed) ...[
            if (index > 0) const Divider(height: AppSpacing.xl),
            const SizedBox(height: AppSpacing.s),
            TextButton.icon(
              style: TextButton.styleFrom(
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => openExternalWebLink(context, source.url),
              icon: const Icon(LucideIcons.externalLink, size: 18),
              label: Text(
                source.title?.isNotEmpty == true
                    ? source.title!
                    : Uri.tryParse(source.url)?.host ?? source.url,
              ),
            ),
            Text(source.url, style: secondary),
            if (source.publishedAt?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text('来源日期：${source.publishedAt}', style: secondary),
              ),
            if (source.snippet?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s),
                child: Text(
                  source.snippet!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
          ],
          for (final answer in result.answers) ...[
            const Divider(height: AppSpacing.xl),
            Text(answer.query, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.s),
            Text(
              answer.text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
          if (result.truncated)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.m),
              child: Text('结果已截断', style: secondary),
            ),
        ],
        if (page != null) ...[
          TextButton.icon(
            style: TextButton.styleFrom(
              alignment: AlignmentDirectional.centerStart,
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 48),
            ),
            onPressed: () => openExternalWebLink(context, page.url),
            icon: const Icon(LucideIcons.externalLink, size: 18),
            label: Text(
              page.title?.isNotEmpty == true ? page.title! : page.url,
            ),
          ),
          Text(
            'HTTP ${page.statusCode} · ${_time(page.retrievedAt)}',
            style: secondary,
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            page.content.isEmpty ? '（空正文）' : page.content,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          if (page.truncated)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.m),
              child: Text('网页正文已截断', style: secondary),
            ),
        ],
      ],
    );
  }
}
