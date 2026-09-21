import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../datasources/local/app_database.dart';
import '../models/memory_entry.dart';

part 'memory_repository.g.dart';

class MemoryRepository {
  MemoryRepository(this.db);
  final AppDatabase db;

  Stream<List<MemoryEntry>> watch() async* {
    try {
      yield* (db.select(db.memoryEntries)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch()
          .map((rows) => rows.map(_fromRow).toList());
    } on Failure {
      rethrow;
    } on Exception catch (e) {
      throw StorageFailure('读取记忆失败', cause: e);
    }
  }

  Future<MemoryEntry> add({
    required String content,
    String? assistantId,
    String? sourceRunId,
    String? sourceMessageId,
  }) => _guard(() async {
    _validate(content);
    final now = DateTime.now();
    final entry = MemoryEntry(
      id: generateId(),
      content: content.trim(),
      assistantId: assistantId,
      sourceRunId: sourceRunId,
      sourceMessageId: sourceMessageId,
      createdAt: now,
      updatedAt: now,
    );
    await db
        .into(db.memoryEntries)
        .insert(
          MemoryEntriesCompanion.insert(
            id: entry.id,
            content: entry.content,
            assistantId: Value(assistantId),
            sourceRunId: Value(sourceRunId),
            sourceMessageId: Value(sourceMessageId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return entry;
  });

  /// UPDATE 而不是 upsert：被删除的条目不会被迟到编辑重新创建。
  Future<void> update(
    String id, {
    required String content,
    required bool enabled,
  }) => _guard(() async {
    _validate(content);
    final count =
        await (db.update(
          db.memoryEntries,
        )..where((t) => t.id.equals(id))).write(
          MemoryEntriesCompanion(
            content: Value(content.trim()),
            enabled: Value(enabled),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (count == 0) throw const OperationFailure('记忆已删除');
  });

  Future<void> delete(String id) => _guard(() async {
    await (db.delete(db.memoryEntries)..where((t) => t.id.equals(id))).go();
  });

  /// 简单文本/关键字检索；作用域先过滤，长度预算包含来源，绝不跨助手返回。
  Future<List<MemoryEntry>> search(
    String query, {
    required String? assistantId,
    required MemoryScope scope,
    int maxCharacters = 4000,
  }) => _guard(() async {
    if (scope == MemoryScope.disabled) return [];
    final rows =
        await (db.select(db.memoryEntries)
              ..where(
                (t) =>
                    t.enabled.equals(true) &
                    ((assistantId == null
                            ? const Constant(false)
                            : t.assistantId.equals(assistantId)) |
                        (scope == MemoryScope.assistantAndGlobal
                            ? t.assistantId.isNull()
                            : const Constant(false))),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
            .get();
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final matched = rows
        .map(_fromRow)
        .where(
          (e) =>
              terms.isEmpty ||
              terms.any((t) => e.content.toLowerCase().contains(t)),
        )
        .toList();
    int score(MemoryEntry e) =>
        terms.where((t) => e.content.toLowerCase().contains(t)).length;
    matched.sort((a, b) {
      final rank = score(b).compareTo(score(a));
      return rank != 0 ? rank : b.updatedAt.compareTo(a.updatedAt);
    });
    final result = <MemoryEntry>[];
    var used = 0;
    for (final entry in matched) {
      final size = memoryText(entry).length;
      if (used + size > maxCharacters) continue;
      result.add(entry);
      used += size;
      if (result.length == 20) break;
    }
    return result;
  });

  void _validate(String content) {
    if (content.trim().isEmpty || content.length > 2000) {
      throw const OperationFailure('记忆需要 1–2000 字的内容');
    }
  }

  MemoryEntry _fromRow(MemoryEntryRow r) => MemoryEntry(
    id: r.id,
    content: r.content,
    assistantId: r.assistantId,
    sourceMessageId: r.sourceMessageId,
    sourceRunId: r.sourceRunId,
    enabled: r.enabled,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on Exception catch (e) {
      throw StorageFailure('读写记忆失败', cause: e);
    }
  }
}

String memoryText(MemoryEntry e) =>
    '[记忆 ${e.id}；范围 ${e.assistantId ?? '全局'}；'
    '来源消息 ${e.sourceMessageId ?? '用户编辑'}；运行 ${e.sourceRunId ?? '无'}]\n${e.content}\n';

@Riverpod(keepAlive: true)
Future<MemoryRepository> memoryRepository(Ref ref) async =>
    MemoryRepository(await ref.watch(appDatabaseProvider.future));

@riverpod
Stream<List<MemoryEntry>> memories(Ref ref) async* {
  yield* (await ref.watch(memoryRepositoryProvider.future)).watch();
}
