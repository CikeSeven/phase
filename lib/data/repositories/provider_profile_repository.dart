import 'dart:convert';

import 'package:drift/drift.dart';
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
import 'row_mappers.dart';

part 'provider_profile_repository.g.dart';

/// 服务商与模型配置的读写；API Key 只经 [SecureKeyStorage] 存取。
class ProviderProfileRepository {
  ProviderProfileRepository(this._db, this._keyStorage);

  final AppDatabase _db;
  final SecureKeyStorage _keyStorage;

  Stream<List<ProviderProfile>> watchProfiles() {
    final profileQuery = _db.select(_db.providerProfiles)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return profileQuery.watch().asyncMap((rows) async {
      final modelsByProfile = await _modelsByProfile();
      return [
        for (final row in rows)
          providerProfileFromRow(row, modelsByProfile[row.id] ?? const []),
      ];
    });
  }

  Future<List<ProviderProfile>> listProfiles() async {
    return _guard('读取服务商配置失败', () async {
      final rows = await (_db.select(
        _db.providerProfiles,
      )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
      final modelsByProfile = await _modelsByProfile();
      return [
        for (final row in rows)
          providerProfileFromRow(row, modelsByProfile[row.id] ?? const []),
      ];
    });
  }

  Future<ProviderProfile?> getProfile(String id) {
    return _guard('读取服务商配置失败', () async {
      final row = await (_db.select(
        _db.providerProfiles,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return null;
      return providerProfileFromRow(row, await _modelsOf(id));
    });
  }

  /// 保存配置与模型列表；模型行按 profile 重建，能力设置以本次提交为准。
  Future<ProviderProfile> saveProfile(ProviderProfile profile) {
    return _guard('保存服务商配置失败', () async {
      final normalized = profile.copyWith(
        defaultModel: profile.defaultModel?.isEmpty == true
            ? null
            : profile.defaultModel,
      );
      await _db.transaction(() async {
        await _db
            .into(_db.providerProfiles)
            .insertOnConflictUpdate(
              ProviderProfilesCompanion(
                id: Value(normalized.id),
                name: Value(normalized.name),
                protocol: Value(normalized.protocol.name),
                baseUrl: Value(normalized.baseUrl),
                requiresKey: Value(normalized.requiresKey),
                presetId: Value(normalized.presetId),
                defaultModel: Value(normalized.defaultModel),
                compatJson: Value(
                  normalized.compatOverrides == null
                      ? null
                      : _compatJson(normalized.compatOverrides!),
                ),
                createdAt: Value(normalized.createdAt),
              ),
            );
        await (_db.delete(
          _db.models,
        )..where((t) => t.profileId.equals(normalized.id))).go();
        for (final model in normalized.models) {
          await _db
              .into(_db.models)
              .insert(modelCompanion(normalized.id, model));
        }
      });
      return normalized;
    });
  }

  /// 新建配置（id 由调用方或此处生成）。
  Future<ProviderProfile> createProfile({
    required String name,
    required String baseUrl,
    ApiProtocol protocol = ApiProtocol.openaiCompletions,
    bool requiresKey = true,
    String presetId = 'custom',
    List<ProfileModel> models = const [],
    String? defaultModel,
    OpenAiCompat? compatOverrides,
  }) {
    return saveProfile(
      ProviderProfile(
        id: generateId(),
        name: name,
        protocol: protocol,
        baseUrl: baseUrl,
        requiresKey: requiresKey,
        presetId: presetId,
        models: models,
        defaultModel: defaultModel,
        compatOverrides: compatOverrides,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// 删除配置并清除对应 API Key；Key 清理失败时明确报错，便于重试。
  Future<void> deleteProfile(String id) {
    return _guard('删除服务商配置失败', () async {
      await (_db.delete(
        _db.providerProfiles,
      )..where((t) => t.id.equals(id))).go();
      await _keyStorage.delete(id);
    });
  }

  Future<String?> readApiKey(String profileId) => _keyStorage.read(profileId);

  Future<void> writeApiKey(String profileId, String apiKey) =>
      _keyStorage.write(profileId, apiKey);

  /// 把服务商返回的模型按 id 合并进已有列表：显式能力设置优先，新模型取默认值。
  List<ProfileModel> mergeModels(
    List<ProfileModel> existing,
    List<ProfileModel> fetched,
  ) {
    final byId = {for (final model in existing) model.id: model};
    final merged = <ProfileModel>[];
    for (final model in fetched) {
      final previous = byId.remove(model.id);
      merged.add(
        previous == null
            ? model
            : previous.withSettings(
                // 已有能力设置优先，名称与上限取本次拉取到的信息。
                displayName: model.displayName,
                contextWindow: model.contextWindow ?? previous.contextWindow,
                maxOutputTokens:
                    model.maxOutputTokens ?? previous.maxOutputTokens,
              ),
      );
    }
    // 服务商未返回但用户手动添加的模型保留在原位之后。
    return [...merged, ...byId.values];
  }

  Future<Map<String, List<ProfileModel>>> _modelsByProfile() async {
    final rows = await _db.select(_db.models).get();
    final result = <String, List<ProfileModel>>{};
    for (final row in rows) {
      result.putIfAbsent(row.profileId, () => []).add(profileModelFromRow(row));
    }
    return result;
  }

  Future<List<ProfileModel>> _modelsOf(String profileId) async {
    final rows = await (_db.select(
      _db.models,
    )..where((t) => t.profileId.equals(profileId))).get();
    return rows.map(profileModelFromRow).toList();
  }

  String _compatJson(OpenAiCompat compat) => jsonEncode(compat.toJson());

  Future<T> _guard<T>(String message, Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on Exception catch (e, st) {
      AppLogger.error(message, e, st);
      throw UnknownFailure(message, cause: e);
    }
  }
}

@Riverpod(keepAlive: true)
Future<ProviderProfileRepository> providerProfileRepository(Ref ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  return ProviderProfileRepository(
    database,
    ref.watch(secureKeyStorageProvider),
  );
}

/// 服务商配置列表流（界面用）。
@Riverpod(dependencies: [providerProfileRepository])
Stream<List<ProviderProfile>> providerProfiles(Ref ref) async* {
  final repository = await ref.watch(providerProfileRepositoryProvider.future);
  yield* repository.watchProfiles();
}
