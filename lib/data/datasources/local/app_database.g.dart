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
  static const VerificationMeta _mcpToolNamesJsonMeta = const VerificationMeta(
    'mcpToolNamesJson',
  );
  @override
  late final GeneratedColumn<String> mcpToolNamesJson = GeneratedColumn<String>(
    'mcp_tool_names_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _memoryScopeMeta = const VerificationMeta(
    'memoryScope',
  );
  @override
  late final GeneratedColumn<String> memoryScope = GeneratedColumn<String>(
    'memory_scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('disabled'),
  );
  static const VerificationMeta _skillIdsJsonMeta = const VerificationMeta(
    'skillIdsJson',
  );
  @override
  late final GeneratedColumn<String> skillIdsJson = GeneratedColumn<String>(
    'skill_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
    mcpToolNamesJson,
    memoryScope,
    skillIdsJson,
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
    if (data.containsKey('mcp_tool_names_json')) {
      context.handle(
        _mcpToolNamesJsonMeta,
        mcpToolNamesJson.isAcceptableOrUnknown(
          data['mcp_tool_names_json']!,
          _mcpToolNamesJsonMeta,
        ),
      );
    }
    if (data.containsKey('memory_scope')) {
      context.handle(
        _memoryScopeMeta,
        memoryScope.isAcceptableOrUnknown(
          data['memory_scope']!,
          _memoryScopeMeta,
        ),
      );
    }
    if (data.containsKey('skill_ids_json')) {
      context.handle(
        _skillIdsJsonMeta,
        skillIdsJson.isAcceptableOrUnknown(
          data['skill_ids_json']!,
          _skillIdsJsonMeta,
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
      mcpToolNamesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mcp_tool_names_json'],
      )!,
      memoryScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memory_scope'],
      )!,
      skillIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill_ids_json'],
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

  /// 助手选择的 MCP 工具名集合，不包含执行策略。
  final String mcpToolNamesJson;
  final String memoryScope;
  final String skillIdsJson;
  final DateTime createdAt;
  const AssistantRow({
    required this.id,
    required this.name,
    required this.systemPrompt,
    this.defaultSelectionJson,
    required this.mcpToolNamesJson,
    required this.memoryScope,
    required this.skillIdsJson,
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
    map['mcp_tool_names_json'] = Variable<String>(mcpToolNamesJson);
    map['memory_scope'] = Variable<String>(memoryScope);
    map['skill_ids_json'] = Variable<String>(skillIdsJson);
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
      mcpToolNamesJson: Value(mcpToolNamesJson),
      memoryScope: Value(memoryScope),
      skillIdsJson: Value(skillIdsJson),
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
      mcpToolNamesJson: serializer.fromJson<String>(json['mcpToolNamesJson']),
      memoryScope: serializer.fromJson<String>(json['memoryScope']),
      skillIdsJson: serializer.fromJson<String>(json['skillIdsJson']),
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
      'mcpToolNamesJson': serializer.toJson<String>(mcpToolNamesJson),
      'memoryScope': serializer.toJson<String>(memoryScope),
      'skillIdsJson': serializer.toJson<String>(skillIdsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AssistantRow copyWith({
    String? id,
    String? name,
    String? systemPrompt,
    Value<String?> defaultSelectionJson = const Value.absent(),
    String? mcpToolNamesJson,
    String? memoryScope,
    String? skillIdsJson,
    DateTime? createdAt,
  }) => AssistantRow(
    id: id ?? this.id,
    name: name ?? this.name,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    defaultSelectionJson: defaultSelectionJson.present
        ? defaultSelectionJson.value
        : this.defaultSelectionJson,
    mcpToolNamesJson: mcpToolNamesJson ?? this.mcpToolNamesJson,
    memoryScope: memoryScope ?? this.memoryScope,
    skillIdsJson: skillIdsJson ?? this.skillIdsJson,
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
      mcpToolNamesJson: data.mcpToolNamesJson.present
          ? data.mcpToolNamesJson.value
          : this.mcpToolNamesJson,
      memoryScope: data.memoryScope.present
          ? data.memoryScope.value
          : this.memoryScope,
      skillIdsJson: data.skillIdsJson.present
          ? data.skillIdsJson.value
          : this.skillIdsJson,
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
          ..write('mcpToolNamesJson: $mcpToolNamesJson, ')
          ..write('memoryScope: $memoryScope, ')
          ..write('skillIdsJson: $skillIdsJson, ')
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
    mcpToolNamesJson,
    memoryScope,
    skillIdsJson,
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
          other.mcpToolNamesJson == this.mcpToolNamesJson &&
          other.memoryScope == this.memoryScope &&
          other.skillIdsJson == this.skillIdsJson &&
          other.createdAt == this.createdAt);
}

class AssistantsCompanion extends UpdateCompanion<AssistantRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> systemPrompt;
  final Value<String?> defaultSelectionJson;
  final Value<String> mcpToolNamesJson;
  final Value<String> memoryScope;
  final Value<String> skillIdsJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AssistantsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.defaultSelectionJson = const Value.absent(),
    this.mcpToolNamesJson = const Value.absent(),
    this.memoryScope = const Value.absent(),
    this.skillIdsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantsCompanion.insert({
    required String id,
    required String name,
    this.systemPrompt = const Value.absent(),
    this.defaultSelectionJson = const Value.absent(),
    this.mcpToolNamesJson = const Value.absent(),
    this.memoryScope = const Value.absent(),
    this.skillIdsJson = const Value.absent(),
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
    Expression<String>? mcpToolNamesJson,
    Expression<String>? memoryScope,
    Expression<String>? skillIdsJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (defaultSelectionJson != null)
        'default_selection_json': defaultSelectionJson,
      if (mcpToolNamesJson != null) 'mcp_tool_names_json': mcpToolNamesJson,
      if (memoryScope != null) 'memory_scope': memoryScope,
      if (skillIdsJson != null) 'skill_ids_json': skillIdsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? systemPrompt,
    Value<String?>? defaultSelectionJson,
    Value<String>? mcpToolNamesJson,
    Value<String>? memoryScope,
    Value<String>? skillIdsJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AssistantsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      defaultSelectionJson: defaultSelectionJson ?? this.defaultSelectionJson,
      mcpToolNamesJson: mcpToolNamesJson ?? this.mcpToolNamesJson,
      memoryScope: memoryScope ?? this.memoryScope,
      skillIdsJson: skillIdsJson ?? this.skillIdsJson,
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
    if (mcpToolNamesJson.present) {
      map['mcp_tool_names_json'] = Variable<String>(mcpToolNamesJson.value);
    }
    if (memoryScope.present) {
      map['memory_scope'] = Variable<String>(memoryScope.value);
    }
    if (skillIdsJson.present) {
      map['skill_ids_json'] = Variable<String>(skillIdsJson.value);
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
          ..write('mcpToolNamesJson: $mcpToolNamesJson, ')
          ..write('memoryScope: $memoryScope, ')
          ..write('skillIdsJson: $skillIdsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkspacesTable extends Workspaces
    with TableInfo<$WorkspacesTable, WorkspaceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkspacesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _environmentIdMeta = const VerificationMeta(
    'environmentId',
  );
  @override
  late final GeneratedColumn<String> environmentId = GeneratedColumn<String>(
    'environment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletingMeta = const VerificationMeta(
    'deleting',
  );
  @override
  late final GeneratedColumn<bool> deleting = GeneratedColumn<bool>(
    'deleting',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleting" IN (0, 1))',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    environmentId,
    deleting,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workspaces';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkspaceRow> instance, {
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
    if (data.containsKey('environment_id')) {
      context.handle(
        _environmentIdMeta,
        environmentId.isAcceptableOrUnknown(
          data['environment_id']!,
          _environmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_environmentIdMeta);
    }
    if (data.containsKey('deleting')) {
      context.handle(
        _deletingMeta,
        deleting.isAcceptableOrUnknown(data['deleting']!, _deletingMeta),
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
  WorkspaceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkspaceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      environmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}environment_id'],
      )!,
      deleting: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleting'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WorkspacesTable createAlias(String alias) {
    return $WorkspacesTable(attachedDatabase, alias);
  }
}

class WorkspaceRow extends DataClass implements Insertable<WorkspaceRow> {
  final String id;
  final String name;
  final String environmentId;
  final bool deleting;
  final DateTime createdAt;
  const WorkspaceRow({
    required this.id,
    required this.name,
    required this.environmentId,
    required this.deleting,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['environment_id'] = Variable<String>(environmentId);
    map['deleting'] = Variable<bool>(deleting);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WorkspacesCompanion toCompanion(bool nullToAbsent) {
    return WorkspacesCompanion(
      id: Value(id),
      name: Value(name),
      environmentId: Value(environmentId),
      deleting: Value(deleting),
      createdAt: Value(createdAt),
    );
  }

  factory WorkspaceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkspaceRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      environmentId: serializer.fromJson<String>(json['environmentId']),
      deleting: serializer.fromJson<bool>(json['deleting']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'environmentId': serializer.toJson<String>(environmentId),
      'deleting': serializer.toJson<bool>(deleting),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WorkspaceRow copyWith({
    String? id,
    String? name,
    String? environmentId,
    bool? deleting,
    DateTime? createdAt,
  }) => WorkspaceRow(
    id: id ?? this.id,
    name: name ?? this.name,
    environmentId: environmentId ?? this.environmentId,
    deleting: deleting ?? this.deleting,
    createdAt: createdAt ?? this.createdAt,
  );
  WorkspaceRow copyWithCompanion(WorkspacesCompanion data) {
    return WorkspaceRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      environmentId: data.environmentId.present
          ? data.environmentId.value
          : this.environmentId,
      deleting: data.deleting.present ? data.deleting.value : this.deleting,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('environmentId: $environmentId, ')
          ..write('deleting: $deleting, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, environmentId, deleting, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkspaceRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.environmentId == this.environmentId &&
          other.deleting == this.deleting &&
          other.createdAt == this.createdAt);
}

class WorkspacesCompanion extends UpdateCompanion<WorkspaceRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> environmentId;
  final Value<bool> deleting;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WorkspacesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.environmentId = const Value.absent(),
    this.deleting = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkspacesCompanion.insert({
    required String id,
    required String name,
    required String environmentId,
    this.deleting = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       environmentId = Value(environmentId),
       createdAt = Value(createdAt);
  static Insertable<WorkspaceRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? environmentId,
    Expression<bool>? deleting,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (environmentId != null) 'environment_id': environmentId,
      if (deleting != null) 'deleting': deleting,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkspacesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? environmentId,
    Value<bool>? deleting,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WorkspacesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      environmentId: environmentId ?? this.environmentId,
      deleting: deleting ?? this.deleting,
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
    if (environmentId.present) {
      map['environment_id'] = Variable<String>(environmentId.value);
    }
    if (deleting.present) {
      map['deleting'] = Variable<bool>(deleting.value);
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
    return (StringBuffer('WorkspacesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('environmentId: $environmentId, ')
          ..write('deleting: $deleting, ')
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
  static const VerificationMeta _workspaceIdMeta = const VerificationMeta(
    'workspaceId',
  );
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
    'workspace_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workspaces (id) ON DELETE SET NULL',
    ),
  );
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
  @override
  late final GeneratedColumnWithTypeConverter<PermissionMode, String>
  permissionMode = GeneratedColumn<String>(
    'permission_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(PermissionMode.basic.name),
  ).withConverter<PermissionMode>($ConversationsTable.$converterpermissionMode);
  @override
  late final GeneratedColumnWithTypeConverter<PermissionMode, String>
  lastExecutionMode =
      GeneratedColumn<String>(
        'last_execution_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(PermissionMode.basic.name),
      ).withConverter<PermissionMode>(
        $ConversationsTable.$converterlastExecutionMode,
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
    workspaceId,
    id,
    assistantId,
    title,
    currentMessageId,
    selectionJson,
    permissionMode,
    lastExecutionMode,
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
    if (data.containsKey('workspace_id')) {
      context.handle(
        _workspaceIdMeta,
        workspaceId.isAcceptableOrUnknown(
          data['workspace_id']!,
          _workspaceIdMeta,
        ),
      );
    }
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
      workspaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workspace_id'],
      ),
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
      permissionMode: $ConversationsTable.$converterpermissionMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}permission_mode'],
        )!,
      ),
      lastExecutionMode: $ConversationsTable.$converterlastExecutionMode
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}last_execution_mode'],
            )!,
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

  static JsonTypeConverter2<PermissionMode, String, String>
  $converterpermissionMode = const EnumNameConverter<PermissionMode>(
    PermissionMode.values,
  );
  static JsonTypeConverter2<PermissionMode, String, String>
  $converterlastExecutionMode = const EnumNameConverter<PermissionMode>(
    PermissionMode.values,
  );
}

class ConversationRow extends DataClass implements Insertable<ConversationRow> {
  final String? workspaceId;
  final String id;

  /// 助手被删除后置空，会话保留并允许重新选择助手。
  final String? assistantId;
  final String title;
  final String? currentMessageId;

  /// ModelSelection 的 JSON；为空时用助手默认值。
  final String? selectionJson;
  final PermissionMode permissionMode;
  final PermissionMode lastExecutionMode;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ConversationRow({
    this.workspaceId,
    required this.id,
    this.assistantId,
    required this.title,
    this.currentMessageId,
    this.selectionJson,
    required this.permissionMode,
    required this.lastExecutionMode,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || workspaceId != null) {
      map['workspace_id'] = Variable<String>(workspaceId);
    }
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
    {
      map['permission_mode'] = Variable<String>(
        $ConversationsTable.$converterpermissionMode.toSql(permissionMode),
      );
    }
    {
      map['last_execution_mode'] = Variable<String>(
        $ConversationsTable.$converterlastExecutionMode.toSql(
          lastExecutionMode,
        ),
      );
    }
    map['pinned'] = Variable<bool>(pinned);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      workspaceId: workspaceId == null && nullToAbsent
          ? const Value.absent()
          : Value(workspaceId),
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
      permissionMode: Value(permissionMode),
      lastExecutionMode: Value(lastExecutionMode),
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
      workspaceId: serializer.fromJson<String?>(json['workspaceId']),
      id: serializer.fromJson<String>(json['id']),
      assistantId: serializer.fromJson<String?>(json['assistantId']),
      title: serializer.fromJson<String>(json['title']),
      currentMessageId: serializer.fromJson<String?>(json['currentMessageId']),
      selectionJson: serializer.fromJson<String?>(json['selectionJson']),
      permissionMode: $ConversationsTable.$converterpermissionMode.fromJson(
        serializer.fromJson<String>(json['permissionMode']),
      ),
      lastExecutionMode: $ConversationsTable.$converterlastExecutionMode
          .fromJson(serializer.fromJson<String>(json['lastExecutionMode'])),
      pinned: serializer.fromJson<bool>(json['pinned']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'workspaceId': serializer.toJson<String?>(workspaceId),
      'id': serializer.toJson<String>(id),
      'assistantId': serializer.toJson<String?>(assistantId),
      'title': serializer.toJson<String>(title),
      'currentMessageId': serializer.toJson<String?>(currentMessageId),
      'selectionJson': serializer.toJson<String?>(selectionJson),
      'permissionMode': serializer.toJson<String>(
        $ConversationsTable.$converterpermissionMode.toJson(permissionMode),
      ),
      'lastExecutionMode': serializer.toJson<String>(
        $ConversationsTable.$converterlastExecutionMode.toJson(
          lastExecutionMode,
        ),
      ),
      'pinned': serializer.toJson<bool>(pinned),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConversationRow copyWith({
    Value<String?> workspaceId = const Value.absent(),
    String? id,
    Value<String?> assistantId = const Value.absent(),
    String? title,
    Value<String?> currentMessageId = const Value.absent(),
    Value<String?> selectionJson = const Value.absent(),
    PermissionMode? permissionMode,
    PermissionMode? lastExecutionMode,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ConversationRow(
    workspaceId: workspaceId.present ? workspaceId.value : this.workspaceId,
    id: id ?? this.id,
    assistantId: assistantId.present ? assistantId.value : this.assistantId,
    title: title ?? this.title,
    currentMessageId: currentMessageId.present
        ? currentMessageId.value
        : this.currentMessageId,
    selectionJson: selectionJson.present
        ? selectionJson.value
        : this.selectionJson,
    permissionMode: permissionMode ?? this.permissionMode,
    lastExecutionMode: lastExecutionMode ?? this.lastExecutionMode,
    pinned: pinned ?? this.pinned,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ConversationRow copyWithCompanion(ConversationsCompanion data) {
    return ConversationRow(
      workspaceId: data.workspaceId.present
          ? data.workspaceId.value
          : this.workspaceId,
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
      permissionMode: data.permissionMode.present
          ? data.permissionMode.value
          : this.permissionMode,
      lastExecutionMode: data.lastExecutionMode.present
          ? data.lastExecutionMode.value
          : this.lastExecutionMode,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationRow(')
          ..write('workspaceId: $workspaceId, ')
          ..write('id: $id, ')
          ..write('assistantId: $assistantId, ')
          ..write('title: $title, ')
          ..write('currentMessageId: $currentMessageId, ')
          ..write('selectionJson: $selectionJson, ')
          ..write('permissionMode: $permissionMode, ')
          ..write('lastExecutionMode: $lastExecutionMode, ')
          ..write('pinned: $pinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    workspaceId,
    id,
    assistantId,
    title,
    currentMessageId,
    selectionJson,
    permissionMode,
    lastExecutionMode,
    pinned,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationRow &&
          other.workspaceId == this.workspaceId &&
          other.id == this.id &&
          other.assistantId == this.assistantId &&
          other.title == this.title &&
          other.currentMessageId == this.currentMessageId &&
          other.selectionJson == this.selectionJson &&
          other.permissionMode == this.permissionMode &&
          other.lastExecutionMode == this.lastExecutionMode &&
          other.pinned == this.pinned &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<ConversationRow> {
  final Value<String?> workspaceId;
  final Value<String> id;
  final Value<String?> assistantId;
  final Value<String> title;
  final Value<String?> currentMessageId;
  final Value<String?> selectionJson;
  final Value<PermissionMode> permissionMode;
  final Value<PermissionMode> lastExecutionMode;
  final Value<bool> pinned;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.workspaceId = const Value.absent(),
    this.id = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.title = const Value.absent(),
    this.currentMessageId = const Value.absent(),
    this.selectionJson = const Value.absent(),
    this.permissionMode = const Value.absent(),
    this.lastExecutionMode = const Value.absent(),
    this.pinned = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    this.workspaceId = const Value.absent(),
    required String id,
    this.assistantId = const Value.absent(),
    required String title,
    this.currentMessageId = const Value.absent(),
    this.selectionJson = const Value.absent(),
    this.permissionMode = const Value.absent(),
    this.lastExecutionMode = const Value.absent(),
    this.pinned = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ConversationRow> custom({
    Expression<String>? workspaceId,
    Expression<String>? id,
    Expression<String>? assistantId,
    Expression<String>? title,
    Expression<String>? currentMessageId,
    Expression<String>? selectionJson,
    Expression<String>? permissionMode,
    Expression<String>? lastExecutionMode,
    Expression<bool>? pinned,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (id != null) 'id': id,
      if (assistantId != null) 'assistant_id': assistantId,
      if (title != null) 'title': title,
      if (currentMessageId != null) 'current_message_id': currentMessageId,
      if (selectionJson != null) 'selection_json': selectionJson,
      if (permissionMode != null) 'permission_mode': permissionMode,
      if (lastExecutionMode != null) 'last_execution_mode': lastExecutionMode,
      if (pinned != null) 'pinned': pinned,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String?>? workspaceId,
    Value<String>? id,
    Value<String?>? assistantId,
    Value<String>? title,
    Value<String?>? currentMessageId,
    Value<String?>? selectionJson,
    Value<PermissionMode>? permissionMode,
    Value<PermissionMode>? lastExecutionMode,
    Value<bool>? pinned,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      workspaceId: workspaceId ?? this.workspaceId,
      id: id ?? this.id,
      assistantId: assistantId ?? this.assistantId,
      title: title ?? this.title,
      currentMessageId: currentMessageId ?? this.currentMessageId,
      selectionJson: selectionJson ?? this.selectionJson,
      permissionMode: permissionMode ?? this.permissionMode,
      lastExecutionMode: lastExecutionMode ?? this.lastExecutionMode,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
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
    if (permissionMode.present) {
      map['permission_mode'] = Variable<String>(
        $ConversationsTable.$converterpermissionMode.toSql(
          permissionMode.value,
        ),
      );
    }
    if (lastExecutionMode.present) {
      map['last_execution_mode'] = Variable<String>(
        $ConversationsTable.$converterlastExecutionMode.toSql(
          lastExecutionMode.value,
        ),
      );
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
          ..write('workspaceId: $workspaceId, ')
          ..write('id: $id, ')
          ..write('assistantId: $assistantId, ')
          ..write('title: $title, ')
          ..write('currentMessageId: $currentMessageId, ')
          ..write('selectionJson: $selectionJson, ')
          ..write('permissionMode: $permissionMode, ')
          ..write('lastExecutionMode: $lastExecutionMode, ')
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
  static const VerificationMeta _sourceJsonMeta = const VerificationMeta(
    'sourceJson',
  );
  @override
  late final GeneratedColumn<String> sourceJson = GeneratedColumn<String>(
    'source_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    sourceJson,
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
    if (data.containsKey('source_json')) {
      context.handle(
        _sourceJsonMeta,
        sourceJson.isAcceptableOrUnknown(data['source_json']!, _sourceJsonMeta),
      );
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
      sourceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_json'],
      ),
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
  final String? sourceJson;
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
    this.sourceJson,
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
    if (!nullToAbsent || sourceJson != null) {
      map['source_json'] = Variable<String>(sourceJson);
    }
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
      sourceJson: sourceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceJson),
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
      sourceJson: serializer.fromJson<String?>(json['sourceJson']),
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
      'sourceJson': serializer.toJson<String?>(sourceJson),
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
    Value<String?> sourceJson = const Value.absent(),
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
    sourceJson: sourceJson.present ? sourceJson.value : this.sourceJson,
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
      sourceJson: data.sourceJson.present
          ? data.sourceJson.value
          : this.sourceJson,
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
          ..write('sourceJson: $sourceJson, ')
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
    sourceJson,
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
          other.sourceJson == this.sourceJson &&
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
  final Value<String?> sourceJson;
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
    this.sourceJson = const Value.absent(),
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
    this.sourceJson = const Value.absent(),
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
    Expression<String>? sourceJson,
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
      if (sourceJson != null) 'source_json': sourceJson,
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
    Value<String?>? sourceJson,
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
      sourceJson: sourceJson ?? this.sourceJson,
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
    if (sourceJson.present) {
      map['source_json'] = Variable<String>(sourceJson.value);
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
          ..write('sourceJson: $sourceJson, ')
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

class $McpServersTable extends McpServers
    with TableInfo<$McpServersTable, McpServerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $McpServersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileJsonMeta = const VerificationMeta(
    'profileJson',
  );
  @override
  late final GeneratedColumn<String> profileJson = GeneratedColumn<String>(
    'profile_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toolsJsonMeta = const VerificationMeta(
    'toolsJson',
  );
  @override
  late final GeneratedColumn<String> toolsJson = GeneratedColumn<String>(
    'tools_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _protocolVersionMeta = const VerificationMeta(
    'protocolVersion',
  );
  @override
  late final GeneratedColumn<String> protocolVersion = GeneratedColumn<String>(
    'protocol_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileJson,
    toolsJson,
    protocolVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mcp_servers';
  @override
  VerificationContext validateIntegrity(
    Insertable<McpServerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_json')) {
      context.handle(
        _profileJsonMeta,
        profileJson.isAcceptableOrUnknown(
          data['profile_json']!,
          _profileJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_profileJsonMeta);
    }
    if (data.containsKey('tools_json')) {
      context.handle(
        _toolsJsonMeta,
        toolsJson.isAcceptableOrUnknown(data['tools_json']!, _toolsJsonMeta),
      );
    }
    if (data.containsKey('protocol_version')) {
      context.handle(
        _protocolVersionMeta,
        protocolVersion.isAcceptableOrUnknown(
          data['protocol_version']!,
          _protocolVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  McpServerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return McpServerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_json'],
      )!,
      toolsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tools_json'],
      )!,
      protocolVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}protocol_version'],
      ),
    );
  }

  @override
  $McpServersTable createAlias(String alias) {
    return $McpServersTable(attachedDatabase, alias);
  }
}

class McpServerRow extends DataClass implements Insertable<McpServerRow> {
  final String id;
  final String profileJson;
  final String toolsJson;
  final String? protocolVersion;
  const McpServerRow({
    required this.id,
    required this.profileJson,
    required this.toolsJson,
    this.protocolVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_json'] = Variable<String>(profileJson);
    map['tools_json'] = Variable<String>(toolsJson);
    if (!nullToAbsent || protocolVersion != null) {
      map['protocol_version'] = Variable<String>(protocolVersion);
    }
    return map;
  }

  McpServersCompanion toCompanion(bool nullToAbsent) {
    return McpServersCompanion(
      id: Value(id),
      profileJson: Value(profileJson),
      toolsJson: Value(toolsJson),
      protocolVersion: protocolVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(protocolVersion),
    );
  }

  factory McpServerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return McpServerRow(
      id: serializer.fromJson<String>(json['id']),
      profileJson: serializer.fromJson<String>(json['profileJson']),
      toolsJson: serializer.fromJson<String>(json['toolsJson']),
      protocolVersion: serializer.fromJson<String?>(json['protocolVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileJson': serializer.toJson<String>(profileJson),
      'toolsJson': serializer.toJson<String>(toolsJson),
      'protocolVersion': serializer.toJson<String?>(protocolVersion),
    };
  }

  McpServerRow copyWith({
    String? id,
    String? profileJson,
    String? toolsJson,
    Value<String?> protocolVersion = const Value.absent(),
  }) => McpServerRow(
    id: id ?? this.id,
    profileJson: profileJson ?? this.profileJson,
    toolsJson: toolsJson ?? this.toolsJson,
    protocolVersion: protocolVersion.present
        ? protocolVersion.value
        : this.protocolVersion,
  );
  McpServerRow copyWithCompanion(McpServersCompanion data) {
    return McpServerRow(
      id: data.id.present ? data.id.value : this.id,
      profileJson: data.profileJson.present
          ? data.profileJson.value
          : this.profileJson,
      toolsJson: data.toolsJson.present ? data.toolsJson.value : this.toolsJson,
      protocolVersion: data.protocolVersion.present
          ? data.protocolVersion.value
          : this.protocolVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('McpServerRow(')
          ..write('id: $id, ')
          ..write('profileJson: $profileJson, ')
          ..write('toolsJson: $toolsJson, ')
          ..write('protocolVersion: $protocolVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, profileJson, toolsJson, protocolVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpServerRow &&
          other.id == this.id &&
          other.profileJson == this.profileJson &&
          other.toolsJson == this.toolsJson &&
          other.protocolVersion == this.protocolVersion);
}

class McpServersCompanion extends UpdateCompanion<McpServerRow> {
  final Value<String> id;
  final Value<String> profileJson;
  final Value<String> toolsJson;
  final Value<String?> protocolVersion;
  final Value<int> rowid;
  const McpServersCompanion({
    this.id = const Value.absent(),
    this.profileJson = const Value.absent(),
    this.toolsJson = const Value.absent(),
    this.protocolVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  McpServersCompanion.insert({
    required String id,
    required String profileJson,
    this.toolsJson = const Value.absent(),
    this.protocolVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileJson = Value(profileJson);
  static Insertable<McpServerRow> custom({
    Expression<String>? id,
    Expression<String>? profileJson,
    Expression<String>? toolsJson,
    Expression<String>? protocolVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileJson != null) 'profile_json': profileJson,
      if (toolsJson != null) 'tools_json': toolsJson,
      if (protocolVersion != null) 'protocol_version': protocolVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  McpServersCompanion copyWith({
    Value<String>? id,
    Value<String>? profileJson,
    Value<String>? toolsJson,
    Value<String?>? protocolVersion,
    Value<int>? rowid,
  }) {
    return McpServersCompanion(
      id: id ?? this.id,
      profileJson: profileJson ?? this.profileJson,
      toolsJson: toolsJson ?? this.toolsJson,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileJson.present) {
      map['profile_json'] = Variable<String>(profileJson.value);
    }
    if (toolsJson.present) {
      map['tools_json'] = Variable<String>(toolsJson.value);
    }
    if (protocolVersion.present) {
      map['protocol_version'] = Variable<String>(protocolVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('McpServersCompanion(')
          ..write('id: $id, ')
          ..write('profileJson: $profileJson, ')
          ..write('toolsJson: $toolsJson, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SkillInstallationsTable extends SkillInstallations
    with TableInfo<$SkillInstallationsTable, SkillInstallationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SkillInstallationsTable(this.attachedDatabase, [this._alias]);
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  @override
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _deletingMeta = const VerificationMeta(
    'deleting',
  );
  @override
  late final GeneratedColumn<bool> deleting = GeneratedColumn<bool>(
    'deleting',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleting" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    snapshotJson,
    enabled,
    deleting,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'skill_installations';
  @override
  VerificationContext validateIntegrity(
    Insertable<SkillInstallationRow> instance, {
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
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('deleting')) {
      context.handle(
        _deletingMeta,
        deleting.isAcceptableOrUnknown(data['deleting']!, _deletingMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SkillInstallationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SkillInstallationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      deleting: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleting'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
    );
  }

  @override
  $SkillInstallationsTable createAlias(String alias) {
    return $SkillInstallationsTable(attachedDatabase, alias);
  }
}

class SkillInstallationRow extends DataClass
    implements Insertable<SkillInstallationRow> {
  final String id;
  final String name;
  final String snapshotJson;
  final bool enabled;
  final bool deleting;
  final DateTime installedAt;
  const SkillInstallationRow({
    required this.id,
    required this.name,
    required this.snapshotJson,
    required this.enabled,
    required this.deleting,
    required this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    map['enabled'] = Variable<bool>(enabled);
    map['deleting'] = Variable<bool>(deleting);
    map['installed_at'] = Variable<DateTime>(installedAt);
    return map;
  }

  SkillInstallationsCompanion toCompanion(bool nullToAbsent) {
    return SkillInstallationsCompanion(
      id: Value(id),
      name: Value(name),
      snapshotJson: Value(snapshotJson),
      enabled: Value(enabled),
      deleting: Value(deleting),
      installedAt: Value(installedAt),
    );
  }

  factory SkillInstallationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SkillInstallationRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      snapshotJson: serializer.fromJson<String>(json['snapshotJson']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      deleting: serializer.fromJson<bool>(json['deleting']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'snapshotJson': serializer.toJson<String>(snapshotJson),
      'enabled': serializer.toJson<bool>(enabled),
      'deleting': serializer.toJson<bool>(deleting),
      'installedAt': serializer.toJson<DateTime>(installedAt),
    };
  }

  SkillInstallationRow copyWith({
    String? id,
    String? name,
    String? snapshotJson,
    bool? enabled,
    bool? deleting,
    DateTime? installedAt,
  }) => SkillInstallationRow(
    id: id ?? this.id,
    name: name ?? this.name,
    snapshotJson: snapshotJson ?? this.snapshotJson,
    enabled: enabled ?? this.enabled,
    deleting: deleting ?? this.deleting,
    installedAt: installedAt ?? this.installedAt,
  );
  SkillInstallationRow copyWithCompanion(SkillInstallationsCompanion data) {
    return SkillInstallationRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      deleting: data.deleting.present ? data.deleting.value : this.deleting,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SkillInstallationRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('enabled: $enabled, ')
          ..write('deleting: $deleting, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, snapshotJson, enabled, deleting, installedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SkillInstallationRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.snapshotJson == this.snapshotJson &&
          other.enabled == this.enabled &&
          other.deleting == this.deleting &&
          other.installedAt == this.installedAt);
}

class SkillInstallationsCompanion
    extends UpdateCompanion<SkillInstallationRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> snapshotJson;
  final Value<bool> enabled;
  final Value<bool> deleting;
  final Value<DateTime> installedAt;
  final Value<int> rowid;
  const SkillInstallationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.enabled = const Value.absent(),
    this.deleting = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SkillInstallationsCompanion.insert({
    required String id,
    required String name,
    required String snapshotJson,
    this.enabled = const Value.absent(),
    this.deleting = const Value.absent(),
    required DateTime installedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       snapshotJson = Value(snapshotJson),
       installedAt = Value(installedAt);
  static Insertable<SkillInstallationRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? snapshotJson,
    Expression<bool>? enabled,
    Expression<bool>? deleting,
    Expression<DateTime>? installedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (enabled != null) 'enabled': enabled,
      if (deleting != null) 'deleting': deleting,
      if (installedAt != null) 'installed_at': installedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SkillInstallationsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? snapshotJson,
    Value<bool>? enabled,
    Value<bool>? deleting,
    Value<DateTime>? installedAt,
    Value<int>? rowid,
  }) {
    return SkillInstallationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      enabled: enabled ?? this.enabled,
      deleting: deleting ?? this.deleting,
      installedAt: installedAt ?? this.installedAt,
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
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (deleting.present) {
      map['deleting'] = Variable<bool>(deleting.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SkillInstallationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('enabled: $enabled, ')
          ..write('deleting: $deleting, ')
          ..write('installedAt: $installedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RuntimeEnvironmentsTable extends RuntimeEnvironments
    with TableInfo<$RuntimeEnvironmentsTable, RuntimeEnvironmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuntimeEnvironmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  List<GeneratedColumn> get $columns => [id, configurationJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runtime_environments';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuntimeEnvironmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuntimeEnvironmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuntimeEnvironmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      configurationJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}configuration_json'],
      )!,
    );
  }

  @override
  $RuntimeEnvironmentsTable createAlias(String alias) {
    return $RuntimeEnvironmentsTable(attachedDatabase, alias);
  }
}

class RuntimeEnvironmentRow extends DataClass
    implements Insertable<RuntimeEnvironmentRow> {
  final String id;
  final String configurationJson;
  const RuntimeEnvironmentRow({
    required this.id,
    required this.configurationJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['configuration_json'] = Variable<String>(configurationJson);
    return map;
  }

  RuntimeEnvironmentsCompanion toCompanion(bool nullToAbsent) {
    return RuntimeEnvironmentsCompanion(
      id: Value(id),
      configurationJson: Value(configurationJson),
    );
  }

  factory RuntimeEnvironmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuntimeEnvironmentRow(
      id: serializer.fromJson<String>(json['id']),
      configurationJson: serializer.fromJson<String>(json['configurationJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'configurationJson': serializer.toJson<String>(configurationJson),
    };
  }

  RuntimeEnvironmentRow copyWith({String? id, String? configurationJson}) =>
      RuntimeEnvironmentRow(
        id: id ?? this.id,
        configurationJson: configurationJson ?? this.configurationJson,
      );
  RuntimeEnvironmentRow copyWithCompanion(RuntimeEnvironmentsCompanion data) {
    return RuntimeEnvironmentRow(
      id: data.id.present ? data.id.value : this.id,
      configurationJson: data.configurationJson.present
          ? data.configurationJson.value
          : this.configurationJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuntimeEnvironmentRow(')
          ..write('id: $id, ')
          ..write('configurationJson: $configurationJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, configurationJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuntimeEnvironmentRow &&
          other.id == this.id &&
          other.configurationJson == this.configurationJson);
}

class RuntimeEnvironmentsCompanion
    extends UpdateCompanion<RuntimeEnvironmentRow> {
  final Value<String> id;
  final Value<String> configurationJson;
  final Value<int> rowid;
  const RuntimeEnvironmentsCompanion({
    this.id = const Value.absent(),
    this.configurationJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RuntimeEnvironmentsCompanion.insert({
    required String id,
    required String configurationJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       configurationJson = Value(configurationJson);
  static Insertable<RuntimeEnvironmentRow> custom({
    Expression<String>? id,
    Expression<String>? configurationJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (configurationJson != null) 'configuration_json': configurationJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RuntimeEnvironmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? configurationJson,
    Value<int>? rowid,
  }) {
    return RuntimeEnvironmentsCompanion(
      id: id ?? this.id,
      configurationJson: configurationJson ?? this.configurationJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (configurationJson.present) {
      map['configuration_json'] = Variable<String>(configurationJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuntimeEnvironmentsCompanion(')
          ..write('id: $id, ')
          ..write('configurationJson: $configurationJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkspaceCopiesTable extends WorkspaceCopies
    with TableInfo<$WorkspaceCopiesTable, WorkspaceCopyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkspaceCopiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _workspaceIdMeta = const VerificationMeta(
    'workspaceId',
  );
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
    'workspace_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workspaces (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceJsonMeta = const VerificationMeta(
    'sourceJson',
  );
  @override
  late final GeneratedColumn<String> sourceJson = GeneratedColumn<String>(
    'source_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [workspaceId, relativePath, sourceJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workspace_copies';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkspaceCopyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('workspace_id')) {
      context.handle(
        _workspaceIdMeta,
        workspaceId.isAcceptableOrUnknown(
          data['workspace_id']!,
          _workspaceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('source_json')) {
      context.handle(
        _sourceJsonMeta,
        sourceJson.isAcceptableOrUnknown(data['source_json']!, _sourceJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {workspaceId, relativePath};
  @override
  WorkspaceCopyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkspaceCopyRow(
      workspaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workspace_id'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      sourceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_json'],
      )!,
    );
  }

  @override
  $WorkspaceCopiesTable createAlias(String alias) {
    return $WorkspaceCopiesTable(attachedDatabase, alias);
  }
}

class WorkspaceCopyRow extends DataClass
    implements Insertable<WorkspaceCopyRow> {
  final String workspaceId;
  final String relativePath;
  final String sourceJson;
  const WorkspaceCopyRow({
    required this.workspaceId,
    required this.relativePath,
    required this.sourceJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['workspace_id'] = Variable<String>(workspaceId);
    map['relative_path'] = Variable<String>(relativePath);
    map['source_json'] = Variable<String>(sourceJson);
    return map;
  }

  WorkspaceCopiesCompanion toCompanion(bool nullToAbsent) {
    return WorkspaceCopiesCompanion(
      workspaceId: Value(workspaceId),
      relativePath: Value(relativePath),
      sourceJson: Value(sourceJson),
    );
  }

  factory WorkspaceCopyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkspaceCopyRow(
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      sourceJson: serializer.fromJson<String>(json['sourceJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'workspaceId': serializer.toJson<String>(workspaceId),
      'relativePath': serializer.toJson<String>(relativePath),
      'sourceJson': serializer.toJson<String>(sourceJson),
    };
  }

  WorkspaceCopyRow copyWith({
    String? workspaceId,
    String? relativePath,
    String? sourceJson,
  }) => WorkspaceCopyRow(
    workspaceId: workspaceId ?? this.workspaceId,
    relativePath: relativePath ?? this.relativePath,
    sourceJson: sourceJson ?? this.sourceJson,
  );
  WorkspaceCopyRow copyWithCompanion(WorkspaceCopiesCompanion data) {
    return WorkspaceCopyRow(
      workspaceId: data.workspaceId.present
          ? data.workspaceId.value
          : this.workspaceId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      sourceJson: data.sourceJson.present
          ? data.sourceJson.value
          : this.sourceJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceCopyRow(')
          ..write('workspaceId: $workspaceId, ')
          ..write('relativePath: $relativePath, ')
          ..write('sourceJson: $sourceJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(workspaceId, relativePath, sourceJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkspaceCopyRow &&
          other.workspaceId == this.workspaceId &&
          other.relativePath == this.relativePath &&
          other.sourceJson == this.sourceJson);
}

class WorkspaceCopiesCompanion extends UpdateCompanion<WorkspaceCopyRow> {
  final Value<String> workspaceId;
  final Value<String> relativePath;
  final Value<String> sourceJson;
  final Value<int> rowid;
  const WorkspaceCopiesCompanion({
    this.workspaceId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.sourceJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkspaceCopiesCompanion.insert({
    required String workspaceId,
    required String relativePath,
    required String sourceJson,
    this.rowid = const Value.absent(),
  }) : workspaceId = Value(workspaceId),
       relativePath = Value(relativePath),
       sourceJson = Value(sourceJson);
  static Insertable<WorkspaceCopyRow> custom({
    Expression<String>? workspaceId,
    Expression<String>? relativePath,
    Expression<String>? sourceJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (relativePath != null) 'relative_path': relativePath,
      if (sourceJson != null) 'source_json': sourceJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkspaceCopiesCompanion copyWith({
    Value<String>? workspaceId,
    Value<String>? relativePath,
    Value<String>? sourceJson,
    Value<int>? rowid,
  }) {
    return WorkspaceCopiesCompanion(
      workspaceId: workspaceId ?? this.workspaceId,
      relativePath: relativePath ?? this.relativePath,
      sourceJson: sourceJson ?? this.sourceJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (sourceJson.present) {
      map['source_json'] = Variable<String>(sourceJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceCopiesCompanion(')
          ..write('workspaceId: $workspaceId, ')
          ..write('relativePath: $relativePath, ')
          ..write('sourceJson: $sourceJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContextSummariesTable extends ContextSummaries
    with TableInfo<$ContextSummariesTable, ContextSummaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContextSummariesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _branchEndIdMeta = const VerificationMeta(
    'branchEndId',
  );
  @override
  late final GeneratedColumn<String> branchEndId = GeneratedColumn<String>(
    'branch_end_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coveredIdsJsonMeta = const VerificationMeta(
    'coveredIdsJson',
  );
  @override
  late final GeneratedColumn<String> coveredIdsJson = GeneratedColumn<String>(
    'covered_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceModelMeta = const VerificationMeta(
    'sourceModel',
  );
  @override
  late final GeneratedColumn<String> sourceModel = GeneratedColumn<String>(
    'source_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkpointJsonMeta = const VerificationMeta(
    'checkpointJson',
  );
  @override
  late final GeneratedColumn<String> checkpointJson = GeneratedColumn<String>(
    'checkpoint_json',
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
    conversationId,
    runId,
    branchEndId,
    coveredIdsJson,
    fingerprint,
    sourceModel,
    version,
    status,
    content,
    checkpointJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'context_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContextSummaryRow> instance, {
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
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('branch_end_id')) {
      context.handle(
        _branchEndIdMeta,
        branchEndId.isAcceptableOrUnknown(
          data['branch_end_id']!,
          _branchEndIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_branchEndIdMeta);
    }
    if (data.containsKey('covered_ids_json')) {
      context.handle(
        _coveredIdsJsonMeta,
        coveredIdsJson.isAcceptableOrUnknown(
          data['covered_ids_json']!,
          _coveredIdsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_coveredIdsJsonMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('source_model')) {
      context.handle(
        _sourceModelMeta,
        sourceModel.isAcceptableOrUnknown(
          data['source_model']!,
          _sourceModelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceModelMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('checkpoint_json')) {
      context.handle(
        _checkpointJsonMeta,
        checkpointJson.isAcceptableOrUnknown(
          data['checkpoint_json']!,
          _checkpointJsonMeta,
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
  ContextSummaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContextSummaryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      ),
      branchEndId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_end_id'],
      )!,
      coveredIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}covered_ids_json'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      sourceModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_model'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      checkpointJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checkpoint_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ContextSummariesTable createAlias(String alias) {
    return $ContextSummariesTable(attachedDatabase, alias);
  }
}

class ContextSummaryRow extends DataClass
    implements Insertable<ContextSummaryRow> {
  final String id;
  final String conversationId;
  final String? runId;
  final String branchEndId;
  final String coveredIdsJson;
  final String fingerprint;
  final String sourceModel;
  final int version;
  final String status;
  final String content;
  final String checkpointJson;
  final DateTime createdAt;
  const ContextSummaryRow({
    required this.id,
    required this.conversationId,
    this.runId,
    required this.branchEndId,
    required this.coveredIdsJson,
    required this.fingerprint,
    required this.sourceModel,
    required this.version,
    required this.status,
    required this.content,
    required this.checkpointJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    if (!nullToAbsent || runId != null) {
      map['run_id'] = Variable<String>(runId);
    }
    map['branch_end_id'] = Variable<String>(branchEndId);
    map['covered_ids_json'] = Variable<String>(coveredIdsJson);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['source_model'] = Variable<String>(sourceModel);
    map['version'] = Variable<int>(version);
    map['status'] = Variable<String>(status);
    map['content'] = Variable<String>(content);
    map['checkpoint_json'] = Variable<String>(checkpointJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ContextSummariesCompanion toCompanion(bool nullToAbsent) {
    return ContextSummariesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      runId: runId == null && nullToAbsent
          ? const Value.absent()
          : Value(runId),
      branchEndId: Value(branchEndId),
      coveredIdsJson: Value(coveredIdsJson),
      fingerprint: Value(fingerprint),
      sourceModel: Value(sourceModel),
      version: Value(version),
      status: Value(status),
      content: Value(content),
      checkpointJson: Value(checkpointJson),
      createdAt: Value(createdAt),
    );
  }

  factory ContextSummaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContextSummaryRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      runId: serializer.fromJson<String?>(json['runId']),
      branchEndId: serializer.fromJson<String>(json['branchEndId']),
      coveredIdsJson: serializer.fromJson<String>(json['coveredIdsJson']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      sourceModel: serializer.fromJson<String>(json['sourceModel']),
      version: serializer.fromJson<int>(json['version']),
      status: serializer.fromJson<String>(json['status']),
      content: serializer.fromJson<String>(json['content']),
      checkpointJson: serializer.fromJson<String>(json['checkpointJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'runId': serializer.toJson<String?>(runId),
      'branchEndId': serializer.toJson<String>(branchEndId),
      'coveredIdsJson': serializer.toJson<String>(coveredIdsJson),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'sourceModel': serializer.toJson<String>(sourceModel),
      'version': serializer.toJson<int>(version),
      'status': serializer.toJson<String>(status),
      'content': serializer.toJson<String>(content),
      'checkpointJson': serializer.toJson<String>(checkpointJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ContextSummaryRow copyWith({
    String? id,
    String? conversationId,
    Value<String?> runId = const Value.absent(),
    String? branchEndId,
    String? coveredIdsJson,
    String? fingerprint,
    String? sourceModel,
    int? version,
    String? status,
    String? content,
    String? checkpointJson,
    DateTime? createdAt,
  }) => ContextSummaryRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    runId: runId.present ? runId.value : this.runId,
    branchEndId: branchEndId ?? this.branchEndId,
    coveredIdsJson: coveredIdsJson ?? this.coveredIdsJson,
    fingerprint: fingerprint ?? this.fingerprint,
    sourceModel: sourceModel ?? this.sourceModel,
    version: version ?? this.version,
    status: status ?? this.status,
    content: content ?? this.content,
    checkpointJson: checkpointJson ?? this.checkpointJson,
    createdAt: createdAt ?? this.createdAt,
  );
  ContextSummaryRow copyWithCompanion(ContextSummariesCompanion data) {
    return ContextSummaryRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      runId: data.runId.present ? data.runId.value : this.runId,
      branchEndId: data.branchEndId.present
          ? data.branchEndId.value
          : this.branchEndId,
      coveredIdsJson: data.coveredIdsJson.present
          ? data.coveredIdsJson.value
          : this.coveredIdsJson,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      sourceModel: data.sourceModel.present
          ? data.sourceModel.value
          : this.sourceModel,
      version: data.version.present ? data.version.value : this.version,
      status: data.status.present ? data.status.value : this.status,
      content: data.content.present ? data.content.value : this.content,
      checkpointJson: data.checkpointJson.present
          ? data.checkpointJson.value
          : this.checkpointJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContextSummaryRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('runId: $runId, ')
          ..write('branchEndId: $branchEndId, ')
          ..write('coveredIdsJson: $coveredIdsJson, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('sourceModel: $sourceModel, ')
          ..write('version: $version, ')
          ..write('status: $status, ')
          ..write('content: $content, ')
          ..write('checkpointJson: $checkpointJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    runId,
    branchEndId,
    coveredIdsJson,
    fingerprint,
    sourceModel,
    version,
    status,
    content,
    checkpointJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContextSummaryRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.runId == this.runId &&
          other.branchEndId == this.branchEndId &&
          other.coveredIdsJson == this.coveredIdsJson &&
          other.fingerprint == this.fingerprint &&
          other.sourceModel == this.sourceModel &&
          other.version == this.version &&
          other.status == this.status &&
          other.content == this.content &&
          other.checkpointJson == this.checkpointJson &&
          other.createdAt == this.createdAt);
}

class ContextSummariesCompanion extends UpdateCompanion<ContextSummaryRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String?> runId;
  final Value<String> branchEndId;
  final Value<String> coveredIdsJson;
  final Value<String> fingerprint;
  final Value<String> sourceModel;
  final Value<int> version;
  final Value<String> status;
  final Value<String> content;
  final Value<String> checkpointJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ContextSummariesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.runId = const Value.absent(),
    this.branchEndId = const Value.absent(),
    this.coveredIdsJson = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.sourceModel = const Value.absent(),
    this.version = const Value.absent(),
    this.status = const Value.absent(),
    this.content = const Value.absent(),
    this.checkpointJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContextSummariesCompanion.insert({
    required String id,
    required String conversationId,
    this.runId = const Value.absent(),
    required String branchEndId,
    required String coveredIdsJson,
    required String fingerprint,
    required String sourceModel,
    required int version,
    required String status,
    required String content,
    this.checkpointJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       branchEndId = Value(branchEndId),
       coveredIdsJson = Value(coveredIdsJson),
       fingerprint = Value(fingerprint),
       sourceModel = Value(sourceModel),
       version = Value(version),
       status = Value(status),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<ContextSummaryRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? runId,
    Expression<String>? branchEndId,
    Expression<String>? coveredIdsJson,
    Expression<String>? fingerprint,
    Expression<String>? sourceModel,
    Expression<int>? version,
    Expression<String>? status,
    Expression<String>? content,
    Expression<String>? checkpointJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (runId != null) 'run_id': runId,
      if (branchEndId != null) 'branch_end_id': branchEndId,
      if (coveredIdsJson != null) 'covered_ids_json': coveredIdsJson,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (sourceModel != null) 'source_model': sourceModel,
      if (version != null) 'version': version,
      if (status != null) 'status': status,
      if (content != null) 'content': content,
      if (checkpointJson != null) 'checkpoint_json': checkpointJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContextSummariesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String?>? runId,
    Value<String>? branchEndId,
    Value<String>? coveredIdsJson,
    Value<String>? fingerprint,
    Value<String>? sourceModel,
    Value<int>? version,
    Value<String>? status,
    Value<String>? content,
    Value<String>? checkpointJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ContextSummariesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      runId: runId ?? this.runId,
      branchEndId: branchEndId ?? this.branchEndId,
      coveredIdsJson: coveredIdsJson ?? this.coveredIdsJson,
      fingerprint: fingerprint ?? this.fingerprint,
      sourceModel: sourceModel ?? this.sourceModel,
      version: version ?? this.version,
      status: status ?? this.status,
      content: content ?? this.content,
      checkpointJson: checkpointJson ?? this.checkpointJson,
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
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (branchEndId.present) {
      map['branch_end_id'] = Variable<String>(branchEndId.value);
    }
    if (coveredIdsJson.present) {
      map['covered_ids_json'] = Variable<String>(coveredIdsJson.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (sourceModel.present) {
      map['source_model'] = Variable<String>(sourceModel.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (checkpointJson.present) {
      map['checkpoint_json'] = Variable<String>(checkpointJson.value);
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
    return (StringBuffer('ContextSummariesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('runId: $runId, ')
          ..write('branchEndId: $branchEndId, ')
          ..write('coveredIdsJson: $coveredIdsJson, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('sourceModel: $sourceModel, ')
          ..write('version: $version, ')
          ..write('status: $status, ')
          ..write('content: $content, ')
          ..write('checkpointJson: $checkpointJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelRequestsTable extends ModelRequests
    with TableInfo<$ModelRequestsTable, ModelRequestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelRequestsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logicalTurnMeta = const VerificationMeta(
    'logicalTurn',
  );
  @override
  late final GeneratedColumn<int> logicalTurn = GeneratedColumn<int>(
    'logical_turn',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptIndexMeta = const VerificationMeta(
    'attemptIndex',
  );
  @override
  late final GeneratedColumn<int> attemptIndex = GeneratedColumn<int>(
    'attempt_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purposeMeta = const VerificationMeta(
    'purpose',
  );
  @override
  late final GeneratedColumn<String> purpose = GeneratedColumn<String>(
    'purpose',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  static const VerificationMeta _requestedModelIdMeta = const VerificationMeta(
    'requestedModelId',
  );
  @override
  late final GeneratedColumn<String> requestedModelId = GeneratedColumn<String>(
    'requested_model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseModelIdMeta = const VerificationMeta(
    'responseModelId',
  );
  @override
  late final GeneratedColumn<String> responseModelId = GeneratedColumn<String>(
    'response_model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assistantMessageIdMeta =
      const VerificationMeta('assistantMessageId');
  @override
  late final GeneratedColumn<String> assistantMessageId =
      GeneratedColumn<String>(
        'assistant_message_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
      );
  static const VerificationMeta _summaryIdMeta = const VerificationMeta(
    'summaryId',
  );
  @override
  late final GeneratedColumn<String> summaryId = GeneratedColumn<String>(
    'summary_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _summaryJobIdMeta = const VerificationMeta(
    'summaryJobId',
  );
  @override
  late final GeneratedColumn<String> summaryJobId = GeneratedColumn<String>(
    'summary_job_id',
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
  static const VerificationMeta _usageRevisionMeta = const VerificationMeta(
    'usageRevision',
  );
  @override
  late final GeneratedColumn<int> usageRevision = GeneratedColumn<int>(
    'usage_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _usageCompleteMeta = const VerificationMeta(
    'usageComplete',
  );
  @override
  late final GeneratedColumn<bool> usageComplete = GeneratedColumn<bool>(
    'usage_complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("usage_complete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _contextJsonMeta = const VerificationMeta(
    'contextJson',
  );
  @override
  late final GeneratedColumn<String> contextJson = GeneratedColumn<String>(
    'context_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originRequestIdMeta = const VerificationMeta(
    'originRequestId',
  );
  @override
  late final GeneratedColumn<String> originRequestId = GeneratedColumn<String>(
    'origin_request_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isInheritedMeta = const VerificationMeta(
    'isInherited',
  );
  @override
  late final GeneratedColumn<bool> isInherited = GeneratedColumn<bool>(
    'is_inherited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_inherited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    conversationId,
    runId,
    logicalTurn,
    attemptIndex,
    purpose,
    status,
    profileId,
    protocol,
    requestedModelId,
    responseModelId,
    assistantMessageId,
    summaryId,
    summaryJobId,
    usageJson,
    usageRevision,
    usageComplete,
    contextJson,
    originRequestId,
    isInherited,
    errorCode,
    createdAt,
    startedAt,
    finishedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_requests';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelRequestRow> instance, {
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
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('logical_turn')) {
      context.handle(
        _logicalTurnMeta,
        logicalTurn.isAcceptableOrUnknown(
          data['logical_turn']!,
          _logicalTurnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_logicalTurnMeta);
    }
    if (data.containsKey('attempt_index')) {
      context.handle(
        _attemptIndexMeta,
        attemptIndex.isAcceptableOrUnknown(
          data['attempt_index']!,
          _attemptIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attemptIndexMeta);
    }
    if (data.containsKey('purpose')) {
      context.handle(
        _purposeMeta,
        purpose.isAcceptableOrUnknown(data['purpose']!, _purposeMeta),
      );
    } else if (isInserting) {
      context.missing(_purposeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('protocol')) {
      context.handle(
        _protocolMeta,
        protocol.isAcceptableOrUnknown(data['protocol']!, _protocolMeta),
      );
    } else if (isInserting) {
      context.missing(_protocolMeta);
    }
    if (data.containsKey('requested_model_id')) {
      context.handle(
        _requestedModelIdMeta,
        requestedModelId.isAcceptableOrUnknown(
          data['requested_model_id']!,
          _requestedModelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestedModelIdMeta);
    }
    if (data.containsKey('response_model_id')) {
      context.handle(
        _responseModelIdMeta,
        responseModelId.isAcceptableOrUnknown(
          data['response_model_id']!,
          _responseModelIdMeta,
        ),
      );
    }
    if (data.containsKey('assistant_message_id')) {
      context.handle(
        _assistantMessageIdMeta,
        assistantMessageId.isAcceptableOrUnknown(
          data['assistant_message_id']!,
          _assistantMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('summary_id')) {
      context.handle(
        _summaryIdMeta,
        summaryId.isAcceptableOrUnknown(data['summary_id']!, _summaryIdMeta),
      );
    }
    if (data.containsKey('summary_job_id')) {
      context.handle(
        _summaryJobIdMeta,
        summaryJobId.isAcceptableOrUnknown(
          data['summary_job_id']!,
          _summaryJobIdMeta,
        ),
      );
    }
    if (data.containsKey('usage_json')) {
      context.handle(
        _usageJsonMeta,
        usageJson.isAcceptableOrUnknown(data['usage_json']!, _usageJsonMeta),
      );
    }
    if (data.containsKey('usage_revision')) {
      context.handle(
        _usageRevisionMeta,
        usageRevision.isAcceptableOrUnknown(
          data['usage_revision']!,
          _usageRevisionMeta,
        ),
      );
    }
    if (data.containsKey('usage_complete')) {
      context.handle(
        _usageCompleteMeta,
        usageComplete.isAcceptableOrUnknown(
          data['usage_complete']!,
          _usageCompleteMeta,
        ),
      );
    }
    if (data.containsKey('context_json')) {
      context.handle(
        _contextJsonMeta,
        contextJson.isAcceptableOrUnknown(
          data['context_json']!,
          _contextJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contextJsonMeta);
    }
    if (data.containsKey('origin_request_id')) {
      context.handle(
        _originRequestIdMeta,
        originRequestId.isAcceptableOrUnknown(
          data['origin_request_id']!,
          _originRequestIdMeta,
        ),
      );
    }
    if (data.containsKey('is_inherited')) {
      context.handle(
        _isInheritedMeta,
        isInherited.isAcceptableOrUnknown(
          data['is_inherited']!,
          _isInheritedMeta,
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
  ModelRequestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelRequestRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      ),
      logicalTurn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}logical_turn'],
      )!,
      attemptIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_index'],
      )!,
      purpose: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purpose'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      protocol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}protocol'],
      )!,
      requestedModelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}requested_model_id'],
      )!,
      responseModelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_model_id'],
      ),
      assistantMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assistant_message_id'],
      ),
      summaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_id'],
      ),
      summaryJobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_job_id'],
      ),
      usageJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}usage_json'],
      ),
      usageRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}usage_revision'],
      )!,
      usageComplete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}usage_complete'],
      )!,
      contextJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_json'],
      )!,
      originRequestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_request_id'],
      ),
      isInherited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_inherited'],
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
  $ModelRequestsTable createAlias(String alias) {
    return $ModelRequestsTable(attachedDatabase, alias);
  }
}

class ModelRequestRow extends DataClass implements Insertable<ModelRequestRow> {
  final String id;
  final String conversationId;
  final String? runId;
  final int logicalTurn;
  final int attemptIndex;
  final String purpose;
  final String status;
  final String profileId;
  final String protocol;
  final String requestedModelId;
  final String? responseModelId;
  final String? assistantMessageId;
  final String? summaryId;
  final String? summaryJobId;
  final String? usageJson;
  final int usageRevision;
  final bool usageComplete;
  final String contextJson;
  final String? originRequestId;
  final bool isInherited;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  const ModelRequestRow({
    required this.id,
    required this.conversationId,
    this.runId,
    required this.logicalTurn,
    required this.attemptIndex,
    required this.purpose,
    required this.status,
    required this.profileId,
    required this.protocol,
    required this.requestedModelId,
    this.responseModelId,
    this.assistantMessageId,
    this.summaryId,
    this.summaryJobId,
    this.usageJson,
    required this.usageRevision,
    required this.usageComplete,
    required this.contextJson,
    this.originRequestId,
    required this.isInherited,
    this.errorCode,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    if (!nullToAbsent || runId != null) {
      map['run_id'] = Variable<String>(runId);
    }
    map['logical_turn'] = Variable<int>(logicalTurn);
    map['attempt_index'] = Variable<int>(attemptIndex);
    map['purpose'] = Variable<String>(purpose);
    map['status'] = Variable<String>(status);
    map['profile_id'] = Variable<String>(profileId);
    map['protocol'] = Variable<String>(protocol);
    map['requested_model_id'] = Variable<String>(requestedModelId);
    if (!nullToAbsent || responseModelId != null) {
      map['response_model_id'] = Variable<String>(responseModelId);
    }
    if (!nullToAbsent || assistantMessageId != null) {
      map['assistant_message_id'] = Variable<String>(assistantMessageId);
    }
    if (!nullToAbsent || summaryId != null) {
      map['summary_id'] = Variable<String>(summaryId);
    }
    if (!nullToAbsent || summaryJobId != null) {
      map['summary_job_id'] = Variable<String>(summaryJobId);
    }
    if (!nullToAbsent || usageJson != null) {
      map['usage_json'] = Variable<String>(usageJson);
    }
    map['usage_revision'] = Variable<int>(usageRevision);
    map['usage_complete'] = Variable<bool>(usageComplete);
    map['context_json'] = Variable<String>(contextJson);
    if (!nullToAbsent || originRequestId != null) {
      map['origin_request_id'] = Variable<String>(originRequestId);
    }
    map['is_inherited'] = Variable<bool>(isInherited);
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

  ModelRequestsCompanion toCompanion(bool nullToAbsent) {
    return ModelRequestsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      runId: runId == null && nullToAbsent
          ? const Value.absent()
          : Value(runId),
      logicalTurn: Value(logicalTurn),
      attemptIndex: Value(attemptIndex),
      purpose: Value(purpose),
      status: Value(status),
      profileId: Value(profileId),
      protocol: Value(protocol),
      requestedModelId: Value(requestedModelId),
      responseModelId: responseModelId == null && nullToAbsent
          ? const Value.absent()
          : Value(responseModelId),
      assistantMessageId: assistantMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(assistantMessageId),
      summaryId: summaryId == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryId),
      summaryJobId: summaryJobId == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryJobId),
      usageJson: usageJson == null && nullToAbsent
          ? const Value.absent()
          : Value(usageJson),
      usageRevision: Value(usageRevision),
      usageComplete: Value(usageComplete),
      contextJson: Value(contextJson),
      originRequestId: originRequestId == null && nullToAbsent
          ? const Value.absent()
          : Value(originRequestId),
      isInherited: Value(isInherited),
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

  factory ModelRequestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelRequestRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      runId: serializer.fromJson<String?>(json['runId']),
      logicalTurn: serializer.fromJson<int>(json['logicalTurn']),
      attemptIndex: serializer.fromJson<int>(json['attemptIndex']),
      purpose: serializer.fromJson<String>(json['purpose']),
      status: serializer.fromJson<String>(json['status']),
      profileId: serializer.fromJson<String>(json['profileId']),
      protocol: serializer.fromJson<String>(json['protocol']),
      requestedModelId: serializer.fromJson<String>(json['requestedModelId']),
      responseModelId: serializer.fromJson<String?>(json['responseModelId']),
      assistantMessageId: serializer.fromJson<String?>(
        json['assistantMessageId'],
      ),
      summaryId: serializer.fromJson<String?>(json['summaryId']),
      summaryJobId: serializer.fromJson<String?>(json['summaryJobId']),
      usageJson: serializer.fromJson<String?>(json['usageJson']),
      usageRevision: serializer.fromJson<int>(json['usageRevision']),
      usageComplete: serializer.fromJson<bool>(json['usageComplete']),
      contextJson: serializer.fromJson<String>(json['contextJson']),
      originRequestId: serializer.fromJson<String?>(json['originRequestId']),
      isInherited: serializer.fromJson<bool>(json['isInherited']),
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
      'conversationId': serializer.toJson<String>(conversationId),
      'runId': serializer.toJson<String?>(runId),
      'logicalTurn': serializer.toJson<int>(logicalTurn),
      'attemptIndex': serializer.toJson<int>(attemptIndex),
      'purpose': serializer.toJson<String>(purpose),
      'status': serializer.toJson<String>(status),
      'profileId': serializer.toJson<String>(profileId),
      'protocol': serializer.toJson<String>(protocol),
      'requestedModelId': serializer.toJson<String>(requestedModelId),
      'responseModelId': serializer.toJson<String?>(responseModelId),
      'assistantMessageId': serializer.toJson<String?>(assistantMessageId),
      'summaryId': serializer.toJson<String?>(summaryId),
      'summaryJobId': serializer.toJson<String?>(summaryJobId),
      'usageJson': serializer.toJson<String?>(usageJson),
      'usageRevision': serializer.toJson<int>(usageRevision),
      'usageComplete': serializer.toJson<bool>(usageComplete),
      'contextJson': serializer.toJson<String>(contextJson),
      'originRequestId': serializer.toJson<String?>(originRequestId),
      'isInherited': serializer.toJson<bool>(isInherited),
      'errorCode': serializer.toJson<String?>(errorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
    };
  }

  ModelRequestRow copyWith({
    String? id,
    String? conversationId,
    Value<String?> runId = const Value.absent(),
    int? logicalTurn,
    int? attemptIndex,
    String? purpose,
    String? status,
    String? profileId,
    String? protocol,
    String? requestedModelId,
    Value<String?> responseModelId = const Value.absent(),
    Value<String?> assistantMessageId = const Value.absent(),
    Value<String?> summaryId = const Value.absent(),
    Value<String?> summaryJobId = const Value.absent(),
    Value<String?> usageJson = const Value.absent(),
    int? usageRevision,
    bool? usageComplete,
    String? contextJson,
    Value<String?> originRequestId = const Value.absent(),
    bool? isInherited,
    Value<String?> errorCode = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> finishedAt = const Value.absent(),
  }) => ModelRequestRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    runId: runId.present ? runId.value : this.runId,
    logicalTurn: logicalTurn ?? this.logicalTurn,
    attemptIndex: attemptIndex ?? this.attemptIndex,
    purpose: purpose ?? this.purpose,
    status: status ?? this.status,
    profileId: profileId ?? this.profileId,
    protocol: protocol ?? this.protocol,
    requestedModelId: requestedModelId ?? this.requestedModelId,
    responseModelId: responseModelId.present
        ? responseModelId.value
        : this.responseModelId,
    assistantMessageId: assistantMessageId.present
        ? assistantMessageId.value
        : this.assistantMessageId,
    summaryId: summaryId.present ? summaryId.value : this.summaryId,
    summaryJobId: summaryJobId.present ? summaryJobId.value : this.summaryJobId,
    usageJson: usageJson.present ? usageJson.value : this.usageJson,
    usageRevision: usageRevision ?? this.usageRevision,
    usageComplete: usageComplete ?? this.usageComplete,
    contextJson: contextJson ?? this.contextJson,
    originRequestId: originRequestId.present
        ? originRequestId.value
        : this.originRequestId,
    isInherited: isInherited ?? this.isInherited,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
  );
  ModelRequestRow copyWithCompanion(ModelRequestsCompanion data) {
    return ModelRequestRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      runId: data.runId.present ? data.runId.value : this.runId,
      logicalTurn: data.logicalTurn.present
          ? data.logicalTurn.value
          : this.logicalTurn,
      attemptIndex: data.attemptIndex.present
          ? data.attemptIndex.value
          : this.attemptIndex,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      status: data.status.present ? data.status.value : this.status,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      protocol: data.protocol.present ? data.protocol.value : this.protocol,
      requestedModelId: data.requestedModelId.present
          ? data.requestedModelId.value
          : this.requestedModelId,
      responseModelId: data.responseModelId.present
          ? data.responseModelId.value
          : this.responseModelId,
      assistantMessageId: data.assistantMessageId.present
          ? data.assistantMessageId.value
          : this.assistantMessageId,
      summaryId: data.summaryId.present ? data.summaryId.value : this.summaryId,
      summaryJobId: data.summaryJobId.present
          ? data.summaryJobId.value
          : this.summaryJobId,
      usageJson: data.usageJson.present ? data.usageJson.value : this.usageJson,
      usageRevision: data.usageRevision.present
          ? data.usageRevision.value
          : this.usageRevision,
      usageComplete: data.usageComplete.present
          ? data.usageComplete.value
          : this.usageComplete,
      contextJson: data.contextJson.present
          ? data.contextJson.value
          : this.contextJson,
      originRequestId: data.originRequestId.present
          ? data.originRequestId.value
          : this.originRequestId,
      isInherited: data.isInherited.present
          ? data.isInherited.value
          : this.isInherited,
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
    return (StringBuffer('ModelRequestRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('runId: $runId, ')
          ..write('logicalTurn: $logicalTurn, ')
          ..write('attemptIndex: $attemptIndex, ')
          ..write('purpose: $purpose, ')
          ..write('status: $status, ')
          ..write('profileId: $profileId, ')
          ..write('protocol: $protocol, ')
          ..write('requestedModelId: $requestedModelId, ')
          ..write('responseModelId: $responseModelId, ')
          ..write('assistantMessageId: $assistantMessageId, ')
          ..write('summaryId: $summaryId, ')
          ..write('summaryJobId: $summaryJobId, ')
          ..write('usageJson: $usageJson, ')
          ..write('usageRevision: $usageRevision, ')
          ..write('usageComplete: $usageComplete, ')
          ..write('contextJson: $contextJson, ')
          ..write('originRequestId: $originRequestId, ')
          ..write('isInherited: $isInherited, ')
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
    conversationId,
    runId,
    logicalTurn,
    attemptIndex,
    purpose,
    status,
    profileId,
    protocol,
    requestedModelId,
    responseModelId,
    assistantMessageId,
    summaryId,
    summaryJobId,
    usageJson,
    usageRevision,
    usageComplete,
    contextJson,
    originRequestId,
    isInherited,
    errorCode,
    createdAt,
    startedAt,
    finishedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelRequestRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.runId == this.runId &&
          other.logicalTurn == this.logicalTurn &&
          other.attemptIndex == this.attemptIndex &&
          other.purpose == this.purpose &&
          other.status == this.status &&
          other.profileId == this.profileId &&
          other.protocol == this.protocol &&
          other.requestedModelId == this.requestedModelId &&
          other.responseModelId == this.responseModelId &&
          other.assistantMessageId == this.assistantMessageId &&
          other.summaryId == this.summaryId &&
          other.summaryJobId == this.summaryJobId &&
          other.usageJson == this.usageJson &&
          other.usageRevision == this.usageRevision &&
          other.usageComplete == this.usageComplete &&
          other.contextJson == this.contextJson &&
          other.originRequestId == this.originRequestId &&
          other.isInherited == this.isInherited &&
          other.errorCode == this.errorCode &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt);
}

class ModelRequestsCompanion extends UpdateCompanion<ModelRequestRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String?> runId;
  final Value<int> logicalTurn;
  final Value<int> attemptIndex;
  final Value<String> purpose;
  final Value<String> status;
  final Value<String> profileId;
  final Value<String> protocol;
  final Value<String> requestedModelId;
  final Value<String?> responseModelId;
  final Value<String?> assistantMessageId;
  final Value<String?> summaryId;
  final Value<String?> summaryJobId;
  final Value<String?> usageJson;
  final Value<int> usageRevision;
  final Value<bool> usageComplete;
  final Value<String> contextJson;
  final Value<String?> originRequestId;
  final Value<bool> isInherited;
  final Value<String?> errorCode;
  final Value<DateTime> createdAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<int> rowid;
  const ModelRequestsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.runId = const Value.absent(),
    this.logicalTurn = const Value.absent(),
    this.attemptIndex = const Value.absent(),
    this.purpose = const Value.absent(),
    this.status = const Value.absent(),
    this.profileId = const Value.absent(),
    this.protocol = const Value.absent(),
    this.requestedModelId = const Value.absent(),
    this.responseModelId = const Value.absent(),
    this.assistantMessageId = const Value.absent(),
    this.summaryId = const Value.absent(),
    this.summaryJobId = const Value.absent(),
    this.usageJson = const Value.absent(),
    this.usageRevision = const Value.absent(),
    this.usageComplete = const Value.absent(),
    this.contextJson = const Value.absent(),
    this.originRequestId = const Value.absent(),
    this.isInherited = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelRequestsCompanion.insert({
    required String id,
    required String conversationId,
    this.runId = const Value.absent(),
    required int logicalTurn,
    required int attemptIndex,
    required String purpose,
    required String status,
    required String profileId,
    required String protocol,
    required String requestedModelId,
    this.responseModelId = const Value.absent(),
    this.assistantMessageId = const Value.absent(),
    this.summaryId = const Value.absent(),
    this.summaryJobId = const Value.absent(),
    this.usageJson = const Value.absent(),
    this.usageRevision = const Value.absent(),
    this.usageComplete = const Value.absent(),
    required String contextJson,
    this.originRequestId = const Value.absent(),
    this.isInherited = const Value.absent(),
    this.errorCode = const Value.absent(),
    required DateTime createdAt,
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       logicalTurn = Value(logicalTurn),
       attemptIndex = Value(attemptIndex),
       purpose = Value(purpose),
       status = Value(status),
       profileId = Value(profileId),
       protocol = Value(protocol),
       requestedModelId = Value(requestedModelId),
       contextJson = Value(contextJson),
       createdAt = Value(createdAt);
  static Insertable<ModelRequestRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? runId,
    Expression<int>? logicalTurn,
    Expression<int>? attemptIndex,
    Expression<String>? purpose,
    Expression<String>? status,
    Expression<String>? profileId,
    Expression<String>? protocol,
    Expression<String>? requestedModelId,
    Expression<String>? responseModelId,
    Expression<String>? assistantMessageId,
    Expression<String>? summaryId,
    Expression<String>? summaryJobId,
    Expression<String>? usageJson,
    Expression<int>? usageRevision,
    Expression<bool>? usageComplete,
    Expression<String>? contextJson,
    Expression<String>? originRequestId,
    Expression<bool>? isInherited,
    Expression<String>? errorCode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (runId != null) 'run_id': runId,
      if (logicalTurn != null) 'logical_turn': logicalTurn,
      if (attemptIndex != null) 'attempt_index': attemptIndex,
      if (purpose != null) 'purpose': purpose,
      if (status != null) 'status': status,
      if (profileId != null) 'profile_id': profileId,
      if (protocol != null) 'protocol': protocol,
      if (requestedModelId != null) 'requested_model_id': requestedModelId,
      if (responseModelId != null) 'response_model_id': responseModelId,
      if (assistantMessageId != null)
        'assistant_message_id': assistantMessageId,
      if (summaryId != null) 'summary_id': summaryId,
      if (summaryJobId != null) 'summary_job_id': summaryJobId,
      if (usageJson != null) 'usage_json': usageJson,
      if (usageRevision != null) 'usage_revision': usageRevision,
      if (usageComplete != null) 'usage_complete': usageComplete,
      if (contextJson != null) 'context_json': contextJson,
      if (originRequestId != null) 'origin_request_id': originRequestId,
      if (isInherited != null) 'is_inherited': isInherited,
      if (errorCode != null) 'error_code': errorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelRequestsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String?>? runId,
    Value<int>? logicalTurn,
    Value<int>? attemptIndex,
    Value<String>? purpose,
    Value<String>? status,
    Value<String>? profileId,
    Value<String>? protocol,
    Value<String>? requestedModelId,
    Value<String?>? responseModelId,
    Value<String?>? assistantMessageId,
    Value<String?>? summaryId,
    Value<String?>? summaryJobId,
    Value<String?>? usageJson,
    Value<int>? usageRevision,
    Value<bool>? usageComplete,
    Value<String>? contextJson,
    Value<String?>? originRequestId,
    Value<bool>? isInherited,
    Value<String?>? errorCode,
    Value<DateTime>? createdAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<int>? rowid,
  }) {
    return ModelRequestsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      runId: runId ?? this.runId,
      logicalTurn: logicalTurn ?? this.logicalTurn,
      attemptIndex: attemptIndex ?? this.attemptIndex,
      purpose: purpose ?? this.purpose,
      status: status ?? this.status,
      profileId: profileId ?? this.profileId,
      protocol: protocol ?? this.protocol,
      requestedModelId: requestedModelId ?? this.requestedModelId,
      responseModelId: responseModelId ?? this.responseModelId,
      assistantMessageId: assistantMessageId ?? this.assistantMessageId,
      summaryId: summaryId ?? this.summaryId,
      summaryJobId: summaryJobId ?? this.summaryJobId,
      usageJson: usageJson ?? this.usageJson,
      usageRevision: usageRevision ?? this.usageRevision,
      usageComplete: usageComplete ?? this.usageComplete,
      contextJson: contextJson ?? this.contextJson,
      originRequestId: originRequestId ?? this.originRequestId,
      isInherited: isInherited ?? this.isInherited,
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
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (logicalTurn.present) {
      map['logical_turn'] = Variable<int>(logicalTurn.value);
    }
    if (attemptIndex.present) {
      map['attempt_index'] = Variable<int>(attemptIndex.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(purpose.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (protocol.present) {
      map['protocol'] = Variable<String>(protocol.value);
    }
    if (requestedModelId.present) {
      map['requested_model_id'] = Variable<String>(requestedModelId.value);
    }
    if (responseModelId.present) {
      map['response_model_id'] = Variable<String>(responseModelId.value);
    }
    if (assistantMessageId.present) {
      map['assistant_message_id'] = Variable<String>(assistantMessageId.value);
    }
    if (summaryId.present) {
      map['summary_id'] = Variable<String>(summaryId.value);
    }
    if (summaryJobId.present) {
      map['summary_job_id'] = Variable<String>(summaryJobId.value);
    }
    if (usageJson.present) {
      map['usage_json'] = Variable<String>(usageJson.value);
    }
    if (usageRevision.present) {
      map['usage_revision'] = Variable<int>(usageRevision.value);
    }
    if (usageComplete.present) {
      map['usage_complete'] = Variable<bool>(usageComplete.value);
    }
    if (contextJson.present) {
      map['context_json'] = Variable<String>(contextJson.value);
    }
    if (originRequestId.present) {
      map['origin_request_id'] = Variable<String>(originRequestId.value);
    }
    if (isInherited.present) {
      map['is_inherited'] = Variable<bool>(isInherited.value);
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
    return (StringBuffer('ModelRequestsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('runId: $runId, ')
          ..write('logicalTurn: $logicalTurn, ')
          ..write('attemptIndex: $attemptIndex, ')
          ..write('purpose: $purpose, ')
          ..write('status: $status, ')
          ..write('profileId: $profileId, ')
          ..write('protocol: $protocol, ')
          ..write('requestedModelId: $requestedModelId, ')
          ..write('responseModelId: $responseModelId, ')
          ..write('assistantMessageId: $assistantMessageId, ')
          ..write('summaryId: $summaryId, ')
          ..write('summaryJobId: $summaryJobId, ')
          ..write('usageJson: $usageJson, ')
          ..write('usageRevision: $usageRevision, ')
          ..write('usageComplete: $usageComplete, ')
          ..write('contextJson: $contextJson, ')
          ..write('originRequestId: $originRequestId, ')
          ..write('isInherited: $isInherited, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsageArchivesTable extends UsageArchives
    with TableInfo<$UsageArchivesTable, UsageArchiveRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageArchivesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceKindMeta = const VerificationMeta(
    'sourceKind',
  );
  @override
  late final GeneratedColumn<String> sourceKind = GeneratedColumn<String>(
    'source_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reportJsonMeta = const VerificationMeta(
    'reportJson',
  );
  @override
  late final GeneratedColumn<String> reportJson = GeneratedColumn<String>(
    'report_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    conversationId,
    sourceKind,
    sourceId,
    reportJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_archives';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageArchiveRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
    if (data.containsKey('source_kind')) {
      context.handle(
        _sourceKindMeta,
        sourceKind.isAcceptableOrUnknown(data['source_kind']!, _sourceKindMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKindMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('report_json')) {
      context.handle(
        _reportJsonMeta,
        reportJson.isAcceptableOrUnknown(data['report_json']!, _reportJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_reportJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    conversationId,
    sourceKind,
    sourceId,
  };
  @override
  UsageArchiveRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageArchiveRow(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      sourceKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_kind'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      reportJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}report_json'],
      )!,
    );
  }

  @override
  $UsageArchivesTable createAlias(String alias) {
    return $UsageArchivesTable(attachedDatabase, alias);
  }
}

class UsageArchiveRow extends DataClass implements Insertable<UsageArchiveRow> {
  final String conversationId;
  final String sourceKind;
  final String sourceId;
  final String reportJson;
  const UsageArchiveRow({
    required this.conversationId,
    required this.sourceKind,
    required this.sourceId,
    required this.reportJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['source_kind'] = Variable<String>(sourceKind);
    map['source_id'] = Variable<String>(sourceId);
    map['report_json'] = Variable<String>(reportJson);
    return map;
  }

  UsageArchivesCompanion toCompanion(bool nullToAbsent) {
    return UsageArchivesCompanion(
      conversationId: Value(conversationId),
      sourceKind: Value(sourceKind),
      sourceId: Value(sourceId),
      reportJson: Value(reportJson),
    );
  }

  factory UsageArchiveRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageArchiveRow(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      sourceKind: serializer.fromJson<String>(json['sourceKind']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      reportJson: serializer.fromJson<String>(json['reportJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'sourceKind': serializer.toJson<String>(sourceKind),
      'sourceId': serializer.toJson<String>(sourceId),
      'reportJson': serializer.toJson<String>(reportJson),
    };
  }

  UsageArchiveRow copyWith({
    String? conversationId,
    String? sourceKind,
    String? sourceId,
    String? reportJson,
  }) => UsageArchiveRow(
    conversationId: conversationId ?? this.conversationId,
    sourceKind: sourceKind ?? this.sourceKind,
    sourceId: sourceId ?? this.sourceId,
    reportJson: reportJson ?? this.reportJson,
  );
  UsageArchiveRow copyWithCompanion(UsageArchivesCompanion data) {
    return UsageArchiveRow(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      sourceKind: data.sourceKind.present
          ? data.sourceKind.value
          : this.sourceKind,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      reportJson: data.reportJson.present
          ? data.reportJson.value
          : this.reportJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageArchiveRow(')
          ..write('conversationId: $conversationId, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceId: $sourceId, ')
          ..write('reportJson: $reportJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(conversationId, sourceKind, sourceId, reportJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageArchiveRow &&
          other.conversationId == this.conversationId &&
          other.sourceKind == this.sourceKind &&
          other.sourceId == this.sourceId &&
          other.reportJson == this.reportJson);
}

class UsageArchivesCompanion extends UpdateCompanion<UsageArchiveRow> {
  final Value<String> conversationId;
  final Value<String> sourceKind;
  final Value<String> sourceId;
  final Value<String> reportJson;
  final Value<int> rowid;
  const UsageArchivesCompanion({
    this.conversationId = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.reportJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsageArchivesCompanion.insert({
    required String conversationId,
    required String sourceKind,
    required String sourceId,
    required String reportJson,
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       sourceKind = Value(sourceKind),
       sourceId = Value(sourceId),
       reportJson = Value(reportJson);
  static Insertable<UsageArchiveRow> custom({
    Expression<String>? conversationId,
    Expression<String>? sourceKind,
    Expression<String>? sourceId,
    Expression<String>? reportJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (sourceKind != null) 'source_kind': sourceKind,
      if (sourceId != null) 'source_id': sourceId,
      if (reportJson != null) 'report_json': reportJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsageArchivesCompanion copyWith({
    Value<String>? conversationId,
    Value<String>? sourceKind,
    Value<String>? sourceId,
    Value<String>? reportJson,
    Value<int>? rowid,
  }) {
    return UsageArchivesCompanion(
      conversationId: conversationId ?? this.conversationId,
      sourceKind: sourceKind ?? this.sourceKind,
      sourceId: sourceId ?? this.sourceId,
      reportJson: reportJson ?? this.reportJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (sourceKind.present) {
      map['source_kind'] = Variable<String>(sourceKind.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (reportJson.present) {
      map['report_json'] = Variable<String>(reportJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageArchivesCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceId: $sourceId, ')
          ..write('reportJson: $reportJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentPlansTable extends AgentPlans
    with TableInfo<$AgentPlansTable, AgentPlanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _sourceRunIdMeta = const VerificationMeta(
    'sourceRunId',
  );
  @override
  late final GeneratedColumn<String> sourceRunId = GeneratedColumn<String>(
    'source_run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMessageIdMeta = const VerificationMeta(
    'sourceMessageId',
  );
  @override
  late final GeneratedColumn<String> sourceMessageId = GeneratedColumn<String>(
    'source_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepsJsonMeta = const VerificationMeta(
    'stepsJson',
  );
  @override
  late final GeneratedColumn<String> stepsJson = GeneratedColumn<String>(
    'steps_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _executionRunIdMeta = const VerificationMeta(
    'executionRunId',
  );
  @override
  late final GeneratedColumn<String> executionRunId = GeneratedColumn<String>(
    'execution_run_id',
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
    revision,
    conversationId,
    sourceRunId,
    sourceMessageId,
    title,
    stepsJson,
    status,
    executionRunId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentPlanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
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
    if (data.containsKey('source_run_id')) {
      context.handle(
        _sourceRunIdMeta,
        sourceRunId.isAcceptableOrUnknown(
          data['source_run_id']!,
          _sourceRunIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceRunIdMeta);
    }
    if (data.containsKey('source_message_id')) {
      context.handle(
        _sourceMessageIdMeta,
        sourceMessageId.isAcceptableOrUnknown(
          data['source_message_id']!,
          _sourceMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceMessageIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('steps_json')) {
      context.handle(
        _stepsJsonMeta,
        stepsJson.isAcceptableOrUnknown(data['steps_json']!, _stepsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('execution_run_id')) {
      context.handle(
        _executionRunIdMeta,
        executionRunId.isAcceptableOrUnknown(
          data['execution_run_id']!,
          _executionRunIdMeta,
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
  Set<GeneratedColumn> get $primaryKey => {id, revision};
  @override
  AgentPlanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentPlanRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      sourceRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_run_id'],
      )!,
      sourceMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_message_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      stepsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steps_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      executionRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}execution_run_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AgentPlansTable createAlias(String alias) {
    return $AgentPlansTable(attachedDatabase, alias);
  }
}

class AgentPlanRow extends DataClass implements Insertable<AgentPlanRow> {
  final String id;
  final int revision;
  final String conversationId;
  final String sourceRunId;
  final String sourceMessageId;
  final String title;
  final String stepsJson;
  final String status;
  final String? executionRunId;
  final DateTime createdAt;
  const AgentPlanRow({
    required this.id,
    required this.revision,
    required this.conversationId,
    required this.sourceRunId,
    required this.sourceMessageId,
    required this.title,
    required this.stepsJson,
    required this.status,
    this.executionRunId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['revision'] = Variable<int>(revision);
    map['conversation_id'] = Variable<String>(conversationId);
    map['source_run_id'] = Variable<String>(sourceRunId);
    map['source_message_id'] = Variable<String>(sourceMessageId);
    map['title'] = Variable<String>(title);
    map['steps_json'] = Variable<String>(stepsJson);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || executionRunId != null) {
      map['execution_run_id'] = Variable<String>(executionRunId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AgentPlansCompanion toCompanion(bool nullToAbsent) {
    return AgentPlansCompanion(
      id: Value(id),
      revision: Value(revision),
      conversationId: Value(conversationId),
      sourceRunId: Value(sourceRunId),
      sourceMessageId: Value(sourceMessageId),
      title: Value(title),
      stepsJson: Value(stepsJson),
      status: Value(status),
      executionRunId: executionRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(executionRunId),
      createdAt: Value(createdAt),
    );
  }

  factory AgentPlanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentPlanRow(
      id: serializer.fromJson<String>(json['id']),
      revision: serializer.fromJson<int>(json['revision']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      sourceRunId: serializer.fromJson<String>(json['sourceRunId']),
      sourceMessageId: serializer.fromJson<String>(json['sourceMessageId']),
      title: serializer.fromJson<String>(json['title']),
      stepsJson: serializer.fromJson<String>(json['stepsJson']),
      status: serializer.fromJson<String>(json['status']),
      executionRunId: serializer.fromJson<String?>(json['executionRunId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'revision': serializer.toJson<int>(revision),
      'conversationId': serializer.toJson<String>(conversationId),
      'sourceRunId': serializer.toJson<String>(sourceRunId),
      'sourceMessageId': serializer.toJson<String>(sourceMessageId),
      'title': serializer.toJson<String>(title),
      'stepsJson': serializer.toJson<String>(stepsJson),
      'status': serializer.toJson<String>(status),
      'executionRunId': serializer.toJson<String?>(executionRunId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AgentPlanRow copyWith({
    String? id,
    int? revision,
    String? conversationId,
    String? sourceRunId,
    String? sourceMessageId,
    String? title,
    String? stepsJson,
    String? status,
    Value<String?> executionRunId = const Value.absent(),
    DateTime? createdAt,
  }) => AgentPlanRow(
    id: id ?? this.id,
    revision: revision ?? this.revision,
    conversationId: conversationId ?? this.conversationId,
    sourceRunId: sourceRunId ?? this.sourceRunId,
    sourceMessageId: sourceMessageId ?? this.sourceMessageId,
    title: title ?? this.title,
    stepsJson: stepsJson ?? this.stepsJson,
    status: status ?? this.status,
    executionRunId: executionRunId.present
        ? executionRunId.value
        : this.executionRunId,
    createdAt: createdAt ?? this.createdAt,
  );
  AgentPlanRow copyWithCompanion(AgentPlansCompanion data) {
    return AgentPlanRow(
      id: data.id.present ? data.id.value : this.id,
      revision: data.revision.present ? data.revision.value : this.revision,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      sourceRunId: data.sourceRunId.present
          ? data.sourceRunId.value
          : this.sourceRunId,
      sourceMessageId: data.sourceMessageId.present
          ? data.sourceMessageId.value
          : this.sourceMessageId,
      title: data.title.present ? data.title.value : this.title,
      stepsJson: data.stepsJson.present ? data.stepsJson.value : this.stepsJson,
      status: data.status.present ? data.status.value : this.status,
      executionRunId: data.executionRunId.present
          ? data.executionRunId.value
          : this.executionRunId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentPlanRow(')
          ..write('id: $id, ')
          ..write('revision: $revision, ')
          ..write('conversationId: $conversationId, ')
          ..write('sourceRunId: $sourceRunId, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('title: $title, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('status: $status, ')
          ..write('executionRunId: $executionRunId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    revision,
    conversationId,
    sourceRunId,
    sourceMessageId,
    title,
    stepsJson,
    status,
    executionRunId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentPlanRow &&
          other.id == this.id &&
          other.revision == this.revision &&
          other.conversationId == this.conversationId &&
          other.sourceRunId == this.sourceRunId &&
          other.sourceMessageId == this.sourceMessageId &&
          other.title == this.title &&
          other.stepsJson == this.stepsJson &&
          other.status == this.status &&
          other.executionRunId == this.executionRunId &&
          other.createdAt == this.createdAt);
}

class AgentPlansCompanion extends UpdateCompanion<AgentPlanRow> {
  final Value<String> id;
  final Value<int> revision;
  final Value<String> conversationId;
  final Value<String> sourceRunId;
  final Value<String> sourceMessageId;
  final Value<String> title;
  final Value<String> stepsJson;
  final Value<String> status;
  final Value<String?> executionRunId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AgentPlansCompanion({
    this.id = const Value.absent(),
    this.revision = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.sourceRunId = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    this.title = const Value.absent(),
    this.stepsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.executionRunId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentPlansCompanion.insert({
    required String id,
    required int revision,
    required String conversationId,
    required String sourceRunId,
    required String sourceMessageId,
    required String title,
    required String stepsJson,
    required String status,
    this.executionRunId = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       revision = Value(revision),
       conversationId = Value(conversationId),
       sourceRunId = Value(sourceRunId),
       sourceMessageId = Value(sourceMessageId),
       title = Value(title),
       stepsJson = Value(stepsJson),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<AgentPlanRow> custom({
    Expression<String>? id,
    Expression<int>? revision,
    Expression<String>? conversationId,
    Expression<String>? sourceRunId,
    Expression<String>? sourceMessageId,
    Expression<String>? title,
    Expression<String>? stepsJson,
    Expression<String>? status,
    Expression<String>? executionRunId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (revision != null) 'revision': revision,
      if (conversationId != null) 'conversation_id': conversationId,
      if (sourceRunId != null) 'source_run_id': sourceRunId,
      if (sourceMessageId != null) 'source_message_id': sourceMessageId,
      if (title != null) 'title': title,
      if (stepsJson != null) 'steps_json': stepsJson,
      if (status != null) 'status': status,
      if (executionRunId != null) 'execution_run_id': executionRunId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentPlansCompanion copyWith({
    Value<String>? id,
    Value<int>? revision,
    Value<String>? conversationId,
    Value<String>? sourceRunId,
    Value<String>? sourceMessageId,
    Value<String>? title,
    Value<String>? stepsJson,
    Value<String>? status,
    Value<String?>? executionRunId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AgentPlansCompanion(
      id: id ?? this.id,
      revision: revision ?? this.revision,
      conversationId: conversationId ?? this.conversationId,
      sourceRunId: sourceRunId ?? this.sourceRunId,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      title: title ?? this.title,
      stepsJson: stepsJson ?? this.stepsJson,
      status: status ?? this.status,
      executionRunId: executionRunId ?? this.executionRunId,
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
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (sourceRunId.present) {
      map['source_run_id'] = Variable<String>(sourceRunId.value);
    }
    if (sourceMessageId.present) {
      map['source_message_id'] = Variable<String>(sourceMessageId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (stepsJson.present) {
      map['steps_json'] = Variable<String>(stepsJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (executionRunId.present) {
      map['execution_run_id'] = Variable<String>(executionRunId.value);
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
    return (StringBuffer('AgentPlansCompanion(')
          ..write('id: $id, ')
          ..write('revision: $revision, ')
          ..write('conversationId: $conversationId, ')
          ..write('sourceRunId: $sourceRunId, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('title: $title, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('status: $status, ')
          ..write('executionRunId: $executionRunId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryEntriesTable extends MemoryEntries
    with TableInfo<$MemoryEntriesTable, MemoryEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceMessageIdMeta = const VerificationMeta(
    'sourceMessageId',
  );
  @override
  late final GeneratedColumn<String> sourceMessageId = GeneratedColumn<String>(
    'source_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceRunIdMeta = const VerificationMeta(
    'sourceRunId',
  );
  @override
  late final GeneratedColumn<String> sourceRunId = GeneratedColumn<String>(
    'source_run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    sourceMessageId,
    sourceRunId,
    content,
    enabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryEntryRow> instance, {
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
    if (data.containsKey('source_message_id')) {
      context.handle(
        _sourceMessageIdMeta,
        sourceMessageId.isAcceptableOrUnknown(
          data['source_message_id']!,
          _sourceMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('source_run_id')) {
      context.handle(
        _sourceRunIdMeta,
        sourceRunId.isAcceptableOrUnknown(
          data['source_run_id']!,
          _sourceRunIdMeta,
        ),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
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
  MemoryEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      assistantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assistant_id'],
      ),
      sourceMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_message_id'],
      ),
      sourceRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_run_id'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
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
  $MemoryEntriesTable createAlias(String alias) {
    return $MemoryEntriesTable(attachedDatabase, alias);
  }
}

class MemoryEntryRow extends DataClass implements Insertable<MemoryEntryRow> {
  final String id;
  final String? assistantId;
  final String? sourceMessageId;
  final String? sourceRunId;
  final String content;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MemoryEntryRow({
    required this.id,
    this.assistantId,
    this.sourceMessageId,
    this.sourceRunId,
    required this.content,
    required this.enabled,
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
    if (!nullToAbsent || sourceMessageId != null) {
      map['source_message_id'] = Variable<String>(sourceMessageId);
    }
    if (!nullToAbsent || sourceRunId != null) {
      map['source_run_id'] = Variable<String>(sourceRunId);
    }
    map['content'] = Variable<String>(content);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MemoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return MemoryEntriesCompanion(
      id: Value(id),
      assistantId: assistantId == null && nullToAbsent
          ? const Value.absent()
          : Value(assistantId),
      sourceMessageId: sourceMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMessageId),
      sourceRunId: sourceRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRunId),
      content: Value(content),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MemoryEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryEntryRow(
      id: serializer.fromJson<String>(json['id']),
      assistantId: serializer.fromJson<String?>(json['assistantId']),
      sourceMessageId: serializer.fromJson<String?>(json['sourceMessageId']),
      sourceRunId: serializer.fromJson<String?>(json['sourceRunId']),
      content: serializer.fromJson<String>(json['content']),
      enabled: serializer.fromJson<bool>(json['enabled']),
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
      'sourceMessageId': serializer.toJson<String?>(sourceMessageId),
      'sourceRunId': serializer.toJson<String?>(sourceRunId),
      'content': serializer.toJson<String>(content),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MemoryEntryRow copyWith({
    String? id,
    Value<String?> assistantId = const Value.absent(),
    Value<String?> sourceMessageId = const Value.absent(),
    Value<String?> sourceRunId = const Value.absent(),
    String? content,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MemoryEntryRow(
    id: id ?? this.id,
    assistantId: assistantId.present ? assistantId.value : this.assistantId,
    sourceMessageId: sourceMessageId.present
        ? sourceMessageId.value
        : this.sourceMessageId,
    sourceRunId: sourceRunId.present ? sourceRunId.value : this.sourceRunId,
    content: content ?? this.content,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MemoryEntryRow copyWithCompanion(MemoryEntriesCompanion data) {
    return MemoryEntryRow(
      id: data.id.present ? data.id.value : this.id,
      assistantId: data.assistantId.present
          ? data.assistantId.value
          : this.assistantId,
      sourceMessageId: data.sourceMessageId.present
          ? data.sourceMessageId.value
          : this.sourceMessageId,
      sourceRunId: data.sourceRunId.present
          ? data.sourceRunId.value
          : this.sourceRunId,
      content: data.content.present ? data.content.value : this.content,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEntryRow(')
          ..write('id: $id, ')
          ..write('assistantId: $assistantId, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('sourceRunId: $sourceRunId, ')
          ..write('content: $content, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    assistantId,
    sourceMessageId,
    sourceRunId,
    content,
    enabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryEntryRow &&
          other.id == this.id &&
          other.assistantId == this.assistantId &&
          other.sourceMessageId == this.sourceMessageId &&
          other.sourceRunId == this.sourceRunId &&
          other.content == this.content &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MemoryEntriesCompanion extends UpdateCompanion<MemoryEntryRow> {
  final Value<String> id;
  final Value<String?> assistantId;
  final Value<String?> sourceMessageId;
  final Value<String?> sourceRunId;
  final Value<String> content;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MemoryEntriesCompanion({
    this.id = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    this.sourceRunId = const Value.absent(),
    this.content = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryEntriesCompanion.insert({
    required String id,
    this.assistantId = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    this.sourceRunId = const Value.absent(),
    required String content,
    this.enabled = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       content = Value(content),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MemoryEntryRow> custom({
    Expression<String>? id,
    Expression<String>? assistantId,
    Expression<String>? sourceMessageId,
    Expression<String>? sourceRunId,
    Expression<String>? content,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assistantId != null) 'assistant_id': assistantId,
      if (sourceMessageId != null) 'source_message_id': sourceMessageId,
      if (sourceRunId != null) 'source_run_id': sourceRunId,
      if (content != null) 'content': content,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryEntriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? assistantId,
    Value<String?>? sourceMessageId,
    Value<String?>? sourceRunId,
    Value<String>? content,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MemoryEntriesCompanion(
      id: id ?? this.id,
      assistantId: assistantId ?? this.assistantId,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      sourceRunId: sourceRunId ?? this.sourceRunId,
      content: content ?? this.content,
      enabled: enabled ?? this.enabled,
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
    if (sourceMessageId.present) {
      map['source_message_id'] = Variable<String>(sourceMessageId.value);
    }
    if (sourceRunId.present) {
      map['source_run_id'] = Variable<String>(sourceRunId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
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
    return (StringBuffer('MemoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('assistantId: $assistantId, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('sourceRunId: $sourceRunId, ')
          ..write('content: $content, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
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
  late final $WorkspacesTable workspaces = $WorkspacesTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $AgentRunsTable agentRuns = $AgentRunsTable(this);
  late final $ToolCallsTable toolCalls = $ToolCallsTable(this);
  late final $McpServersTable mcpServers = $McpServersTable(this);
  late final $SkillInstallationsTable skillInstallations =
      $SkillInstallationsTable(this);
  late final $RuntimeEnvironmentsTable runtimeEnvironments =
      $RuntimeEnvironmentsTable(this);
  late final $WorkspaceCopiesTable workspaceCopies = $WorkspaceCopiesTable(
    this,
  );
  late final $ContextSummariesTable contextSummaries = $ContextSummariesTable(
    this,
  );
  late final $ModelRequestsTable modelRequests = $ModelRequestsTable(this);
  late final $UsageArchivesTable usageArchives = $UsageArchivesTable(this);
  late final $AgentPlansTable agentPlans = $AgentPlansTable(this);
  late final $MemoryEntriesTable memoryEntries = $MemoryEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    providerProfiles,
    models,
    assistants,
    workspaces,
    conversations,
    messages,
    attachments,
    agentRuns,
    toolCalls,
    mcpServers,
    skillInstallations,
    runtimeEnvironments,
    workspaceCopies,
    contextSummaries,
    modelRequests,
    usageArchives,
    agentPlans,
    memoryEntries,
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
        'workspaces',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('conversations', kind: UpdateKind.update)],
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workspaces',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workspace_copies', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('context_summaries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('model_requests', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('usage_archives', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('agent_plans', kind: UpdateKind.delete)],
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
  Value<String> mcpToolNamesJson,
  Value<String> memoryScope,
  Value<String> skillIdsJson,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$AssistantsTableUpdateCompanionBuilder = AssistantsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> systemPrompt,
  Value<String?> defaultSelectionJson,
  Value<String> mcpToolNamesJson,
  Value<String> memoryScope,
  Value<String> skillIdsJson,
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

  ColumnFilters<String> get mcpToolNamesJson => $composableBuilder(
    column: $table.mcpToolNamesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memoryScope => $composableBuilder(
    column: $table.memoryScope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skillIdsJson => $composableBuilder(
    column: $table.skillIdsJson,
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

  ColumnOrderings<String> get mcpToolNamesJson => $composableBuilder(
    column: $table.mcpToolNamesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memoryScope => $composableBuilder(
    column: $table.memoryScope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skillIdsJson => $composableBuilder(
    column: $table.skillIdsJson,
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

  GeneratedColumn<String> get mcpToolNamesJson => $composableBuilder(
    column: $table.mcpToolNamesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memoryScope => $composableBuilder(
    column: $table.memoryScope,
    builder: (column) => column,
  );

  GeneratedColumn<String> get skillIdsJson => $composableBuilder(
    column: $table.skillIdsJson,
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
                Value<String> mcpToolNamesJson = const Value.absent(),
                Value<String> memoryScope = const Value.absent(),
                Value<String> skillIdsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantsCompanion(
                id: id,
                name: name,
                systemPrompt: systemPrompt,
                defaultSelectionJson: defaultSelectionJson,
                mcpToolNamesJson: mcpToolNamesJson,
                memoryScope: memoryScope,
                skillIdsJson: skillIdsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> systemPrompt = const Value.absent(),
                Value<String?> defaultSelectionJson = const Value.absent(),
                Value<String> mcpToolNamesJson = const Value.absent(),
                Value<String> memoryScope = const Value.absent(),
                Value<String> skillIdsJson = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AssistantsCompanion.insert(
                id: id,
                name: name,
                systemPrompt: systemPrompt,
                defaultSelectionJson: defaultSelectionJson,
                mcpToolNamesJson: mcpToolNamesJson,
                memoryScope: memoryScope,
                skillIdsJson: skillIdsJson,
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
typedef $$WorkspacesTableCreateCompanionBuilder = WorkspacesCompanion Function({
  required String id,
  required String name,
  required String environmentId,
  Value<bool> deleting,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$WorkspacesTableUpdateCompanionBuilder = WorkspacesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> environmentId,
  Value<bool> deleting,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$WorkspacesTableReferences
    extends BaseReferences<_$AppDatabase, $WorkspacesTable, WorkspaceRow> {
  $$WorkspacesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ConversationsTable, List<ConversationRow>>
  _conversationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.conversations,
    aliasName: 'workspaces__id__conversations__workspace_id',
  );

  $$ConversationsTableProcessedTableManager get conversationsRefs {
    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.workspaceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_conversationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorkspaceCopiesTable, List<WorkspaceCopyRow>>
  _workspaceCopiesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workspaceCopies,
    aliasName: 'workspaces__id__workspace_copies__workspace_id',
  );

  $$WorkspaceCopiesTableProcessedTableManager get workspaceCopiesRefs {
    final manager = $$WorkspaceCopiesTableTableManager(
      $_db,
      $_db.workspaceCopies,
    ).filter((f) => f.workspaceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workspaceCopiesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkspacesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkspacesTable> {
  $$WorkspacesTableFilterComposer({
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

  ColumnFilters<String> get environmentId => $composableBuilder(
    column: $table.environmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleting => $composableBuilder(
    column: $table.deleting,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> conversationsRefs(
    Expression<bool> Function($$ConversationsTableFilterComposer f) f,
  ) {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.workspaceId,
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
    return f(composer);
  }

  Expression<bool> workspaceCopiesRefs(
    Expression<bool> Function($$WorkspaceCopiesTableFilterComposer f) f,
  ) {
    final $$WorkspaceCopiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workspaceCopies,
      getReferencedColumn: (t) => t.workspaceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspaceCopiesTableFilterComposer(
            $db: $db,
            $table: $db.workspaceCopies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkspacesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkspacesTable> {
  $$WorkspacesTableOrderingComposer({
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

  ColumnOrderings<String> get environmentId => $composableBuilder(
    column: $table.environmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleting => $composableBuilder(
    column: $table.deleting,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkspacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkspacesTable> {
  $$WorkspacesTableAnnotationComposer({
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

  GeneratedColumn<String> get environmentId => $composableBuilder(
    column: $table.environmentId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleting =>
      $composableBuilder(column: $table.deleting, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> conversationsRefs<T extends Object>(
    Expression<T> Function($$ConversationsTableAnnotationComposer a) f,
  ) {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.workspaceId,
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
    return f(composer);
  }

  Expression<T> workspaceCopiesRefs<T extends Object>(
    Expression<T> Function($$WorkspaceCopiesTableAnnotationComposer a) f,
  ) {
    final $$WorkspaceCopiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workspaceCopies,
      getReferencedColumn: (t) => t.workspaceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspaceCopiesTableAnnotationComposer(
            $db: $db,
            $table: $db.workspaceCopies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkspacesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkspacesTable,
          WorkspaceRow,
          $$WorkspacesTableFilterComposer,
          $$WorkspacesTableOrderingComposer,
          $$WorkspacesTableAnnotationComposer,
          $$WorkspacesTableCreateCompanionBuilder,
          $$WorkspacesTableUpdateCompanionBuilder,
          (WorkspaceRow, $$WorkspacesTableReferences),
          WorkspaceRow,
          PrefetchHooks Function({
            bool conversationsRefs,
            bool workspaceCopiesRefs,
          })
        > {
  $$WorkspacesTableTableManager(_$AppDatabase db, $WorkspacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkspacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkspacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkspacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> environmentId = const Value.absent(),
                Value<bool> deleting = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkspacesCompanion(
                id: id,
                name: name,
                environmentId: environmentId,
                deleting: deleting,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String environmentId,
                Value<bool> deleting = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkspacesCompanion.insert(
                id: id,
                name: name,
                environmentId: environmentId,
                deleting: deleting,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkspacesTable, WorkspaceRow>(table),
                  $$WorkspacesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({conversationsRefs = false, workspaceCopiesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (conversationsRefs) db.conversations,
                    if (workspaceCopiesRefs) db.workspaceCopies,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (conversationsRefs)
                        await $_getPrefetchedData<
                          WorkspaceRow,
                          $WorkspacesTable,
                          ConversationRow
                        >(
                          currentTable: table,
                          referencedTable: $$WorkspacesTableReferences
                              ._conversationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkspacesTableReferences(
                                db,
                                table,
                                p0,
                              ).conversationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workspaceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workspaceCopiesRefs)
                        await $_getPrefetchedData<
                          WorkspaceRow,
                          $WorkspacesTable,
                          WorkspaceCopyRow
                        >(
                          currentTable: table,
                          referencedTable: $$WorkspacesTableReferences
                              ._workspaceCopiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkspacesTableReferences(
                                db,
                                table,
                                p0,
                              ).workspaceCopiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workspaceId == item.id,
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

typedef $$WorkspacesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkspacesTable,
      WorkspaceRow,
      $$WorkspacesTableFilterComposer,
      $$WorkspacesTableOrderingComposer,
      $$WorkspacesTableAnnotationComposer,
      $$WorkspacesTableCreateCompanionBuilder,
      $$WorkspacesTableUpdateCompanionBuilder,
      (WorkspaceRow, $$WorkspacesTableReferences),
      WorkspaceRow,
      PrefetchHooks Function({bool conversationsRefs, bool workspaceCopiesRefs})
    >;
typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String?> workspaceId,
      required String id,
      Value<String?> assistantId,
      required String title,
      Value<String?> currentMessageId,
      Value<String?> selectionJson,
      Value<PermissionMode> permissionMode,
      Value<PermissionMode> lastExecutionMode,
      Value<bool> pinned,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String?> workspaceId,
      Value<String> id,
      Value<String?> assistantId,
      Value<String> title,
      Value<String?> currentMessageId,
      Value<String?> selectionJson,
      Value<PermissionMode> permissionMode,
      Value<PermissionMode> lastExecutionMode,
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

  static $WorkspacesTable _workspaceIdTable(_$AppDatabase db) =>
      db.workspaces.createAlias('conversations__workspace_id__workspaces__id');

  $$WorkspacesTableProcessedTableManager? get workspaceId {
    final $_column = $_itemColumn<String>('workspace_id');
    if ($_column == null) return null;
    final manager = $$WorkspacesTableTableManager(
      $_db,
      $_db.workspaces,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workspaceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

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

  static MultiTypedResultKey<$ContextSummariesTable, List<ContextSummaryRow>>
  _contextSummariesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.contextSummaries,
    aliasName: 'conversations__id__context_summaries__conversation_id',
  );

  $$ContextSummariesTableProcessedTableManager get contextSummariesRefs {
    final manager = $$ContextSummariesTableTableManager(
      $_db,
      $_db.contextSummaries,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _contextSummariesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ModelRequestsTable, List<ModelRequestRow>>
  _modelRequestsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.modelRequests,
    aliasName: 'conversations__id__model_requests__conversation_id',
  );

  $$ModelRequestsTableProcessedTableManager get modelRequestsRefs {
    final manager = $$ModelRequestsTableTableManager(
      $_db,
      $_db.modelRequests,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_modelRequestsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UsageArchivesTable, List<UsageArchiveRow>>
  _usageArchivesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.usageArchives,
    aliasName: 'conversations__id__usage_archives__conversation_id',
  );

  $$UsageArchivesTableProcessedTableManager get usageArchivesRefs {
    final manager = $$UsageArchivesTableTableManager(
      $_db,
      $_db.usageArchives,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_usageArchivesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AgentPlansTable, List<AgentPlanRow>>
  _agentPlansRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.agentPlans,
    aliasName: 'conversations__id__agent_plans__conversation_id',
  );

  $$AgentPlansTableProcessedTableManager get agentPlansRefs {
    final manager = $$AgentPlansTableTableManager(
      $_db,
      $_db.agentPlans,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_agentPlansRefsTable($_db));
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

  ColumnWithTypeConverterFilters<PermissionMode, PermissionMode, String>
  get permissionMode => $composableBuilder(
    column: $table.permissionMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<PermissionMode, PermissionMode, String>
  get lastExecutionMode => $composableBuilder(
    column: $table.lastExecutionMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
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

  $$WorkspacesTableFilterComposer get workspaceId {
    final $$WorkspacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspaceId,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableFilterComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

  Expression<bool> contextSummariesRefs(
    Expression<bool> Function($$ContextSummariesTableFilterComposer f) f,
  ) {
    final $$ContextSummariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contextSummaries,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContextSummariesTableFilterComposer(
            $db: $db,
            $table: $db.contextSummaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> modelRequestsRefs(
    Expression<bool> Function($$ModelRequestsTableFilterComposer f) f,
  ) {
    final $$ModelRequestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.modelRequests,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelRequestsTableFilterComposer(
            $db: $db,
            $table: $db.modelRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> usageArchivesRefs(
    Expression<bool> Function($$UsageArchivesTableFilterComposer f) f,
  ) {
    final $$UsageArchivesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.usageArchives,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsageArchivesTableFilterComposer(
            $db: $db,
            $table: $db.usageArchives,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> agentPlansRefs(
    Expression<bool> Function($$AgentPlansTableFilterComposer f) f,
  ) {
    final $$AgentPlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.agentPlans,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPlansTableFilterComposer(
            $db: $db,
            $table: $db.agentPlans,
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

  ColumnOrderings<String> get permissionMode => $composableBuilder(
    column: $table.permissionMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastExecutionMode => $composableBuilder(
    column: $table.lastExecutionMode,
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

  $$WorkspacesTableOrderingComposer get workspaceId {
    final $$WorkspacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspaceId,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableOrderingComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  GeneratedColumnWithTypeConverter<PermissionMode, String> get permissionMode =>
      $composableBuilder(
        column: $table.permissionMode,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<PermissionMode, String>
  get lastExecutionMode => $composableBuilder(
    column: $table.lastExecutionMode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$WorkspacesTableAnnotationComposer get workspaceId {
    final $$WorkspacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspaceId,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableAnnotationComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

  Expression<T> contextSummariesRefs<T extends Object>(
    Expression<T> Function($$ContextSummariesTableAnnotationComposer a) f,
  ) {
    final $$ContextSummariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contextSummaries,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContextSummariesTableAnnotationComposer(
            $db: $db,
            $table: $db.contextSummaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> modelRequestsRefs<T extends Object>(
    Expression<T> Function($$ModelRequestsTableAnnotationComposer a) f,
  ) {
    final $$ModelRequestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.modelRequests,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelRequestsTableAnnotationComposer(
            $db: $db,
            $table: $db.modelRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> usageArchivesRefs<T extends Object>(
    Expression<T> Function($$UsageArchivesTableAnnotationComposer a) f,
  ) {
    final $$UsageArchivesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.usageArchives,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsageArchivesTableAnnotationComposer(
            $db: $db,
            $table: $db.usageArchives,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> agentPlansRefs<T extends Object>(
    Expression<T> Function($$AgentPlansTableAnnotationComposer a) f,
  ) {
    final $$AgentPlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.agentPlans,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPlansTableAnnotationComposer(
            $db: $db,
            $table: $db.agentPlans,
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
            bool workspaceId,
            bool messagesRefs,
            bool attachmentsRefs,
            bool agentRunsRefs,
            bool contextSummariesRefs,
            bool modelRequestsRefs,
            bool usageArchivesRefs,
            bool agentPlansRefs,
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
                Value<String?> workspaceId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> assistantId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> currentMessageId = const Value.absent(),
                Value<String?> selectionJson = const Value.absent(),
                Value<PermissionMode> permissionMode = const Value.absent(),
                Value<PermissionMode> lastExecutionMode = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                workspaceId: workspaceId,
                id: id,
                assistantId: assistantId,
                title: title,
                currentMessageId: currentMessageId,
                selectionJson: selectionJson,
                permissionMode: permissionMode,
                lastExecutionMode: lastExecutionMode,
                pinned: pinned,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> workspaceId = const Value.absent(),
                required String id,
                Value<String?> assistantId = const Value.absent(),
                required String title,
                Value<String?> currentMessageId = const Value.absent(),
                Value<String?> selectionJson = const Value.absent(),
                Value<PermissionMode> permissionMode = const Value.absent(),
                Value<PermissionMode> lastExecutionMode = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                workspaceId: workspaceId,
                id: id,
                assistantId: assistantId,
                title: title,
                currentMessageId: currentMessageId,
                selectionJson: selectionJson,
                permissionMode: permissionMode,
                lastExecutionMode: lastExecutionMode,
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
                workspaceId = false,
                messagesRefs = false,
                attachmentsRefs = false,
                agentRunsRefs = false,
                contextSummariesRefs = false,
                modelRequestsRefs = false,
                usageArchivesRefs = false,
                agentPlansRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (messagesRefs) db.messages,
                    if (attachmentsRefs) db.attachments,
                    if (agentRunsRefs) db.agentRuns,
                    if (contextSummariesRefs) db.contextSummaries,
                    if (modelRequestsRefs) db.modelRequests,
                    if (usageArchivesRefs) db.usageArchives,
                    if (agentPlansRefs) db.agentPlans,
                  ],
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
                        if (workspaceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.workspaceId,
                            referencedTable: $$ConversationsTableReferences
                                ._workspaceIdTable(db),
                            referencedColumn: $$ConversationsTableReferences
                                ._workspaceIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
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
                      if (contextSummariesRefs)
                        await $_getPrefetchedData<
                          ConversationRow,
                          $ConversationsTable,
                          ContextSummaryRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationsTableReferences
                              ._contextSummariesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationsTableReferences(
                                db,
                                table,
                                p0,
                              ).contextSummariesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.conversationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (modelRequestsRefs)
                        await $_getPrefetchedData<
                          ConversationRow,
                          $ConversationsTable,
                          ModelRequestRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationsTableReferences
                              ._modelRequestsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationsTableReferences(
                                db,
                                table,
                                p0,
                              ).modelRequestsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.conversationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (usageArchivesRefs)
                        await $_getPrefetchedData<
                          ConversationRow,
                          $ConversationsTable,
                          UsageArchiveRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationsTableReferences
                              ._usageArchivesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationsTableReferences(
                                db,
                                table,
                                p0,
                              ).usageArchivesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.conversationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (agentPlansRefs)
                        await $_getPrefetchedData<
                          ConversationRow,
                          $ConversationsTable,
                          AgentPlanRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationsTableReferences
                              ._agentPlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationsTableReferences(
                                db,
                                table,
                                p0,
                              ).agentPlansRefs,
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
        bool workspaceId,
        bool messagesRefs,
        bool attachmentsRefs,
        bool agentRunsRefs,
        bool contextSummariesRefs,
        bool modelRequestsRefs,
        bool usageArchivesRefs,
        bool agentPlansRefs,
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
  Value<String?> sourceJson,
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
  Value<String?> sourceJson,
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

  ColumnFilters<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
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

  ColumnOrderings<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
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

  GeneratedColumn<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
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
                Value<String?> sourceJson = const Value.absent(),
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
                sourceJson: sourceJson,
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
                Value<String?> sourceJson = const Value.absent(),
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
                sourceJson: sourceJson,
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
typedef $$McpServersTableCreateCompanionBuilder = McpServersCompanion Function({
  required String id,
  required String profileJson,
  Value<String> toolsJson,
  Value<String?> protocolVersion,
  Value<int> rowid,
});
typedef $$McpServersTableUpdateCompanionBuilder = McpServersCompanion Function({
  Value<String> id,
  Value<String> profileJson,
  Value<String> toolsJson,
  Value<String?> protocolVersion,
  Value<int> rowid,
});

class $$McpServersTableFilterComposer
    extends Composer<_$AppDatabase, $McpServersTable> {
  $$McpServersTableFilterComposer({
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

  ColumnFilters<String> get profileJson => $composableBuilder(
    column: $table.profileJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolsJson => $composableBuilder(
    column: $table.toolsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$McpServersTableOrderingComposer
    extends Composer<_$AppDatabase, $McpServersTable> {
  $$McpServersTableOrderingComposer({
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

  ColumnOrderings<String> get profileJson => $composableBuilder(
    column: $table.profileJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolsJson => $composableBuilder(
    column: $table.toolsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$McpServersTableAnnotationComposer
    extends Composer<_$AppDatabase, $McpServersTable> {
  $$McpServersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileJson => $composableBuilder(
    column: $table.profileJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toolsJson =>
      $composableBuilder(column: $table.toolsJson, builder: (column) => column);

  GeneratedColumn<String> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => column,
  );
}

class $$McpServersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $McpServersTable,
          McpServerRow,
          $$McpServersTableFilterComposer,
          $$McpServersTableOrderingComposer,
          $$McpServersTableAnnotationComposer,
          $$McpServersTableCreateCompanionBuilder,
          $$McpServersTableUpdateCompanionBuilder,
          (
            McpServerRow,
            BaseReferences<_$AppDatabase, $McpServersTable, McpServerRow>,
          ),
          McpServerRow,
          PrefetchHooks Function()
        > {
  $$McpServersTableTableManager(_$AppDatabase db, $McpServersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$McpServersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$McpServersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$McpServersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileJson = const Value.absent(),
                Value<String> toolsJson = const Value.absent(),
                Value<String?> protocolVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => McpServersCompanion(
                id: id,
                profileJson: profileJson,
                toolsJson: toolsJson,
                protocolVersion: protocolVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileJson,
                Value<String> toolsJson = const Value.absent(),
                Value<String?> protocolVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => McpServersCompanion.insert(
                id: id,
                profileJson: profileJson,
                toolsJson: toolsJson,
                protocolVersion: protocolVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$McpServersTable, McpServerRow>(table),
                  BaseReferences<_$AppDatabase, $McpServersTable, McpServerRow>(
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

typedef $$McpServersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $McpServersTable,
      McpServerRow,
      $$McpServersTableFilterComposer,
      $$McpServersTableOrderingComposer,
      $$McpServersTableAnnotationComposer,
      $$McpServersTableCreateCompanionBuilder,
      $$McpServersTableUpdateCompanionBuilder,
      (
        McpServerRow,
        BaseReferences<_$AppDatabase, $McpServersTable, McpServerRow>,
      ),
      McpServerRow,
      PrefetchHooks Function()
    >;
typedef $$SkillInstallationsTableCreateCompanionBuilder =
    SkillInstallationsCompanion Function({
      required String id,
      required String name,
      required String snapshotJson,
      Value<bool> enabled,
      Value<bool> deleting,
      required DateTime installedAt,
      Value<int> rowid,
    });
typedef $$SkillInstallationsTableUpdateCompanionBuilder =
    SkillInstallationsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> snapshotJson,
      Value<bool> enabled,
      Value<bool> deleting,
      Value<DateTime> installedAt,
      Value<int> rowid,
    });

class $$SkillInstallationsTableFilterComposer
    extends Composer<_$AppDatabase, $SkillInstallationsTable> {
  $$SkillInstallationsTableFilterComposer({
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

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleting => $composableBuilder(
    column: $table.deleting,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SkillInstallationsTableOrderingComposer
    extends Composer<_$AppDatabase, $SkillInstallationsTable> {
  $$SkillInstallationsTableOrderingComposer({
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

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleting => $composableBuilder(
    column: $table.deleting,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SkillInstallationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SkillInstallationsTable> {
  $$SkillInstallationsTableAnnotationComposer({
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

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get deleting =>
      $composableBuilder(column: $table.deleting, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );
}

class $$SkillInstallationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SkillInstallationsTable,
          SkillInstallationRow,
          $$SkillInstallationsTableFilterComposer,
          $$SkillInstallationsTableOrderingComposer,
          $$SkillInstallationsTableAnnotationComposer,
          $$SkillInstallationsTableCreateCompanionBuilder,
          $$SkillInstallationsTableUpdateCompanionBuilder,
          (
            SkillInstallationRow,
            BaseReferences<
              _$AppDatabase,
              $SkillInstallationsTable,
              SkillInstallationRow
            >,
          ),
          SkillInstallationRow,
          PrefetchHooks Function()
        > {
  $$SkillInstallationsTableTableManager(
    _$AppDatabase db,
    $SkillInstallationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SkillInstallationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SkillInstallationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SkillInstallationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> deleting = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SkillInstallationsCompanion(
                id: id,
                name: name,
                snapshotJson: snapshotJson,
                enabled: enabled,
                deleting: deleting,
                installedAt: installedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String snapshotJson,
                Value<bool> enabled = const Value.absent(),
                Value<bool> deleting = const Value.absent(),
                required DateTime installedAt,
                Value<int> rowid = const Value.absent(),
              }) => SkillInstallationsCompanion.insert(
                id: id,
                name: name,
                snapshotJson: snapshotJson,
                enabled: enabled,
                deleting: deleting,
                installedAt: installedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SkillInstallationsTable, SkillInstallationRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $SkillInstallationsTable,
                    SkillInstallationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SkillInstallationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SkillInstallationsTable,
      SkillInstallationRow,
      $$SkillInstallationsTableFilterComposer,
      $$SkillInstallationsTableOrderingComposer,
      $$SkillInstallationsTableAnnotationComposer,
      $$SkillInstallationsTableCreateCompanionBuilder,
      $$SkillInstallationsTableUpdateCompanionBuilder,
      (
        SkillInstallationRow,
        BaseReferences<
          _$AppDatabase,
          $SkillInstallationsTable,
          SkillInstallationRow
        >,
      ),
      SkillInstallationRow,
      PrefetchHooks Function()
    >;
typedef $$RuntimeEnvironmentsTableCreateCompanionBuilder =
    RuntimeEnvironmentsCompanion Function({
      required String id,
      required String configurationJson,
      Value<int> rowid,
    });
typedef $$RuntimeEnvironmentsTableUpdateCompanionBuilder =
    RuntimeEnvironmentsCompanion Function({
      Value<String> id,
      Value<String> configurationJson,
      Value<int> rowid,
    });

class $$RuntimeEnvironmentsTableFilterComposer
    extends Composer<_$AppDatabase, $RuntimeEnvironmentsTable> {
  $$RuntimeEnvironmentsTableFilterComposer({
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

  ColumnFilters<String> get configurationJson => $composableBuilder(
    column: $table.configurationJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuntimeEnvironmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $RuntimeEnvironmentsTable> {
  $$RuntimeEnvironmentsTableOrderingComposer({
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

  ColumnOrderings<String> get configurationJson => $composableBuilder(
    column: $table.configurationJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuntimeEnvironmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RuntimeEnvironmentsTable> {
  $$RuntimeEnvironmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get configurationJson => $composableBuilder(
    column: $table.configurationJson,
    builder: (column) => column,
  );
}

class $$RuntimeEnvironmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RuntimeEnvironmentsTable,
          RuntimeEnvironmentRow,
          $$RuntimeEnvironmentsTableFilterComposer,
          $$RuntimeEnvironmentsTableOrderingComposer,
          $$RuntimeEnvironmentsTableAnnotationComposer,
          $$RuntimeEnvironmentsTableCreateCompanionBuilder,
          $$RuntimeEnvironmentsTableUpdateCompanionBuilder,
          (
            RuntimeEnvironmentRow,
            BaseReferences<
              _$AppDatabase,
              $RuntimeEnvironmentsTable,
              RuntimeEnvironmentRow
            >,
          ),
          RuntimeEnvironmentRow,
          PrefetchHooks Function()
        > {
  $$RuntimeEnvironmentsTableTableManager(
    _$AppDatabase db,
    $RuntimeEnvironmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuntimeEnvironmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RuntimeEnvironmentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RuntimeEnvironmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> configurationJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuntimeEnvironmentsCompanion(
                id: id,
                configurationJson: configurationJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String configurationJson,
                Value<int> rowid = const Value.absent(),
              }) => RuntimeEnvironmentsCompanion.insert(
                id: id,
                configurationJson: configurationJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RuntimeEnvironmentsTable, RuntimeEnvironmentRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $RuntimeEnvironmentsTable,
                    RuntimeEnvironmentRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuntimeEnvironmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RuntimeEnvironmentsTable,
      RuntimeEnvironmentRow,
      $$RuntimeEnvironmentsTableFilterComposer,
      $$RuntimeEnvironmentsTableOrderingComposer,
      $$RuntimeEnvironmentsTableAnnotationComposer,
      $$RuntimeEnvironmentsTableCreateCompanionBuilder,
      $$RuntimeEnvironmentsTableUpdateCompanionBuilder,
      (
        RuntimeEnvironmentRow,
        BaseReferences<
          _$AppDatabase,
          $RuntimeEnvironmentsTable,
          RuntimeEnvironmentRow
        >,
      ),
      RuntimeEnvironmentRow,
      PrefetchHooks Function()
    >;
typedef $$WorkspaceCopiesTableCreateCompanionBuilder =
    WorkspaceCopiesCompanion Function({
      required String workspaceId,
      required String relativePath,
      required String sourceJson,
      Value<int> rowid,
    });
typedef $$WorkspaceCopiesTableUpdateCompanionBuilder =
    WorkspaceCopiesCompanion Function({
      Value<String> workspaceId,
      Value<String> relativePath,
      Value<String> sourceJson,
      Value<int> rowid,
    });

final class $$WorkspaceCopiesTableReferences
    extends
        BaseReferences<_$AppDatabase, $WorkspaceCopiesTable, WorkspaceCopyRow> {
  $$WorkspaceCopiesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkspacesTable _workspaceIdTable(_$AppDatabase db) => db.workspaces
      .createAlias('workspace_copies__workspace_id__workspaces__id');

  $$WorkspacesTableProcessedTableManager get workspaceId {
    final $_column = $_itemColumn<String>('workspace_id')!;

    final manager = $$WorkspacesTableTableManager(
      $_db,
      $_db.workspaces,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workspaceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkspaceCopiesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkspaceCopiesTable> {
  $$WorkspaceCopiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkspacesTableFilterComposer get workspaceId {
    final $$WorkspacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspaceId,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableFilterComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkspaceCopiesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkspaceCopiesTable> {
  $$WorkspaceCopiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkspacesTableOrderingComposer get workspaceId {
    final $$WorkspacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspaceId,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableOrderingComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkspaceCopiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkspaceCopiesTable> {
  $$WorkspaceCopiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => column,
  );

  $$WorkspacesTableAnnotationComposer get workspaceId {
    final $$WorkspacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspaceId,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableAnnotationComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkspaceCopiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkspaceCopiesTable,
          WorkspaceCopyRow,
          $$WorkspaceCopiesTableFilterComposer,
          $$WorkspaceCopiesTableOrderingComposer,
          $$WorkspaceCopiesTableAnnotationComposer,
          $$WorkspaceCopiesTableCreateCompanionBuilder,
          $$WorkspaceCopiesTableUpdateCompanionBuilder,
          (WorkspaceCopyRow, $$WorkspaceCopiesTableReferences),
          WorkspaceCopyRow,
          PrefetchHooks Function({bool workspaceId})
        > {
  $$WorkspaceCopiesTableTableManager(
    _$AppDatabase db,
    $WorkspaceCopiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkspaceCopiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkspaceCopiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkspaceCopiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> workspaceId = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> sourceJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkspaceCopiesCompanion(
                workspaceId: workspaceId,
                relativePath: relativePath,
                sourceJson: sourceJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String workspaceId,
                required String relativePath,
                required String sourceJson,
                Value<int> rowid = const Value.absent(),
              }) => WorkspaceCopiesCompanion.insert(
                workspaceId: workspaceId,
                relativePath: relativePath,
                sourceJson: sourceJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkspaceCopiesTable, WorkspaceCopyRow>(table),
                  $$WorkspaceCopiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workspaceId = false}) {
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
                    if (workspaceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.workspaceId,
                        referencedTable: $$WorkspaceCopiesTableReferences
                            ._workspaceIdTable(db),
                        referencedColumn: $$WorkspaceCopiesTableReferences
                            ._workspaceIdTable(db)
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

typedef $$WorkspaceCopiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkspaceCopiesTable,
      WorkspaceCopyRow,
      $$WorkspaceCopiesTableFilterComposer,
      $$WorkspaceCopiesTableOrderingComposer,
      $$WorkspaceCopiesTableAnnotationComposer,
      $$WorkspaceCopiesTableCreateCompanionBuilder,
      $$WorkspaceCopiesTableUpdateCompanionBuilder,
      (WorkspaceCopyRow, $$WorkspaceCopiesTableReferences),
      WorkspaceCopyRow,
      PrefetchHooks Function({bool workspaceId})
    >;
typedef $$ContextSummariesTableCreateCompanionBuilder =
    ContextSummariesCompanion Function({
      required String id,
      required String conversationId,
      Value<String?> runId,
      required String branchEndId,
      required String coveredIdsJson,
      required String fingerprint,
      required String sourceModel,
      required int version,
      required String status,
      required String content,
      Value<String> checkpointJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ContextSummariesTableUpdateCompanionBuilder =
    ContextSummariesCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String?> runId,
      Value<String> branchEndId,
      Value<String> coveredIdsJson,
      Value<String> fingerprint,
      Value<String> sourceModel,
      Value<int> version,
      Value<String> status,
      Value<String> content,
      Value<String> checkpointJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ContextSummariesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ContextSummariesTable,
          ContextSummaryRow
        > {
  $$ContextSummariesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationsTable _conversationIdTable(_$AppDatabase db) => db
      .conversations
      .createAlias('context_summaries__conversation_id__conversations__id');

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

class $$ContextSummariesTableFilterComposer
    extends Composer<_$AppDatabase, $ContextSummariesTable> {
  $$ContextSummariesTableFilterComposer({
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

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branchEndId => $composableBuilder(
    column: $table.branchEndId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coveredIdsJson => $composableBuilder(
    column: $table.coveredIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceModel => $composableBuilder(
    column: $table.sourceModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkpointJson => $composableBuilder(
    column: $table.checkpointJson,
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

class $$ContextSummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $ContextSummariesTable> {
  $$ContextSummariesTableOrderingComposer({
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

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branchEndId => $composableBuilder(
    column: $table.branchEndId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coveredIdsJson => $composableBuilder(
    column: $table.coveredIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceModel => $composableBuilder(
    column: $table.sourceModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkpointJson => $composableBuilder(
    column: $table.checkpointJson,
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

class $$ContextSummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContextSummariesTable> {
  $$ContextSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<String> get branchEndId => $composableBuilder(
    column: $table.branchEndId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coveredIdsJson => $composableBuilder(
    column: $table.coveredIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceModel => $composableBuilder(
    column: $table.sourceModel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get checkpointJson => $composableBuilder(
    column: $table.checkpointJson,
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

class $$ContextSummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContextSummariesTable,
          ContextSummaryRow,
          $$ContextSummariesTableFilterComposer,
          $$ContextSummariesTableOrderingComposer,
          $$ContextSummariesTableAnnotationComposer,
          $$ContextSummariesTableCreateCompanionBuilder,
          $$ContextSummariesTableUpdateCompanionBuilder,
          (ContextSummaryRow, $$ContextSummariesTableReferences),
          ContextSummaryRow,
          PrefetchHooks Function({bool conversationId})
        > {
  $$ContextSummariesTableTableManager(
    _$AppDatabase db,
    $ContextSummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContextSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContextSummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContextSummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<String> branchEndId = const Value.absent(),
                Value<String> coveredIdsJson = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<String> sourceModel = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> checkpointJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContextSummariesCompanion(
                id: id,
                conversationId: conversationId,
                runId: runId,
                branchEndId: branchEndId,
                coveredIdsJson: coveredIdsJson,
                fingerprint: fingerprint,
                sourceModel: sourceModel,
                version: version,
                status: status,
                content: content,
                checkpointJson: checkpointJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                Value<String?> runId = const Value.absent(),
                required String branchEndId,
                required String coveredIdsJson,
                required String fingerprint,
                required String sourceModel,
                required int version,
                required String status,
                required String content,
                Value<String> checkpointJson = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ContextSummariesCompanion.insert(
                id: id,
                conversationId: conversationId,
                runId: runId,
                branchEndId: branchEndId,
                coveredIdsJson: coveredIdsJson,
                fingerprint: fingerprint,
                sourceModel: sourceModel,
                version: version,
                status: status,
                content: content,
                checkpointJson: checkpointJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContextSummariesTable, ContextSummaryRow>(table),
                  $$ContextSummariesTableReferences(db, table, e),
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
                        referencedTable: $$ContextSummariesTableReferences
                            ._conversationIdTable(db),
                        referencedColumn: $$ContextSummariesTableReferences
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

typedef $$ContextSummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContextSummariesTable,
      ContextSummaryRow,
      $$ContextSummariesTableFilterComposer,
      $$ContextSummariesTableOrderingComposer,
      $$ContextSummariesTableAnnotationComposer,
      $$ContextSummariesTableCreateCompanionBuilder,
      $$ContextSummariesTableUpdateCompanionBuilder,
      (ContextSummaryRow, $$ContextSummariesTableReferences),
      ContextSummaryRow,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$ModelRequestsTableCreateCompanionBuilder =
    ModelRequestsCompanion Function({
      required String id,
      required String conversationId,
      Value<String?> runId,
      required int logicalTurn,
      required int attemptIndex,
      required String purpose,
      required String status,
      required String profileId,
      required String protocol,
      required String requestedModelId,
      Value<String?> responseModelId,
      Value<String?> assistantMessageId,
      Value<String?> summaryId,
      Value<String?> summaryJobId,
      Value<String?> usageJson,
      Value<int> usageRevision,
      Value<bool> usageComplete,
      required String contextJson,
      Value<String?> originRequestId,
      Value<bool> isInherited,
      Value<String?> errorCode,
      required DateTime createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
      Value<int> rowid,
    });
typedef $$ModelRequestsTableUpdateCompanionBuilder =
    ModelRequestsCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String?> runId,
      Value<int> logicalTurn,
      Value<int> attemptIndex,
      Value<String> purpose,
      Value<String> status,
      Value<String> profileId,
      Value<String> protocol,
      Value<String> requestedModelId,
      Value<String?> responseModelId,
      Value<String?> assistantMessageId,
      Value<String?> summaryId,
      Value<String?> summaryJobId,
      Value<String?> usageJson,
      Value<int> usageRevision,
      Value<bool> usageComplete,
      Value<String> contextJson,
      Value<String?> originRequestId,
      Value<bool> isInherited,
      Value<String?> errorCode,
      Value<DateTime> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
      Value<int> rowid,
    });

final class $$ModelRequestsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ModelRequestsTable, ModelRequestRow> {
  $$ModelRequestsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationsTable _conversationIdTable(_$AppDatabase db) => db
      .conversations
      .createAlias('model_requests__conversation_id__conversations__id');

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

class $$ModelRequestsTableFilterComposer
    extends Composer<_$AppDatabase, $ModelRequestsTable> {
  $$ModelRequestsTableFilterComposer({
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

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get logicalTurn => $composableBuilder(
    column: $table.logicalTurn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptIndex => $composableBuilder(
    column: $table.attemptIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestedModelId => $composableBuilder(
    column: $table.requestedModelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseModelId => $composableBuilder(
    column: $table.responseModelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assistantMessageId => $composableBuilder(
    column: $table.assistantMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryId => $composableBuilder(
    column: $table.summaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJobId => $composableBuilder(
    column: $table.summaryJobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usageJson => $composableBuilder(
    column: $table.usageJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usageRevision => $composableBuilder(
    column: $table.usageRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get usageComplete => $composableBuilder(
    column: $table.usageComplete,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextJson => $composableBuilder(
    column: $table.contextJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originRequestId => $composableBuilder(
    column: $table.originRequestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInherited => $composableBuilder(
    column: $table.isInherited,
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

class $$ModelRequestsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelRequestsTable> {
  $$ModelRequestsTableOrderingComposer({
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

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get logicalTurn => $composableBuilder(
    column: $table.logicalTurn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptIndex => $composableBuilder(
    column: $table.attemptIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestedModelId => $composableBuilder(
    column: $table.requestedModelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseModelId => $composableBuilder(
    column: $table.responseModelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assistantMessageId => $composableBuilder(
    column: $table.assistantMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryId => $composableBuilder(
    column: $table.summaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJobId => $composableBuilder(
    column: $table.summaryJobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usageJson => $composableBuilder(
    column: $table.usageJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usageRevision => $composableBuilder(
    column: $table.usageRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get usageComplete => $composableBuilder(
    column: $table.usageComplete,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextJson => $composableBuilder(
    column: $table.contextJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originRequestId => $composableBuilder(
    column: $table.originRequestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInherited => $composableBuilder(
    column: $table.isInherited,
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

class $$ModelRequestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelRequestsTable> {
  $$ModelRequestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<int> get logicalTurn => $composableBuilder(
    column: $table.logicalTurn,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptIndex => $composableBuilder(
    column: $table.attemptIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get protocol =>
      $composableBuilder(column: $table.protocol, builder: (column) => column);

  GeneratedColumn<String> get requestedModelId => $composableBuilder(
    column: $table.requestedModelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responseModelId => $composableBuilder(
    column: $table.responseModelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assistantMessageId => $composableBuilder(
    column: $table.assistantMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryId =>
      $composableBuilder(column: $table.summaryId, builder: (column) => column);

  GeneratedColumn<String> get summaryJobId => $composableBuilder(
    column: $table.summaryJobId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get usageJson =>
      $composableBuilder(column: $table.usageJson, builder: (column) => column);

  GeneratedColumn<int> get usageRevision => $composableBuilder(
    column: $table.usageRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get usageComplete => $composableBuilder(
    column: $table.usageComplete,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contextJson => $composableBuilder(
    column: $table.contextJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originRequestId => $composableBuilder(
    column: $table.originRequestId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isInherited => $composableBuilder(
    column: $table.isInherited,
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

class $$ModelRequestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelRequestsTable,
          ModelRequestRow,
          $$ModelRequestsTableFilterComposer,
          $$ModelRequestsTableOrderingComposer,
          $$ModelRequestsTableAnnotationComposer,
          $$ModelRequestsTableCreateCompanionBuilder,
          $$ModelRequestsTableUpdateCompanionBuilder,
          (ModelRequestRow, $$ModelRequestsTableReferences),
          ModelRequestRow,
          PrefetchHooks Function({bool conversationId})
        > {
  $$ModelRequestsTableTableManager(_$AppDatabase db, $ModelRequestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelRequestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelRequestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelRequestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<int> logicalTurn = const Value.absent(),
                Value<int> attemptIndex = const Value.absent(),
                Value<String> purpose = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> protocol = const Value.absent(),
                Value<String> requestedModelId = const Value.absent(),
                Value<String?> responseModelId = const Value.absent(),
                Value<String?> assistantMessageId = const Value.absent(),
                Value<String?> summaryId = const Value.absent(),
                Value<String?> summaryJobId = const Value.absent(),
                Value<String?> usageJson = const Value.absent(),
                Value<int> usageRevision = const Value.absent(),
                Value<bool> usageComplete = const Value.absent(),
                Value<String> contextJson = const Value.absent(),
                Value<String?> originRequestId = const Value.absent(),
                Value<bool> isInherited = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelRequestsCompanion(
                id: id,
                conversationId: conversationId,
                runId: runId,
                logicalTurn: logicalTurn,
                attemptIndex: attemptIndex,
                purpose: purpose,
                status: status,
                profileId: profileId,
                protocol: protocol,
                requestedModelId: requestedModelId,
                responseModelId: responseModelId,
                assistantMessageId: assistantMessageId,
                summaryId: summaryId,
                summaryJobId: summaryJobId,
                usageJson: usageJson,
                usageRevision: usageRevision,
                usageComplete: usageComplete,
                contextJson: contextJson,
                originRequestId: originRequestId,
                isInherited: isInherited,
                errorCode: errorCode,
                createdAt: createdAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                Value<String?> runId = const Value.absent(),
                required int logicalTurn,
                required int attemptIndex,
                required String purpose,
                required String status,
                required String profileId,
                required String protocol,
                required String requestedModelId,
                Value<String?> responseModelId = const Value.absent(),
                Value<String?> assistantMessageId = const Value.absent(),
                Value<String?> summaryId = const Value.absent(),
                Value<String?> summaryJobId = const Value.absent(),
                Value<String?> usageJson = const Value.absent(),
                Value<int> usageRevision = const Value.absent(),
                Value<bool> usageComplete = const Value.absent(),
                required String contextJson,
                Value<String?> originRequestId = const Value.absent(),
                Value<bool> isInherited = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelRequestsCompanion.insert(
                id: id,
                conversationId: conversationId,
                runId: runId,
                logicalTurn: logicalTurn,
                attemptIndex: attemptIndex,
                purpose: purpose,
                status: status,
                profileId: profileId,
                protocol: protocol,
                requestedModelId: requestedModelId,
                responseModelId: responseModelId,
                assistantMessageId: assistantMessageId,
                summaryId: summaryId,
                summaryJobId: summaryJobId,
                usageJson: usageJson,
                usageRevision: usageRevision,
                usageComplete: usageComplete,
                contextJson: contextJson,
                originRequestId: originRequestId,
                isInherited: isInherited,
                errorCode: errorCode,
                createdAt: createdAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelRequestsTable, ModelRequestRow>(table),
                  $$ModelRequestsTableReferences(db, table, e),
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
                        referencedTable: $$ModelRequestsTableReferences
                            ._conversationIdTable(db),
                        referencedColumn: $$ModelRequestsTableReferences
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

typedef $$ModelRequestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelRequestsTable,
      ModelRequestRow,
      $$ModelRequestsTableFilterComposer,
      $$ModelRequestsTableOrderingComposer,
      $$ModelRequestsTableAnnotationComposer,
      $$ModelRequestsTableCreateCompanionBuilder,
      $$ModelRequestsTableUpdateCompanionBuilder,
      (ModelRequestRow, $$ModelRequestsTableReferences),
      ModelRequestRow,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$UsageArchivesTableCreateCompanionBuilder =
    UsageArchivesCompanion Function({
      required String conversationId,
      required String sourceKind,
      required String sourceId,
      required String reportJson,
      Value<int> rowid,
    });
typedef $$UsageArchivesTableUpdateCompanionBuilder =
    UsageArchivesCompanion Function({
      Value<String> conversationId,
      Value<String> sourceKind,
      Value<String> sourceId,
      Value<String> reportJson,
      Value<int> rowid,
    });

final class $$UsageArchivesTableReferences
    extends
        BaseReferences<_$AppDatabase, $UsageArchivesTable, UsageArchiveRow> {
  $$UsageArchivesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationsTable _conversationIdTable(_$AppDatabase db) => db
      .conversations
      .createAlias('usage_archives__conversation_id__conversations__id');

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

class $$UsageArchivesTableFilterComposer
    extends Composer<_$AppDatabase, $UsageArchivesTable> {
  $$UsageArchivesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportJson => $composableBuilder(
    column: $table.reportJson,
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

class $$UsageArchivesTableOrderingComposer
    extends Composer<_$AppDatabase, $UsageArchivesTable> {
  $$UsageArchivesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportJson => $composableBuilder(
    column: $table.reportJson,
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

class $$UsageArchivesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsageArchivesTable> {
  $$UsageArchivesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get reportJson => $composableBuilder(
    column: $table.reportJson,
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
}

class $$UsageArchivesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsageArchivesTable,
          UsageArchiveRow,
          $$UsageArchivesTableFilterComposer,
          $$UsageArchivesTableOrderingComposer,
          $$UsageArchivesTableAnnotationComposer,
          $$UsageArchivesTableCreateCompanionBuilder,
          $$UsageArchivesTableUpdateCompanionBuilder,
          (UsageArchiveRow, $$UsageArchivesTableReferences),
          UsageArchiveRow,
          PrefetchHooks Function({bool conversationId})
        > {
  $$UsageArchivesTableTableManager(_$AppDatabase db, $UsageArchivesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageArchivesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageArchivesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsageArchivesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<String> sourceKind = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> reportJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageArchivesCompanion(
                conversationId: conversationId,
                sourceKind: sourceKind,
                sourceId: sourceId,
                reportJson: reportJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required String sourceKind,
                required String sourceId,
                required String reportJson,
                Value<int> rowid = const Value.absent(),
              }) => UsageArchivesCompanion.insert(
                conversationId: conversationId,
                sourceKind: sourceKind,
                sourceId: sourceId,
                reportJson: reportJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsageArchivesTable, UsageArchiveRow>(table),
                  $$UsageArchivesTableReferences(db, table, e),
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
                        referencedTable: $$UsageArchivesTableReferences
                            ._conversationIdTable(db),
                        referencedColumn: $$UsageArchivesTableReferences
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

typedef $$UsageArchivesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsageArchivesTable,
      UsageArchiveRow,
      $$UsageArchivesTableFilterComposer,
      $$UsageArchivesTableOrderingComposer,
      $$UsageArchivesTableAnnotationComposer,
      $$UsageArchivesTableCreateCompanionBuilder,
      $$UsageArchivesTableUpdateCompanionBuilder,
      (UsageArchiveRow, $$UsageArchivesTableReferences),
      UsageArchiveRow,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$AgentPlansTableCreateCompanionBuilder = AgentPlansCompanion Function({
  required String id,
  required int revision,
  required String conversationId,
  required String sourceRunId,
  required String sourceMessageId,
  required String title,
  required String stepsJson,
  required String status,
  Value<String?> executionRunId,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$AgentPlansTableUpdateCompanionBuilder = AgentPlansCompanion Function({
  Value<String> id,
  Value<int> revision,
  Value<String> conversationId,
  Value<String> sourceRunId,
  Value<String> sourceMessageId,
  Value<String> title,
  Value<String> stepsJson,
  Value<String> status,
  Value<String?> executionRunId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$AgentPlansTableReferences
    extends BaseReferences<_$AppDatabase, $AgentPlansTable, AgentPlanRow> {
  $$AgentPlansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$AppDatabase db) => db
      .conversations
      .createAlias('agent_plans__conversation_id__conversations__id');

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

class $$AgentPlansTableFilterComposer
    extends Composer<_$AppDatabase, $AgentPlansTable> {
  $$AgentPlansTableFilterComposer({
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

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRunId => $composableBuilder(
    column: $table.sourceRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get executionRunId => $composableBuilder(
    column: $table.executionRunId,
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

class $$AgentPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $AgentPlansTable> {
  $$AgentPlansTableOrderingComposer({
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

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRunId => $composableBuilder(
    column: $table.sourceRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get executionRunId => $composableBuilder(
    column: $table.executionRunId,
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

class $$AgentPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $AgentPlansTable> {
  $$AgentPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get sourceRunId => $composableBuilder(
    column: $table.sourceRunId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get stepsJson =>
      $composableBuilder(column: $table.stepsJson, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get executionRunId => $composableBuilder(
    column: $table.executionRunId,
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

class $$AgentPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AgentPlansTable,
          AgentPlanRow,
          $$AgentPlansTableFilterComposer,
          $$AgentPlansTableOrderingComposer,
          $$AgentPlansTableAnnotationComposer,
          $$AgentPlansTableCreateCompanionBuilder,
          $$AgentPlansTableUpdateCompanionBuilder,
          (AgentPlanRow, $$AgentPlansTableReferences),
          AgentPlanRow,
          PrefetchHooks Function({bool conversationId})
        > {
  $$AgentPlansTableTableManager(_$AppDatabase db, $AgentPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> sourceRunId = const Value.absent(),
                Value<String> sourceMessageId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> stepsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> executionRunId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentPlansCompanion(
                id: id,
                revision: revision,
                conversationId: conversationId,
                sourceRunId: sourceRunId,
                sourceMessageId: sourceMessageId,
                title: title,
                stepsJson: stepsJson,
                status: status,
                executionRunId: executionRunId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int revision,
                required String conversationId,
                required String sourceRunId,
                required String sourceMessageId,
                required String title,
                required String stepsJson,
                required String status,
                Value<String?> executionRunId = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AgentPlansCompanion.insert(
                id: id,
                revision: revision,
                conversationId: conversationId,
                sourceRunId: sourceRunId,
                sourceMessageId: sourceMessageId,
                title: title,
                stepsJson: stepsJson,
                status: status,
                executionRunId: executionRunId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AgentPlansTable, AgentPlanRow>(table),
                  $$AgentPlansTableReferences(db, table, e),
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
                        referencedTable: $$AgentPlansTableReferences
                            ._conversationIdTable(db),
                        referencedColumn: $$AgentPlansTableReferences
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

typedef $$AgentPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AgentPlansTable,
      AgentPlanRow,
      $$AgentPlansTableFilterComposer,
      $$AgentPlansTableOrderingComposer,
      $$AgentPlansTableAnnotationComposer,
      $$AgentPlansTableCreateCompanionBuilder,
      $$AgentPlansTableUpdateCompanionBuilder,
      (AgentPlanRow, $$AgentPlansTableReferences),
      AgentPlanRow,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$MemoryEntriesTableCreateCompanionBuilder =
    MemoryEntriesCompanion Function({
      required String id,
      Value<String?> assistantId,
      Value<String?> sourceMessageId,
      Value<String?> sourceRunId,
      required String content,
      Value<bool> enabled,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MemoryEntriesTableUpdateCompanionBuilder =
    MemoryEntriesCompanion Function({
      Value<String> id,
      Value<String?> assistantId,
      Value<String?> sourceMessageId,
      Value<String?> sourceRunId,
      Value<String> content,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MemoryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryEntriesTable> {
  $$MemoryEntriesTableFilterComposer({
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

  ColumnFilters<String> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRunId => $composableBuilder(
    column: $table.sourceRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
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
}

class $$MemoryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryEntriesTable> {
  $$MemoryEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRunId => $composableBuilder(
    column: $table.sourceRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
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

class $$MemoryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryEntriesTable> {
  $$MemoryEntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRunId => $composableBuilder(
    column: $table.sourceRunId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MemoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryEntriesTable,
          MemoryEntryRow,
          $$MemoryEntriesTableFilterComposer,
          $$MemoryEntriesTableOrderingComposer,
          $$MemoryEntriesTableAnnotationComposer,
          $$MemoryEntriesTableCreateCompanionBuilder,
          $$MemoryEntriesTableUpdateCompanionBuilder,
          (
            MemoryEntryRow,
            BaseReferences<_$AppDatabase, $MemoryEntriesTable, MemoryEntryRow>,
          ),
          MemoryEntryRow,
          PrefetchHooks Function()
        > {
  $$MemoryEntriesTableTableManager(_$AppDatabase db, $MemoryEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> assistantId = const Value.absent(),
                Value<String?> sourceMessageId = const Value.absent(),
                Value<String?> sourceRunId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryEntriesCompanion(
                id: id,
                assistantId: assistantId,
                sourceMessageId: sourceMessageId,
                sourceRunId: sourceRunId,
                content: content,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> assistantId = const Value.absent(),
                Value<String?> sourceMessageId = const Value.absent(),
                Value<String?> sourceRunId = const Value.absent(),
                required String content,
                Value<bool> enabled = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MemoryEntriesCompanion.insert(
                id: id,
                assistantId: assistantId,
                sourceMessageId: sourceMessageId,
                sourceRunId: sourceRunId,
                content: content,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MemoryEntriesTable, MemoryEntryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MemoryEntriesTable,
                    MemoryEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryEntriesTable,
      MemoryEntryRow,
      $$MemoryEntriesTableFilterComposer,
      $$MemoryEntriesTableOrderingComposer,
      $$MemoryEntriesTableAnnotationComposer,
      $$MemoryEntriesTableCreateCompanionBuilder,
      $$MemoryEntriesTableUpdateCompanionBuilder,
      (
        MemoryEntryRow,
        BaseReferences<_$AppDatabase, $MemoryEntriesTable, MemoryEntryRow>,
      ),
      MemoryEntryRow,
      PrefetchHooks Function()
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
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db, _db.workspaces);
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
  $$McpServersTableTableManager get mcpServers =>
      $$McpServersTableTableManager(_db, _db.mcpServers);
  $$SkillInstallationsTableTableManager get skillInstallations =>
      $$SkillInstallationsTableTableManager(_db, _db.skillInstallations);
  $$RuntimeEnvironmentsTableTableManager get runtimeEnvironments =>
      $$RuntimeEnvironmentsTableTableManager(_db, _db.runtimeEnvironments);
  $$WorkspaceCopiesTableTableManager get workspaceCopies =>
      $$WorkspaceCopiesTableTableManager(_db, _db.workspaceCopies);
  $$ContextSummariesTableTableManager get contextSummaries =>
      $$ContextSummariesTableTableManager(_db, _db.contextSummaries);
  $$ModelRequestsTableTableManager get modelRequests =>
      $$ModelRequestsTableTableManager(_db, _db.modelRequests);
  $$UsageArchivesTableTableManager get usageArchives =>
      $$UsageArchivesTableTableManager(_db, _db.usageArchives);
  $$AgentPlansTableTableManager get agentPlans =>
      $$AgentPlansTableTableManager(_db, _db.agentPlans);
  $$MemoryEntriesTableTableManager get memoryEntries =>
      $$MemoryEntriesTableTableManager(_db, _db.memoryEntries);
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
        retry: _databaseRetry,
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

String _$appDatabaseHash() => r'c16f03295bac7f80eef515b57f05fafeb3b75f12';
