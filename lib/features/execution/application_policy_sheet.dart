import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/models/application_access_policy.dart';
import '../../../core/widgets/app_dropdown.dart';
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
  required Future<List<InstalledApplication>> Function() loadApplications,
  required ApplicationAccessPolicy initialPolicy,
}) => showModalBottomSheet<ApplicationAccessPolicy>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ApplicationPolicySheet(
    loadApplications: loadApplications,
    initialPolicy: initialPolicy,
  ),
);

class ApplicationPolicySheet extends StatefulWidget {
  const ApplicationPolicySheet({
    required this.loadApplications,
    required this.initialPolicy,
    super.key,
  });
  final Future<List<InstalledApplication>> Function() loadApplications;
  final ApplicationAccessPolicy initialPolicy;
  @override
  State<ApplicationPolicySheet> createState() => _ApplicationPolicySheetState();
}

class _ApplicationPolicySheetState extends State<ApplicationPolicySheet> {
  late Future<List<InstalledApplication>> _applications;
  bool _loading = false;
  late ApplicationAccessPolicy _policy = widget.initialPolicy;
  ApplicationFilter _filter = ApplicationFilter.all;
  ApplicationSort _sort = ApplicationSort.name;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _applications = _loadApplications();
  }

  Future<List<InstalledApplication>> _loadApplications() async {
    _loading = true;
    try {
      return await widget.loadApplications();
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<InstalledApplication>>(
        future: _applications,
        builder: (context, snapshot) => AppSheet(
          title: '应用名单',
          footer: FilledButton(
            key: const ValueKey('confirm-application-policy'),
            onPressed:
                snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData
                ? () => Navigator.pop(context, _policy)
                : null,
            child: const Text('确定'),
          ),
          child: snapshot.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          snapshot.error is Failure
                              ? (snapshot.error! as Failure).userMessage
                              : '读取应用名单失败',
                        ),
                        TextButton(
                          onPressed: () {
                            if (_loading) return;
                            final applications = _loadApplications();
                            setState(() {
                              _applications = applications;
                            });
                          },
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildApplications(snapshot.requireData),
        ),
      );

  Widget _buildApplications(List<InstalledApplication> applications) {
    final visible = filterApplications(
      applications,
      query: _query,
      filter: _filter,
      sort: _sort,
    );
    final black = _policy.mode == AppListMode.blacklist;
    return CustomScrollView(
      key: const ValueKey('application-list-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              children: [
                AppDropdown<AppListMode>(
                  key: const ValueKey('application-list-mode'),
                  value: _policy.mode,
                  label: '名单模式',
                  options: const {
                    AppListMode.blacklist: '黑名单',
                    AppListMode.whitelist: '白名单',
                  },
                  onChanged: (value) {
                    setState(() => _policy = _policy.withMode(value));
                  },
                ),
                const SizedBox(height: AppSpacing.m),
                Text(black ? '勾选禁止 · 系统应用默认禁止' : '仅允许勾选的应用'),
                const SizedBox(height: AppSpacing.m),
                TextField(
                  key: const ValueKey('application-list-query'),
                  decoration: const InputDecoration(labelText: '搜索名称或包名'),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: AppSpacing.m),
                AppDropdown<ApplicationFilter>(
                  key: const ValueKey('application-list-filter'),
                  value: _filter,
                  label: '应用类型',
                  options: const {
                    ApplicationFilter.all: '全部应用',
                    ApplicationFilter.thirdParty: '第三方应用',
                    ApplicationFilter.system: '系统应用',
                  },
                  onChanged: (value) {
                    setState(() => _filter = value);
                  },
                ),
                const SizedBox(height: AppSpacing.m),
                AppDropdown<ApplicationSort>(
                  key: const ValueKey('application-list-sort'),
                  value: _sort,
                  label: '排序',
                  options: const {
                    ApplicationSort.name: '名称',
                    ApplicationSort.installedAt: '安装时间（新到旧）',
                    ApplicationSort.size: '安装包大小（大到小）',
                  },
                  onChanged: (value) {
                    setState(() => _sort = value);
                  },
                ),
                const SizedBox(height: AppSpacing.s),
                Text('${visible.length} 个应用 · 安装包大小不含数据和缓存'),
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
    );
  }
}
