import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../../core/utils/logger.dart';
import '../datasources/local/app_database.dart';
import '../models/assistant.dart';
import 'row_mappers.dart';

part 'assistant_repository.g.dart';

/// 助手的读写；删除助手不删除已有会话。
class AssistantRepository {
  AssistantRepository(this._db);

  final AppDatabase _db;

  Stream<List<Assistant>> watchAssistants() {
    final query = _db.select(_db.assistants)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(assistantFromRow).toList());
  }

  Future<List<Assistant>> getAssistants() async {
    final rows = await (_db.select(
      _db.assistants,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
    return rows.map(assistantFromRow).toList();
  }

  Future<Assistant?> getById(String id) async {
    final row = await (_db.select(
      _db.assistants,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : assistantFromRow(row);
  }

  /// 首次建库时写入内置的普通助手；已存在时不重复创建。
  Future<Assistant> ensureDefault() async {
    return _guard('创建默认助手失败', () async {
      final existing = await getAssistants();
      if (existing.isNotEmpty) return existing.first;
      final assistant = Assistant(
        id: generateId(),
        name: defaultAssistantName,
        systemPrompt: '',
        createdAt: DateTime.now(),
      );
      await _db.into(_db.assistants).insert(assistantCompanion(assistant));
      return assistant;
    });
  }

  Future<Assistant> save(Assistant assistant) {
    return _guard('保存助手失败', () async {
      await _db
          .into(_db.assistants)
          .insertOnConflictUpdate(assistantCompanion(assistant));
      return assistant;
    });
  }

  /// 删除助手并把引用它的会话置空，会话本身保留。
  Future<void> delete(String id) {
    return _guard('删除助手失败', () async {
      await _db.transaction(() async {
        await (_db.delete(_db.assistants)..where((t) => t.id.equals(id))).go();
        await (_db.update(_db.conversations)
              ..where((t) => t.assistantId.equals(id)))
            .write(const ConversationsCompanion(assistantId: Value(null)));
      });
    });
  }

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
Future<AssistantRepository> assistantRepository(Ref ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  return AssistantRepository(database);
}
