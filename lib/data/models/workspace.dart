enum EnvironmentPhase {
  notInstalled,
  downloading,
  verifying,
  extracting,
  configuring,
  checking,
  ready,
  failed,
  cancelled,
}

/// 一个已安装依赖 profile 的记录；版本来自验证命令输出，缺失不视为失败。
class InstalledDependency {
  const InstalledDependency({required this.installedAt, this.version});
  final DateTime installedAt;
  final String? version;
  Map<String, dynamic> toJson() => {
    'installedAt': installedAt.toIso8601String(),
    'version': version,
  };
  factory InstalledDependency.fromJson(Map<String, dynamic> json) =>
      InstalledDependency(
        installedAt:
            DateTime.tryParse(json['installedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        version: json['version'] as String?,
      );
}

class RuntimeEnvironment {
  const RuntimeEnvironment({
    this.phase = EnvironmentPhase.notInstalled,
    this.rootPath,
    this.revision,
    this.error,
    this.imageUrl,
    this.imageDigest,
    this.abi = 'arm64-v8a',
    this.downloadBytes = 0,
    this.installedDependencies = const {},
  });
  final EnvironmentPhase phase;
  final String? rootPath;
  final String? revision;
  final String? error;
  final String? imageUrl;
  final String? imageDigest;
  final String abi;
  final int downloadBytes;
  final Map<String, InstalledDependency> installedDependencies;
  bool get ready => phase == EnvironmentPhase.ready && rootPath != null;
  RuntimeEnvironment withDependencies(
    String profileId,
    InstalledDependency dependency,
  ) => RuntimeEnvironment(
    phase: phase,
    rootPath: rootPath,
    revision: revision,
    error: error,
    imageUrl: imageUrl,
    imageDigest: imageDigest,
    abi: abi,
    downloadBytes: downloadBytes,
    installedDependencies: {...installedDependencies, profileId: dependency},
  );
  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl,
    'imageDigest': imageDigest,
    'abi': abi,
    'downloadBytes': downloadBytes,
    'phase': phase.name,
    'rootPath': rootPath,
    'revision': revision,
    'error': error,
    'installedDependencies': {
      for (final entry in installedDependencies.entries)
        entry.key: entry.value.toJson(),
    },
  };
  factory RuntimeEnvironment.fromJson(Map<String, dynamic> json) =>
      RuntimeEnvironment(
        imageUrl: json['imageUrl'] as String?,
        imageDigest: json['imageDigest'] as String?,
        abi: json['abi'] as String,
        downloadBytes: json['downloadBytes'] as int,
        phase: EnvironmentPhase.values.byName(json['phase'] as String),
        rootPath: json['rootPath'] as String?,
        revision: json['revision'] as String?,
        error: json['error'] as String?,
        installedDependencies: {
          for (final entry
              in (json['installedDependencies'] as Map<String, dynamic>? ??
                      const <String, dynamic>{})
                  .entries)
            entry.key: InstalledDependency.fromJson(
              (entry.value as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
        },
      );
}

class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.rootPath,
    required this.createdAt,
    this.deleting = false,
  });
  final String id;
  final String name;
  final String rootPath;
  final DateTime createdAt;
  final bool deleting;
}

/// 一次运行固定的环境安装与工作区。路径只供宿主使用，不放入模型提示。
class WorkspaceSnapshot {
  const WorkspaceSnapshot({
    required this.id,
    required this.name,
    required this.rootPath,
    required this.environmentRoot,
    required this.environmentRevision,
  });
  final String id;
  final String name;
  final String rootPath;
  final String? environmentRoot;
  final String? environmentRevision;
  bool get linuxAvailable =>
      environmentRoot != null && environmentRevision != null;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rootPath': rootPath,
    'environmentRoot': environmentRoot,
    'environmentRevision': environmentRevision,
  };
  factory WorkspaceSnapshot.fromJson(Map<String, dynamic> json) =>
      WorkspaceSnapshot(
        id: json['id'] as String,
        name: json['name'] as String,
        rootPath: json['rootPath'] as String,
        environmentRoot: json['environmentRoot'] as String?,
        environmentRevision: json['environmentRevision'] as String?,
      );
}
