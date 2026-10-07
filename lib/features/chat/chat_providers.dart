import '../../data/datasources/local/model_catalog_cache.dart';
import '../../data/datasources/local/secure_key_storage.dart';
import '../../data/datasources/local/settings_storage.dart';
import '../../data/repositories/agent_context_repository.dart';
import '../../data/repositories/agent_run_repository.dart';
import '../../data/repositories/mcp_server_repository.dart';
import '../../data/repositories/memory_repository.dart';
import '../../data/repositories/model_request_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/skill_repository.dart';
import '../../data/repositories/tool_call_repository.dart';
import '../../data/repositories/workspace_repository.dart';
import '../../data/repositories/web_search_repository.dart';
import '../commands/command_channel_driver.dart';
import '../commands/command_channels_controller.dart';
import '../mcp/mcp_connections.dart';
import '../workspace/process_driver.dart';
import '../tasks/command_task_controller.dart';
import 'context/chat_context_coordinator.dart';
import 'runtime/chat_run_factory.dart';
import 'runtime/chat_tool_runtime.dart';
import 'runtime/model_turn_runner.dart';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/datasources/local/artifact_storage.dart';
import '../../data/datasources/local/attachment_storage.dart';
import '../../data/models/assistant.dart';
import '../../data/repositories/assistant_repository.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../providers/provider_factory.dart';
import '../execution/channel_driver.dart';
import '../tools/http_transport.dart';
import '../tools/tool.dart';
import '../tools/tool_registry.dart';
import 'active_conversation.dart';
import 'conversation_providers.dart';
import 'model_retry.dart';
part 'chat_providers.g.dart';

/// 内置工具集：文件路径由当前环境或授权 URI 解释，HTTP 走独立 Dio 实例。
///
/// 单独开注入点是为了让测试能替换工具集（记录调用的假工具、替代网络实现），
/// 与 [aiProviderFactoryProvider] 同样的理由。
@Riverpod(keepAlive: true)
ToolRegistry toolRegistry(Ref ref) {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  ref.onDispose(() => dio.close(force: true));
  return buildBuiltInRegistry(
    platform: () => ref.read(channelDriverProvider),
    httpFetch: (request) => fetchToolHttp(dio, request),
  );
}

/// 单一重试预算，协议传输不再叠加第二层自动重试。
@Riverpod(keepAlive: true)
ModelRetryPolicy modelRetryPolicy(Ref ref) => const ModelRetryPolicy();

/// 工具运行的存储能力：会话附件、按会话隔离的产物目录与产物登记。
///
/// 附件索引由仓储注入：数据源只依赖模型与文件系统。
@Riverpod(keepAlive: true)
Future<ArtifactStorage> artifactStorage(Ref ref) async {
  final attachments = await ref.watch(attachmentStorageProvider.future);
  final repository = await ref.watch(conversationRepositoryProvider.future);
  return ArtifactStorage(
    root: attachments.root,
    loadAttachments: repository.availableAttachmentsFor,
    saveAttachment: repository.saveAttachment,
  );
}

/// 助手列表；先确保内置助手存在再发出。
@Riverpod(keepAlive: true)
Stream<List<Assistant>> assistants(Ref ref) async* {
  if (!ref.mounted) return;
  final repository = await ref.watch(assistantRepositoryProvider.future);
  if (!ref.mounted) return;
  await repository.ensureDefault();
  if (!ref.mounted) return;
  yield* repository.watchAssistants();
}

/// 当前生效的助手。
///
/// 已打开的会话用会话绑定的助手；新会话用草稿助手；两者都没有、
/// 或绑定的助手已被删除时回退到列表第一个（内置助手）。
///
/// 只读内存中的列表与线程：调用方先 await 好这两路数据（见
/// [awaitAssistantContext]），避免把「尚未加载」误判成「没有助手」。
@Riverpod(keepAlive: true, dependencies: [assistants, conversationThread])
Assistant? currentAssistant(Ref ref, ActiveConversationState active) {
  final assistants = ref.watch(assistantsProvider).value ?? const <Assistant>[];
  final conversationId = active.conversationId;
  final bound = conversationId == null
      ? null
      : ref
            .watch(conversationThreadProvider(conversationId))
            .value
            ?.conversation
            .assistantId;
  return resolveAssistant(
    assistants,
    draftAssistantId: active.draftAssistantId,
    boundAssistantId: bound,
  );
}

/// 从助手列表里解析当前助手。
///
/// 优先级：本次会话显式选择（草稿）→ 会话绑定的助手 → 列表第一个。
/// 草稿在会话建立后继续代表「用户刚为这个会话选定的助手」，因此排在绑定的
/// 助手之前；下发到会话的绑定关系由 `selectAssistant` 落库。
///
/// 发送（[awaitAssistantContext]）与模型选择共用这一处规则。
Assistant? resolveAssistant(
  List<Assistant> assistants, {
  String? draftAssistantId,
  String? boundAssistantId,
}) {
  if (assistants.isEmpty) return null;
  final wanted = draftAssistantId ?? boundAssistantId;
  if (wanted != null) {
    for (final assistant in assistants) {
      if (assistant.id == wanted) return assistant;
    }
  }
  return assistants.first;
}

/// 发送前的助手解析：先把列表等就绪，再按当前会话/草稿取助手。
///
/// 供 聊天发送入口 使用；不使用 provider 的 `.value`，那样在流式
/// provider 已就绪时也可能读到 null。
Future<Assistant?> awaitAssistantContext(Ref ref) async {
  final assistants = await ref.read(assistantsProvider.future);
  if (assistants.isEmpty) return null;
  final active = ref.read(activeConversationProvider);
  var boundId = active.draftAssistantId;
  final conversationId = active.conversationId;
  if (conversationId != null) {
    final repository = await ref.read(conversationRepositoryProvider.future);
    final thread = await repository.getThread(conversationId);
    boundId = thread?.conversation.assistantId ?? boundId;
  }
  return resolveAssistant(
    assistants,
    draftAssistantId: active.draftAssistantId,
    boundAssistantId: boundId,
  );
}

/// 装配点只提供依赖；目录发现、运行创建和资源启动由对应组件显式调用。
@Riverpod(keepAlive: true, dependencies: [settingsStorage, webSearchRepository])
Future<ChatToolRuntimeFactory> chatToolRuntimeFactory(Ref ref) async {
  return ChatToolRuntimeFactory(
    builtIns: ref.watch(toolRegistryProvider),
    web: ref.watch(webSearchRepositoryProvider),
    conversations: await ref.watch(conversationRepositoryProvider.future),
    runs: await ref.watch(agentRunRepositoryProvider.future),
    calls: await ref.watch(toolCallRepositoryProvider.future),
    assistants: await ref.watch(assistantRepositoryProvider.future),
    plans: await ref.watch(planRepositoryProvider.future),
    memories: await ref.watch(memoryRepositoryProvider.future),
    // 未启用的可选能力不初始化目录、清理安装状态或访问平台进程桥。
    loadWorkspaces: () => ref.read(workspaceRepositoryProvider.future),
    loadSkills: () => ref.read(skillRepositoryProvider.future),
    loadMcpServers: () => ref.read(mcpServerRepositoryProvider.future),
    settings: ref.watch(settingsStorageProvider),
    platform: () => ref.read(channelDriverProvider),
    commands: () => ref.read(commandChannelDriverProvider),
    processes: () => ref.read(processDriverProvider),
    tasks: () => ref.read(commandTaskControllerProvider.notifier),
    connections: () => ref.read(mcpConnectionsProvider),
    commandSnapshots: () => commandSnapshots(ref),
  );
}

@Riverpod(keepAlive: true, dependencies: [chatToolRuntimeFactory, modelCatalog])
Future<ChatRunFactory> chatRunFactory(Ref ref) async {
  return ChatRunFactory(
    conversations: await ref.watch(conversationRepositoryProvider.future),
    runs: await ref.watch(agentRunRepositoryProvider.future),
    plans: await ref.watch(planRepositoryProvider.future),
    modelCatalog: await ref.watch(modelCatalogProvider.future),
    tools: await ref.watch(chatToolRuntimeFactoryProvider.future),
  );
}

@Riverpod(keepAlive: true)
Future<ChatContextCoordinator> chatContextCoordinator(Ref ref) async {
  return ChatContextCoordinator(
    conversations: await ref.watch(conversationRepositoryProvider.future),
    runs: await ref.watch(agentRunRepositoryProvider.future),
    summaries: await ref.watch(agentContextRepositoryProvider.future),
    requests: await ref.watch(modelRequestRepositoryProvider.future),
    keys: ref.watch(secureKeyStorageProvider),
    buildProvider: ref.watch(aiProviderFactoryProvider),
  );
}

@Riverpod(keepAlive: true)
Future<ModelTurnRunnerFactory> modelTurnRunnerFactory(Ref ref) async {
  return ModelTurnRunnerFactory(
    conversations: await ref.watch(conversationRepositoryProvider.future),
    runs: await ref.watch(agentRunRepositoryProvider.future),
    requests: await ref.watch(modelRequestRepositoryProvider.future),
    keys: ref.watch(secureKeyStorageProvider),
    buildProvider: ref.watch(aiProviderFactoryProvider),
    retryPolicy: ref.watch(modelRetryPolicyProvider),
    contexts: await ref.watch(chatContextCoordinatorProvider.future),
  );
}
