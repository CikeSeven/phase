import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../../features/skills/skill_package.dart';
import '../../features/tools/tool.dart';
import '../datasources/local/app_database.dart';
import '../models/agent_run.dart';
import '../models/skill_installation.dart';

part 'skill_repository.g.dart';

class SkillLease {
  SkillLease(this.skills, this._release);
  final List<SkillSnapshot> skills;
  final Future<void> Function() _release;
  bool _closed = false;
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _release();
  }
}

/// 文件先准备，数据库事务只切换指针；失败不会覆盖正在使用的版本。
class SkillRepository {
  SkillRepository(this._db, this.root);
  final AppDatabase _db;
  final Directory root;
  final _pins = <String, int>{};
  Future<void> _tail = Future.value();
  SkillPackageReader get packages =>
      SkillPackageReader(Directory(p.join(root.path, 'staging')));

  SkillInstallation _entry(SkillInstallationRow row) => SkillInstallation(
    snapshot: SkillSnapshot.fromJson(
      jsonDecode(row.snapshotJson) as Map<String, dynamic>,
    ),
    installedAt: row.installedAt,
    enabled: row.enabled,
    deleting: row.deleting,
  );

  Future<List<SkillInstallation>> list() => _records(
    () async => (await (_db.select(
      _db.skillInstallations,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get()).map(_entry).toList(),
  );

  Future<SkillInstallation?> get(String id) => _records(() async {
    final row = await (_db.select(
      _db.skillInstallations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _entry(row);
  });

  Stream<List<SkillInstallation>> watch() async* {
    try {
      yield* (_db.select(_db.skillInstallations)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch()
          .map((rows) => rows.map(_entry).toList());
    } catch (error) {
      throw StorageFailure('读取 Skill 安装记录失败', cause: error);
    }
  }

  Future<SkillInstallation> install(
    PreparedSkill package,
    RunCancellation cancellation, {
    String? replaceId,
  }) => _exclusive(() async {
    cancellation.throwIfCancelled();
    final entries = await list();
    final old = replaceId == null
        ? null
        : entries.where((e) => e.id == replaceId).firstOrNull;
    if (replaceId != null && (old == null || old.deleting)) {
      throw const SkillFailure('missingInstallation', '要更新的 Skill 已不存在或正在删除');
    }
    final sameName = entries
        .where(
          (e) => e.snapshot.name.toLowerCase() == package.name.toLowerCase(),
        )
        .firstOrNull;
    if (sameName != null && sameName.id != replaceId) {
      throw const SkillFailure('duplicateName', '已有同名 Skill，请从它的详情页更新');
    }
    if (old != null && old.snapshot.name != package.name) {
      throw const SkillFailure(
        'nameChanged',
        '更新包名称与原 Skill 不一致，请作为新 Skill 导入',
      );
    }
    final id = old?.id ?? generateId();
    final directory = Directory(
      p.join(root.path, 'versions', id, '${package.revision}-${generateId()}'),
    );
    var created = false;
    try {
      if (!await directory.exists()) {
        await directory.parent.create(recursive: true);
        cancellation.throwIfCancelled();
        await package.directory.rename(directory.path);
        created = true;
      }
      cancellation.throwIfCancelled();
      final snapshot = SkillSnapshot(
        id: id,
        name: package.name,
        description: package.description,
        revision: package.revision,
        source: package.source,
        installedPath: directory.path,
        resources: package.resources,
        ignoredFields: package.ignoredFields,
      );
      final now = DateTime.now();
      await _records(
        () => _db
            .into(_db.skillInstallations)
            .insertOnConflictUpdate(
              SkillInstallationsCompanion.insert(
                id: id,
                name: package.name,
                snapshotJson: jsonEncode(snapshot.toJson()),
                installedAt: now,
                enabled: Value(old?.enabled ?? true),
              ),
            ),
      );
      // 提交后即为成功；取消不会撤销已经安装的版本。
      return SkillInstallation(
        snapshot: snapshot,
        installedAt: now,
        enabled: old?.enabled ?? true,
      );
    } catch (error) {
      if (created && await directory.exists()) {
        await _files(() => directory.rename(package.directory.path));
      }
      if (error is FileSystemException) {
        throw const SkillFailure('installFailed', '无法保存 Skill 文件，请检查可用空间后重试');
      }
      rethrow;
    }
  });

  Future<void> setEnabled(String id, bool enabled) => _exclusive(() async {
    final entry = await get(id);
    if (entry == null || entry.deleting) {
      throw const SkillFailure('missingInstallation', 'Skill 已不存在或正在删除');
    }
    await _records(
      () => (_db.update(_db.skillInstallations)..where((t) => t.id.equals(id)))
          .write(SkillInstallationsCompanion(enabled: Value(enabled))),
    );
  });

  /// 先标记不可读，再清理选择和文件；失败保留条目供重试。
  Future<void> delete(String id) => _exclusive(() async {
    await _records(
      () => _db.transaction(() async {
        await (_db.update(
          _db.skillInstallations,
        )..where((t) => t.id.equals(id))).write(
          const SkillInstallationsCompanion(
            enabled: Value(false),
            deleting: Value(true),
          ),
        );
        for (final row in await _db.select(_db.assistants).get()) {
          final ids = (jsonDecode(row.skillIdsJson) as List).cast<String>();
          if (!ids.remove(id)) continue;
          await (_db.update(_db.assistants)..where((t) => t.id.equals(row.id)))
              .write(AssistantsCompanion(skillIdsJson: Value(jsonEncode(ids))));
        }
      }),
    );
    await _collect();
  });

  Future<SkillLease> acquire(Set<String> ids, {bool enabledOnly = true}) =>
      _exclusive(() async {
        final selected = [
          for (final entry in await list())
            if (ids.contains(entry.id) &&
                !entry.deleting &&
                (!enabledOnly || entry.enabled))
              entry.snapshot,
        ];
        for (final snapshot in selected) {
          _pins.update(snapshot.installedPath, (n) => n + 1, ifAbsent: () => 1);
        }
        return SkillLease(
          List.unmodifiable(selected),
          () => _exclusive(() async {
            for (final snapshot in selected) {
              final key = snapshot.installedPath;
              final count = _pins[key] ?? 0;
              if (count <= 1) {
                _pins.remove(key);
              } else {
                _pins[key] = count - 1;
              }
            }
            await _collect();
          }),
        );
      });

  Future<void> initialize() => _exclusive(() async {
    await _files(() async {
      final staging = packages.stagingRoot;
      if (await staging.exists()) await staging.delete(recursive: true);
    });
    await _collect();
  });

  Future<void> collectGarbage() => _exclusive(_collect);

  Future<void> _collect() async {
    final entries = await list();
    final retained = {
      ..._pins.keys,
      for (final entry in entries)
        if (!entry.deleting) entry.snapshot.installedPath,
    };
    final active = await _records(
      () =>
          (_db.select(_db.agentRuns)..where(
                (t) =>
                    t.status.equalsValue(RunStatus.running) |
                    t.status.equalsValue(RunStatus.awaitingConfirmation),
              ))
              .get(),
    );
    for (final run in active) {
      final config = RunConfiguration.fromJson(
        jsonDecode(run.configurationJson) as Map<String, dynamic>,
      );
      retained.addAll(config.skills.map((s) => s.installedPath));
    }
    await _files(() async {
      final versions = Directory(p.join(root.path, 'versions'));
      if (await versions.exists()) {
        await for (final installation in versions.list(followLinks: false)) {
          if (installation is! Directory) continue;
          await for (final version in installation.list(followLinks: false)) {
            if (!retained.contains(version.path)) {
              await version.delete(recursive: true);
            }
          }
          if (await installation.list().isEmpty) await installation.delete();
        }
      }
    });
    for (final entry in entries.where((e) => e.deleting)) {
      final directory = Directory(p.join(root.path, 'versions', entry.id));
      if (!await directory.exists()) {
        await _records(
          () => (_db.delete(
            _db.skillInstallations,
          )..where((t) => t.id.equals(entry.id))).go(),
        );
      }
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<T> _records<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } catch (error) {
      throw StorageFailure('Skill 记录读取或保存失败', cause: error);
    }
  }

  Future<T> _files<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FileSystemException {
      throw const SkillFailure('cleanupFailed', 'Skill 文件清理失败，请重试');
    }
  }
}

@Riverpod(keepAlive: true)
Future<SkillRepository> skillRepository(Ref ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final documents = await getApplicationDocumentsDirectory();
  final repository = SkillRepository(
    database,
    Directory(p.join(documents.path, 'skills')),
  );
  await repository.initialize();
  return repository;
}

@riverpod
Stream<List<SkillInstallation>> skillInstallations(Ref ref) async* {
  yield* (await ref.watch(skillRepositoryProvider.future)).watch();
}
