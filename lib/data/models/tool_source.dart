import 'dart:convert';

import 'package:crypto/crypto.dart';

enum ToolSourceKind { builtIn, mcp }

enum ToolEffectClass { unknown, readOnly, mutating }

/// 来源身份与 Android 执行通道独立；修订绑定完整定义和执行目标。
class ToolSource {
  const ToolSource({
    required this.kind,
    required this.id,
    required this.originalName,
    required this.definitionRevision,
    this.effectClass = ToolEffectClass.unknown,
  });

  final ToolSourceKind kind;
  final String id;
  final String originalName;
  final String definitionRevision;
  final ToolEffectClass effectClass;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'id': id,
    'originalName': originalName,
    'definitionRevision': definitionRevision,
    'effectClass': effectClass.name,
  };

  factory ToolSource.fromJson(Map<String, dynamic> json) => ToolSource(
    kind: ToolSourceKind.values.byName(json['kind'] as String),
    id: json['id'] as String,
    originalName: json['originalName'] as String,
    definitionRevision: json['definitionRevision'] as String,
    effectClass: ToolEffectClass.values.byName(json['effectClass'] as String),
  );
}

/// JSON 对象键顺序不影响修订；数组顺序仍有意义。
String definitionDigest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();

Object? _canonical(Object? value) => switch (value) {
  Map() => {
    for (final key in (value.keys.cast<String>().toList()..sort()))
      key: _canonical(value[key]),
  },
  List() => value.map(_canonical).toList(),
  _ => value,
};

Map<String, dynamic> freezeJson(Map<String, dynamic> value) =>
    _freeze(value) as Map<String, dynamic>;

Object? _freeze(Object? value) => switch (value) {
  Map() => Map<String, dynamic>.unmodifiable({
    for (final entry in value.entries)
      entry.key as String: _freeze(entry.value),
  }),
  List() => List<Object?>.unmodifiable(value.map(_freeze)),
  _ => value,
};

class ToolSnapshot {
  ToolSnapshot({
    required this.name,
    required this.description,
    required Map<String, dynamic> inputSchema,
    required this.source,
  }) : inputSchema = freezeJson(inputSchema);

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final ToolSource source;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'inputSchema': inputSchema,
    'source': source.toJson(),
  };

  factory ToolSnapshot.fromJson(Map<String, dynamic> json) => ToolSnapshot(
    name: json['name'] as String,
    description: json['description'] as String,
    inputSchema: json['inputSchema'] as Map<String, dynamic>,
    source: ToolSource.fromJson(json['source'] as Map<String, dynamic>),
  );
}
