import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../../core/utils/logger.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/secure_key_storage.dart';
import '../datasources/local/settings_storage.dart';
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
            compatOverrides == null
                ? null
                : jsonEncode(compatOverrides.toJson()),
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

  /// 一次性迁移：旧版按模型名启发式把部分模型写成 supportsReasoning=false，
  /// 现统一翻回 true（所有模型默认支持推理）。返回改动的配置数。
  Future<int> enableReasoningForStoredModels() async {
    try {
      final rows = await _db.getProviderProfileRows();
      var changed = 0;
      for (final row in rows) {
        final models = decodeProfileModels(row.modelsJson);
        if (models.every((model) => model.supportsReasoning)) continue;
        await _db.upsertProviderProfile(
          ProviderProfilesCompanion(
            id: Value(row.id),
            name: Value(row.name),
            baseUrl: Value(row.baseUrl),
            protocol: Value(row.protocol),
            presetId: Value(row.presetId),
            modelsJson: Value(
              encodeProfileModels([
                for (final model in models)
                  model.copyWith(supportsReasoning: true),
              ]),
            ),
            defaultModel: Value(row.defaultModel),
            compatJson: Value(row.compatJson),
            createdAt: Value(row.createdAt),
          ),
        );
        changed++;
      }
      return changed;
    } on Exception catch (e, st) {
      AppLogger.error('迁移存量模型推理标记失败', e, st);
      throw UnknownFailure('迁移存量模型推理标记失败', cause: e);
    }
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

/// 一次性迁移：存量模型的 supportsReasoning 统一翻为 true。
/// 失败不阻断读取（下次启动重试）。
@Riverpod(
  keepAlive: true,
  dependencies: [settingsStorage, providerProfileRepository],
)
Future<void> reasoningSupportMigration(Ref ref) async {
  final settings = ref.watch(settingsStorageProvider);
  if (settings.readReasoningSupportMigrated()) return;
  try {
    await ref
        .read(providerProfileRepositoryProvider)
        .enableReasoningForStoredModels();
    await settings.writeReasoningSupportMigrated();
  } on Failure catch (e, st) {
    AppLogger.error('推理默认支持迁移未完成', e, st);
  }
}

/// 服务商配置列表流；先等一次性迁移完成再发出，避免读到迁移前的旧标记。
@Riverpod(dependencies: [reasoningSupportMigration, providerProfileRepository])
Stream<List<ProviderProfile>> providerProfiles(Ref ref) async* {
  await ref.watch(reasoningSupportMigrationProvider.future);
  yield* ref.watch(providerProfileRepositoryProvider).watchProfiles();
}
