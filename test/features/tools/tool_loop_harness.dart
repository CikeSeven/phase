import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/assistant.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/datasources/local/artifact_storage.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/repositories/agent_run_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/data/repositories/row_mappers.dart';
import 'package:phase/data/repositories/tool_call_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/model_selection.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/tools/tool_executor.dart';
import 'package:phase/features/execution/channel_driver.dart';
import 'package:phase/features/execution/execution_controller.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_secure_storage.dart';
import '../../support/fake_channel_driver.dart';

/// 一段文本回答的事件序列。
Stream<ChatChunk> textTurn(String text, {String partId = 'text_0'}) {
  return Stream.fromIterable([
    PartStart(partId: partId, kind: PartKind.text),
    TextDelta(partId: partId, text: text),
    PartEnd(
      partId: partId,
      part: TextPart(text: text, partId: partId),
    ),
    const ResponseEnd(),
  ]);
}

/// 一轮工具调用；[text] 非空时先给出正文（模型边说边调）。
Stream<ChatChunk> toolTurn({
  required String callId,
  required String toolName,
  required String arguments,
  String? text,
}) {
  return multiToolTurn([
    (callId: callId, toolName: toolName, arguments: arguments),
  ], text: text);
}

/// 一轮多个工具调用：事件顺序就是调用顺序，执行按同一顺序串行。
Stream<ChatChunk> multiToolTurn(
  List<({String callId, String toolName, String arguments})> calls, {
  String? text,
}) {
  return Stream.fromIterable([
    if (text != null) ...[
      const PartStart(partId: 'text_0', kind: PartKind.text),
      TextDelta(partId: 'text_0', text: text),
      PartEnd(
        partId: 'text_0',
        part: TextPart(text: text, partId: 'text_0'),
      ),
    ],
    for (final (index, call) in calls.indexed) ...[
      PartStart(partId: 'tool_$index', kind: PartKind.toolCall),
      ToolCallDelta(
        partId: 'tool_$index',
        callId: call.callId,
        toolName: call.toolName,
        argumentsFragment: call.arguments,
      ),
      PartEnd(
        partId: 'tool_$index',
        part: ToolCallPart(toolCallId: call.callId),
      ),
    ],
    const ResponseEnd(),
  ]);
}

/// 记录每次执行的假工具：验证「是否真的被派发」与执行顺序。
class RecordingTool extends Tool {
  RecordingTool({
    required this.name,
    this.channel = ExecutionChannel.app,
    this.policy = ToolPolicy.allow,
    this.outcome = const ToolOutcome.success('已执行'),
    this.schema = const {
      'type': 'object',
      'properties': <String, dynamic>{},
      'additionalProperties': false,
    },
  });

  @override
  final String name;

  @override
  final ExecutionChannel channel;

  final ToolPolicy policy;

  /// 固定结果；需要按参数区分时用 [outcomeOf]。
  final ToolOutcome outcome;

  /// 每次执行的结果由参数决定（返回 null 用 [outcome]）。
  ToolOutcome Function(Map<String, dynamic> arguments)? outcomeOf;

  /// 自定义执行体：需要等待取消或按调用区分的场景用它。
  Future<ToolOutcome> Function(
    Map<String, dynamic> arguments,
    RunCancellation cancellation,
  )?
  executeAsync;

  final Map<String, dynamic> schema;

  /// 已执行的参数，按执行顺序；未执行时为空。
  final executions = <Map<String, dynamic>>[];

  @override
  String get description => '测试工具 $name';

  @override
  Map<String, dynamic> get inputSchema => schema;

  @override
  Set<String> get requiredCapabilities => const {};

  @override
  ToolPolicy get defaultPolicy => policy;

  @override
  String describeAction(Map<String, dynamic> arguments) => '$name（测试）';

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    executions.add(arguments);
    cancellation.throwIfCancelled();
    if (executeAsync case final execute?) {
      return execute(arguments, cancellation);
    }
    return outcomeOf?.call(arguments) ?? outcome;
  }
}

/// 按脚本给出响应的假 provider：一次 `streamChat` 取一轮。
class ScriptedProvider implements AiProvider {
  ScriptedProvider(this.protocol);

  @override
  final ApiProtocol protocol;

  /// 每轮响应，按调用顺序取用。
  final turns = <Stream<ChatChunk>>[];

  /// 每次真实请求的入参（含重试），按顺序保存。
  final requests = <ChatRequest>[];

  @override
  Future<List<ProfileModel>> listModels() async => const [];

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) {
    requests.add(request);
    if (turns.isEmpty) {
      throw StateError('没有更多预设响应（第 ${requests.length} 次请求）');
    }
    return turns.removeAt(0);
  }
}

/// 工具循环测试的装配：临时加密库 + ProviderContainer + 脚本化模型响应。
///
/// Drift 在同 isolate 打开：widget 与 fake-async 环境无法驱动后台 isolate。
class ToolLoopHarness {
  ToolLoopHarness._(
    this.container,
    this.tempDir,
    this.database,
    this.provider,
    this.profile,
  );

  static const _dbKey =
      'a1b2c3d4e5f60718293a4b5c6d7e8f90'
      'a1b2c3d4e5f60718293a4b5c6d7e8f90';

  final ProviderContainer container;
  final Directory tempDir;
  final AppDatabase database;
  final ScriptedProvider provider;
  final ProviderProfile profile;

  /// [registry] 替换内置工具集；[models] 替换模型列表（能力开关）。
  static Future<ToolLoopHarness> create({
    ToolRegistry? registry,
    List<ProfileModel>? models,
    AiProvider Function(ProviderProfile profile, String apiKey)? factory,
    Future<void> Function(Attachment attachment)? saveArtifact,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final tempDir = Directory.systemTemp.createTempSync('phase_tool_loop');
    final database = openAppDatabase(
      path: p.join(tempDir.path, 'phase.sqlite'),
      hexKey: _dbKey,
      background: false,
    );
    final keys = FakeSecureStorage();
    final scripted = ScriptedProvider(ApiProtocol.openaiCompletions);
    final profileRepository = ProviderProfileRepository(
      database,
      SecureKeyStorage(keys),
    );
    final profile = await profileRepository.createProfile(
      name: '测试服务商',
      baseUrl: 'https://example.com/v1',
      protocol: ApiProtocol.openaiCompletions,
      models: models ?? const [ProfileModel(id: 'model-a', enabled: true)],
      defaultModel: 'model-a',
    );

    if (registry != null) {
      final assistants = AssistantRepository(database);
      final assistant = await assistants.ensureDefault();
      await assistants.save(
        assistant.copyWith(
          toolPolicy: ToolPolicyConfig(
            policies: {
              for (final tool in registry.tools) tool.name: tool.defaultPolicy,
            },
          ),
        ),
      );
    }
    final container = ProviderContainer(
      overrides: [
        channelDriverProvider.overrideWith((ref) {
          final driver = FakeChannelDriver();
          ref.onDispose(() => unawaited(driver.dispose()));
          return driver;
        }),
        sharedPreferencesProvider.overrideWith((ref) => preferences),
        appDatabaseProvider.overrideWith((ref) => database),
        secureKeyStorageProvider.overrideWith((ref) => SecureKeyStorage(keys)),
        // 附件与产物写到临时目录，不依赖平台文档目录。
        attachmentStorageProvider.overrideWith(
          (ref) => AttachmentStorage(Directory(p.join(tempDir.path, 'files'))),
        ),
        aiProviderFactoryProvider.overrideWith(
          (ref) =>
              (profile, apiKey) => factory?.call(profile, apiKey) ?? scripted,
        ),
        if (saveArtifact != null)
          artifactStorageProvider.overrideWith(
            (ref) => ArtifactStorage(
              root: Directory(p.join(tempDir.path, 'files')),
              loadAttachments: (id) async =>
                  (await ref.read(conversationRepositoryProvider.future))
                      .attachmentsFor(id),
              saveAttachment: saveArtifact,
            ),
          ),
        if (registry != null)
          toolRegistryProvider.overrideWith((ref) => registry),
      ],
    );
    // autoDispose 的 provider 在测试里没有 widget 监听，需持订阅防中途销毁。
    addTearDown(container.listen(chatControllerProvider, (_, _) {}).close);
    addTearDown(container.listen(modelSelectionProvider, (_, _) {}).close);
    addTearDown(() async {
      container.dispose();
      await database.close();
      tempDir.deleteSync(recursive: true);
    });
    return ToolLoopHarness._(container, tempDir, database, scripted, profile);
  }

  ChatController controller() =>
      container.read(chatControllerProvider.notifier);

  /// 测试展示端消费真实待确认状态，决定仍提交给应用级控制器。
  set onConfirmation(
    Future<ToolDecision> Function(ToolConfirmationRequest) handler,
  ) {
    final subscription = container.listen(executionControllerProvider, (
      previous,
      next,
    ) {
      final request = next.confirmation;
      if (request == null || identical(previous?.confirmation, request)) return;
      unawaited(
        handler(request).then((decision) {
          container
              .read(executionControllerProvider.notifier)
              .decide(request.record.runId, request.record.id, decision);
        }),
      );
    });
    addTearDown(subscription.close);
  }

  ChatState state() => container.read(chatControllerProvider);

  String? conversationId() =>
      container.read(activeConversationProvider).conversationId;

  /// 会话产物目录（工具写入的位置）。
  Directory artifactsDir(String conversationId) =>
      Directory(p.join(tempDir.path, 'files', 'artifacts', conversationId));

  Future<ConversationRepository> conversations() =>
      container.read(conversationRepositoryProvider.future);

  Future<ToolCallRepository> toolCalls() =>
      container.read(toolCallRepositoryProvider.future);

  Future<AgentRunRepository> runs() =>
      container.read(agentRunRepositoryProvider.future);

  /// 当前分支（父链顺序）。
  Future<List<ChatMessage>> branch() async {
    final repository = await conversations();
    final thread = await repository.getThread(conversationId()!);
    return thread!.branch;
  }

  /// 当前分支对应的运行。
  Future<AgentRun> latestRun() async {
    final messages = await branch();
    final runId = messages.lastWhere((message) => message.runId != null).runId!;
    final repository = await runs();
    return (await repository.getById(runId))!;
  }

  /// 本次会话的全部工具记录，按协议调用 id 索引。
  Future<Map<String, ToolCallRecord>> recordsByCall() async {
    final rows = await (database.select(
      database.toolCalls,
    )..orderBy([(t) => OrderingTerm.asc(t.providerCallId)])).get();
    final records = <String, ToolCallRecord>{};
    for (final row in rows) {
      final record = toolCallFromRow(row);
      final callId = record.providerCallId;
      if (callId != null) records[callId] = record;
    }
    return records;
  }

  /// 记录引用的结果消息正文。
  Future<String?> resultTextOf(ToolCallRecord record) async {
    final messageId = record.resultMessageId;
    if (messageId == null) return null;
    final row = await (database.select(
      database.messages,
    )..where((t) => t.id.equals(messageId))).getSingleOrNull();
    if (row == null) return null;
    return messageFromRow(row).parts.whereType<TextPart>().firstOrNull?.text;
  }

  /// 等待条件成立：发送、停止与工具执行都有多次异步落库。
  Future<void> waitUntil(FutureOr<bool> Function() condition) async {
    var met = false;
    for (var attempt = 0; attempt < 200 && !met; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      met = await condition();
    }
    expect(met, isTrue, reason: '等待条件超时');
  }
}
