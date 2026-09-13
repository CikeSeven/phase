import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/models/application_access_policy.dart';
import 'execution_api.g.dart';

enum ApplicationFilter { all, thirdParty, system }

enum ApplicationSort { name, installedAt, size }

List<InstalledApplication> filterApplications(
  Iterable<InstalledApplication> apps, {
  String query = '',
  ApplicationFilter filter = ApplicationFilter.all,
  ApplicationSort sort = ApplicationSort.name,
}) {
  final normalized = query.toLowerCase().trim();
  final result = apps
      .where(
        (app) =>
            (filter == ApplicationFilter.all ||
                app.isSystem == (filter == ApplicationFilter.system)) &&
            '${app.label} ${app.packageName}'.toLowerCase().contains(
              normalized,
            ),
      )
      .toList();
  int names(InstalledApplication a, InstalledApplication b) {
    final label = a.label.toLowerCase().compareTo(b.label.toLowerCase());
    return label == 0 ? a.packageName.compareTo(b.packageName) : label;
  }

  result.sort((a, b) {
    final comparison = switch (sort) {
      ApplicationSort.name => names(a, b),
      ApplicationSort.installedAt => b.installedAtMs.compareTo(a.installedAtMs),
      ApplicationSort.size =>
        a.sizeBytes == null
            ? (b.sizeBytes == null ? 0 : 1)
            : b.sizeBytes == null
            ? -1
            : b.sizeBytes!.compareTo(a.sizeBytes!),
    };
    return comparison == 0 ? names(a, b) : comparison;
  });
  return result;
}

Future<ApplicationAccessPolicy?> showApplicationPolicySheet(
  BuildContext context, {
  required List<InstalledApplication> applications,
  required ApplicationAccessPolicy initialPolicy,
}) => showModalBottomSheet<ApplicationAccessPolicy>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ApplicationPolicySheet(
    applications: applications,
    initialPolicy: initialPolicy,
  ),
);

class ApplicationPolicySheet extends StatefulWidget {
  const ApplicationPolicySheet({
    required this.applications,
    required this.initialPolicy,
    super.key,
  });
  final List<InstalledApplication> applications;
  final ApplicationAccessPolicy initialPolicy;
  @override
  State<ApplicationPolicySheet> createState() => _ApplicationPolicySheetState();
}

class _ApplicationPolicySheetState extends State<ApplicationPolicySheet> {
  late ApplicationAccessPolicy _policy = widget.initialPolicy;
  ApplicationFilter _filter = ApplicationFilter.all;
  ApplicationSort _sort = ApplicationSort.name;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = filterApplications(
      widget.applications,
      query: _query,
      filter: _filter,
      sort: _sort,
    );
    final black = _policy.mode == AppListMode.blacklist;
    return AppSheet(
      title: '应用名单',
      footer: FilledButton(
        key: const ValueKey('confirm-application-policy'),
        onPressed: () => Navigator.pop(context, _policy),
        child: const Text('确定'),
      ),
      child: CustomScrollView(
        key: const ValueKey('application-list-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                children: [
                  DropdownButtonFormField<AppListMode>(
                    key: const ValueKey('application-list-mode'),
                    initialValue: _policy.mode,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '名单模式'),
                    items: const [
                      DropdownMenuItem(
                        value: AppListMode.blacklist,
                        child: Text('黑名单'),
                      ),
                      DropdownMenuItem(
                        value: AppListMode.whitelist,
                        child: Text('白名单'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _policy = _policy.withMode(value));
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    black ? '勾选表示禁止。系统应用默认禁止，取消勾选可逐个放行。' : '只有勾选的应用允许获取信息和操作。',
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    key: const ValueKey('application-list-query'),
                    decoration: const InputDecoration(labelText: '搜索名称或包名'),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  DropdownButtonFormField<ApplicationFilter>(
                    key: const ValueKey('application-list-filter'),
                    initialValue: _filter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '应用类型'),
                    items: const [
                      DropdownMenuItem(
                        value: ApplicationFilter.all,
                        child: Text('全部应用'),
                      ),
                      DropdownMenuItem(
                        value: ApplicationFilter.thirdParty,
                        child: Text('第三方应用'),
                      ),
                      DropdownMenuItem(
                        value: ApplicationFilter.system,
                        child: Text('系统应用'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _filter = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  DropdownButtonFormField<ApplicationSort>(
                    key: const ValueKey('application-list-sort'),
                    initialValue: _sort,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '排序'),
                    items: const [
                      DropdownMenuItem(
                        value: ApplicationSort.name,
                        child: Text('名称'),
                      ),
                      DropdownMenuItem(
                        value: ApplicationSort.installedAt,
                        child: Text('安装时间'),
                      ),
                      DropdownMenuItem(
                        value: ApplicationSort.size,
                        child: Text('安装包大小'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sort = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    '共 ${visible.length} 个匹配应用。时间按新到旧，大小按大到小；大小不含应用数据和缓存，未知值排在末尾。',
                  ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final app = visible[index];
              final allowed = _policy.allows(
                app.packageName,
                isSystem: app.isSystem,
              );
              final date = app.installedAtMs <= 0
                  ? '安装时间未知'
                  : DateTime.fromMillisecondsSinceEpoch(app.installedAtMs)
                        .toIso8601String()
                        .split('T')
                        .first;
              final size = app.sizeBytes == null
                  ? '大小未知'
                  : '${(app.sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
              return CheckboxListTile(
                key: ValueKey('application-policy-${app.packageName}'),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(app.label),
                subtitle: Text(
                  '${app.packageName}\n${app.isSystem ? '系统' : '第三方'} · $size · $date${app.launchable ? '' : '\n无启动图标'}',
                ),
                value: black ? !allowed : allowed,
                onChanged: (value) {
                  if (value != null) {
                    setState(
                      () => _policy = _policy.select(
                        app.packageName,
                        isSystem: app.isSystem,
                        selected: value,
                      ),
                    );
                  }
                },
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.l)),
        ],
      ),
    );
  }
}
