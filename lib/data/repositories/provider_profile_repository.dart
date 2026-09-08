import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../../core/utils/logger.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/secure_key_storage.dart';
import '../models/api_protocol.dart';
import '../models/openai_compat.dart';
import '../models/profile_model.dart';
import '../models/provider_profile.dart';

part 'provider_profile_repository.g.dart';

/// 服务商配置仓库：配置存 drift，API Key 经 [SecureKeyStorage] 存取。
class ProviderProfileRepository {
  ProviderProfileRepository(this._db, this._keyStorage);

  final AppDatabase _db;
  final SecureKeyStorage _keyStorage;

  Stream<List<ProviderProfile>> watchProfiles() {
    return _db.watchProviderProfileRows().map(
      (rows) => rows.map(_toProfile).toList(),
    );
  }

  Future<ProviderProfile?> getProfile(String id) async {
    try {
      final row = await _db.getProviderProfileRow(id);
      return row == null ? null : _toProfile(row);
    } on Exception catch (e, st) {
      AppLogger.error('读取服务商配置失败', e, st);
      throw UnknownFailure('读取服务商配置失败', cause: e);
    }
  }

  /// 新增或更新配置（id 为空时生成新 id；defaultModel 空串归一为 null）。
  Future<ProviderProfile> saveProfile({
    String? id,
    required String name,
    required String baseUrl,
    ApiProtocol protocol = ApiProtocol.openaiCompletions,
    String presetId = 'custom',
    String? defaultModel,
    List<ProfileModel> models = const [],
    OpenAiCompat? compatOverrides,
  }) async {
    try {
      final profileId = id ?? generateId();
      final normalizedDefault = defaultModel == null || defaultModel.isEmpty
          ? null
          : defaultModel;
      await _db.upsertProviderProfile(
        ProviderProfilesCompanion.insert(
          id: profileId,
          name: name,
          baseUrl: baseUrl,
          protocol: Value(protocol.name),
          presetId: Value(presetId),
          modelsJson: Value(encodeProfileModels(models)),
          defaultModel: Value(normalizedDefault),
          compatJson: Value(
            compatOverrides == null ? null : jsonEncode(compatOverrides.toJson()),
          ),
          createdAt: DateTime.now(),
        ),
      );
      return ProviderProfile(
        id: profileId,
        name: name,
        baseUrl: baseUrl,
        protocol: protocol,
        presetId: presetId,
        models: models,
        defaultModel: normalizedDefault,
        compatOverrides: compatOverrides,
        createdAt: DateTime.now(),
      );
    } on Exception catch (e, st) {
      AppLogger.error('保存服务商配置失败', e, st);
      throw UnknownFailure('保存服务商配置失败', cause: e);
    }
  }

  Future<List<ProviderProfile>> listProfiles() async {
    try {
      final rows = await _db.getProviderProfileRows();
      return rows.map(_toProfile).toList();
    } on Exception catch (e, st) {
      AppLogger.error('读取服务商配置失败', e, st);
      throw UnknownFailure('读取服务商配置失败', cause: e);
    }
  }

  /// 删除配置并一并清除对应的 API Key。
  Future<void> deleteProfile(String id) async {
    try {
      await _db.deleteProviderProfileRow(id);
      await _keyStorage.deleteApiKey(id);
    } on Exception catch (e, st) {
      AppLogger.error('删除服务商配置失败', e, st);
      throw UnknownFailure('删除服务商配置失败', cause: e);
    }
  }

  Future<String?> readApiKey(String profileId) {
    return _keyStorage.readApiKey(profileId);
  }

  Future<void> writeApiKey(String profileId, String apiKey) {
    return _keyStorage.writeApiKey(profileId, apiKey);
  }

  ProviderProfile _toProfile(ProviderProfileRow row) {
    return ProviderProfile(
      id: row.id,
      name: row.name,
      baseUrl: row.baseUrl,
      protocol: apiProtocolFromName(row.protocol),
      presetId: row.presetId,
      models: decodeProfileModels(row.modelsJson),
      defaultModel: row.defaultModel,
      compatOverrides: _decodeCompat(row.compatJson),
      createdAt: row.createdAt,
    );
  }

  OpenAiCompat? _decodeCompat(String? compatJson) {
    if (compatJson == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(compatJson);
      return decoded is Map<String, dynamic>
          ? OpenAiCompat.fromJson(decoded)
          : null;
    } on FormatException {
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
ProviderProfileRepository providerProfileRepository(Ref ref) {
  return ProviderProfileRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(secureKeyStorageProvider),
  );
}

/// 服务商配置列表流。
@riverpod
Stream<List<ProviderProfile>> providerProfiles(Ref ref) {
  return ref.watch(providerProfileRepositoryProvider).watchProfiles();
}
