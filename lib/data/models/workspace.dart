enum EnvironmentPhase {
  notInstalled,
  downloading,
  verifying,
  extracting,
  checking,
  ready,
  failed,
  cancelled,
}

class RuntimeEnvironment {
  const RuntimeEnvironment({
    this.phase = EnvironmentPhase.notInstalled,
    this.rootPath,
    this.revision,
    this.installedBytes = 0,
    this.error,
    this.imageUrl,
    this.imageDigest,
    this.abi = 'arm64-v8a',
    this.downloadBytes = 0,
  });
  final EnvironmentPhase phase;
  final String? rootPath;
  final String? revision;
  final int installedBytes;
  final String? error;
  final String? imageUrl;
  final String? imageDigest;
  final String abi;
  final int downloadBytes;
  bool get ready => phase == EnvironmentPhase.ready && rootPath != null;
  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl,
    'imageDigest': imageDigest,
    'abi': abi,
    'downloadBytes': downloadBytes,
    'phase': phase.name,
    'rootPath': rootPath,
    'revision': revision,
    'installedBytes': installedBytes,
    'error': error,
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
        installedBytes: json['installedBytes'] as int,
        error: json['error'] as String?,
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
  final String environmentRoot;
  final String environmentRevision;
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
        environmentRoot: json['environmentRoot'] as String,
        environmentRevision: json['environmentRevision'] as String,
      );
}
