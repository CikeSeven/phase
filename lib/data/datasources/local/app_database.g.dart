// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProviderProfilesTable extends ProviderProfiles
    with TableInfo<$ProviderProfilesTable, ProviderProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _protocolMeta = const VerificationMeta(
    'protocol',
  );
  @override
  late final GeneratedColumn<String> protocol = GeneratedColumn<String>(
    'protocol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requiresKeyMeta = const VerificationMeta(
    'requiresKey',
  );
  @override
  late final GeneratedColumn<bool> requiresKey = GeneratedColumn<bool>(
    'requires_key',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_key" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _presetIdMeta = const VerificationMeta(
    'presetId',
  );
  @override
  late final GeneratedColumn<String> presetId = GeneratedColumn<String>(
    'preset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('custom'),
  );
  static const VerificationMeta _defaultModelMeta = const VerificationMeta(
    'defaultModel',
  );
  @override
  late final GeneratedColumn<String> defaultModel = GeneratedColumn<String>(
    'default_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _compatJsonMeta = const VerificationMeta(
    'compatJson',
  );
  @override
  late final GeneratedColumn<String> compatJson = GeneratedColumn<String>(
    'compat_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    protocol,
    baseUrl,
    requiresKey,
    presetId,
    defaultModel,
    compatJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('protocol')) {
      context.handle(
        _protocolMeta,
        protocol.isAcceptableOrUnknown(data['protocol']!, _protocolMeta),
      );
    } else if (isInserting) {
      context.missing(_protocolMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('requires_key')) {
      context.handle(
        _requiresKeyMeta,
        requiresKey.isAcceptableOrUnknown(
          data['requires_key']!,
          _requiresKeyMeta,
        ),
      );
    }
    if (data.containsKey('preset_id')) {
      context.handle(
        _presetIdMeta,
        presetId.isAcceptableOrUnknown(data['preset_id']!, _presetIdMeta),
      );
    }
    if (data.containsKey('default_model')) {
      context.handle(
        _defaultModelMeta,
        defaultModel.isAcceptableOrUnknown(
          data['default_model']!,
          _defaultModelMeta,
        ),
      );
    }
    if (data.containsKey('compat_json')) {
      context.handle(
        _compatJsonMeta,
        compatJson.isAcceptableOrUnknown(data['compat_json']!, _compatJsonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProviderProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      protocol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}protocol'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      requiresKey: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_key'],
      )!,
      presetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preset_id'],
      )!,
      defaultModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_model'],
      ),
      compatJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compat_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProviderProfilesTable createAlias(String alias) {
    return $ProviderProfilesTable(attachedDatabase, alias);
  }
}

class ProviderProfileRow extends DataClass
    implements Insertable<ProviderProfileRow> {
  final String id;
  final String name;
  final String protocol;
  final String baseUrl;
  final bool requiresKey;

  /// 创建时选用的预设 id；只用于回填表单。
  final String presetId;

  /// 该服务商默认使用的模型 id；为空时回退到启用的第一个模型。
  final String? defaultModel;

  /// OpenAI 兼容协议的差异声明（OpenAiCompat JSON）。
  final String? compatJson;
  final DateTime createdAt;
  const ProviderProfileRow({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    required this.requiresKey,
    required this.presetId,
    this.defaultModel,
    this.compatJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['protocol'] = Variable<String>(protocol);
    map['base_url'] = Variable<String>(baseUrl);
    map['requires_key'] = Variable<bool>(requiresKey);
    map['preset_id'] = Variable<String>(presetId);
    if (!nullToAbsent || defaultModel != null) {
      map['default_model'] = Variable<String>(defaultModel);
    }
    if (!nullToAbsent || compatJson != null) {
      map['compat_json'] = Variable<String>(compatJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProviderProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProviderProfilesCompanion(
      id: Value(id),
      name: Value(name),
      protocol: Value(protocol),
      baseUrl: Value(baseUrl),
      requiresKey: Value(requiresKey),
      presetId: Value(presetId),
      defaultModel: defaultModel == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultModel),
      compatJson: compatJson == null && nullToAbsent
          ? const Value.absent()
          : Value(compatJson),
      createdAt: Value(createdAt),
    );
  }

  factory ProviderProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      protocol: serializer.fromJson<String>(json['protocol']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      requiresKey: serializer.fromJson<bool>(json['requiresKey']),
      presetId: serializer.fromJson<String>(json['presetId']),
      defaultModel: serializer.fromJson<String?>(json['defaultModel']),
      compatJson: serializer.fromJson<String?>(json['compatJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'protocol': serializer.toJson<String>(protocol),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'requiresKey': serializer.toJson<bool>(requiresKey),
      'presetId': serializer.toJson<String>(presetId),
      'defaultModel': serializer.toJson<String?>(defaultModel),
      'compatJson': serializer.toJson<String?>(compatJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProviderProfileRow copyWith({
    String? id,
    String? name,
    String? protocol,
    String? baseUrl,
    bool? requiresKey,
    String? presetId,
    Value<String?> defaultModel = const Value.absent(),
    Value<String?> compatJson = const Value.absent(),
    DateTime? createdAt,
  }) => ProviderProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    protocol: protocol ?? this.protocol,
    baseUrl: baseUrl ?? this.baseUrl,
    requiresKey: requiresKey ?? this.requiresKey,
    presetId: presetId ?? this.presetId,
    defaultModel: defaultModel.present ? defaultModel.value : this.defaultModel,
    compatJson: compatJson.present ? compatJson.value : this.compatJson,
    createdAt: createdAt ?? this.createdAt,
  );
  ProviderProfileRow copyWithCompanion(ProviderProfilesCompanion data) {
    return ProviderProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      protocol: data.protocol.present ? data.protocol.value : this.protocol,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      requiresKey: data.requiresKey.present
          ? data.requiresKey.value
          : this.requiresKey,
      presetId: data.presetId.present ? data.presetId.value : this.presetId,
      defaultModel: data.defaultModel.present
          ? data.defaultModel.value
          : this.defaultModel,
      compatJson: data.compatJson.present
          ? data.compatJson.value
          : this.compatJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('protocol: $protocol, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('requiresKey: $requiresKey, ')
          ..write('presetId: $presetId, ')
          ..write('defaultModel: $defaultModel, ')
          ..write('compatJson: $compatJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    protocol,
    baseUrl,
    requiresKey,
    presetId,
    defaultModel,
    compatJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.protocol == this.protocol &&
          other.baseUrl == this.baseUrl &&
          other.requiresKey == this.requiresKey &&
          other.presetId == this.presetId &&
          other.defaultModel == this.defaultModel &&
          other.compatJson == this.compatJson &&
          other.createdAt == this.createdAt);
}

class ProviderProfilesCompanion extends UpdateCompanion<ProviderProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> protocol;
  final Value<String> baseUrl;
  final Value<bool> requiresKey;
  final Value<String> presetId;
  final Value<String?> defaultModel;
  final Value<String?> compatJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProviderProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.protocol = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.requiresKey = const Value.absent(),
    this.presetId = const Value.absent(),
    this.defaultModel = const Value.absent(),
    this.compatJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderProfilesCompanion.insert({
    required String id,
    required String name,
    required String protocol,
    required String baseUrl,
    this.requiresKey = const Value.absent(),
    this.presetId = const Value.absent(),
    this.defaultModel = const Value.absent(),
    this.compatJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       protocol = Value(protocol),
       baseUrl = Value(baseUrl),
       createdAt = Value(createdAt);
  static Insertable<ProviderProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? protocol,
    Expression<String>? baseUrl,
    Expression<bool>? requiresKey,
    Expression<String>? presetId,
    Expression<String>? defaultModel,
    Expression<String>? compatJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (protocol != null) 'protocol': protocol,
      if (baseUrl != null) 'base_url': baseUrl,
      if (requiresKey != null) 'requires_key': requiresKey,
      if (presetId != null) 'preset_id': presetId,
      if (defaultModel != null) 'default_model': defaultModel,
      if (compatJson != null) 'compat_json': compatJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? protocol,
    Value<String>? baseUrl,
    Value<bool>? requiresKey,
    Value<String>? presetId,
    Value<String?>? defaultModel,
    Value<String?>? compatJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProviderProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      requiresKey: requiresKey ?? this.requiresKey,
      presetId: presetId ?? this.presetId,
      defaultModel: defaultModel ?? this.defaultModel,
      compatJson: compatJson ?? this.compatJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (protocol.present) {
      map['protocol'] = Variable<String>(protocol.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (requiresKey.present) {
      map['requires_key'] = Variable<bool>(requiresKey.value);
    }
    if (presetId.present) {
      map['preset_id'] = Variable<String>(presetId.value);
    }
    if (defaultModel.present) {
      map['default_model'] = Variable<String>(defaultModel.value);
    }
    if (compatJson.present) {
      map['compat_json'] = Variable<String>(compatJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('protocol: $protocol, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('requiresKey: $requiresKey, ')
          ..write('presetId: $presetId, ')
          ..write('defaultModel: $defaultModel, ')
          ..write('compatJson: $compatJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelsTable extends Models with TableInfo<$ModelsTable, ModelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES provider_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _supportsReasoningMeta = const VerificationMeta(
    'supportsReasoning',
  );
  @override
  late final GeneratedColumn<bool> supportsReasoning = GeneratedColumn<bool>(
    'supports_reasoning',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_reasoning" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _supportsToolsMeta = const VerificationMeta(
    'supportsTools',
  );
  @override
  late final GeneratedColumn<bool> supportsTools = GeneratedColumn<bool>(
    'supports_tools',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_tools" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _supportsImagesMeta = const VerificationMeta(
    'supportsImages',
  );
  @override
  late final GeneratedColumn<bool> supportsImages = GeneratedColumn<bool>(
    'supports_images',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_images" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _contextWindowMeta = const VerificationMeta(
    'contextWindow',
  );
  @override
  late final GeneratedColumn<int> contextWindow = GeneratedColumn<int>(
    'context_window',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxOutputTokensMeta = const VerificationMeta(
    'maxOutputTokens',
  );
  @override
  late final GeneratedColumn<int> maxOutputTokens = GeneratedColumn<int>(
    'max_output_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _temperatureMeta = const VerificationMeta(
    'temperature',
  );
  @override
  late final GeneratedColumn<double> temperature = GeneratedColumn<double>(
    'temperature',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    modelId,
    displayName,
    enabled,
    supportsReasoning,
    supportsTools,
    supportsImages,
    contextWindow,
    maxOutputTokens,
    temperature,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'models';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('supports_reasoning')) {
      context.handle(
        _supportsReasoningMeta,
        supportsReasoning.isAcceptableOrUnknown(
          data['supports_reasoning']!,
          _supportsReasoningMeta,
        ),
      );
    }
    if (data.containsKey('supports_tools')) {
      context.handle(
        _supportsToolsMeta,
        supportsTools.isAcceptableOrUnknown(
          data['supports_tools']!,
          _supportsToolsMeta,
        ),
      );
    }
    if (data.containsKey('supports_images')) {
      context.handle(
        _supportsImagesMeta,
        supportsImages.isAcceptableOrUnknown(
          data['supports_images']!,
          _supportsImagesMeta,
        ),
      );
    }
    if (data.containsKey('context_window')) {
      context.handle(
        _contextWindowMeta,
        contextWindow.isAcceptableOrUnknown(
          data['context_window']!,
          _contextWindowMeta,
        ),
      );
    }
    if (data.containsKey('max_output_tokens')) {
      context.handle(
        _maxOutputTokensMeta,
        maxOutputTokens.isAcceptableOrUnknown(
          data['max_output_tokens']!,
          _maxOutputTokensMeta,
        ),
      );
    }
    if (data.containsKey('temperature')) {
      context.handle(
        _temperatureMeta,
        temperature.isAcceptableOrUnknown(
          data['temperature']!,
          _temperatureMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, modelId};
  @override
  ModelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelRow(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      supportsReasoning: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_reasoning'],
      )!,
      supportsTools: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_tools'],
      )!,
      supportsImages: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_images'],
      )!,
      contextWindow: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}context_window'],
      ),
      maxOutputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_output_tokens'],
      ),
      temperature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature'],
      ),
    );
  }

  @override
  $ModelsTable createAlias(String alias) {
    return $ModelsTable(attachedDatabase, alias);
  }
}

class ModelRow extends DataClass implements Insertable<ModelRow> {
  final String profileId;
  final String modelId;
  final String? displayName;
  final bool enabled;
  final bool supportsReasoning;
  final bool supportsTools;
  final bool supportsImages;
  final int? contextWindow;
  final int? maxOutputTokens;

  /// 采样温度；未设置时不下发。
  final double? temperature;
  const ModelRow({
    required this.profileId,
    required this.modelId,
    this.displayName,
    required this.enabled,
    required this.supportsReasoning,
    required this.supportsTools,
    required this.supportsImages,
    this.contextWindow,
    this.maxOutputTokens,
    this.temperature,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['model_id'] = Variable<String>(modelId);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['supports_reasoning'] = Variable<bool>(supportsReasoning);
    map['supports_tools'] = Variable<bool>(supportsTools);
    map['supports_images'] = Variable<bool>(supportsImages);
    if (!nullToAbsent || contextWindow != null) {
      map['context_window'] = Variable<int>(contextWindow);
    }
    if (!nullToAbsent || maxOutputTokens != null) {
      map['max_output_tokens'] = Variable<int>(maxOutputTokens);
    }
    if (!nullToAbsent || temperature != null) {
      map['temperature'] = Variable<double>(temperature);
    }
    return map;
  }

  ModelsCompanion toCompanion(bool nullToAbsent) {
    return ModelsCompanion(
      profileId: Value(profileId),
      modelId: Value(modelId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      enabled: Value(enabled),
      supportsReasoning: Value(supportsReasoning),
      supportsTools: Value(supportsTools),
      supportsImages: Value(supportsImages),
      contextWindow: contextWindow == null && nullToAbsent
          ? const Value.absent()
          : Value(contextWindow),
      maxOutputTokens: maxOutputTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(maxOutputTokens),
      temperature: temperature == null && nullToAbsent
          ? const Value.absent()
          : Value(temperature),
    );
  }

  factory ModelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelRow(
      profileId: serializer.fromJson<String>(json['profileId']),
      modelId: serializer.fromJson<String>(json['modelId']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      supportsReasoning: serializer.fromJson<bool>(json['supportsReasoning']),
      supportsTools: serializer.fromJson<bool>(json['supportsTools']),
      supportsImages: serializer.fromJson<bool>(json['supportsImages']),
      contextWindow: serializer.fromJson<int?>(json['contextWindow']),
      maxOutputTokens: serializer.fromJson<int?>(json['maxOutputTokens']),
      temperature: serializer.fromJson<double?>(json['temperature']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'modelId': serializer.toJson<String>(modelId),
      'displayName': serializer.toJson<String?>(displayName),
      'enabled': serializer.toJson<bool>(enabled),
      'supportsReasoning': serializer.toJson<bool>(supportsReasoning),
      'supportsTools': serializer.toJson<bool>(supportsTools),
      'supportsImages': serializer.toJson<bool>(supportsImages),
      'contextWindow': serializer.toJson<int?>(contextWindow),
      'maxOutputTokens': serializer.toJson<int?>(maxOutputTokens),
      'temperature': serializer.toJson<double?>(temperature),
    };
  }

  ModelRow copyWith({
    String? profileId,
    String? modelId,
    Value<String?> displayName = const Value.absent(),
    bool? enabled,
    bool? supportsReasoning,
    bool? supportsTools,
    bool? supportsImages,
    Value<int?> contextWindow = const Value.absent(),
    Value<int?> maxOutputTokens = const Value.absent(),
    Value<double?> temperature = const Value.absent(),
  }) => ModelRow(
    profileId: profileId ?? this.profileId,
    modelId: modelId ?? this.modelId,
    displayName: displayName.present ? displayName.value : this.displayName,
    enabled: enabled ?? this.enabled,
    supportsReasoning: supportsReasoning ?? this.supportsReasoning,
    supportsTools: supportsTools ?? this.supportsTools,
    supportsImages: supportsImages ?? this.supportsImages,
    contextWindow: contextWindow.present
        ? contextWindow.value
        : this.contextWindow,
    maxOutputTokens: maxOutputTokens.present
        ? maxOutputTokens.value
        : this.maxOutputTokens,
    temperature: temperature.present ? temperature.value : this.temperature,
  );
  ModelRow copyWithCompanion(ModelsCompanion data) {
    return ModelRow(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      supportsReasoning: data.supportsReasoning.present
          ? data.supportsReasoning.value
          : this.supportsReasoning,
      supportsTools: data.supportsTools.present
          ? data.supportsTools.value
          : this.supportsTools,
      supportsImages: data.supportsImages.present
          ? data.supportsImages.value
          : this.supportsImages,
      contextWindow: data.contextWindow.present
          ? data.contextWindow.value
          : this.contextWindow,
      maxOutputTokens: data.maxOutputTokens.present
          ? data.maxOutputTokens.value
          : this.maxOutputTokens,
      temperature: data.temperature.present
          ? data.temperature.value
          : this.temperature,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelRow(')
          ..write('profileId: $profileId, ')
          ..write('modelId: $modelId, ')
          ..write('displayName: $displayName, ')
          ..write('enabled: $enabled, ')
          ..write('supportsReasoning: $supportsReasoning, ')
          ..write('supportsTools: $supportsTools, ')
          ..write('supportsImages: $supportsImages, ')
          ..write('contextWindow: $contextWindow, ')
          ..write('maxOutputTokens: $maxOutputTokens, ')
          ..write('temperature: $temperature')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    modelId,
    displayName,
    enabled,
    supportsReasoning,
    supportsTools,
    supportsImages,
    contextWindow,
    maxOutputTokens,
    temperature,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelRow &&
          other.profileId == this.profileId &&
          other.modelId == this.modelId &&
          other.displayName == this.displayName &&
          other.enabled == this.enabled &&
          other.supportsReasoning == this.supportsReasoning &&
          other.supportsTools == this.supportsTools &&
          other.supportsImages == this.supportsImages &&
          other.contextWindow == this.contextWindow &&
          other.maxOutputTokens == this.maxOutputTokens &&
          other.temperature == this.temperature);
}

class ModelsCompanion extends UpdateCompanion<ModelRow> {
  final Value<String> profileId;
  final Value<String> modelId;
  final Value<String?> displayName;
  final Value<bool> enabled;
  final Value<bool> supportsReasoning;
  final Value<bool> supportsTools;
  final Value<bool> supportsImages;
  final Value<int?> contextWindow;
  final Value<int?> maxOutputTokens;
  final Value<double?> temperature;
  final Value<int> rowid;
  const ModelsCompanion({
    this.profileId = const Value.absent(),
    this.modelId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.enabled = const Value.absent(),
    this.supportsReasoning = const Value.absent(),
    this.supportsTools = const Value.absent(),
    this.supportsImages = const Value.absent(),
    this.contextWindow = const Value.absent(),
    this.maxOutputTokens = const Value.absent(),
    this.temperature = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelsCompanion.insert({
    required String profileId,
    required String modelId,
    this.displayName = const Value.absent(),
    this.enabled = const Value.absent(),
    this.supportsReasoning = const Value.absent(),
    this.supportsTools = const Value.absent(),
    this.supportsImages = const Value.absent(),
    this.contextWindow = const Value.absent(),
    this.maxOutputTokens = const Value.absent(),
    this.temperature = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       modelId = Value(modelId);
  static Insertable<ModelRow> custom({
    Expression<String>? profileId,
    Expression<String>? modelId,
    Expression<String>? displayName,
    Expression<bool>? enabled,
    Expression<bool>? supportsReasoning,
    Expression<bool>? supportsTools,
    Expression<bool>? supportsImages,
    Expression<int>? contextWindow,
    Expression<int>? maxOutputTokens,
    Expression<double>? temperature,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (modelId != null) 'model_id': modelId,
      if (displayName != null) 'display_name': displayName,
      if (enabled != null) 'enabled': enabled,
      if (supportsReasoning != null) 'supports_reasoning': supportsReasoning,
      if (supportsTools != null) 'supports_tools': supportsTools,
      if (supportsImages != null) 'supports_images': supportsImages,
      if (contextWindow != null) 'context_window': contextWindow,
      if (maxOutputTokens != null) 'max_output_tokens': maxOutputTokens,
      if (temperature != null) 'temperature': temperature,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelsCompanion copyWith({
    Value<String>? profileId,
    Value<String>? modelId,
    Value<String?>? displayName,
    Value<bool>? enabled,
    Value<bool>? supportsReasoning,
    Value<bool>? supportsTools,
    Value<bool>? supportsImages,
    Value<int?>? contextWindow,
    Value<int?>? maxOutputTokens,
    Value<double?>? temperature,
    Value<int>? rowid,
  }) {
    return ModelsCompanion(
      profileId: profileId ?? this.profileId,
      modelId: modelId ?? this.modelId,
      displayName: displayName ?? this.displayName,
      enabled: enabled ?? this.enabled,
      supportsReasoning: supportsReasoning ?? this.supportsReasoning,
      supportsTools: supportsTools ?? this.supportsTools,
      supportsImages: supportsImages ?? this.supportsImages,
      contextWindow: contextWindow ?? this.contextWindow,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      temperature: temperature ?? this.temperature,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (supportsReasoning.present) {
      map['supports_reasoning'] = Variable<bool>(supportsReasoning.value);
    }
    if (supportsTools.present) {
      map['supports_tools'] = Variable<bool>(supportsTools.value);
    }
    if (supportsImages.present) {
      map['supports_images'] = Variable<bool>(supportsImages.value);
    }
    if (contextWindow.present) {
      map['context_window'] = Variable<int>(contextWindow.value);
    }
    if (maxOutputTokens.present) {
      map['max_output_tokens'] = Variable<int>(maxOutputTokens.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<double>(temperature.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('modelId: $modelId, ')
          ..write('displayName: $displayName, ')
          ..write('enabled: $enabled, ')
          ..write('supportsReasoning: $supportsReasoning, ')
          ..write('supportsTools: $supportsTools, ')
          ..write('supportsImages: $supportsImages, ')
          ..write('contextWindow: $contextWindow, ')
          ..write('maxOutputTokens: $maxOutputTokens, ')
          ..write('temperature: $temperature, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssistantsTable extends Assistants
    with TableInfo<$AssistantsTable, AssistantRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssistantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _systemPromptMeta = const VerificationMeta(
    'systemPrompt',
  );
  @override
  late final GeneratedColumn<String> systemPrompt = GeneratedColumn<String>(
    'system_prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _defaultSelectionJsonMeta =
      const VerificationMeta('defaultSelectionJson');
  @override
  late final GeneratedColumn<String> defaultSelectionJson =
      GeneratedColumn<String>(
        'default_selection_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _toolPolicyJsonMeta = const VerificationMeta(
    'toolPolicyJson',
  );
  @override
  late final GeneratedColumn<String> toolPolicyJson = GeneratedColumn<String>(
    'tool_policy_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    systemPrompt,
    defaultSelectionJson,
    toolPolicyJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assistants';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssistantRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('system_prompt')) {
      context.handle(
        _systemPromptMeta,
        systemPrompt.isAcceptableOrUnknown(
          data['system_prompt']!,
          _systemPromptMeta,
        ),
      );
    }
    if (data.containsKey('default_selection_json')) {
      context.handle(
        _defaultSelectionJsonMeta,
        defaultSelectionJson.isAcceptableOrUnknown(
          data['default_selection_json']!,
          _defaultSelectionJsonMeta,
        ),
      );
    }
    if (data.containsKey('tool_policy_json')) {
      context.handle(
        _toolPolicyJsonMeta,
        toolPolicyJson.isAcceptableOrUnknown(
          data['tool_policy_json']!,
          _toolPolicyJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssistantRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssistantRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      systemPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}system_prompt'],
      )!,
      defaultSelectionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_selection_json'],
      ),
      toolPolicyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_policy_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AssistantsTable createAlias(String alias) {
    return $AssistantsTable(attachedDatabase, alias);
  }
}

class AssistantRow extends DataClass implements Insertable<AssistantRow> {
  final String id;
  final String name;
  final String systemPrompt;

  /// ModelSelection 的 JSON；未设置默认模型时为 null。
  final String? defaultSelectionJson;

  /// 工具名 → 策略 的 JSON 对象。
  final String toolPolicyJson;
  final DateTime createdAt;
  const AssistantRow({
    required this.id,
    required this.name,
    required this.systemPrompt,
    this.defaultSelectionJson,
    required this.toolPolicyJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['system_prompt'] = Variable<String>(systemPrompt);
    if (!nullToAbsent || defaultSelectionJson != null) {
      map['default_selection_json'] = Variable<String>(defaultSelectionJson);
    }
    map['tool_policy_json'] = Variable<String>(toolPolicyJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AssistantsCompanion toCompanion(bool nullToAbsent) {
    return AssistantsCompanion(
      id: Value(id),
      name: Value(name),
      systemPrompt: Value(systemPrompt),
      defaultSelectionJson: defaultSelectionJson == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultSelectionJson),
      toolPolicyJson: Value(toolPolicyJson),
      createdAt: Value(createdAt),
    );
  }

  factory AssistantRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssistantRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      systemPrompt: serializer.fromJson<String>(json['systemPrompt']),
      defaultSelectionJson: serializer.fromJson<String?>(
        json['defaultSelectionJson'],
      ),
      toolPolicyJson: serializer.fromJson<String>(json['toolPolicyJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'systemPrompt': serializer.toJson<String>(systemPrompt),
      'defaultSelectionJson': serializer.toJson<String?>(defaultSelectionJson),
      'toolPolicyJson': serializer.toJson<String>(toolPolicyJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AssistantRow copyWith({
    String? id,
    String? name,
    String? systemPrompt,
    Value<String?> defaultSelectionJson = const Value.absent(),
    String? toolPolicyJson,
    DateTime? createdAt,
  }) => AssistantRow(
    id: id ?? this.id,
    name: name ?? this.name,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    defaultSelectionJson: defaultSelectionJson.present
        ? defaultSelectionJson.value
        : this.defaultSelectionJson,
    toolPolicyJson: toolPolicyJson ?? this.toolPolicyJson,
    createdAt: createdAt ?? this.createdAt,
  );
  AssistantRow copyWithCompanion(AssistantsCompanion data) {
    return AssistantRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
      defaultSelectionJson: data.defaultSelectionJson.present
          ? data.defaultSelectionJson.value
          : this.defaultSelectionJson,
      toolPolicyJson: data.toolPolicyJson.present
          ? data.toolPolicyJson.value
          : this.toolPolicyJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssistantRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('defaultSelectionJson: $defaultSelectionJson, ')
          ..write('toolPolicyJson: $toolPolicyJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    systemPrompt,
    defaultSelectionJson,
    toolPolicyJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.systemPrompt == this.systemPrompt &&
          other.defaultSelectionJson == this.defaultSelectionJson &&
          other.toolPolicyJson == this.toolPolicyJson &&
          other.createdAt == this.createdAt);
}

class AssistantsCompanion extends UpdateCompanion<AssistantRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> systemPrompt;
  final Value<String?> defaultSelectionJson;
  final Value<String> toolPolicyJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AssistantsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.defaultSelectionJson = const Value.absent(),
    this.toolPolicyJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantsCompanion.insert({
    required String id,
    required String name,
    this.systemPrompt = const Value.absent(),
    this.defaultSelectionJson = const Value.absent(),
    this.toolPolicyJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<AssistantRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? systemPrompt,
    Expression<String>? defaultSelectionJson,
    Expression<String>? toolPolicyJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (defaultSelectionJson != null)
        'default_selection_json': defaultSelectionJson,
      if (toolPolicyJson != null) 'tool_policy_json': toolPolicyJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? systemPrompt,
    Value<String?>? defaultSelectionJson,
    Value<String>? toolPolicyJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AssistantsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      defaultSelectionJson: defaultSelectionJson ?? this.defaultSelectionJson,
      toolPolicyJson: toolPolicyJson ?? this.toolPolicyJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (systemPrompt.present) {
      map['system_prompt'] = Variable<String>(systemPrompt.value);
    }
    if (defaultSelectionJson.present) {
      map['default_selection_json'] = Variable<String>(
        defaultSelectionJson.value,
      );
    }
    if (toolPolicyJson.present) {
      map['tool_policy_json'] = Variable<String>(toolPolicyJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssistantsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('defaultSelectionJson: $defaultSelectionJson, ')
          ..write('toolPolicyJson: $toolPolicyJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, ConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assistantIdMeta = const VerificationMeta(
    'assistantId',
  );
  @override
  late final GeneratedColumn<String> assistantId = GeneratedColumn<String>(
    'assistant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 0,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentMessageIdMeta = const VerificationMeta(
    'currentMessageId',
  );
  @override
  late final GeneratedColumn<String> currentMessageId = GeneratedColumn<String>(
    'current_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selectionJsonMeta = const VerificationMeta(
    'selectionJson',
  );
  @override
  late final GeneratedColumn<String> selectionJson = GeneratedColumn<String>(
    'selection_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assistantId,
    title,
    currentMessageId,
    selectionJson,
    pinned,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('assistant_id')) {
      context.handle(
        _assistantIdMeta,
        assistantId.isAcceptableOrUnknown(
          data['assistant_id']!,
          _assistantIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('current_message_id')) {
      context.handle(
        _currentMessageIdMeta,
        currentMessageId.isAcceptableOrUnknown(
          data['current_message_id']!,
          _currentMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('selection_json')) {
      context.handle(
        _selectionJsonMeta,
        selectionJson.isAcceptableOrUnknown(
          data['selection_json']!,
          _selectionJsonMeta,
        ),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      assistantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assistant_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      currentMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_message_id'],
      ),
      selectionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selection_json'],
      ),
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class ConversationRow extends DataClass implements Insertable<ConversationRow> {
  final String id;

  /// 助手被删除后置空，会话保留并允许重新选择助手。
  final String? assistantId;
  final String title;
  final String? currentMessageId;

  /// ModelSelection 的 JSON；为空时用助手默认值。
  final String? selectionJson;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ConversationRow({
    required this.id,
    this.assistantId,
    required this.title,
    this.currentMessageId,
    this.selectionJson,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || assistantId != null) {
      map['assistant_id'] = Variable<String>(assistantId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || currentMessageId != null) {
      map['current_message_id'] = Variable<String>(currentMessageId);
    }
    if (!nullToAbsent || selectionJson != null) {
      map['selection_json'] = Variable<String>(selectionJson);
    }
    map['pinned'] = Variable<bool>(pinned);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      assistantId: assistantId == null && nullToAbsent
          ? const Value.absent()
          : Value(assistantId),
      title: Value(title),
      currentMessageId: currentMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentMessageId),
      selectionJson: selectionJson == null && nullToAbsent
          ? const Value.absent()
          : Value(selectionJson),
      pinned: Value(pinned),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConversationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationRow(
      id: serializer.fromJson<String>(json['id']),
      assistantId: serializer.fromJson<String?>(json['assistantId']),
      title: serializer.fromJson<String>(json['title']),
      currentMessageId: serializer.fromJson<String?>(json['currentMessageId']),
      selectionJson: serializer.fromJson<String?>(json['selectionJson']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'assistantId': serializer.toJson<String?>(assistantId),
      'title': serializer.toJson<String>(title),
      'currentMessageId': serializer.toJson<String?>(currentMessageId),
      'selectionJson': serializer.toJson<String?>(selectionJson),
      'pinned': serializer.toJson<bool>(pinned),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConversationRow copyWith({
    String? id,
    Value<String?> assistantId = const Value.absent(),
    String? title,
    Value<String?> currentMessageId = const Value.absent(),
    Value<String?> selectionJson = const Value.absent(),
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ConversationRow(
    id: id ?? this.id,
    assistantId: assistantId.present ? assistantId.value : this.assistantId,
    title: title ?? this.title,
    currentMessageId: currentMessageId.present
        ? currentMessageId.value
        : this.currentMessageId,
    selectionJson: selectionJson.present
        ? selectionJson.value
        : this.selectionJson,
    pinned: pinned ?? this.pinned,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ConversationRow copyWithCompanion(ConversationsCompanion data) {
    return ConversationRow(
      id: data.id.present ? data.id.value : this.id,
      assistantId: data.assistantId.present
          ? data.assistantId.value
          : this.assistantId,
      title: data.title.present ? data.title.value : this.title,
      currentMessageId: data.currentMessageId.present
          ? data.currentMessageId.value
          : this.currentMessageId,
      selectionJson: data.selectionJson.present
          ? data.selectionJson.value
          : this.selectionJson,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationRow(')
          ..write('id: $id, ')
          ..write('assistantId: $assistantId, ')
          ..write('title: $title, ')
          ..write('currentMessageId: $currentMessageId, ')
          ..write('selectionJson: $selectionJson, ')
          ..write('pinned: $pinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    assistantId,
    title,
    currentMessageId,
    selectionJson,
    pinned,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationRow &&
          other.id == this.id &&
          other.assistantId == this.assistantId &&
          other.title == this.title &&
          other.currentMessageId == this.currentMessageId &&
          other.selectionJson == this.selectionJson &&
          other.pinned == this.pinned &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<ConversationRow> {
  final Value<String> id;
  final Value<String?> assistantId;
  final Value<String> title;
  final Value<String?> currentMessageId;
  final Value<String?> selectionJson;
  final Value<bool> pinned;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.title = const Value.absent(),
    this.currentMessageId = const Value.absent(),
    this.selectionJson = const Value.absent(),
    this.pinned = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    this.assistantId = const Value.absent(),
    required String title,
    this.currentMessageId = const Value.absent(),
    this.selectionJson = const Value.absent(),
    this.pinned = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ConversationRow> custom({
    Expression<String>? id,
    Expression<String>? assistantId,
    Expression<String>? title,
    Expression<String>? currentMessageId,
    Expression<String>? selectionJson,
    Expression<bool>? pinned,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assistantId != null) 'assistant_id': assistantId,
      if (title != null) 'title': title,
      if (currentMessageId != null) 'current_message_id': currentMessageId,
      if (selectionJson != null) 'selection_json': selectionJson,
      if (pinned != null) 'pinned': pinned,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String?>? assistantId,
    Value<String>? title,
    Value<String?>? currentMessageId,
    Value<String?>? selectionJson,
    Value<bool>? pinned,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      assistantId: assistantId ?? this.assistantId,
      title: title ?? this.title,
      currentMessageId: currentMessageId ?? this.currentMessageId,
      selectionJson: selectionJson ?? this.selectionJson,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (assistantId.present) {
      map['assistant_id'] = Variable<String>(assistantId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (currentMessageId.present) {
      map['current_message_id'] = Variable<String>(currentMessageId.value);
    }
    if (selectionJson.present) {
      map['selection_json'] = Variable<String>(selectionJson.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('assistantId: $assistantId, ')
          ..write('title: $title, ')
          ..write('currentMessageId: $currentMessageId, ')
          ..write('selectionJson: $selectionJson, ')
          ..write('pinned: $pinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ChatRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ChatRole>($MessagesTable.$converterrole);
  @override
  late final GeneratedColumnWithTypeConverter<MessageStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MessageStatus>($MessagesTable.$converterstatus);
  static const VerificationMeta _partsJsonMeta = const VerificationMeta(
    'partsJson',
  );
  @override
  late final GeneratedColumn<String> partsJson = GeneratedColumn<String>(
    'parts_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _modelLabelMeta = const VerificationMeta(
    'modelLabel',
  );
  @override
  late final GeneratedColumn<String> modelLabel = GeneratedColumn<String>(
    'model_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usageJsonMeta = const VerificationMeta(
    'usageJson',
  );
  @override
  late final GeneratedColumn<String> usageJson = GeneratedColumn<String>(
    'usage_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thinkingDurationMsMeta =
      const VerificationMeta('thinkingDurationMs');
  @override
  late final GeneratedColumn<int> thinkingDurationMs = GeneratedColumn<int>(
    'thinking_duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    parentId,
    runId,
    role,
    status,
    partsJson,
    modelLabel,
    usageJson,
    thinkingDurationMs,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('parts_json')) {
      context.handle(
        _partsJsonMeta,
        partsJson.isAcceptableOrUnknown(data['parts_json']!, _partsJsonMeta),
      );
    }
    if (data.containsKey('model_label')) {
      context.handle(
        _modelLabelMeta,
        modelLabel.isAcceptableOrUnknown(data['model_label']!, _modelLabelMeta),
      );
    }
    if (data.containsKey('usage_json')) {
      context.handle(
        _usageJsonMeta,
        usageJson.isAcceptableOrUnknown(data['usage_json']!, _usageJsonMeta),
      );
    }
    if (data.containsKey('thinking_duration_ms')) {
      context.handle(
        _thinkingDurationMsMeta,
        thinkingDurationMs.isAcceptableOrUnknown(
          data['thinking_duration_ms']!,
          _thinkingDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      ),
      role: $MessagesTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      status: $MessagesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      partsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parts_json'],
      )!,
      modelLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_label'],
      ),
      usageJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}usage_json'],
      ),
      thinkingDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}thinking_duration_ms'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ChatRole, String, String> $converterrole =
      const EnumNameConverter<ChatRole>(ChatRole.values);
  static JsonTypeConverter2<MessageStatus, String, String> $converterstatus =
      const EnumNameConverter<MessageStatus>(MessageStatus.values);
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String id;
  final String conversationId;

  /// 消息树父指针；null 表示本会话第一条消息。
  final String? parentId;
  final String? runId;
  final ChatRole role;
  final MessageStatus status;
  final String partsJson;
  final String? modelLabel;

  /// TokenUsage 的 JSON；接口未提供用量时为 null。
  final String? usageJson;
  final int? thinkingDurationMs;
  final DateTime createdAt;
  const MessageRow({
    required this.id,
    required this.conversationId,
    this.parentId,
    this.runId,
    required this.role,
    required this.status,
    required this.partsJson,
    this.modelLabel,
    this.usageJson,
    this.thinkingDurationMs,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || runId != null) {
      map['run_id'] = Variable<String>(runId);
    }
    {
      map['role'] = Variable<String>($MessagesTable.$converterrole.toSql(role));
    }
    {
      map['status'] = Variable<String>(
        $MessagesTable.$converterstatus.toSql(status),
      );
    }
    map['parts_json'] = Variable<String>(partsJson);
    if (!nullToAbsent || modelLabel != null) {
      map['model_label'] = Variable<String>(modelLabel);
    }
    if (!nullToAbsent || usageJson != null) {
      map['usage_json'] = Variable<String>(usageJson);
    }
    if (!nullToAbsent || thinkingDurationMs != null) {
      map['thinking_duration_ms'] = Variable<int>(thinkingDurationMs);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      runId: runId == null && nullToAbsent
          ? const Value.absent()
          : Value(runId),
      role: Value(role),
      status: Value(status),
      partsJson: Value(partsJson),
      modelLabel: modelLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(modelLabel),
      usageJson: usageJson == null && nullToAbsent
          ? const Value.absent()
          : Value(usageJson),
      thinkingDurationMs: thinkingDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(thinkingDurationMs),
      createdAt: Value(createdAt),
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      runId: serializer.fromJson<String?>(json['runId']),
      role: $MessagesTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      status: $MessagesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      partsJson: serializer.fromJson<String>(json['partsJson']),
      modelLabel: serializer.fromJson<String?>(json['modelLabel']),
      usageJson: serializer.fromJson<String?>(json['usageJson']),
      thinkingDurationMs: serializer.fromJson<int?>(json['thinkingDurationMs']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'parentId': serializer.toJson<String?>(parentId),
      'runId': serializer.toJson<String?>(runId),
      'role': serializer.toJson<String>(
        $MessagesTable.$converterrole.toJson(role),
      ),
      'status': serializer.toJson<String>(
        $MessagesTable.$converterstatus.toJson(status),
      ),
      'partsJson': serializer.toJson<String>(partsJson),
      'modelLabel': serializer.toJson<String?>(modelLabel),
      'usageJson': serializer.toJson<String?>(usageJson),
      'thinkingDurationMs': serializer.toJson<int?>(thinkingDurationMs),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MessageRow copyWith({
    String? id,
    String? conversationId,
    Value<String?> parentId = const Value.absent(),
    Value<String?> runId = const Value.absent(),
    ChatRole? role,
    MessageStatus? status,
    String? partsJson,
    Value<String?> modelLabel = const Value.absent(),
    Value<String?> usageJson = const Value.absent(),
    Value<int?> thinkingDurationMs = const Value.absent(),
    DateTime? createdAt,
  }) => MessageRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    parentId: parentId.present ? parentId.value : this.parentId,
    runId: runId.present ? runId.value : this.runId,
    role: role ?? this.role,
    status: status ?? this.status,
    partsJson: partsJson ?? this.partsJson,
    modelLabel: modelLabel.present ? modelLabel.value : this.modelLabel,
    usageJson: usageJson.present ? usageJson.value : this.usageJson,
    thinkingDurationMs: thinkingDurationMs.present
        ? thinkingDurationMs.value
        : this.thinkingDurationMs,
    createdAt: createdAt ?? this.createdAt,
  );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      runId: data.runId.present ? data.runId.value : this.runId,
      role: data.role.present ? data.role.value : this.role,
      status: data.status.present ? data.status.value : this.status,
      partsJson: data.partsJson.present ? data.partsJson.value : this.partsJson,
      modelLabel: data.modelLabel.present
          ? data.modelLabel.value
          : this.modelLabel,
      usageJson: data.usageJson.present ? data.usageJson.value : this.usageJson,
      thinkingDurationMs: data.thinkingDurationMs.present
          ? data.thinkingDurationMs.value
          : this.thinkingDurationMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('parentId: $parentId, ')
          ..write('runId: $runId, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('partsJson: $partsJson, ')
          ..write('modelLabel: $modelLabel, ')
          ..write('usageJson: $usageJson, ')
          ..write('thinkingDurationMs: $thinkingDurationMs, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    parentId,
    runId,
    role,
    status,
    partsJson,
    modelLabel,
    usageJson,
    thinkingDurationMs,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.parentId == this.parentId &&
          other.runId == this.runId &&
          other.role == this.role &&
          other.status == this.status &&
          other.partsJson == this.partsJson &&
          other.modelLabel == this.modelLabel &&
          other.usageJson == this.usageJson &&
          other.thinkingDurationMs == this.thinkingDurationMs &&
          other.createdAt == this.createdAt);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String?> parentId;
  final Value<String?> runId;
  final Value<ChatRole> role;
  final Value<MessageStatus> status;
  final Value<String> partsJson;
  final Value<String?> modelLabel;
  final Value<String?> usageJson;
  final Value<int?> thinkingDurationMs;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.runId = const Value.absent(),
    this.role = const Value.absent(),
    this.status = const Value.absent(),
    this.partsJson = const Value.absent(),
    this.modelLabel = const Value.absent(),
    this.usageJson = const Value.absent(),
    this.thinkingDurationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String conversationId,
    this.parentId = const Value.absent(),
    this.runId = const Value.absent(),
    required ChatRole role,
    required MessageStatus status,
    this.partsJson = const Value.absent(),
    this.modelLabel = const Value.absent(),
    this.usageJson = const Value.absent(),
    this.thinkingDurationMs = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       role = Value(role),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<MessageRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? parentId,
    Expression<String>? runId,
    Expression<String>? role,
    Expression<String>? status,
    Expression<String>? partsJson,
    Expression<String>? modelLabel,
    Expression<String>? usageJson,
    Expression<int>? thinkingDurationMs,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (parentId != null) 'parent_id': parentId,
      if (runId != null) 'run_id': runId,
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      if (partsJson != null) 'parts_json': partsJson,
      if (modelLabel != null) 'model_label': modelLabel,
      if (usageJson != null) 'usage_json': usageJson,
      if (thinkingDurationMs != null)
        'thinking_duration_ms': thinkingDurationMs,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String?>? parentId,
    Value<String?>? runId,
    Value<ChatRole>? role,
    Value<MessageStatus>? status,
    Value<String>? partsJson,
    Value<String?>? modelLabel,
    Value<String?>? usageJson,
    Value<int?>? thinkingDurationMs,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      parentId: parentId ?? this.parentId,
      runId: runId ?? this.runId,
      role: role ?? this.role,
      status: status ?? this.status,
      partsJson: partsJson ?? this.partsJson,
      modelLabel: modelLabel ?? this.modelLabel,
      usageJson: usageJson ?? this.usageJson,
      thinkingDurationMs: thinkingDurationMs ?? this.thinkingDurationMs,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $MessagesTable.$converterrole.toSql(role.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $MessagesTable.$converterstatus.toSql(status.value),
      );
    }
    if (partsJson.present) {
      map['parts_json'] = Variable<String>(partsJson.value);
    }
    if (modelLabel.present) {
      map['model_label'] = Variable<String>(modelLabel.value);
    }
    if (usageJson.present) {
      map['usage_json'] = Variable<String>(usageJson.value);
    }
    if (thinkingDurationMs.present) {
      map['thinking_duration_ms'] = Variable<int>(thinkingDurationMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('parentId: $parentId, ')
          ..write('runId: $runId, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('partsJson: $partsJson, ')
          ..write('modelLabel: $modelLabel, ')
          ..write('usageJson: $usageJson, ')
          ..write('thinkingDurationMs: $thinkingDurationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, AttachmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extractedTextPathMeta = const VerificationMeta(
    'extractedTextPath',
  );
  @override
  late final GeneratedColumn<String> extractedTextPath =
      GeneratedColumn<String>(
        'extracted_text_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _extractionErrorMeta = const VerificationMeta(
    'extractionError',
  );
  @override
  late final GeneratedColumn<String> extractionError = GeneratedColumn<String>(
    'extraction_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    kind,
    name,
    mimeType,
    size,
    localPath,
    sha256,
    extractedTextPath,
    extractionError,
    width,
    height,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('extracted_text_path')) {
      context.handle(
        _extractedTextPathMeta,
        extractedTextPath.isAcceptableOrUnknown(
          data['extracted_text_path']!,
          _extractedTextPathMeta,
        ),
      );
    }
    if (data.containsKey('extraction_error')) {
      context.handle(
        _extractionErrorMeta,
        extractionError.isAcceptableOrUnknown(
          data['extraction_error']!,
          _extractionErrorMeta,
        ),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttachmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      extractedTextPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extracted_text_path'],
      ),
      extractionError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extraction_error'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class AttachmentRow extends DataClass implements Insertable<AttachmentRow> {
  final String id;
  final String conversationId;
  final String kind;
  final String name;
  final String mimeType;
  final int size;
  final String localPath;
  final String? sha256;
  final String? extractedTextPath;

  /// 抽取失败的原因（扫描件等）；成功或未尝试为 null。
  final String? extractionError;
  final int? width;
  final int? height;
  final DateTime createdAt;
  const AttachmentRow({
    required this.id,
    required this.conversationId,
    required this.kind,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.localPath,
    this.sha256,
    this.extractedTextPath,
    this.extractionError,
    this.width,
    this.height,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    map['mime_type'] = Variable<String>(mimeType);
    map['size'] = Variable<int>(size);
    map['local_path'] = Variable<String>(localPath);
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    if (!nullToAbsent || extractedTextPath != null) {
      map['extracted_text_path'] = Variable<String>(extractedTextPath);
    }
    if (!nullToAbsent || extractionError != null) {
      map['extraction_error'] = Variable<String>(extractionError);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      kind: Value(kind),
      name: Value(name),
      mimeType: Value(mimeType),
      size: Value(size),
      localPath: Value(localPath),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      extractedTextPath: extractedTextPath == null && nullToAbsent
          ? const Value.absent()
          : Value(extractedTextPath),
      extractionError: extractionError == null && nullToAbsent
          ? const Value.absent()
          : Value(extractionError),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      createdAt: Value(createdAt),
    );
  }

  factory AttachmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      size: serializer.fromJson<int>(json['size']),
      localPath: serializer.fromJson<String>(json['localPath']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      extractedTextPath: serializer.fromJson<String?>(
        json['extractedTextPath'],
      ),
      extractionError: serializer.fromJson<String?>(json['extractionError']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'mimeType': serializer.toJson<String>(mimeType),
      'size': serializer.toJson<int>(size),
      'localPath': serializer.toJson<String>(localPath),
      'sha256': serializer.toJson<String?>(sha256),
      'extractedTextPath': serializer.toJson<String?>(extractedTextPath),
      'extractionError': serializer.toJson<String?>(extractionError),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AttachmentRow copyWith({
    String? id,
    String? conversationId,
    String? kind,
    String? name,
    String? mimeType,
    int? size,
    String? localPath,
    Value<String?> sha256 = const Value.absent(),
    Value<String?> extractedTextPath = const Value.absent(),
    Value<String?> extractionError = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    DateTime? createdAt,
  }) => AttachmentRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    mimeType: mimeType ?? this.mimeType,
    size: size ?? this.size,
    localPath: localPath ?? this.localPath,
    sha256: sha256.present ? sha256.value : this.sha256,
    extractedTextPath: extractedTextPath.present
        ? extractedTextPath.value
        : this.extractedTextPath,
    extractionError: extractionError.present
        ? extractionError.value
        : this.extractionError,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    createdAt: createdAt ?? this.createdAt,
  );
  AttachmentRow copyWithCompanion(AttachmentsCompanion data) {
    return AttachmentRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      size: data.size.present ? data.size.value : this.size,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      extractedTextPath: data.extractedTextPath.present
          ? data.extractedTextPath.value
          : this.extractedTextPath,
      extractionError: data.extractionError.present
          ? data.extractionError.value
          : this.extractionError,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('localPath: $localPath, ')
          ..write('sha256: $sha256, ')
          ..write('extractedTextPath: $extractedTextPath, ')
          ..write('extractionError: $extractionError, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    kind,
    name,
    mimeType,
    size,
    localPath,
    sha256,
    extractedTextPath,
    extractionError,
    width,
    height,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.mimeType == this.mimeType &&
          other.size == this.size &&
          other.localPath == this.localPath &&
          other.sha256 == this.sha256 &&
          other.extractedTextPath == this.extractedTextPath &&
          other.extractionError == this.extractionError &&
          other.width == this.width &&
          other.height == this.height &&
          other.createdAt == this.createdAt);
}

class AttachmentsCompanion extends UpdateCompanion<AttachmentRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> kind;
  final Value<String> name;
  final Value<String> mimeType;
  final Value<int> size;
  final Value<String> localPath;
  final Value<String?> sha256;
  final Value<String?> extractedTextPath;
  final Value<String?> extractionError;
  final Value<int?> width;
  final Value<int?> height;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.size = const Value.absent(),
    this.localPath = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.extractedTextPath = const Value.absent(),
    this.extractionError = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    required String conversationId,
    required String kind,
    required String name,
    required String mimeType,
    required int size,
    required String localPath,
    this.sha256 = const Value.absent(),
    this.extractedTextPath = const Value.absent(),
    this.extractionError = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       kind = Value(kind),
       name = Value(name),
       mimeType = Value(mimeType),
       size = Value(size),
       localPath = Value(localPath),
       createdAt = Value(createdAt);
  static Insertable<AttachmentRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? mimeType,
    Expression<int>? size,
    Expression<String>? localPath,
    Expression<String>? sha256,
    Expression<String>? extractedTextPath,
    Expression<String>? extractionError,
    Expression<int>? width,
    Expression<int>? height,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (mimeType != null) 'mime_type': mimeType,
      if (size != null) 'size': size,
      if (localPath != null) 'local_path': localPath,
      if (sha256 != null) 'sha256': sha256,
      if (extractedTextPath != null) 'extracted_text_path': extractedTextPath,
      if (extractionError != null) 'extraction_error': extractionError,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? kind,
    Value<String>? name,
    Value<String>? mimeType,
    Value<int>? size,
    Value<String>? localPath,
    Value<String?>? sha256,
    Value<String?>? extractedTextPath,
    Value<String?>? extractionError,
    Value<int?>? width,
    Value<int?>? height,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      localPath: localPath ?? this.localPath,
      sha256: sha256 ?? this.sha256,
      extractedTextPath: extractedTextPath ?? this.extractedTextPath,
      extractionError: extractionError ?? this.extractionError,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (extractedTextPath.present) {
      map['extracted_text_path'] = Variable<String>(extractedTextPath.value);
    }
    if (extractionError.present) {
      map['extraction_error'] = Variable<String>(extractionError.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('localPath: $localPath, ')
          ..write('sha256: $sha256, ')
          ..write('extractedTextPath: $extractedTextPath, ')
          ..write('extractionError: $extractionError, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentRunsTable extends AgentRuns
    with TableInfo<$AgentRunsTable, AgentRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _assistantIdMeta = const VerificationMeta(
    'assistantId',
  );
  @override
  late final GeneratedColumn<String> assistantId = GeneratedColumn<String>(
    'assistant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inputMessageIdMeta = const VerificationMeta(
    'inputMessageId',
  );
  @override
  late final GeneratedColumn<String> inputMessageId = GeneratedColumn<String>(
    'input_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentMessageIdMeta = const VerificationMeta(
    'currentMessageId',
  );
  @override
  late final GeneratedColumn<String> currentMessageId = GeneratedColumn<String>(
    'current_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeToolCallIdMeta = const VerificationMeta(
    'activeToolCallId',
  );
  @override
  late final GeneratedColumn<String> activeToolCallId = GeneratedColumn<String>(
    'active_tool_call_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _configurationJsonMeta = const VerificationMeta(
    'configurationJson',
  );
  @override
  late final GeneratedColumn<String> configurationJson =
      GeneratedColumn<String>(
        'configuration_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  late final GeneratedColumnWithTypeConverter<RunStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RunStatus>($AgentRunsTable.$converterstatus);
  @override
  late final GeneratedColumnWithTypeConverter<RunFinishReason?, String>
  finishReason = GeneratedColumn<String>(
    'finish_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<RunFinishReason?>($AgentRunsTable.$converterfinishReasonn);
  static const VerificationMeta _turnCountMeta = const VerificationMeta(
    'turnCount',
  );
  @override
  late final GeneratedColumn<int> turnCount = GeneratedColumn<int>(
    'turn_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modelAttemptCountMeta = const VerificationMeta(
    'modelAttemptCount',
  );
  @override
  late final GeneratedColumn<int> modelAttemptCount = GeneratedColumn<int>(
    'model_attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxTurnsMeta = const VerificationMeta(
    'maxTurns',
  );
  @override
  late final GeneratedColumn<int> maxTurns = GeneratedColumn<int>(
    'max_turns',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usageJsonMeta = const VerificationMeta(
    'usageJson',
  );
  @override
  late final GeneratedColumn<String> usageJson = GeneratedColumn<String>(
    'usage_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    assistantId,
    inputMessageId,
    currentMessageId,
    activeToolCallId,
    configurationJson,
    status,
    finishReason,
    turnCount,
    modelAttemptCount,
    maxTurns,
    usageJson,
    createdAt,
    finishedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('assistant_id')) {
      context.handle(
        _assistantIdMeta,
        assistantId.isAcceptableOrUnknown(
          data['assistant_id']!,
          _assistantIdMeta,
        ),
      );
    }
    if (data.containsKey('input_message_id')) {
      context.handle(
        _inputMessageIdMeta,
        inputMessageId.isAcceptableOrUnknown(
          data['input_message_id']!,
          _inputMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inputMessageIdMeta);
    }
    if (data.containsKey('current_message_id')) {
      context.handle(
        _currentMessageIdMeta,
        currentMessageId.isAcceptableOrUnknown(
          data['current_message_id']!,
          _currentMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('active_tool_call_id')) {
      context.handle(
        _activeToolCallIdMeta,
        activeToolCallId.isAcceptableOrUnknown(
          data['active_tool_call_id']!,
          _activeToolCallIdMeta,
        ),
      );
    }
    if (data.containsKey('configuration_json')) {
      context.handle(
        _configurationJsonMeta,
        configurationJson.isAcceptableOrUnknown(
          data['configuration_json']!,
          _configurationJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_configurationJsonMeta);
    }
    if (data.containsKey('turn_count')) {
      context.handle(
        _turnCountMeta,
        turnCount.isAcceptableOrUnknown(data['turn_count']!, _turnCountMeta),
      );
    }
    if (data.containsKey('model_attempt_count')) {
      context.handle(
        _modelAttemptCountMeta,
        modelAttemptCount.isAcceptableOrUnknown(
          data['model_attempt_count']!,
          _modelAttemptCountMeta,
        ),
      );
    }
    if (data.containsKey('max_turns')) {
      context.handle(
        _maxTurnsMeta,
        maxTurns.isAcceptableOrUnknown(data['max_turns']!, _maxTurnsMeta),
      );
    } else if (isInserting) {
      context.missing(_maxTurnsMeta);
    }
    if (data.containsKey('usage_json')) {
      context.handle(
        _usageJsonMeta,
        usageJson.isAcceptableOrUnknown(data['usage_json']!, _usageJsonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      assistantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assistant_id'],
      ),
      inputMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_message_id'],
      )!,
      currentMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_message_id'],
      ),
      activeToolCallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_tool_call_id'],
      ),
      configurationJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}configuration_json'],
      )!,
      status: $AgentRunsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      finishReason: $AgentRunsTable.$converterfinishReasonn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}finish_reason'],
        ),
      ),
      turnCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}turn_count'],
      )!,
      modelAttemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}model_attempt_count'],
      )!,
      maxTurns: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_turns'],
      )!,
      usageJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}usage_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
    );
  }

  @override
  $AgentRunsTable createAlias(String alias) {
    return $AgentRunsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RunStatus, String, String> $converterstatus =
      const EnumNameConverter<RunStatus>(RunStatus.values);
  static JsonTypeConverter2<RunFinishReason, String, String>
  $converterfinishReason = const EnumNameConverter<RunFinishReason>(
    RunFinishReason.values,
  );
  static JsonTypeConverter2<RunFinishReason?, String?, String?>
  $converterfinishReasonn = JsonTypeConverter2.asNullable(
    $converterfinishReason,
  );
}

class AgentRunRow extends DataClass implements Insertable<AgentRunRow> {
  final String id;
  final String conversationId;
  final String? assistantId;
  final String inputMessageId;
  final String? currentMessageId;
  final String? activeToolCallId;

  /// RunConfiguration 的 JSON；密钥不在其中。
  final String configurationJson;
  final RunStatus status;
  final RunFinishReason? finishReason;
  final int turnCount;
  final int modelAttemptCount;
  final int maxTurns;

  /// TokenUsage 的 JSON；未收口时为 null。
  final String? usageJson;
  final DateTime createdAt;
  final DateTime? finishedAt;
  const AgentRunRow({
    required this.id,
    required this.conversationId,
    this.assistantId,
    required this.inputMessageId,
    this.currentMessageId,
    this.activeToolCallId,
    required this.configurationJson,
    required this.status,
    this.finishReason,
    required this.turnCount,
    required this.modelAttemptCount,
    required this.maxTurns,
    this.usageJson,
    required this.createdAt,
    this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    if (!nullToAbsent || assistantId != null) {
      map['assistant_id'] = Variable<String>(assistantId);
    }
    map['input_message_id'] = Variable<String>(inputMessageId);
    if (!nullToAbsent || currentMessageId != null) {
      map['current_message_id'] = Variable<String>(currentMessageId);
    }
    if (!nullToAbsent || activeToolCallId != null) {
      map['active_tool_call_id'] = Variable<String>(activeToolCallId);
    }
    map['configuration_json'] = Variable<String>(configurationJson);
    {
      map['status'] = Variable<String>(
        $AgentRunsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || finishReason != null) {
      map['finish_reason'] = Variable<String>(
        $AgentRunsTable.$converterfinishReasonn.toSql(finishReason),
      );
    }
    map['turn_count'] = Variable<int>(turnCount);
    map['model_attempt_count'] = Variable<int>(modelAttemptCount);
    map['max_turns'] = Variable<int>(maxTurns);
    if (!nullToAbsent || usageJson != null) {
      map['usage_json'] = Variable<String>(usageJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    return map;
  }

  AgentRunsCompanion toCompanion(bool nullToAbsent) {
    return AgentRunsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      assistantId: assistantId == null && nullToAbsent
          ? const Value.absent()
          : Value(assistantId),
      inputMessageId: Value(inputMessageId),
      currentMessageId: currentMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentMessageId),
      activeToolCallId: activeToolCallId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeToolCallId),
      configurationJson: Value(configurationJson),
      status: Value(status),
      finishReason: finishReason == null && nullToAbsent
          ? const Value.absent()
          : Value(finishReason),
      turnCount: Value(turnCount),
      modelAttemptCount: Value(modelAttemptCount),
      maxTurns: Value(maxTurns),
      usageJson: usageJson == null && nullToAbsent
          ? const Value.absent()
          : Value(usageJson),
      createdAt: Value(createdAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
    );
  }

  factory AgentRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentRunRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      assistantId: serializer.fromJson<String?>(json['assistantId']),
      inputMessageId: serializer.fromJson<String>(json['inputMessageId']),
      currentMessageId: serializer.fromJson<String?>(json['currentMessageId']),
      activeToolCallId: serializer.fromJson<String?>(json['activeToolCallId']),
      configurationJson: serializer.fromJson<String>(json['configurationJson']),
      status: $AgentRunsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      finishReason: $AgentRunsTable.$converterfinishReasonn.fromJson(
        serializer.fromJson<String?>(json['finishReason']),
      ),
      turnCount: serializer.fromJson<int>(json['turnCount']),
      modelAttemptCount: serializer.fromJson<int>(json['modelAttemptCount']),
      maxTurns: serializer.fromJson<int>(json['maxTurns']),
      usageJson: serializer.fromJson<String?>(json['usageJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'assistantId': serializer.toJson<String?>(assistantId),
      'inputMessageId': serializer.toJson<String>(inputMessageId),
      'currentMessageId': serializer.toJson<String?>(currentMessageId),
      'activeToolCallId': serializer.toJson<String?>(activeToolCallId),
      'configurationJson': serializer.toJson<String>(configurationJson),
      'status': serializer.toJson<String>(
        $AgentRunsTable.$converterstatus.toJson(status),
      ),
      'finishReason': serializer.toJson<String?>(
        $AgentRunsTable.$converterfinishReasonn.toJson(finishReason),
      ),
      'turnCount': serializer.toJson<int>(turnCount),
      'modelAttemptCount': serializer.toJson<int>(modelAttemptCount),
      'maxTurns': serializer.toJson<int>(maxTurns),
      'usageJson': serializer.toJson<String?>(usageJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
    };
  }

  AgentRunRow copyWith({
    String? id,
    String? conversationId,
    Value<String?> assistantId = const Value.absent(),
    String? inputMessageId,
    Value<String?> currentMessageId = const Value.absent(),
    Value<String?> activeToolCallId = const Value.absent(),
    String? configurationJson,
    RunStatus? status,
    Value<RunFinishReason?> finishReason = const Value.absent(),
    int? turnCount,
    int? modelAttemptCount,
    int? maxTurns,
    Value<String?> usageJson = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> finishedAt = const Value.absent(),
  }) => AgentRunRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    assistantId: assistantId.present ? assistantId.value : this.assistantId,
    inputMessageId: inputMessageId ?? this.inputMessageId,
    currentMessageId: currentMessageId.present
        ? currentMessageId.value
        : this.currentMessageId,
    activeToolCallId: activeToolCallId.present
        ? activeToolCallId.value
        : this.activeToolCallId,
    configurationJson: configurationJson ?? this.configurationJson,
    status: status ?? this.status,
    finishReason: finishReason.present ? finishReason.value : this.finishReason,
    turnCount: turnCount ?? this.turnCount,
    modelAttemptCount: modelAttemptCount ?? this.modelAttemptCount,
    maxTurns: maxTurns ?? this.maxTurns,
    usageJson: usageJson.present ? usageJson.value : this.usageJson,
    createdAt: createdAt ?? this.createdAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
  );
  AgentRunRow copyWithCompanion(AgentRunsCompanion data) {
    return AgentRunRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      assistantId: data.assistantId.present
          ? data.assistantId.value
          : this.assistantId,
      inputMessageId: data.inputMessageId.present
          ? data.inputMessageId.value
          : this.inputMessageId,
      currentMessageId: data.currentMessageId.present
          ? data.currentMessageId.value
          : this.currentMessageId,
      activeToolCallId: data.activeToolCallId.present
          ? data.activeToolCallId.value
          : this.activeToolCallId,
      configurationJson: data.configurationJson.present
          ? data.configurationJson.value
          : this.configurationJson,
      status: data.status.present ? data.status.value : this.status,
      finishReason: data.finishReason.present
          ? data.finishReason.value
          : this.finishReason,
      turnCount: data.turnCount.present ? data.turnCount.value : this.turnCount,
      modelAttemptCount: data.modelAttemptCount.present
          ? data.modelAttemptCount.value
          : this.modelAttemptCount,
      maxTurns: data.maxTurns.present ? data.maxTurns.value : this.maxTurns,
      usageJson: data.usageJson.present ? data.usageJson.value : this.usageJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentRunRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('assistantId: $assistantId, ')
          ..write('inputMessageId: $inputMessageId, ')
          ..write('currentMessageId: $currentMessageId, ')
          ..write('activeToolCallId: $activeToolCallId, ')
          ..write('configurationJson: $configurationJson, ')
          ..write('status: $status, ')
          ..write('finishReason: $finishReason, ')
          ..write('turnCount: $turnCount, ')
          ..write('modelAttemptCount: $modelAttemptCount, ')
          ..write('maxTurns: $maxTurns, ')
          ..write('usageJson: $usageJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    assistantId,
    inputMessageId,
    currentMessageId,
    activeToolCallId,
    configurationJson,
    status,
    finishReason,
    turnCount,
    modelAttemptCount,
    maxTurns,
    usageJson,
    createdAt,
    finishedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentRunRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.assistantId == this.assistantId &&
          other.inputMessageId == this.inputMessageId &&
          other.currentMessageId == this.currentMessageId &&
          other.activeToolCallId == this.activeToolCallId &&
          other.configurationJson == this.configurationJson &&
          other.status == this.status &&
          other.finishReason == this.finishReason &&
          other.turnCount == this.turnCount &&
          other.modelAttemptCount == this.modelAttemptCount &&
          other.maxTurns == this.maxTurns &&
          other.usageJson == this.usageJson &&
          other.createdAt == this.createdAt &&
          other.finishedAt == this.finishedAt);
}

class AgentRunsCompanion extends UpdateCompanion<AgentRunRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String?> assistantId;
  final Value<String> inputMessageId;
  final Value<String?> currentMessageId;
  final Value<String?> activeToolCallId;
  final Value<String> configurationJson;
  final Value<RunStatus> status;
  final Value<RunFinishReason?> finishReason;
  final Value<int> turnCount;
  final Value<int> modelAttemptCount;
  final Value<int> maxTurns;
  final Value<String?> usageJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> finishedAt;
  final Value<int> rowid;
  const AgentRunsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.inputMessageId = const Value.absent(),
    this.currentMessageId = const Value.absent(),
    this.activeToolCallId = const Value.absent(),
    this.configurationJson = const Value.absent(),
    this.status = const Value.absent(),
    this.finishReason = const Value.absent(),
    this.turnCount = const Value.absent(),
    this.modelAttemptCount = const Value.absent(),
    this.maxTurns = const Value.absent(),
    this.usageJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentRunsCompanion.insert({
    required String id,
    required String conversationId,
    this.assistantId = const Value.absent(),
    required String inputMessageId,
    this.currentMessageId = const Value.absent(),
    this.activeToolCallId = const Value.absent(),
    required String configurationJson,
    required RunStatus status,
    this.finishReason = const Value.absent(),
    this.turnCount = const Value.absent(),
    this.modelAttemptCount = const Value.absent(),
    required int maxTurns,
    this.usageJson = const Value.absent(),
    required DateTime createdAt,
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       inputMessageId = Value(inputMessageId),
       configurationJson = Value(configurationJson),
       status = Value(status),
       maxTurns = Value(maxTurns),
       createdAt = Value(createdAt);
  static Insertable<AgentRunRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? assistantId,
    Expression<String>? inputMessageId,
    Expression<String>? currentMessageId,
    Expression<String>? activeToolCallId,
    Expression<String>? configurationJson,
    Expression<String>? status,
    Expression<String>? finishReason,
    Expression<int>? turnCount,
    Expression<int>? modelAttemptCount,
    Expression<int>? maxTurns,
    Expression<String>? usageJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? finishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (assistantId != null) 'assistant_id': assistantId,
      if (inputMessageId != null) 'input_message_id': inputMessageId,
      if (currentMessageId != null) 'current_message_id': currentMessageId,
      if (activeToolCallId != null) 'active_tool_call_id': activeToolCallId,
      if (configurationJson != null) 'configuration_json': configurationJson,
      if (status != null) 'status': status,
      if (finishReason != null) 'finish_reason': finishReason,
      if (turnCount != null) 'turn_count': turnCount,
      if (modelAttemptCount != null) 'model_attempt_count': modelAttemptCount,
      if (maxTurns != null) 'max_turns': maxTurns,
      if (usageJson != null) 'usage_json': usageJson,
      if (createdAt != null) 'created_at': createdAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentRunsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String?>? assistantId,
    Value<String>? inputMessageId,
    Value<String?>? currentMessageId,
    Value<String?>? activeToolCallId,
    Value<String>? configurationJson,
    Value<RunStatus>? status,
    Value<RunFinishReason?>? finishReason,
    Value<int>? turnCount,
    Value<int>? modelAttemptCount,
    Value<int>? maxTurns,
    Value<String?>? usageJson,
    Value<DateTime>? createdAt,
    Value<DateTime?>? finishedAt,
    Value<int>? rowid,
  }) {
    return AgentRunsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      assistantId: assistantId ?? this.assistantId,
      inputMessageId: inputMessageId ?? this.inputMessageId,
      currentMessageId: currentMessageId ?? this.currentMessageId,
      activeToolCallId: activeToolCallId ?? this.activeToolCallId,
      configurationJson: configurationJson ?? this.configurationJson,
      status: status ?? this.status,
      finishReason: finishReason ?? this.finishReason,
      turnCount: turnCount ?? this.turnCount,
      modelAttemptCount: modelAttemptCount ?? this.modelAttemptCount,
      maxTurns: maxTurns ?? this.maxTurns,
      usageJson: usageJson ?? this.usageJson,
      createdAt: createdAt ?? this.createdAt,
      finishedAt: finishedAt ?? this.finishedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (assistantId.present) {
      map['assistant_id'] = Variable<String>(assistantId.value);
    }
    if (inputMessageId.present) {
      map['input_message_id'] = Variable<String>(inputMessageId.value);
    }
    if (currentMessageId.present) {
      map['current_message_id'] = Variable<String>(currentMessageId.value);
    }
    if (activeToolCallId.present) {
      map['active_tool_call_id'] = Variable<String>(activeToolCallId.value);
    }
    if (configurationJson.present) {
      map['configuration_json'] = Variable<String>(configurationJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $AgentRunsTable.$converterstatus.toSql(status.value),
      );
    }
    if (finishReason.present) {
      map['finish_reason'] = Variable<String>(
        $AgentRunsTable.$converterfinishReasonn.toSql(finishReason.value),
      );
    }
    if (turnCount.present) {
      map['turn_count'] = Variable<int>(turnCount.value);
    }
    if (modelAttemptCount.present) {
      map['model_attempt_count'] = Variable<int>(modelAttemptCount.value);
    }
    if (maxTurns.present) {
      map['max_turns'] = Variable<int>(maxTurns.value);
    }
    if (usageJson.present) {
      map['usage_json'] = Variable<String>(usageJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentRunsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('assistantId: $assistantId, ')
          ..write('inputMessageId: $inputMessageId, ')
          ..write('currentMessageId: $currentMessageId, ')
          ..write('activeToolCallId: $activeToolCallId, ')
          ..write('configurationJson: $configurationJson, ')
          ..write('status: $status, ')
          ..write('finishReason: $finishReason, ')
          ..write('turnCount: $turnCount, ')
          ..write('modelAttemptCount: $modelAttemptCount, ')
          ..write('maxTurns: $maxTurns, ')
          ..write('usageJson: $usageJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ToolCallsTable extends ToolCalls
    with TableInfo<$ToolCallsTable, ToolCallRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ToolCallsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES agent_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _assistantMessageIdMeta =
      const VerificationMeta('assistantMessageId');
  @override
  late final GeneratedColumn<String> assistantMessageId =
      GeneratedColumn<String>(
        'assistant_message_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _resultMessageIdMeta = const VerificationMeta(
    'resultMessageId',
  );
  @override
  late final GeneratedColumn<String> resultMessageId = GeneratedColumn<String>(
    'result_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerCallIdMeta = const VerificationMeta(
    'providerCallId',
  );
  @override
  late final GeneratedColumn<String> providerCallId = GeneratedColumn<String>(
    'provider_call_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toolNameMeta = const VerificationMeta(
    'toolName',
  );
  @override
  late final GeneratedColumn<String> toolName = GeneratedColumn<String>(
    'tool_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _argumentsJsonMeta = const VerificationMeta(
    'argumentsJson',
  );
  @override
  late final GeneratedColumn<String> argumentsJson = GeneratedColumn<String>(
    'arguments_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerDataJsonMeta = const VerificationMeta(
    'providerDataJson',
  );
  @override
  late final GeneratedColumn<String> providerDataJson = GeneratedColumn<String>(
    'provider_data_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ExecutionChannel, String>
  channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ExecutionChannel>($ToolCallsTable.$converterchannel);
  @override
  late final GeneratedColumnWithTypeConverter<ToolPolicy, String>
  defaultPolicy = GeneratedColumn<String>(
    'default_policy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ToolPolicy>($ToolCallsTable.$converterdefaultPolicy);
  @override
  late final GeneratedColumnWithTypeConverter<ToolCallStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ToolCallStatus>($ToolCallsTable.$converterstatus);
  @override
  late final GeneratedColumnWithTypeConverter<ToolDecision?, String> decision =
      GeneratedColumn<String>(
        'decision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<ToolDecision?>($ToolCallsTable.$converterdecisionn);
  static const VerificationMeta _confirmationRequestedAtMeta =
      const VerificationMeta('confirmationRequestedAt');
  @override
  late final GeneratedColumn<DateTime> confirmationRequestedAt =
      GeneratedColumn<DateTime>(
        'confirmation_requested_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _confirmationExpiresAtMeta =
      const VerificationMeta('confirmationExpiresAt');
  @override
  late final GeneratedColumn<DateTime> confirmationExpiresAt =
      GeneratedColumn<DateTime>(
        'confirmation_expires_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _decidedAtMeta = const VerificationMeta(
    'decidedAt',
  );
  @override
  late final GeneratedColumn<DateTime> decidedAt = GeneratedColumn<DateTime>(
    'decided_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artifactsJsonMeta = const VerificationMeta(
    'artifactsJson',
  );
  @override
  late final GeneratedColumn<String> artifactsJson = GeneratedColumn<String>(
    'artifacts_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    assistantMessageId,
    resultMessageId,
    providerCallId,
    toolName,
    argumentsJson,
    providerDataJson,
    target,
    channel,
    defaultPolicy,
    status,
    decision,
    confirmationRequestedAt,
    confirmationExpiresAt,
    decidedAt,
    result,
    artifactsJson,
    errorCode,
    createdAt,
    startedAt,
    finishedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tool_calls';
  @override
  VerificationContext validateIntegrity(
    Insertable<ToolCallRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('assistant_message_id')) {
      context.handle(
        _assistantMessageIdMeta,
        assistantMessageId.isAcceptableOrUnknown(
          data['assistant_message_id']!,
          _assistantMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assistantMessageIdMeta);
    }
    if (data.containsKey('result_message_id')) {
      context.handle(
        _resultMessageIdMeta,
        resultMessageId.isAcceptableOrUnknown(
          data['result_message_id']!,
          _resultMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('provider_call_id')) {
      context.handle(
        _providerCallIdMeta,
        providerCallId.isAcceptableOrUnknown(
          data['provider_call_id']!,
          _providerCallIdMeta,
        ),
      );
    }
    if (data.containsKey('tool_name')) {
      context.handle(
        _toolNameMeta,
        toolName.isAcceptableOrUnknown(data['tool_name']!, _toolNameMeta),
      );
    } else if (isInserting) {
      context.missing(_toolNameMeta);
    }
    if (data.containsKey('arguments_json')) {
      context.handle(
        _argumentsJsonMeta,
        argumentsJson.isAcceptableOrUnknown(
          data['arguments_json']!,
          _argumentsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_argumentsJsonMeta);
    }
    if (data.containsKey('provider_data_json')) {
      context.handle(
        _providerDataJsonMeta,
        providerDataJson.isAcceptableOrUnknown(
          data['provider_data_json']!,
          _providerDataJsonMeta,
        ),
      );
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    }
    if (data.containsKey('confirmation_requested_at')) {
      context.handle(
        _confirmationRequestedAtMeta,
        confirmationRequestedAt.isAcceptableOrUnknown(
          data['confirmation_requested_at']!,
          _confirmationRequestedAtMeta,
        ),
      );
    }
    if (data.containsKey('confirmation_expires_at')) {
      context.handle(
        _confirmationExpiresAtMeta,
        confirmationExpiresAt.isAcceptableOrUnknown(
          data['confirmation_expires_at']!,
          _confirmationExpiresAtMeta,
        ),
      );
    }
    if (data.containsKey('decided_at')) {
      context.handle(
        _decidedAtMeta,
        decidedAt.isAcceptableOrUnknown(data['decided_at']!, _decidedAtMeta),
      );
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    if (data.containsKey('artifacts_json')) {
      context.handle(
        _artifactsJsonMeta,
        artifactsJson.isAcceptableOrUnknown(
          data['artifacts_json']!,
          _artifactsJsonMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ToolCallRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ToolCallRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      assistantMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assistant_message_id'],
      )!,
      resultMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_message_id'],
      ),
      providerCallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_call_id'],
      ),
      toolName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_name'],
      )!,
      argumentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arguments_json'],
      )!,
      providerDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_data_json'],
      ),
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      ),
      channel: $ToolCallsTable.$converterchannel.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}channel'],
        )!,
      ),
      defaultPolicy: $ToolCallsTable.$converterdefaultPolicy.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}default_policy'],
        )!,
      ),
      status: $ToolCallsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      decision: $ToolCallsTable.$converterdecisionn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}decision'],
        ),
      ),
      confirmationRequestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}confirmation_requested_at'],
      ),
      confirmationExpiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}confirmation_expires_at'],
      ),
      decidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}decided_at'],
      ),
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      ),
      artifactsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artifacts_json'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
    );
  }

  @override
  $ToolCallsTable createAlias(String alias) {
    return $ToolCallsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ExecutionChannel, String, String>
  $converterchannel = const EnumNameConverter<ExecutionChannel>(
    ExecutionChannel.values,
  );
  static JsonTypeConverter2<ToolPolicy, String, String>
  $converterdefaultPolicy = const EnumNameConverter<ToolPolicy>(
    ToolPolicy.values,
  );
  static JsonTypeConverter2<ToolCallStatus, String, String> $converterstatus =
      const EnumNameConverter<ToolCallStatus>(ToolCallStatus.values);
  static JsonTypeConverter2<ToolDecision, String, String> $converterdecision =
      const EnumNameConverter<ToolDecision>(ToolDecision.values);
  static JsonTypeConverter2<ToolDecision?, String?, String?>
  $converterdecisionn = JsonTypeConverter2.asNullable($converterdecision);
}

class ToolCallRow extends DataClass implements Insertable<ToolCallRow> {
  final String id;
  final String runId;
  final String assistantMessageId;
  final String? resultMessageId;

  /// 模型协议自己的调用 id，仅用于结果回填。
  final String? providerCallId;
  final String toolName;
  final String argumentsJson;
  final String? providerDataJson;
  final String? target;
  final ExecutionChannel channel;
  final ToolPolicy defaultPolicy;
  final ToolCallStatus status;
  final ToolDecision? decision;
  final DateTime? confirmationRequestedAt;
  final DateTime? confirmationExpiresAt;
  final DateTime? decidedAt;
  final String? result;

  /// 产物附件 id 列表的 JSON。
  final String artifactsJson;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  const ToolCallRow({
    required this.id,
    required this.runId,
    required this.assistantMessageId,
    this.resultMessageId,
    this.providerCallId,
    required this.toolName,
    required this.argumentsJson,
    this.providerDataJson,
    this.target,
    required this.channel,
    required this.defaultPolicy,
    required this.status,
    this.decision,
    this.confirmationRequestedAt,
    this.confirmationExpiresAt,
    this.decidedAt,
    this.result,
    required this.artifactsJson,
    this.errorCode,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['assistant_message_id'] = Variable<String>(assistantMessageId);
    if (!nullToAbsent || resultMessageId != null) {
      map['result_message_id'] = Variable<String>(resultMessageId);
    }
    if (!nullToAbsent || providerCallId != null) {
      map['provider_call_id'] = Variable<String>(providerCallId);
    }
    map['tool_name'] = Variable<String>(toolName);
    map['arguments_json'] = Variable<String>(argumentsJson);
    if (!nullToAbsent || providerDataJson != null) {
      map['provider_data_json'] = Variable<String>(providerDataJson);
    }
    if (!nullToAbsent || target != null) {
      map['target'] = Variable<String>(target);
    }
    {
      map['channel'] = Variable<String>(
        $ToolCallsTable.$converterchannel.toSql(channel),
      );
    }
    {
      map['default_policy'] = Variable<String>(
        $ToolCallsTable.$converterdefaultPolicy.toSql(defaultPolicy),
      );
    }
    {
      map['status'] = Variable<String>(
        $ToolCallsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || decision != null) {
      map['decision'] = Variable<String>(
        $ToolCallsTable.$converterdecisionn.toSql(decision),
      );
    }
    if (!nullToAbsent || confirmationRequestedAt != null) {
      map['confirmation_requested_at'] = Variable<DateTime>(
        confirmationRequestedAt,
      );
    }
    if (!nullToAbsent || confirmationExpiresAt != null) {
      map['confirmation_expires_at'] = Variable<DateTime>(
        confirmationExpiresAt,
      );
    }
    if (!nullToAbsent || decidedAt != null) {
      map['decided_at'] = Variable<DateTime>(decidedAt);
    }
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    map['artifacts_json'] = Variable<String>(artifactsJson);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    return map;
  }

  ToolCallsCompanion toCompanion(bool nullToAbsent) {
    return ToolCallsCompanion(
      id: Value(id),
      runId: Value(runId),
      assistantMessageId: Value(assistantMessageId),
      resultMessageId: resultMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(resultMessageId),
      providerCallId: providerCallId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerCallId),
      toolName: Value(toolName),
      argumentsJson: Value(argumentsJson),
      providerDataJson: providerDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(providerDataJson),
      target: target == null && nullToAbsent
          ? const Value.absent()
          : Value(target),
      channel: Value(channel),
      defaultPolicy: Value(defaultPolicy),
      status: Value(status),
      decision: decision == null && nullToAbsent
          ? const Value.absent()
          : Value(decision),
      confirmationRequestedAt: confirmationRequestedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmationRequestedAt),
      confirmationExpiresAt: confirmationExpiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmationExpiresAt),
      decidedAt: decidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(decidedAt),
      result: result == null && nullToAbsent
          ? const Value.absent()
          : Value(result),
      artifactsJson: Value(artifactsJson),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      createdAt: Value(createdAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
    );
  }

  factory ToolCallRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ToolCallRow(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      assistantMessageId: serializer.fromJson<String>(
        json['assistantMessageId'],
      ),
      resultMessageId: serializer.fromJson<String?>(json['resultMessageId']),
      providerCallId: serializer.fromJson<String?>(json['providerCallId']),
      toolName: serializer.fromJson<String>(json['toolName']),
      argumentsJson: serializer.fromJson<String>(json['argumentsJson']),
      providerDataJson: serializer.fromJson<String?>(json['providerDataJson']),
      target: serializer.fromJson<String?>(json['target']),
      channel: $ToolCallsTable.$converterchannel.fromJson(
        serializer.fromJson<String>(json['channel']),
      ),
      defaultPolicy: $ToolCallsTable.$converterdefaultPolicy.fromJson(
        serializer.fromJson<String>(json['defaultPolicy']),
      ),
      status: $ToolCallsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      decision: $ToolCallsTable.$converterdecisionn.fromJson(
        serializer.fromJson<String?>(json['decision']),
      ),
      confirmationRequestedAt: serializer.fromJson<DateTime?>(
        json['confirmationRequestedAt'],
      ),
      confirmationExpiresAt: serializer.fromJson<DateTime?>(
        json['confirmationExpiresAt'],
      ),
      decidedAt: serializer.fromJson<DateTime?>(json['decidedAt']),
      result: serializer.fromJson<String?>(json['result']),
      artifactsJson: serializer.fromJson<String>(json['artifactsJson']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'assistantMessageId': serializer.toJson<String>(assistantMessageId),
      'resultMessageId': serializer.toJson<String?>(resultMessageId),
      'providerCallId': serializer.toJson<String?>(providerCallId),
      'toolName': serializer.toJson<String>(toolName),
      'argumentsJson': serializer.toJson<String>(argumentsJson),
      'providerDataJson': serializer.toJson<String?>(providerDataJson),
      'target': serializer.toJson<String?>(target),
      'channel': serializer.toJson<String>(
        $ToolCallsTable.$converterchannel.toJson(channel),
      ),
      'defaultPolicy': serializer.toJson<String>(
        $ToolCallsTable.$converterdefaultPolicy.toJson(defaultPolicy),
      ),
      'status': serializer.toJson<String>(
        $ToolCallsTable.$converterstatus.toJson(status),
      ),
      'decision': serializer.toJson<String?>(
        $ToolCallsTable.$converterdecisionn.toJson(decision),
      ),
      'confirmationRequestedAt': serializer.toJson<DateTime?>(
        confirmationRequestedAt,
      ),
      'confirmationExpiresAt': serializer.toJson<DateTime?>(
        confirmationExpiresAt,
      ),
      'decidedAt': serializer.toJson<DateTime?>(decidedAt),
      'result': serializer.toJson<String?>(result),
      'artifactsJson': serializer.toJson<String>(artifactsJson),
      'errorCode': serializer.toJson<String?>(errorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
    };
  }

  ToolCallRow copyWith({
    String? id,
    String? runId,
    String? assistantMessageId,
    Value<String?> resultMessageId = const Value.absent(),
    Value<String?> providerCallId = const Value.absent(),
    String? toolName,
    String? argumentsJson,
    Value<String?> providerDataJson = const Value.absent(),
    Value<String?> target = const Value.absent(),
    ExecutionChannel? channel,
    ToolPolicy? defaultPolicy,
    ToolCallStatus? status,
    Value<ToolDecision?> decision = const Value.absent(),
    Value<DateTime?> confirmationRequestedAt = const Value.absent(),
    Value<DateTime?> confirmationExpiresAt = const Value.absent(),
    Value<DateTime?> decidedAt = const Value.absent(),
    Value<String?> result = const Value.absent(),
    String? artifactsJson,
    Value<String?> errorCode = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> finishedAt = const Value.absent(),
  }) => ToolCallRow(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    assistantMessageId: assistantMessageId ?? this.assistantMessageId,
    resultMessageId: resultMessageId.present
        ? resultMessageId.value
        : this.resultMessageId,
    providerCallId: providerCallId.present
        ? providerCallId.value
        : this.providerCallId,
    toolName: toolName ?? this.toolName,
    argumentsJson: argumentsJson ?? this.argumentsJson,
    providerDataJson: providerDataJson.present
        ? providerDataJson.value
        : this.providerDataJson,
    target: target.present ? target.value : this.target,
    channel: channel ?? this.channel,
    defaultPolicy: defaultPolicy ?? this.defaultPolicy,
    status: status ?? this.status,
    decision: decision.present ? decision.value : this.decision,
    confirmationRequestedAt: confirmationRequestedAt.present
        ? confirmationRequestedAt.value
        : this.confirmationRequestedAt,
    confirmationExpiresAt: confirmationExpiresAt.present
        ? confirmationExpiresAt.value
        : this.confirmationExpiresAt,
    decidedAt: decidedAt.present ? decidedAt.value : this.decidedAt,
    result: result.present ? result.value : this.result,
    artifactsJson: artifactsJson ?? this.artifactsJson,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
  );
  ToolCallRow copyWithCompanion(ToolCallsCompanion data) {
    return ToolCallRow(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      assistantMessageId: data.assistantMessageId.present
          ? data.assistantMessageId.value
          : this.assistantMessageId,
      resultMessageId: data.resultMessageId.present
          ? data.resultMessageId.value
          : this.resultMessageId,
      providerCallId: data.providerCallId.present
          ? data.providerCallId.value
          : this.providerCallId,
      toolName: data.toolName.present ? data.toolName.value : this.toolName,
      argumentsJson: data.argumentsJson.present
          ? data.argumentsJson.value
          : this.argumentsJson,
      providerDataJson: data.providerDataJson.present
          ? data.providerDataJson.value
          : this.providerDataJson,
      target: data.target.present ? data.target.value : this.target,
      channel: data.channel.present ? data.channel.value : this.channel,
      defaultPolicy: data.defaultPolicy.present
          ? data.defaultPolicy.value
          : this.defaultPolicy,
      status: data.status.present ? data.status.value : this.status,
      decision: data.decision.present ? data.decision.value : this.decision,
      confirmationRequestedAt: data.confirmationRequestedAt.present
          ? data.confirmationRequestedAt.value
          : this.confirmationRequestedAt,
      confirmationExpiresAt: data.confirmationExpiresAt.present
          ? data.confirmationExpiresAt.value
          : this.confirmationExpiresAt,
      decidedAt: data.decidedAt.present ? data.decidedAt.value : this.decidedAt,
      result: data.result.present ? data.result.value : this.result,
      artifactsJson: data.artifactsJson.present
          ? data.artifactsJson.value
          : this.artifactsJson,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ToolCallRow(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('assistantMessageId: $assistantMessageId, ')
          ..write('resultMessageId: $resultMessageId, ')
          ..write('providerCallId: $providerCallId, ')
          ..write('toolName: $toolName, ')
          ..write('argumentsJson: $argumentsJson, ')
          ..write('providerDataJson: $providerDataJson, ')
          ..write('target: $target, ')
          ..write('channel: $channel, ')
          ..write('defaultPolicy: $defaultPolicy, ')
          ..write('status: $status, ')
          ..write('decision: $decision, ')
          ..write('confirmationRequestedAt: $confirmationRequestedAt, ')
          ..write('confirmationExpiresAt: $confirmationExpiresAt, ')
          ..write('decidedAt: $decidedAt, ')
          ..write('result: $result, ')
          ..write('artifactsJson: $artifactsJson, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    runId,
    assistantMessageId,
    resultMessageId,
    providerCallId,
    toolName,
    argumentsJson,
    providerDataJson,
    target,
    channel,
    defaultPolicy,
    status,
    decision,
    confirmationRequestedAt,
    confirmationExpiresAt,
    decidedAt,
    result,
    artifactsJson,
    errorCode,
    createdAt,
    startedAt,
    finishedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolCallRow &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.assistantMessageId == this.assistantMessageId &&
          other.resultMessageId == this.resultMessageId &&
          other.providerCallId == this.providerCallId &&
          other.toolName == this.toolName &&
          other.argumentsJson == this.argumentsJson &&
          other.providerDataJson == this.providerDataJson &&
          other.target == this.target &&
          other.channel == this.channel &&
          other.defaultPolicy == this.defaultPolicy &&
          other.status == this.status &&
          other.decision == this.decision &&
          other.confirmationRequestedAt == this.confirmationRequestedAt &&
          other.confirmationExpiresAt == this.confirmationExpiresAt &&
          other.decidedAt == this.decidedAt &&
          other.result == this.result &&
          other.artifactsJson == this.artifactsJson &&
          other.errorCode == this.errorCode &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt);
}

class ToolCallsCompanion extends UpdateCompanion<ToolCallRow> {
  final Value<String> id;
  final Value<String> runId;
  final Value<String> assistantMessageId;
  final Value<String?> resultMessageId;
  final Value<String?> providerCallId;
  final Value<String> toolName;
  final Value<String> argumentsJson;
  final Value<String?> providerDataJson;
  final Value<String?> target;
  final Value<ExecutionChannel> channel;
  final Value<ToolPolicy> defaultPolicy;
  final Value<ToolCallStatus> status;
  final Value<ToolDecision?> decision;
  final Value<DateTime?> confirmationRequestedAt;
  final Value<DateTime?> confirmationExpiresAt;
  final Value<DateTime?> decidedAt;
  final Value<String?> result;
  final Value<String> artifactsJson;
  final Value<String?> errorCode;
  final Value<DateTime> createdAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<int> rowid;
  const ToolCallsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.assistantMessageId = const Value.absent(),
    this.resultMessageId = const Value.absent(),
    this.providerCallId = const Value.absent(),
    this.toolName = const Value.absent(),
    this.argumentsJson = const Value.absent(),
    this.providerDataJson = const Value.absent(),
    this.target = const Value.absent(),
    this.channel = const Value.absent(),
    this.defaultPolicy = const Value.absent(),
    this.status = const Value.absent(),
    this.decision = const Value.absent(),
    this.confirmationRequestedAt = const Value.absent(),
    this.confirmationExpiresAt = const Value.absent(),
    this.decidedAt = const Value.absent(),
    this.result = const Value.absent(),
    this.artifactsJson = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ToolCallsCompanion.insert({
    required String id,
    required String runId,
    required String assistantMessageId,
    this.resultMessageId = const Value.absent(),
    this.providerCallId = const Value.absent(),
    required String toolName,
    required String argumentsJson,
    this.providerDataJson = const Value.absent(),
    this.target = const Value.absent(),
    required ExecutionChannel channel,
    required ToolPolicy defaultPolicy,
    required ToolCallStatus status,
    this.decision = const Value.absent(),
    this.confirmationRequestedAt = const Value.absent(),
    this.confirmationExpiresAt = const Value.absent(),
    this.decidedAt = const Value.absent(),
    this.result = const Value.absent(),
    this.artifactsJson = const Value.absent(),
    this.errorCode = const Value.absent(),
    required DateTime createdAt,
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       assistantMessageId = Value(assistantMessageId),
       toolName = Value(toolName),
       argumentsJson = Value(argumentsJson),
       channel = Value(channel),
       defaultPolicy = Value(defaultPolicy),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<ToolCallRow> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<String>? assistantMessageId,
    Expression<String>? resultMessageId,
    Expression<String>? providerCallId,
    Expression<String>? toolName,
    Expression<String>? argumentsJson,
    Expression<String>? providerDataJson,
    Expression<String>? target,
    Expression<String>? channel,
    Expression<String>? defaultPolicy,
    Expression<String>? status,
    Expression<String>? decision,
    Expression<DateTime>? confirmationRequestedAt,
    Expression<DateTime>? confirmationExpiresAt,
    Expression<DateTime>? decidedAt,
    Expression<String>? result,
    Expression<String>? artifactsJson,
    Expression<String>? errorCode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (assistantMessageId != null)
        'assistant_message_id': assistantMessageId,
      if (resultMessageId != null) 'result_message_id': resultMessageId,
      if (providerCallId != null) 'provider_call_id': providerCallId,
      if (toolName != null) 'tool_name': toolName,
      if (argumentsJson != null) 'arguments_json': argumentsJson,
      if (providerDataJson != null) 'provider_data_json': providerDataJson,
      if (target != null) 'target': target,
      if (channel != null) 'channel': channel,
      if (defaultPolicy != null) 'default_policy': defaultPolicy,
      if (status != null) 'status': status,
      if (decision != null) 'decision': decision,
      if (confirmationRequestedAt != null)
        'confirmation_requested_at': confirmationRequestedAt,
      if (confirmationExpiresAt != null)
        'confirmation_expires_at': confirmationExpiresAt,
      if (decidedAt != null) 'decided_at': decidedAt,
      if (result != null) 'result': result,
      if (artifactsJson != null) 'artifacts_json': artifactsJson,
      if (errorCode != null) 'error_code': errorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ToolCallsCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<String>? assistantMessageId,
    Value<String?>? resultMessageId,
    Value<String?>? providerCallId,
    Value<String>? toolName,
    Value<String>? argumentsJson,
    Value<String?>? providerDataJson,
    Value<String?>? target,
    Value<ExecutionChannel>? channel,
    Value<ToolPolicy>? defaultPolicy,
    Value<ToolCallStatus>? status,
    Value<ToolDecision?>? decision,
    Value<DateTime?>? confirmationRequestedAt,
    Value<DateTime?>? confirmationExpiresAt,
    Value<DateTime?>? decidedAt,
    Value<String?>? result,
    Value<String>? artifactsJson,
    Value<String?>? errorCode,
    Value<DateTime>? createdAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<int>? rowid,
  }) {
    return ToolCallsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      assistantMessageId: assistantMessageId ?? this.assistantMessageId,
      resultMessageId: resultMessageId ?? this.resultMessageId,
      providerCallId: providerCallId ?? this.providerCallId,
      toolName: toolName ?? this.toolName,
      argumentsJson: argumentsJson ?? this.argumentsJson,
      providerDataJson: providerDataJson ?? this.providerDataJson,
      target: target ?? this.target,
      channel: channel ?? this.channel,
      defaultPolicy: defaultPolicy ?? this.defaultPolicy,
      status: status ?? this.status,
      decision: decision ?? this.decision,
      confirmationRequestedAt:
          confirmationRequestedAt ?? this.confirmationRequestedAt,
      confirmationExpiresAt:
          confirmationExpiresAt ?? this.confirmationExpiresAt,
      decidedAt: decidedAt ?? this.decidedAt,
      result: result ?? this.result,
      artifactsJson: artifactsJson ?? this.artifactsJson,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (assistantMessageId.present) {
      map['assistant_message_id'] = Variable<String>(assistantMessageId.value);
    }
    if (resultMessageId.present) {
      map['result_message_id'] = Variable<String>(resultMessageId.value);
    }
    if (providerCallId.present) {
      map['provider_call_id'] = Variable<String>(providerCallId.value);
    }
    if (toolName.present) {
      map['tool_name'] = Variable<String>(toolName.value);
    }
    if (argumentsJson.present) {
      map['arguments_json'] = Variable<String>(argumentsJson.value);
    }
    if (providerDataJson.present) {
      map['provider_data_json'] = Variable<String>(providerDataJson.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(
        $ToolCallsTable.$converterchannel.toSql(channel.value),
      );
    }
    if (defaultPolicy.present) {
      map['default_policy'] = Variable<String>(
        $ToolCallsTable.$converterdefaultPolicy.toSql(defaultPolicy.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $ToolCallsTable.$converterstatus.toSql(status.value),
      );
    }
    if (decision.present) {
      map['decision'] = Variable<String>(
        $ToolCallsTable.$converterdecisionn.toSql(decision.value),
      );
    }
    if (confirmationRequestedAt.present) {
      map['confirmation_requested_at'] = Variable<DateTime>(
        confirmationRequestedAt.value,
      );
    }
    if (confirmationExpiresAt.present) {
      map['confirmation_expires_at'] = Variable<DateTime>(
        confirmationExpiresAt.value,
      );
    }
    if (decidedAt.present) {
      map['decided_at'] = Variable<DateTime>(decidedAt.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (artifactsJson.present) {
      map['artifacts_json'] = Variable<String>(artifactsJson.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ToolCallsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('assistantMessageId: $assistantMessageId, ')
          ..write('resultMessageId: $resultMessageId, ')
          ..write('providerCallId: $providerCallId, ')
          ..write('toolName: $toolName, ')
          ..write('argumentsJson: $argumentsJson, ')
          ..write('providerDataJson: $providerDataJson, ')
          ..write('target: $target, ')
          ..write('channel: $channel, ')
          ..write('defaultPolicy: $defaultPolicy, ')
          ..write('status: $status, ')
          ..write('decision: $decision, ')
          ..write('confirmationRequestedAt: $confirmationRequestedAt, ')
          ..write('confirmationExpiresAt: $confirmationExpiresAt, ')
          ..write('decidedAt: $decidedAt, ')
          ..write('result: $result, ')
          ..write('artifactsJson: $artifactsJson, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProviderProfilesTable providerProfiles = $ProviderProfilesTable(
    this,
  );
  late final $ModelsTable models = $ModelsTable(this);
  late final $AssistantsTable assistants = $AssistantsTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $AgentRunsTable agentRuns = $AgentRunsTable(this);
  late final $ToolCallsTable toolCalls = $ToolCallsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    providerProfiles,
    models,
    assistants,
    conversations,
    messages,
    attachments,
    agentRuns,
    toolCalls,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'provider_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('models', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('agent_runs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'agent_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tool_calls', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ProviderProfilesTableCreateCompanionBuilder =
    ProviderProfilesCompanion Function({
      required String id,
      required String name,
      required String protocol,
      required String baseUrl,
      Value<bool> requiresKey,
      Value<String> presetId,
      Value<String?> defaultModel,
      Value<String?> compatJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ProviderProfilesTableUpdateCompanionBuilder =
    ProviderProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> protocol,
      Value<String> baseUrl,
      Value<bool> requiresKey,
      Value<String> presetId,
      Value<String?> defaultModel,
      Value<String?> compatJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ProviderProfilesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ProviderProfilesTable,
          ProviderProfileRow
        > {
  $$ProviderProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ModelsTable, List<ModelRow>> _modelsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.models,
    aliasName: 'provider_profiles__id__models__profile_id',
  );

  $$ModelsTableProcessedTableManager get modelsRefs {
    final manager = $$ModelsTableTableManager(
      $_db,
      $_db.models,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_modelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProviderProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProviderProfilesTable> {
  $$ProviderProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresKey => $composableBuilder(
    column: $table.requiresKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presetId => $composableBuilder(
    column: $table.presetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultModel => $composableBuilder(
    column: $table.defaultModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compatJson => $composableBuilder(
    column: $table.compatJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> modelsRefs(
    Expression<bool> Function($$ModelsTableFilterComposer f) f,
  ) {
    final $$ModelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.models,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelsTableFilterComposer(
            $db: $db,
            $table: $db.models,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProviderProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProviderProfilesTable> {
  $$ProviderProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresKey => $composableBuilder(
    column: $table.requiresKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presetId => $composableBuilder(
    column: $table.presetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultModel => $composableBuilder(
    column: $table.defaultModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compatJson => $composableBuilder(
    column: $table.compatJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProviderProfilesTable> {
  $$ProviderProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get protocol =>
      $composableBuilder(column: $table.protocol, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<bool> get requiresKey => $composableBuilder(
    column: $table.requiresKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get presetId =>
      $composableBuilder(column: $table.presetId, builder: (column) => column);

  GeneratedColumn<String> get defaultModel => $composableBuilder(
    column: $table.defaultModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get compatJson => $composableBuilder(
    column: $table.compatJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> modelsRefs<T extends Object>(
    Expression<T> Function($$ModelsTableAnnotationComposer a) f,
  ) {
    final $$ModelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.models,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelsTableAnnotationComposer(
            $db: $db,
            $table: $db.models,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProviderProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProviderProfilesTable,
          ProviderProfileRow,
          $$ProviderProfilesTableFilterComposer,
          $$ProviderProfilesTableOrderingComposer,
          $$ProviderProfilesTableAnnotationComposer,
          $$ProviderProfilesTableCreateCompanionBuilder,
          $$ProviderProfilesTableUpdateCompanionBuilder,
          (ProviderProfileRow, $$ProviderProfilesTableReferences),
          ProviderProfileRow,
          PrefetchHooks Function({bool modelsRefs})
        > {
  $$ProviderProfilesTableTableManager(
    _$AppDatabase db,
    $ProviderProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> protocol = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<bool> requiresKey = const Value.absent(),
                Value<String> presetId = const Value.absent(),
                Value<String?> defaultModel = const Value.absent(),
                Value<String?> compatJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderProfilesCompanion(
                id: id,
                name: name,
                protocol: protocol,
                baseUrl: baseUrl,
                requiresKey: requiresKey,
                presetId: presetId,
                defaultModel: defaultModel,
                compatJson: compatJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String protocol,
                required String baseUrl,
                Value<bool> requiresKey = const Value.absent(),
                Value<String> presetId = const Value.absent(),
                Value<String?> defaultModel = const Value.absent(),
                Value<String?> compatJson = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProviderProfilesCompanion.insert(
                id: id,
                name: name,
                protocol: protocol,
                baseUrl: baseUrl,
                requiresKey: requiresKey,
                presetId: presetId,
                defaultModel: defaultModel,
                compatJson: compatJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProviderProfilesTable, ProviderProfileRow>(
                    table,
                  ),
                  $$ProviderProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({modelsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (modelsRefs) db.models],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (modelsRefs)
                    await $_getPrefetchedData<
                      ProviderProfileRow,
                      $ProviderProfilesTable,
                      ModelRow
                    >(
                      currentTable: table,
                      referencedTable: $$ProviderProfilesTableReferences
                          ._modelsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProviderProfilesTableReferences(
                            db,
                            table,
                            p0,
                          ).modelsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.profileId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProviderProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProviderProfilesTable,
      ProviderProfileRow,
      $$ProviderProfilesTableFilterComposer,
      $$ProviderProfilesTableOrderingComposer,
      $$ProviderProfilesTableAnnotationComposer,
      $$ProviderProfilesTableCreateCompanionBuilder,
      $$ProviderProfilesTableUpdateCompanionBuilder,
      (ProviderProfileRow, $$ProviderProfilesTableReferences),
      ProviderProfileRow,
      PrefetchHooks Function({bool modelsRefs})
    >;
typedef $$ModelsTableCreateCompanionBuilder = ModelsCompanion Function({
  required String profileId,
  required String modelId,
  Value<String?> displayName,
  Value<bool> enabled,
  Value<bool> supportsReasoning,
  Value<bool> supportsTools,
  Value<bool> supportsImages,
  Value<int?> contextWindow,
  Value<int?> maxOutputTokens,
  Value<double?> temperature,
  Value<int> rowid,
});
typedef $$ModelsTableUpdateCompanionBuilder = ModelsCompanion Function({
  Value<String> profileId,
  Value<String> modelId,
  Value<String?> displayName,
  Value<bool> enabled,
  Value<bool> supportsReasoning,
  Value<bool> supportsTools,
  Value<bool> supportsImages,
  Value<int?> contextWindow,
  Value<int?> maxOutputTokens,
  Value<double?> temperature,
  Value<int> rowid,
});

final class $$ModelsTableReferences
    extends BaseReferences<_$AppDatabase, $ModelsTable, ModelRow> {
  $$ModelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProviderProfilesTable _profileIdTable(_$AppDatabase db) => db
      .providerProfiles
      .createAlias('models__profile_id__provider_profiles__id');

  $$ProviderProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$ProviderProfilesTableTableManager(
      $_db,
      $_db.providerProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ModelsTableFilterComposer
    extends Composer<_$AppDatabase, $ModelsTable> {
  $$ModelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsReasoning => $composableBuilder(
    column: $table.supportsReasoning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsTools => $composableBuilder(
    column: $table.supportsTools,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsImages => $composableBuilder(
    column: $table.supportsImages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contextWindow => $composableBuilder(
    column: $table.contextWindow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxOutputTokens => $composableBuilder(
    column: $table.maxOutputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnFilters(column),
  );

  $$ProviderProfilesTableFilterComposer get profileId {
    final $$ProviderProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.providerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProviderProfilesTableFilterComposer(
            $db: $db,
            $table: $db.providerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelsTable> {
  $$ModelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsReasoning => $composableBuilder(
    column: $table.supportsReasoning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsTools => $composableBuilder(
    column: $table.supportsTools,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsImages => $composableBuilder(
    column: $table.supportsImages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contextWindow => $composableBuilder(
    column: $table.contextWindow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxOutputTokens => $composableBuilder(
    column: $table.maxOutputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProviderProfilesTableOrderingComposer get profileId {
    final $$ProviderProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.providerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProviderProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.providerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelsTable> {
  $$ModelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get supportsReasoning => $composableBuilder(
    column: $table.supportsReasoning,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get supportsTools => $composableBuilder(
    column: $table.supportsTools,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get supportsImages => $composableBuilder(
    column: $table.supportsImages,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contextWindow => $composableBuilder(
    column: $table.contextWindow,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxOutputTokens => $composableBuilder(
    column: $table.maxOutputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => column,
  );

  $$ProviderProfilesTableAnnotationComposer get profileId {
    final $$ProviderProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.providerProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProviderProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.providerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelsTable,
          ModelRow,
          $$ModelsTableFilterComposer,
          $$ModelsTableOrderingComposer,
          $$ModelsTableAnnotationComposer,
          $$ModelsTableCreateCompanionBuilder,
          $$ModelsTableUpdateCompanionBuilder,
          (ModelRow, $$ModelsTableReferences),
          ModelRow,
          PrefetchHooks Function({bool profileId})
        > {
  $$ModelsTableTableManager(_$AppDatabase db, $ModelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> supportsReasoning = const Value.absent(),
                Value<bool> supportsTools = const Value.absent(),
                Value<bool> supportsImages = const Value.absent(),
                Value<int?> contextWindow = const Value.absent(),
                Value<int?> maxOutputTokens = const Value.absent(),
                Value<double?> temperature = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelsCompanion(
                profileId: profileId,
                modelId: modelId,
                displayName: displayName,
                enabled: enabled,
                supportsReasoning: supportsReasoning,
                supportsTools: supportsTools,
                supportsImages: supportsImages,
                contextWindow: contextWindow,
                maxOutputTokens: maxOutputTokens,
                temperature: temperature,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String modelId,
                Value<String?> displayName = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> supportsReasoning = const Value.absent(),
                Value<bool> supportsTools = const Value.absent(),
                Value<bool> supportsImages = const Value.absent(),
                Value<int?> contextWindow = const Value.absent(),
                Value<int?> maxOutputTokens = const Value.absent(),
                Value<double?> temperature = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelsCompanion.insert(
                profileId: profileId,
                modelId: modelId,
                displayName: displayName,
                enabled: enabled,
                supportsReasoning: supportsReasoning,
                supportsTools: supportsTools,
                supportsImages: supportsImages,
                contextWindow: contextWindow,
                maxOutputTokens: maxOutputTokens,
                temperature: temperature,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelsTable, ModelRow>(table),
                  $$ModelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.profileId,
                        referencedTable: $$ModelsTableReferences
                            ._profileIdTable(db),
                        referencedColumn: $$ModelsTableReferences
                            ._profileIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ModelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelsTable,
      ModelRow,
      $$ModelsTableFilterComposer,
      $$ModelsTableOrderingComposer,
      $$ModelsTableAnnotationComposer,
      $$ModelsTableCreateCompanionBuilder,
      $$ModelsTableUpdateCompanionBuilder,
      (ModelRow, $$ModelsTableReferences),
      ModelRow,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$AssistantsTableCreateCompanionBuilder = AssistantsCompanion Function({
  required String id,
  required String name,
  Value<String> systemPrompt,
  Value<String?> defaultSelectionJson,
  Value<String> toolPolicyJson,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$AssistantsTableUpdateCompanionBuilder = AssistantsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> systemPrompt,
  Value<String?> defaultSelectionJson,
  Value<String> toolPolicyJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$AssistantsTableFilterComposer
    extends Composer<_$AppDatabase, $AssistantsTable> {
  $$AssistantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultSelectionJson => $composableBuilder(
    column: $table.defaultSelectionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolPolicyJson => $composableBuilder(
    column: $table.toolPolicyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AssistantsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssistantsTable> {
  $$AssistantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultSelectionJson => $composableBuilder(
    column: $table.defaultSelectionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolPolicyJson => $composableBuilder(
    column: $table.toolPolicyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssistantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssistantsTable> {
  $$AssistantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultSelectionJson => $composableBuilder(
    column: $table.defaultSelectionJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toolPolicyJson => $composableBuilder(
    column: $table.toolPolicyJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AssistantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssistantsTable,
          AssistantRow,
          $$AssistantsTableFilterComposer,
          $$AssistantsTableOrderingComposer,
          $$AssistantsTableAnnotationComposer,
          $$AssistantsTableCreateCompanionBuilder,
          $$AssistantsTableUpdateCompanionBuilder,
          (
            AssistantRow,
            BaseReferences<_$AppDatabase, $AssistantsTable, AssistantRow>,
          ),
          AssistantRow,
          PrefetchHooks Function()
        > {
  $$AssistantsTableTableManager(_$AppDatabase db, $AssistantsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssistantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssistantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssistantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> systemPrompt = const Value.absent(),
                Value<String?> defaultSelectionJson = const Value.absent(),
                Value<String> toolPolicyJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantsCompanion(
                id: id,
                name: name,
                systemPrompt: systemPrompt,
                defaultSelectionJson: defaultSelectionJson,
                toolPolicyJson: toolPolicyJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> systemPrompt = const Value.absent(),
                Value<String?> defaultSelectionJson = const Value.absent(),
                Value<String> toolPolicyJson = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AssistantsCompanion.insert(
                id: id,
                name: name,
                systemPrompt: systemPrompt,
                defaultSelectionJson: defaultSelectionJson,
                toolPolicyJson: toolPolicyJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AssistantsTable, AssistantRow>(table),
                  BaseReferences<_$AppDatabase, $AssistantsTable, AssistantRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AssistantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssistantsTable,
      AssistantRow,
      $$AssistantsTableFilterComposer,
      $$AssistantsTableOrderingComposer,
      $$AssistantsTableAnnotationComposer,
      $$AssistantsTableCreateCompanionBuilder,
      $$AssistantsTableUpdateCompanionBuilder,
      (
        AssistantRow,
        BaseReferences<_$AppDatabase, $AssistantsTable, AssistantRow>,
      ),
      AssistantRow,
      PrefetchHooks Function()
    >;
typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      Value<String?> assistantId,
      required String title,
      Value<String?> currentMessageId,
      Value<String?> selectionJson,
      Value<bool> pinned,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<String?> assistantId,
      Value<String> title,
      Value<String?> currentMessageId,
      Value<String?> selectionJson,
      Value<bool> pinned,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ConversationsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ConversationsTable, ConversationRow> {
  $$ConversationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$MessagesTable, List<MessageRow>>
  _messagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: 'conversations__id__messages__conversation_id',
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<AttachmentRow>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: 'conversations__id__attachments__conversation_id',
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AgentRunsTable, List<AgentRunRow>>
  _agentRunsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.agentRuns,
    aliasName: 'conversations__id__agent_runs__conversation_id',
  );

  $$AgentRunsTableProcessedTableManager get agentRunsRefs {
    final manager = $$AgentRunsTableTableManager(
      $_db,
      $_db.agentRuns,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_agentRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentMessageId => $composableBuilder(
    column: $table.currentMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectionJson => $composableBuilder(
    column: $table.selectionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> agentRunsRefs(
    Expression<bool> Function($$AgentRunsTableFilterComposer f) f,
  ) {
    final $$AgentRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.agentRuns,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunsTableFilterComposer(
            $db: $db,
            $table: $db.agentRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentMessageId => $composableBuilder(
    column: $table.currentMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectionJson => $composableBuilder(
    column: $table.selectionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get currentMessageId => $composableBuilder(
    column: $table.currentMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectionJson => $composableBuilder(
    column: $table.selectionJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> agentRunsRefs<T extends Object>(
    Expression<T> Function($$AgentRunsTableAnnotationComposer a) f,
  ) {
    final $$AgentRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.agentRuns,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.agentRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationsTable,
          ConversationRow,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (ConversationRow, $$ConversationsTableReferences),
          ConversationRow,
          PrefetchHooks Function({
            bool messagesRefs,
            bool attachmentsRefs,
            bool agentRunsRefs,
          })
        > {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> assistantId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> currentMessageId = const Value.absent(),
                Value<String?> selectionJson = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                assistantId: assistantId,
                title: title,
                currentMessageId: currentMessageId,
                selectionJson: selectionJson,
                pinned: pinned,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> assistantId = const Value.absent(),
                required String title,
                Value<String?> currentMessageId = const Value.absent(),
                Value<String?> selectionJson = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                assistantId: assistantId,
                title: title,
                currentMessageId: currentMessageId,
                selectionJson: selectionJson,
                pinned: pinned,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConversationsTable, ConversationRow>(table),
                  $$ConversationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                messagesRefs = false,
                attachmentsRefs = false,
                agentRunsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (messagesRefs) db.messages,
                    if (attachmentsRefs) db.attachments,
                    if (agentRunsRefs) db.agentRuns,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (messagesRefs)
                        await $_getPrefetchedData<
                          ConversationRow,
                          $ConversationsTable,
                          MessageRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationsTableReferences
                              ._messagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationsTableReferences(
                                db,
                                table,
                                p0,
                              ).messagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.conversationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attachmentsRefs)
                        await $_getPrefetchedData<
                          ConversationRow,
                          $ConversationsTable,
                          AttachmentRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationsTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationsTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.conversationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (agentRunsRefs)
                        await $_getPrefetchedData<
                          ConversationRow,
                          $ConversationsTable,
                          AgentRunRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationsTableReferences
                              ._agentRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationsTableReferences(
                                db,
                                table,
                                p0,
                              ).agentRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.conversationId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationsTable,
      ConversationRow,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (ConversationRow, $$ConversationsTableReferences),
      ConversationRow,
      PrefetchHooks Function({
        bool messagesRefs,
        bool attachmentsRefs,
        bool agentRunsRefs,
      })
    >;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  required String id,
  required String conversationId,
  Value<String?> parentId,
  Value<String?> runId,
  required ChatRole role,
  required MessageStatus status,
  Value<String> partsJson,
  Value<String?> modelLabel,
  Value<String?> usageJson,
  Value<int?> thinkingDurationMs,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<String> id,
  Value<String> conversationId,
  Value<String?> parentId,
  Value<String?> runId,
  Value<ChatRole> role,
  Value<MessageStatus> status,
  Value<String> partsJson,
  Value<String?> modelLabel,
  Value<String?> usageJson,
  Value<int?> thinkingDurationMs,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$MessagesTableReferences
    extends BaseReferences<_$AppDatabase, $MessagesTable, MessageRow> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$AppDatabase db) => db
      .conversations
      .createAlias('messages__conversation_id__conversations__id');

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ChatRole, ChatRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<MessageStatus, MessageStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get partsJson => $composableBuilder(
    column: $table.partsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelLabel => $composableBuilder(
    column: $table.modelLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usageJson => $composableBuilder(
    column: $table.usageJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get thinkingDurationMs => $composableBuilder(
    column: $table.thinkingDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partsJson => $composableBuilder(
    column: $table.partsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelLabel => $composableBuilder(
    column: $table.modelLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usageJson => $composableBuilder(
    column: $table.usageJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get thinkingDurationMs => $composableBuilder(
    column: $table.thinkingDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ChatRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get partsJson =>
      $composableBuilder(column: $table.partsJson, builder: (column) => column);

  GeneratedColumn<String> get modelLabel => $composableBuilder(
    column: $table.modelLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get usageJson =>
      $composableBuilder(column: $table.usageJson, builder: (column) => column);

  GeneratedColumn<int> get thinkingDurationMs => $composableBuilder(
    column: $table.thinkingDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          MessageRow,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (MessageRow, $$MessagesTableReferences),
          MessageRow,
          PrefetchHooks Function({bool conversationId})
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<ChatRole> role = const Value.absent(),
                Value<MessageStatus> status = const Value.absent(),
                Value<String> partsJson = const Value.absent(),
                Value<String?> modelLabel = const Value.absent(),
                Value<String?> usageJson = const Value.absent(),
                Value<int?> thinkingDurationMs = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                conversationId: conversationId,
                parentId: parentId,
                runId: runId,
                role: role,
                status: status,
                partsJson: partsJson,
                modelLabel: modelLabel,
                usageJson: usageJson,
                thinkingDurationMs: thinkingDurationMs,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                Value<String?> parentId = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                required ChatRole role,
                required MessageStatus status,
                Value<String> partsJson = const Value.absent(),
                Value<String?> modelLabel = const Value.absent(),
                Value<String?> usageJson = const Value.absent(),
                Value<int?> thinkingDurationMs = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                parentId: parentId,
                runId: runId,
                role: role,
                status: status,
                partsJson: partsJson,
                modelLabel: modelLabel,
                usageJson: usageJson,
                thinkingDurationMs: thinkingDurationMs,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessagesTable, MessageRow>(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (conversationId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.conversationId,
                        referencedTable: $$MessagesTableReferences
                            ._conversationIdTable(db),
                        referencedColumn: $$MessagesTableReferences
                            ._conversationIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      MessageRow,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (MessageRow, $$MessagesTableReferences),
      MessageRow,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      required String conversationId,
      required String kind,
      required String name,
      required String mimeType,
      required int size,
      required String localPath,
      Value<String?> sha256,
      Value<String?> extractedTextPath,
      Value<String?> extractionError,
      Value<int?> width,
      Value<int?> height,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> kind,
      Value<String> name,
      Value<String> mimeType,
      Value<int> size,
      Value<String> localPath,
      Value<String?> sha256,
      Value<String?> extractedTextPath,
      Value<String?> extractionError,
      Value<int?> width,
      Value<int?> height,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$AttachmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AttachmentsTable, AttachmentRow> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$AppDatabase db) => db
      .conversations
      .createAlias('attachments__conversation_id__conversations__id');

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractedTextPath => $composableBuilder(
    column: $table.extractedTextPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractionError => $composableBuilder(
    column: $table.extractionError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractedTextPath => $composableBuilder(
    column: $table.extractedTextPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractionError => $composableBuilder(
    column: $table.extractionError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get extractedTextPath => $composableBuilder(
    column: $table.extractedTextPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extractionError => $composableBuilder(
    column: $table.extractionError,
    builder: (column) => column,
  );

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          AttachmentRow,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (AttachmentRow, $$AttachmentsTableReferences),
          AttachmentRow,
          PrefetchHooks Function({bool conversationId})
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<String?> extractedTextPath = const Value.absent(),
                Value<String?> extractionError = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                conversationId: conversationId,
                kind: kind,
                name: name,
                mimeType: mimeType,
                size: size,
                localPath: localPath,
                sha256: sha256,
                extractedTextPath: extractedTextPath,
                extractionError: extractionError,
                width: width,
                height: height,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String kind,
                required String name,
                required String mimeType,
                required int size,
                required String localPath,
                Value<String?> sha256 = const Value.absent(),
                Value<String?> extractedTextPath = const Value.absent(),
                Value<String?> extractionError = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                conversationId: conversationId,
                kind: kind,
                name: name,
                mimeType: mimeType,
                size: size,
                localPath: localPath,
                sha256: sha256,
                extractedTextPath: extractedTextPath,
                extractionError: extractionError,
                width: width,
                height: height,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttachmentsTable, AttachmentRow>(table),
                  $$AttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (conversationId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.conversationId,
                        referencedTable: $$AttachmentsTableReferences
                            ._conversationIdTable(db),
                        referencedColumn: $$AttachmentsTableReferences
                            ._conversationIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      AttachmentRow,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (AttachmentRow, $$AttachmentsTableReferences),
      AttachmentRow,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$AgentRunsTableCreateCompanionBuilder = AgentRunsCompanion Function({
  required String id,
  required String conversationId,
  Value<String?> assistantId,
  required String inputMessageId,
  Value<String?> currentMessageId,
  Value<String?> activeToolCallId,
  required String configurationJson,
  required RunStatus status,
  Value<RunFinishReason?> finishReason,
  Value<int> turnCount,
  Value<int> modelAttemptCount,
  required int maxTurns,
  Value<String?> usageJson,
  required DateTime createdAt,
  Value<DateTime?> finishedAt,
  Value<int> rowid,
});
typedef $$AgentRunsTableUpdateCompanionBuilder = AgentRunsCompanion Function({
  Value<String> id,
  Value<String> conversationId,
  Value<String?> assistantId,
  Value<String> inputMessageId,
  Value<String?> currentMessageId,
  Value<String?> activeToolCallId,
  Value<String> configurationJson,
  Value<RunStatus> status,
  Value<RunFinishReason?> finishReason,
  Value<int> turnCount,
  Value<int> modelAttemptCount,
  Value<int> maxTurns,
  Value<String?> usageJson,
  Value<DateTime> createdAt,
  Value<DateTime?> finishedAt,
  Value<int> rowid,
});

final class $$AgentRunsTableReferences
    extends BaseReferences<_$AppDatabase, $AgentRunsTable, AgentRunRow> {
  $$AgentRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$AppDatabase db) => db
      .conversations
      .createAlias('agent_runs__conversation_id__conversations__id');

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ToolCallsTable, List<ToolCallRow>>
  _toolCallsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.toolCalls,
    aliasName: 'agent_runs__id__tool_calls__run_id',
  );

  $$ToolCallsTableProcessedTableManager get toolCallsRefs {
    final manager = $$ToolCallsTableTableManager(
      $_db,
      $_db.toolCalls,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_toolCallsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AgentRunsTableFilterComposer
    extends Composer<_$AppDatabase, $AgentRunsTable> {
  $$AgentRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputMessageId => $composableBuilder(
    column: $table.inputMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentMessageId => $composableBuilder(
    column: $table.currentMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeToolCallId => $composableBuilder(
    column: $table.activeToolCallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configurationJson => $composableBuilder(
    column: $table.configurationJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RunStatus, RunStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<RunFinishReason?, RunFinishReason, String>
  get finishReason => $composableBuilder(
    column: $table.finishReason,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get turnCount => $composableBuilder(
    column: $table.turnCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modelAttemptCount => $composableBuilder(
    column: $table.modelAttemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxTurns => $composableBuilder(
    column: $table.maxTurns,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usageJson => $composableBuilder(
    column: $table.usageJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> toolCallsRefs(
    Expression<bool> Function($$ToolCallsTableFilterComposer f) f,
  ) {
    final $$ToolCallsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.toolCalls,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ToolCallsTableFilterComposer(
            $db: $db,
            $table: $db.toolCalls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AgentRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $AgentRunsTable> {
  $$AgentRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputMessageId => $composableBuilder(
    column: $table.inputMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentMessageId => $composableBuilder(
    column: $table.currentMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeToolCallId => $composableBuilder(
    column: $table.activeToolCallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configurationJson => $composableBuilder(
    column: $table.configurationJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finishReason => $composableBuilder(
    column: $table.finishReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get turnCount => $composableBuilder(
    column: $table.turnCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modelAttemptCount => $composableBuilder(
    column: $table.modelAttemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxTurns => $composableBuilder(
    column: $table.maxTurns,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usageJson => $composableBuilder(
    column: $table.usageJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AgentRunsTable> {
  $$AgentRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inputMessageId => $composableBuilder(
    column: $table.inputMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentMessageId => $composableBuilder(
    column: $table.currentMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeToolCallId => $composableBuilder(
    column: $table.activeToolCallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configurationJson => $composableBuilder(
    column: $table.configurationJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<RunStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RunFinishReason?, String> get finishReason =>
      $composableBuilder(
        column: $table.finishReason,
        builder: (column) => column,
      );

  GeneratedColumn<int> get turnCount =>
      $composableBuilder(column: $table.turnCount, builder: (column) => column);

  GeneratedColumn<int> get modelAttemptCount => $composableBuilder(
    column: $table.modelAttemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxTurns =>
      $composableBuilder(column: $table.maxTurns, builder: (column) => column);

  GeneratedColumn<String> get usageJson =>
      $composableBuilder(column: $table.usageJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> toolCallsRefs<T extends Object>(
    Expression<T> Function($$ToolCallsTableAnnotationComposer a) f,
  ) {
    final $$ToolCallsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.toolCalls,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ToolCallsTableAnnotationComposer(
            $db: $db,
            $table: $db.toolCalls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AgentRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AgentRunsTable,
          AgentRunRow,
          $$AgentRunsTableFilterComposer,
          $$AgentRunsTableOrderingComposer,
          $$AgentRunsTableAnnotationComposer,
          $$AgentRunsTableCreateCompanionBuilder,
          $$AgentRunsTableUpdateCompanionBuilder,
          (AgentRunRow, $$AgentRunsTableReferences),
          AgentRunRow,
          PrefetchHooks Function({bool conversationId, bool toolCallsRefs})
        > {
  $$AgentRunsTableTableManager(_$AppDatabase db, $AgentRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String?> assistantId = const Value.absent(),
                Value<String> inputMessageId = const Value.absent(),
                Value<String?> currentMessageId = const Value.absent(),
                Value<String?> activeToolCallId = const Value.absent(),
                Value<String> configurationJson = const Value.absent(),
                Value<RunStatus> status = const Value.absent(),
                Value<RunFinishReason?> finishReason = const Value.absent(),
                Value<int> turnCount = const Value.absent(),
                Value<int> modelAttemptCount = const Value.absent(),
                Value<int> maxTurns = const Value.absent(),
                Value<String?> usageJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentRunsCompanion(
                id: id,
                conversationId: conversationId,
                assistantId: assistantId,
                inputMessageId: inputMessageId,
                currentMessageId: currentMessageId,
                activeToolCallId: activeToolCallId,
                configurationJson: configurationJson,
                status: status,
                finishReason: finishReason,
                turnCount: turnCount,
                modelAttemptCount: modelAttemptCount,
                maxTurns: maxTurns,
                usageJson: usageJson,
                createdAt: createdAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                Value<String?> assistantId = const Value.absent(),
                required String inputMessageId,
                Value<String?> currentMessageId = const Value.absent(),
                Value<String?> activeToolCallId = const Value.absent(),
                required String configurationJson,
                required RunStatus status,
                Value<RunFinishReason?> finishReason = const Value.absent(),
                Value<int> turnCount = const Value.absent(),
                Value<int> modelAttemptCount = const Value.absent(),
                required int maxTurns,
                Value<String?> usageJson = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentRunsCompanion.insert(
                id: id,
                conversationId: conversationId,
                assistantId: assistantId,
                inputMessageId: inputMessageId,
                currentMessageId: currentMessageId,
                activeToolCallId: activeToolCallId,
                configurationJson: configurationJson,
                status: status,
                finishReason: finishReason,
                turnCount: turnCount,
                modelAttemptCount: modelAttemptCount,
                maxTurns: maxTurns,
                usageJson: usageJson,
                createdAt: createdAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AgentRunsTable, AgentRunRow>(table),
                  $$AgentRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({conversationId = false, toolCallsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (toolCallsRefs) db.toolCalls],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (conversationId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.conversationId,
                            referencedTable: $$AgentRunsTableReferences
                                ._conversationIdTable(db),
                            referencedColumn: $$AgentRunsTableReferences
                                ._conversationIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (toolCallsRefs)
                        await $_getPrefetchedData<
                          AgentRunRow,
                          $AgentRunsTable,
                          ToolCallRow
                        >(
                          currentTable: table,
                          referencedTable: $$AgentRunsTableReferences
                              ._toolCallsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AgentRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).toolCallsRefs,
                          referencedItemsForCurrentItem: (
                            item,
                            referencedItems,
                          ) => referencedItems.where((e) => e.runId == item.id),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AgentRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AgentRunsTable,
      AgentRunRow,
      $$AgentRunsTableFilterComposer,
      $$AgentRunsTableOrderingComposer,
      $$AgentRunsTableAnnotationComposer,
      $$AgentRunsTableCreateCompanionBuilder,
      $$AgentRunsTableUpdateCompanionBuilder,
      (AgentRunRow, $$AgentRunsTableReferences),
      AgentRunRow,
      PrefetchHooks Function({bool conversationId, bool toolCallsRefs})
    >;
typedef $$ToolCallsTableCreateCompanionBuilder = ToolCallsCompanion Function({
  required String id,
  required String runId,
  required String assistantMessageId,
  Value<String?> resultMessageId,
  Value<String?> providerCallId,
  required String toolName,
  required String argumentsJson,
  Value<String?> providerDataJson,
  Value<String?> target,
  required ExecutionChannel channel,
  required ToolPolicy defaultPolicy,
  required ToolCallStatus status,
  Value<ToolDecision?> decision,
  Value<DateTime?> confirmationRequestedAt,
  Value<DateTime?> confirmationExpiresAt,
  Value<DateTime?> decidedAt,
  Value<String?> result,
  Value<String> artifactsJson,
  Value<String?> errorCode,
  required DateTime createdAt,
  Value<DateTime?> startedAt,
  Value<DateTime?> finishedAt,
  Value<int> rowid,
});
typedef $$ToolCallsTableUpdateCompanionBuilder = ToolCallsCompanion Function({
  Value<String> id,
  Value<String> runId,
  Value<String> assistantMessageId,
  Value<String?> resultMessageId,
  Value<String?> providerCallId,
  Value<String> toolName,
  Value<String> argumentsJson,
  Value<String?> providerDataJson,
  Value<String?> target,
  Value<ExecutionChannel> channel,
  Value<ToolPolicy> defaultPolicy,
  Value<ToolCallStatus> status,
  Value<ToolDecision?> decision,
  Value<DateTime?> confirmationRequestedAt,
  Value<DateTime?> confirmationExpiresAt,
  Value<DateTime?> decidedAt,
  Value<String?> result,
  Value<String> artifactsJson,
  Value<String?> errorCode,
  Value<DateTime> createdAt,
  Value<DateTime?> startedAt,
  Value<DateTime?> finishedAt,
  Value<int> rowid,
});

final class $$ToolCallsTableReferences
    extends BaseReferences<_$AppDatabase, $ToolCallsTable, ToolCallRow> {
  $$ToolCallsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AgentRunsTable _runIdTable(_$AppDatabase db) =>
      db.agentRuns.createAlias('tool_calls__run_id__agent_runs__id');

  $$AgentRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$AgentRunsTableTableManager(
      $_db,
      $_db.agentRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ToolCallsTableFilterComposer
    extends Composer<_$AppDatabase, $ToolCallsTable> {
  $$ToolCallsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assistantMessageId => $composableBuilder(
    column: $table.assistantMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultMessageId => $composableBuilder(
    column: $table.resultMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerCallId => $composableBuilder(
    column: $table.providerCallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolName => $composableBuilder(
    column: $table.toolName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get argumentsJson => $composableBuilder(
    column: $table.argumentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerDataJson => $composableBuilder(
    column: $table.providerDataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ExecutionChannel, ExecutionChannel, String>
  get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<ToolPolicy, ToolPolicy, String>
  get defaultPolicy => $composableBuilder(
    column: $table.defaultPolicy,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<ToolCallStatus, ToolCallStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<ToolDecision?, ToolDecision, String>
  get decision => $composableBuilder(
    column: $table.decision,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get confirmationRequestedAt => $composableBuilder(
    column: $table.confirmationRequestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get confirmationExpiresAt => $composableBuilder(
    column: $table.confirmationExpiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get decidedAt => $composableBuilder(
    column: $table.decidedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artifactsJson => $composableBuilder(
    column: $table.artifactsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AgentRunsTableFilterComposer get runId {
    final $$AgentRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.agentRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunsTableFilterComposer(
            $db: $db,
            $table: $db.agentRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ToolCallsTableOrderingComposer
    extends Composer<_$AppDatabase, $ToolCallsTable> {
  $$ToolCallsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assistantMessageId => $composableBuilder(
    column: $table.assistantMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultMessageId => $composableBuilder(
    column: $table.resultMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerCallId => $composableBuilder(
    column: $table.providerCallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolName => $composableBuilder(
    column: $table.toolName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get argumentsJson => $composableBuilder(
    column: $table.argumentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerDataJson => $composableBuilder(
    column: $table.providerDataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultPolicy => $composableBuilder(
    column: $table.defaultPolicy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decision => $composableBuilder(
    column: $table.decision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get confirmationRequestedAt => $composableBuilder(
    column: $table.confirmationRequestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get confirmationExpiresAt => $composableBuilder(
    column: $table.confirmationExpiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get decidedAt => $composableBuilder(
    column: $table.decidedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artifactsJson => $composableBuilder(
    column: $table.artifactsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AgentRunsTableOrderingComposer get runId {
    final $$AgentRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.agentRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunsTableOrderingComposer(
            $db: $db,
            $table: $db.agentRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ToolCallsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ToolCallsTable> {
  $$ToolCallsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assistantMessageId => $composableBuilder(
    column: $table.assistantMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultMessageId => $composableBuilder(
    column: $table.resultMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerCallId => $composableBuilder(
    column: $table.providerCallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toolName =>
      $composableBuilder(column: $table.toolName, builder: (column) => column);

  GeneratedColumn<String> get argumentsJson => $composableBuilder(
    column: $table.argumentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerDataJson => $composableBuilder(
    column: $table.providerDataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ExecutionChannel, String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ToolPolicy, String> get defaultPolicy =>
      $composableBuilder(
        column: $table.defaultPolicy,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<ToolCallStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ToolDecision?, String> get decision =>
      $composableBuilder(column: $table.decision, builder: (column) => column);

  GeneratedColumn<DateTime> get confirmationRequestedAt => $composableBuilder(
    column: $table.confirmationRequestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get confirmationExpiresAt => $composableBuilder(
    column: $table.confirmationExpiresAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get decidedAt =>
      $composableBuilder(column: $table.decidedAt, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get artifactsJson => $composableBuilder(
    column: $table.artifactsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  $$AgentRunsTableAnnotationComposer get runId {
    final $$AgentRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.agentRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.agentRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ToolCallsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ToolCallsTable,
          ToolCallRow,
          $$ToolCallsTableFilterComposer,
          $$ToolCallsTableOrderingComposer,
          $$ToolCallsTableAnnotationComposer,
          $$ToolCallsTableCreateCompanionBuilder,
          $$ToolCallsTableUpdateCompanionBuilder,
          (ToolCallRow, $$ToolCallsTableReferences),
          ToolCallRow,
          PrefetchHooks Function({bool runId})
        > {
  $$ToolCallsTableTableManager(_$AppDatabase db, $ToolCallsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ToolCallsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ToolCallsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ToolCallsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String> assistantMessageId = const Value.absent(),
                Value<String?> resultMessageId = const Value.absent(),
                Value<String?> providerCallId = const Value.absent(),
                Value<String> toolName = const Value.absent(),
                Value<String> argumentsJson = const Value.absent(),
                Value<String?> providerDataJson = const Value.absent(),
                Value<String?> target = const Value.absent(),
                Value<ExecutionChannel> channel = const Value.absent(),
                Value<ToolPolicy> defaultPolicy = const Value.absent(),
                Value<ToolCallStatus> status = const Value.absent(),
                Value<ToolDecision?> decision = const Value.absent(),
                Value<DateTime?> confirmationRequestedAt = const Value.absent(),
                Value<DateTime?> confirmationExpiresAt = const Value.absent(),
                Value<DateTime?> decidedAt = const Value.absent(),
                Value<String?> result = const Value.absent(),
                Value<String> artifactsJson = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ToolCallsCompanion(
                id: id,
                runId: runId,
                assistantMessageId: assistantMessageId,
                resultMessageId: resultMessageId,
                providerCallId: providerCallId,
                toolName: toolName,
                argumentsJson: argumentsJson,
                providerDataJson: providerDataJson,
                target: target,
                channel: channel,
                defaultPolicy: defaultPolicy,
                status: status,
                decision: decision,
                confirmationRequestedAt: confirmationRequestedAt,
                confirmationExpiresAt: confirmationExpiresAt,
                decidedAt: decidedAt,
                result: result,
                artifactsJson: artifactsJson,
                errorCode: errorCode,
                createdAt: createdAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                required String assistantMessageId,
                Value<String?> resultMessageId = const Value.absent(),
                Value<String?> providerCallId = const Value.absent(),
                required String toolName,
                required String argumentsJson,
                Value<String?> providerDataJson = const Value.absent(),
                Value<String?> target = const Value.absent(),
                required ExecutionChannel channel,
                required ToolPolicy defaultPolicy,
                required ToolCallStatus status,
                Value<ToolDecision?> decision = const Value.absent(),
                Value<DateTime?> confirmationRequestedAt = const Value.absent(),
                Value<DateTime?> confirmationExpiresAt = const Value.absent(),
                Value<DateTime?> decidedAt = const Value.absent(),
                Value<String?> result = const Value.absent(),
                Value<String> artifactsJson = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ToolCallsCompanion.insert(
                id: id,
                runId: runId,
                assistantMessageId: assistantMessageId,
                resultMessageId: resultMessageId,
                providerCallId: providerCallId,
                toolName: toolName,
                argumentsJson: argumentsJson,
                providerDataJson: providerDataJson,
                target: target,
                channel: channel,
                defaultPolicy: defaultPolicy,
                status: status,
                decision: decision,
                confirmationRequestedAt: confirmationRequestedAt,
                confirmationExpiresAt: confirmationExpiresAt,
                decidedAt: decidedAt,
                result: result,
                artifactsJson: artifactsJson,
                errorCode: errorCode,
                createdAt: createdAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ToolCallsTable, ToolCallRow>(table),
                  $$ToolCallsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (runId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.runId,
                        referencedTable: $$ToolCallsTableReferences._runIdTable(
                          db,
                        ),
                        referencedColumn: $$ToolCallsTableReferences
                            ._runIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ToolCallsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ToolCallsTable,
      ToolCallRow,
      $$ToolCallsTableFilterComposer,
      $$ToolCallsTableOrderingComposer,
      $$ToolCallsTableAnnotationComposer,
      $$ToolCallsTableCreateCompanionBuilder,
      $$ToolCallsTableUpdateCompanionBuilder,
      (ToolCallRow, $$ToolCallsTableReferences),
      ToolCallRow,
      PrefetchHooks Function({bool runId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProviderProfilesTableTableManager get providerProfiles =>
      $$ProviderProfilesTableTableManager(_db, _db.providerProfiles);
  $$ModelsTableTableManager get models =>
      $$ModelsTableTableManager(_db, _db.models);
  $$AssistantsTableTableManager get assistants =>
      $$AssistantsTableTableManager(_db, _db.assistants);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$AgentRunsTableTableManager get agentRuns =>
      $$AgentRunsTableTableManager(_db, _db.agentRuns);
  $$ToolCallsTableTableManager get toolCalls =>
      $$ToolCallsTableTableManager(_db, _db.toolCalls);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppDatabase>,
          AppDatabase,
          FutureOr<AppDatabase>
        >
    with $FutureModifier<AppDatabase>, $FutureProvider<AppDatabase> {
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $FutureProviderElement<AppDatabase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppDatabase> create(Ref ref) {
    return appDatabase(ref);
  }
}

String _$appDatabaseHash() => r'427a129eee5d6174b200a1bf0f586ede649c65bd';
