import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/chat_message.dart';

part 'app_database.g.dart';

/// 会话表。数据类命名为 ConversationRow，与 data/models 的 Conversation 区分。
@DataClassName('ConversationRow')
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 0, max: 200)();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 消息表。
@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(
    Conversations,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get role => textEnum<ChatRole>()();
  TextColumn get content => text()();
  TextColumn get status => textEnum<ChatMessageStatus>()();
  TextColumn get modelName => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 服务商配置表。API Key 不入库，存 flutter_secure_storage。
@DataClassName('ProviderProfileRow')
class ProviderProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get baseUrl => text()();

  /// 模型 id 列表的 JSON 编码（`List<String>`）。
  TextColumn get modelsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 应用数据库，由 drift_flutter 负责各平台 sqlite 初始化。
@DriftDatabase(tables: [Conversations, Messages, ProviderProfiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'phase'));

  @override
  int get schemaVersion => 1;

  // --- 会话 ---

  /// 置顶优先，其余按更新时间倒序。
  Stream<List<ConversationRow>> watchConversationRows() {
    return (select(conversations)..orderBy([
          (t) => OrderingTerm.desc(t.pinned),
          (t) => OrderingTerm.desc(t.updatedAt),
        ]))
        .watch();
  }

  Future<void> insertConversation(ConversationsCompanion companion) {
    return into(conversations).insert(companion);
  }

  Future<int> updateConversationFields(
    String id,
    ConversationsCompanion fields,
  ) {
    return (update(conversations)..where((t) => t.id.equals(id))).write(fields);
  }

  /// 连带删除会话下所有消息。
  Future<void> deleteConversationCascade(String id) {
    return transaction(() async {
      await (delete(messages)..where((t) => t.conversationId.equals(id))).go();
      await (delete(conversations)..where((t) => t.id.equals(id))).go();
    });
  }

  // --- 消息 ---

  Stream<List<MessageRow>> watchMessageRows(String conversationId) {
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<void> insertMessage(MessagesCompanion companion) {
    return into(messages).insert(companion);
  }

  Future<int> updateMessageContent(
    String id, {
    required String content,
    required ChatMessageStatus status,
  }) {
    return (update(messages)..where((t) => t.id.equals(id))).write(
      MessagesCompanion(content: Value(content), status: Value(status)),
    );
  }

  // --- 服务商配置 ---

  Stream<List<ProviderProfileRow>> watchProviderProfileRows() {
    return (select(providerProfiles)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<ProviderProfileRow?> getProviderProfileRow(String id) {
    return (select(providerProfiles)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertProviderProfile(ProviderProfilesCompanion companion) {
    return into(providerProfiles).insertOnConflictUpdate(companion);
  }

  Future<int> deleteProviderProfileRow(String id) {
    return (delete(providerProfiles)..where((t) => t.id.equals(id))).go();
  }
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
}
