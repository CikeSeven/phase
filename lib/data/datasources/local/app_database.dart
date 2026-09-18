import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/logger.dart';
import '../../models/agent_run.dart';
import '../../models/chat_message.dart';
import '../../models/tool_call_record.dart';
import '../../models/tool_policy.dart';
import 'database_key.dart';
import 'key_store.dart';

part 'app_database.g.dart';

/// 服务商配置；API Key 不入库，按 id 存 SecureKeyStorage。
@DataClassName('ProviderProfileRow')
class ProviderProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get protocol => text()();
  TextColumn get baseUrl => text()();
  BoolColumn get requiresKey => boolean().withDefault(const Constant(true))();

  /// 创建时选用的预设 id；只用于回填表单。
  TextColumn get presetId => text().withDefault(const Constant('custom'))();

  /// 该服务商默认使用的模型 id；为空时回退到启用的第一个模型。
  TextColumn get defaultModel => text().nullable()();

  /// OpenAI 兼容协议的差异声明（OpenAiCompat JSON）。
  TextColumn get compatJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 服务商下的模型配置；profile 删除时级联删除。
@DataClassName('ModelRow')
class Models extends Table {
  TextColumn get profileId =>
      text().references(ProviderProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get modelId => text()();
  TextColumn get displayName => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get supportsReasoning =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get supportsTools =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get supportsImages =>
      boolean().withDefault(const Constant(false))();
  IntColumn get contextWindow => integer().nullable()();
  IntColumn get maxOutputTokens => integer().nullable()();

  /// 采样温度；未设置时不下发。
  RealColumn get temperature => real().nullable()();

  @override
  Set<Column> get primaryKey => {profileId, modelId};
}

/// 助手；删除助手不删除已有会话。
@DataClassName('AssistantRow')
class Assistants extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get systemPrompt => text().withDefault(const Constant(''))();

  /// ModelSelection 的 JSON；未设置默认模型时为 null。
  TextColumn get defaultSelectionJson => text().nullable()();

  /// 工具名 → 策略 的 JSON 对象。
  TextColumn get toolPolicyJson => text().withDefault(const Constant('{}'))();
  TextColumn get skillIdsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 会话；currentMessageId 指向当前分支末尾。
@DataClassName('ConversationRow')
class Conversations extends Table {
  TextColumn get id => text()();

  /// 助手被删除后置空，会话保留并允许重新选择助手。
  TextColumn get assistantId => text().nullable()();
  TextColumn get title => text().withLength(min: 0, max: 200)();
  TextColumn get currentMessageId => text().nullable()();

  /// ModelSelection 的 JSON；为空时用助手默认值。
  TextColumn get selectionJson => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 消息；父子指针构成消息树，parts_json 保存有序内容块。
@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(Conversations, #id, onDelete: KeyAction.cascade)();

  /// 消息树父指针；null 表示本会话第一条消息。
  TextColumn get parentId => text().nullable()();
  TextColumn get runId => text().nullable()();
  TextColumn get role => textEnum<ChatRole>()();
  TextColumn get status => textEnum<MessageStatus>()();
  TextColumn get partsJson => text().withDefault(const Constant('[]'))();
  TextColumn get modelLabel => text().nullable()();

  /// TokenUsage 的 JSON；接口未提供用量时为 null。
  TextColumn get usageJson => text().nullable()();
  IntColumn get thinkingDurationMs => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 附件索引；二进制在 AttachmentStorage，抽取文本另有文件。
@DataClassName('AttachmentRow')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get mimeType => text()();
  IntColumn get size => integer()();
  TextColumn get localPath => text()();
  TextColumn get sha256 => text().nullable()();
  TextColumn get extractedTextPath => text().nullable()();

  /// 抽取失败的原因（扫描件等）；成功或未尝试为 null。
  TextColumn get extractionError => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 运行；保存循环位置与计数，供中断后按已存状态恢复。
@DataClassName('AgentRunRow')
class AgentRuns extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get assistantId => text().nullable()();
  TextColumn get inputMessageId => text()();
  TextColumn get currentMessageId => text().nullable()();
  TextColumn get activeToolCallId => text().nullable()();

  /// RunConfiguration 的 JSON；密钥不在其中。
  TextColumn get configurationJson => text()();
  TextColumn get status => textEnum<RunStatus>()();
  TextColumn get finishReason => textEnum<RunFinishReason>().nullable()();
  IntColumn get turnCount => integer().withDefault(const Constant(0))();
  IntColumn get modelAttemptCount => integer().withDefault(const Constant(0))();
  IntColumn get maxTurns => integer()();

  /// TokenUsage 的 JSON；未收口时为 null。
  TextColumn get usageJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 工具调用记录：参数、用户决定与结果的唯一业务事实来源。
@DataClassName('ToolCallRow')
class ToolCalls extends Table {
  TextColumn get id => text()();
  TextColumn get runId =>
      text().references(AgentRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get assistantMessageId => text()();
  TextColumn get resultMessageId => text().nullable()();

  /// 模型协议自己的调用 id，仅用于结果回填。
  TextColumn get providerCallId => text().nullable()();
  TextColumn get toolName => text()();
  TextColumn get argumentsJson => text()();
  TextColumn get sourceJson => text().nullable()();
  TextColumn get providerDataJson => text().nullable()();
  TextColumn get target => text().nullable()();
  TextColumn get channel => textEnum<ExecutionChannel>()();
  TextColumn get defaultPolicy => textEnum<ToolPolicy>()();
  TextColumn get status => textEnum<ToolCallStatus>()();
  TextColumn get decision => textEnum<ToolDecision>().nullable()();
  DateTimeColumn get confirmationRequestedAt => dateTime().nullable()();
  DateTimeColumn get confirmationExpiresAt => dateTime().nullable()();
  DateTimeColumn get decidedAt => dateTime().nullable()();
  TextColumn get result => text().nullable()();

  /// 产物附件 id 列表的 JSON。
  TextColumn get artifactsJson => text().withDefault(const Constant('[]'))();
  TextColumn get errorCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// MCP 配置和发现目录；凭据只保存引用。
@DataClassName('McpServerRow')
class McpServers extends Table {
  TextColumn get id => text()();
  TextColumn get profileJson => text()();
  TextColumn get toolsJson => text().withDefault(const Constant('[]'))();
  TextColumn get protocolVersion => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Skill 当前安装版本，旧版本由运行快照与文件保留规则管理。
@DataClassName('SkillInstallationRow')
class SkillInstallations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get snapshotJson => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get deleting => boolean().withDefault(const Constant(false))();
  DateTimeColumn get installedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

/// 当前初版业务库。
///
/// 数据库从创建时加密；schema 变更随初版演进，不保留开发期旧 schema 的
/// 升级链（见 AGENTS.md §5）。
@DriftDatabase(
  tables: [
    ProviderProfiles,
    Models,
    Assistants,
    Conversations,
    Messages,
    Attachments,
    AgentRuns,
    ToolCalls,
    McpServers,
    SkillInstallations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// schema 变更记录：
  /// 1 初版契约；2 附件抽取错误；3 模型温度；4 MCP 配置与工具来源；5 Skills。
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // 本次装机只允许已安装 E1 测试包的增量升级，不补历史开发期链。
    onUpgrade: (migrator, from, to) async {
      if (from != 4 || to != 5) {
        throw const OperationFailure('此测试安装的数据结构不支持直接升级，请保留原数据');
      }
      await migrator.createTable(skillInstallations);
      await migrator.addColumn(assistants, assistants.skillIdsJson);
    },
    beforeOpen: _prepareDatabase,
  );

  /// 每次打开都确保外键与索引就绪（建表、升级后都会执行）。
  Future<void> _prepareDatabase(OpeningDetails details) async {
    // 删除人工核验机制时一并收口其挂起状态；在枚举解码前执行，保留消息和动作记录。
    await customStatement(
      "UPDATE tool_calls SET status = 'failed', error_code = 'interrupted', "
      "result = REPLACE(REPLACE(COALESCE(result, '上次调用没有返回完整结果。'), '请核验', '可读取最新状态'), '结果未确认', '响应未完整返回') "
      "WHERE status = 'unknown'",
    );
    await customStatement(
      "UPDATE agent_runs SET status = 'failed', finish_reason = 'executionError', "
      "finished_at = COALESCE(finished_at, strftime('%s', 'now')) WHERE status = 'awaitingResult'",
    );
    // 引用约束需要显式打开；索引围绕实际查询建立。
    await customStatement('PRAGMA foreign_keys = ON');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_conversations_pinned_updated '
      'ON conversations (pinned DESC, updated_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_conversation '
      'ON messages (conversation_id, created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_parent ON messages (parent_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_run ON messages (run_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tool_calls_run ON tool_calls (run_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tool_calls_status '
      'ON tool_calls (status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tool_calls_created '
      'ON tool_calls (created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_agent_runs_conversation '
      'ON agent_runs (conversation_id, status)',
    );
  }

  /// 校验实际链接的 SQLite 支持加密；上游 sqlite3 没有 cipher pragma。
  Future<void> assertEncryptionAvailable() async {
    final rows = await customSelect('PRAGMA cipher;').get();
    if (rows.isEmpty) {
      throw StateError('数据库未启用加密：PRAGMA cipher 无结果');
    }
  }
}

/// 打开设备上的加密数据库；密钥由 [DatabaseKey] 提供。
///
/// [background] 为 true 时在后台 isolate 打开与执行 PRAGMA（生产路径，
/// 不阻塞首帧）；widget 测试的 fake-async 环境无法驱动后台 isolate，
/// 此时传 false 在同 isolate 打开。
AppDatabase openAppDatabase({
  required String path,
  required String hexKey,
  bool background = true,
  bool logStatements = false,
}) {
  final file = File(path);
  // ignore: prefer_function_declarations_over_variables
  final setup = (rawDb) => rawDb.execute(sqliteKeyPragma(hexKey));

  final executor = background
      ? NativeDatabase.createInBackground(
          file,
          setup: setup,
          logStatements: logStatements,
        )
      : NativeDatabase(file, setup: setup, logStatements: logStatements);
  return AppDatabase(executor);
}

@Riverpod(keepAlive: true)
Future<AppDatabase> appDatabase(Ref ref) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final database = await openDeviceDatabase(
      directory: directory,
      keyStore: const SecureKeyStore(),
    );
    ref.onDispose(database.close);
    return database;
  } on Exception catch (e, st) {
    AppLogger.error('打开数据库失败', e, st);
    throw UnknownFailure('打开数据库失败', cause: e);
  }
}

/// 打开设备上的加密数据库，并保证它确实是加密库。
///
/// 数据库从创建时加密，因此磁盘上的文件必须是密文（SQLite3MultipleCiphers
/// 的头部不是 `SQLite format 3`）。若遇见明文文件——例如未加密的原型库——
/// 它不是本应用的数据格式，连同旧密钥一并清理后重建；否则它会被当成明文
/// 库打开，密钥形同虚设，表结构也对不上。
Future<AppDatabase> openDeviceDatabase({
  required Directory directory,
  required KeyStore keyStore,
  bool background = true,
}) async {
  final path = p.join(directory.path, 'phase.sqlite');
  final key = DatabaseKey(keyStore);
  if (isPlaintextDatabase(path)) {
    AppLogger.warning('检测到非加密数据库文件，清理后重建：$path');
    key.delete();
    _deleteDatabaseFiles(path);
  }
  final hexKey = await key.readOrCreate();
  final database = openAppDatabase(
    path: path,
    hexKey: hexKey,
    background: background,
  );
  await database.assertEncryptionAvailable();
  return database;
}

/// 文件是否为明文 SQLite 库（SQLite3MultipleCiphers 的密文没有这个文件头）。
bool isPlaintextDatabase(String path) {
  final file = File(path);
  if (!file.existsSync()) return false;
  final RandomAccessFile handle;
  try {
    handle = file.openSync();
  } on FileSystemException {
    return false;
  }
  try {
    if (handle.lengthSync() < 16) return false;
    final header = handle.readSync(16);
    return utf8.decode(header, allowMalformed: true) == 'SQLite format 3 ';
  } finally {
    handle.closeSync();
  }
}

void _deleteDatabaseFiles(String path) {
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final file = File('$path$suffix');
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (e, st) {
      AppLogger.error('清理数据库文件失败', e, st);
    }
  }
}
