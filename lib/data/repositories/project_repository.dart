import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../datasources/local/app_database.dart';
import '../models/attachment.dart';
import '../models/project.dart';
import '../models/workspace.dart';
import 'row_mappers.dart';
import 'workspace_repository.dart';

part 'project_repository.g.dart';

class ProjectRepository {
  ProjectRepository(this.db, this.workspaces);

  final AppDatabase db;
  final WorkspaceRepository workspaces;

  Project _project(ProjectRow row) => Project(
    id: row.id,
    name: row.name,
    workspaceId: row.workspaceId,
    createdAt: row.createdAt,
  );

  Stream<List<Project>> watchProjects() async* {
    try {
      final query = db.select(db.projects)
        ..orderBy([
          (t) => OrderingTerm.desc(t.createdAt),
          (t) => OrderingTerm.asc(t.id),
        ]);
      yield* query.watch().map((rows) => rows.map(_project).toList());
    } on Failure {
      rethrow;
    } on Exception catch (error) {
      throw StorageFailure('读取项目列表失败，请重试', cause: error);
    }
  }

  Stream<Project?> watchProject(String id) async* {
    try {
      yield* (db.select(db.projects)..where((t) => t.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _project(row));
    } on Failure {
      rethrow;
    } on Exception catch (error) {
      throw StorageFailure('读取项目失败，请重试', cause: error);
    }
  }

  Future<Project?> get(String id) => _records(() async {
    final row = await (db.select(
      db.projects,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _project(row);
  });

  Future<Project> create(String name) => _records(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 100) {
      throw const OperationFailure('项目名称需为 1–100 个字符');
    }
    final id = generateId();
    final workspace = await workspaces.create(
      trimmed,
      id: id,
      kind: WorkspaceKind.project,
      createOwner: (workspace) async {
        await db
            .into(db.projects)
            .insert(
              ProjectsCompanion.insert(
                id: id,
                name: trimmed,
                workspaceId: workspace.id,
                createdAt: workspace.createdAt,
              ),
            );
      },
    );
    return Project(
      id: id,
      name: trimmed,
      workspaceId: workspace.id,
      createdAt: workspace.createdAt,
    );
  });

  Stream<List<Attachment>> watchAttachments(String id) async* {
    try {
      final query = db.select(db.attachments)
        ..where((t) => t.projectId.equals(id))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      yield* query.watch().map((rows) => rows.map(attachmentFromRow).toList());
    } on Failure {
      rethrow;
    } on Exception catch (error) {
      throw StorageFailure('读取项目资料失败，请重试', cause: error);
    }
  }

  Future<Attachment> attachment(String projectId, String attachmentId) =>
      _records(() async {
        final row =
            await (db.select(db.attachments)..where(
                  (t) =>
                      t.id.equals(attachmentId) & t.projectId.equals(projectId),
                ))
                .getSingleOrNull();
        if (row == null) throw const OperationFailure('项目资料已不存在');
        return attachmentFromRow(row);
      });

  Future<T> _records<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on Exception catch (error) {
      throw StorageFailure('项目读取或保存失败，请重试', cause: error);
    }
  }
}

@Riverpod(keepAlive: true)
Future<ProjectRepository> projectRepository(Ref ref) async => ProjectRepository(
  await ref.watch(appDatabaseProvider.future),
  await ref.watch(workspaceRepositoryProvider.future),
);
