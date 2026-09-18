/// 安装资源的内容摘要用于版本固定与读取时完整性校验。
class SkillResource {
  const SkillResource({required this.size, required this.digest});
  final int size;
  final String digest;
  Map<String, dynamic> toJson() => {'size': size, 'digest': digest};
  factory SkillResource.fromJson(Map<String, dynamic> json) => SkillResource(
    size: json['size'] as int,
    digest: json['digest'] as String,
  );
}

/// 安装目录不可变；运行保存完整版本信息，不跟随安装记录的当前版本。
class SkillSnapshot {
  SkillSnapshot({
    required this.id,
    required this.name,
    required this.description,
    required this.revision,
    required this.source,
    required this.installedPath,
    required Map<String, SkillResource> resources,
    List<String> ignoredFields = const [],
  }) : resources = Map.unmodifiable(resources),
       ignoredFields = List.unmodifiable(ignoredFields);

  final String id;
  final String name;
  final String description;
  final String revision;
  final String source;
  final String installedPath;
  final Map<String, SkillResource> resources;
  final List<String> ignoredFields;
  int get size => resources.values.fold(0, (total, file) => total + file.size);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'revision': revision,
    'source': source,
    'installedPath': installedPath,
    'resources': {for (final e in resources.entries) e.key: e.value.toJson()},
    'ignoredFields': ignoredFields,
  };
  factory SkillSnapshot.fromJson(Map<String, dynamic> json) => SkillSnapshot(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    revision: json['revision'] as String,
    source: json['source'] as String,
    installedPath: json['installedPath'] as String,
    resources: {
      for (final e in (json['resources'] as Map<String, dynamic>).entries)
        e.key: SkillResource.fromJson(e.value as Map<String, dynamic>),
    },
    ignoredFields: (json['ignoredFields'] as List).cast<String>(),
  );
}

class SkillInstallation {
  const SkillInstallation({
    required this.snapshot,
    required this.installedAt,
    this.enabled = true,
    this.deleting = false,
  });
  final SkillSnapshot snapshot;
  final DateTime installedAt;
  final bool enabled;
  final bool deleting;
  String get id => snapshot.id;
}
