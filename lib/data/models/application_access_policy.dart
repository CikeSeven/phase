enum AppListMode { blacklist, whitelist }

/// 系统应用在黑名单模式下默认禁止，可显式逐个放行；两种模式的名单独立保存。
class ApplicationAccessPolicy {
  const ApplicationAccessPolicy({
    this.mode = AppListMode.blacklist,
    this.blacklist = const {},
    this.whitelist = const {},
    this.allowedSystemApps = const {},
  });

  final AppListMode mode;
  final Set<String> blacklist;
  final Set<String> whitelist;
  final Set<String> allowedSystemApps;

  bool allows(String packageName, {required bool isSystem}) => switch (mode) {
    AppListMode.whitelist => whitelist.contains(packageName),
    AppListMode.blacklist =>
      !blacklist.contains(packageName) &&
          (!isSystem || allowedSystemApps.contains(packageName)),
  };

  ApplicationAccessPolicy withMode(AppListMode value) =>
      ApplicationAccessPolicy(
        mode: value,
        blacklist: blacklist,
        whitelist: whitelist,
        allowedSystemApps: allowedSystemApps,
      );

  /// selected 表示勾选进当前名单；黑名单中勾选是禁止，白名单中勾选是允许。
  ApplicationAccessPolicy select(
    String packageName, {
    required bool isSystem,
    required bool selected,
  }) {
    final black = {...blacklist};
    final white = {...whitelist};
    final system = {...allowedSystemApps};
    if (mode == AppListMode.whitelist) {
      selected ? white.add(packageName) : white.remove(packageName);
    } else {
      selected ? black.add(packageName) : black.remove(packageName);
      if (isSystem) {
        selected ? system.remove(packageName) : system.add(packageName);
      }
    }
    return ApplicationAccessPolicy(
      mode: mode,
      blacklist: black,
      whitelist: white,
      allowedSystemApps: system,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'blacklist': blacklist.toList()..sort(),
    'whitelist': whitelist.toList()..sort(),
    'allowedSystemApps': allowedSystemApps.toList()..sort(),
  };

  factory ApplicationAccessPolicy.fromJson(Map<String, dynamic> json) =>
      ApplicationAccessPolicy(
        mode: AppListMode.values.byName(json['mode'] as String? ?? 'blacklist'),
        blacklist: (json['blacklist'] as List? ?? []).cast<String>().toSet(),
        whitelist: (json['whitelist'] as List? ?? []).cast<String>().toSet(),
        allowedSystemApps: (json['allowedSystemApps'] as List? ?? [])
            .cast<String>()
            .toSet(),
      );
}
