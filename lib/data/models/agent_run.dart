import 'context_policy.dart';
import 'permission_mode.dart';
import 'memory_entry.dart';
import 'model_catalog.dart';
import 'workspace.dart';
import 'skill_installation.dart';
import 'model_selection.dart';
import 'tool_policy.dart';
import 'openai_compat.dart';
import 'execution_scope.dart';
import 'tool_source.dart';
import 'mcp_server_profile.dart';

enum RunStatus {
  running,
  awaitingConfirmation,
  awaitingUser,
  completed,
  stopped,
  failed,
}

enum RunFinishReason {
  completed,
  cancelled,
  turnLimit,
  modelError,
  emptyResponse,
  storageError,
  executionError,
  contextLimit,
}

/// 运行使用的连接快照：编辑服务商不影响已开始的运行，密钥不在此保存。
class RunConnection {
  const RunConnection({
    required this.profileId,
    required this.protocol,
    required this.baseUrl,
    required this.requiresKey,
  });

  final String profileId;

  /// ApiProtocol.name 的持久化取值。
  final String protocol;
  final String baseUrl;
  final bool requiresKey;

  Map<String, dynamic> toJson() => {
    'profileId': profileId,
    'protocol': protocol,
    'baseUrl': baseUrl,
    'requiresKey': requiresKey,
  };

  factory RunConnection.fromJson(Map<String, dynamic> json) => RunConnection(
    profileId: json['profileId'] as String,
    protocol: json['protocol'] as String,
    baseUrl: json['baseUrl'] as String,
    requiresKey: json['requiresKey'] as bool? ?? true,
  );
}

/// 运行创建时固定的配置；后续编辑服务商、助手或模型只影响新运行。
class RunConfiguration {
  const RunConfiguration({
    required this.connection,
    required this.modelSelection,
    required this.systemPrompt,
    this.enabledTools = const {},
    this.toolSnapshots = const [],
    this.mcpServers = const [],
    this.skills = const [],
    this.workspace,
    this.mode = PermissionMode.basic,
    this.planExecutionMode = PermissionMode.basic,
    this.contextWindow,
    this.contextWindowSource,
    this.catalogMaxOutputTokens,
    this.contextPolicy = const ContextPolicy(),
    this.planId,
    this.planRevision,
    this.approvedPlan,
    this.memoryScope = MemoryScope.disabled,
    this.toolPolicies = const {},
    this.supportsReasoning = false,
    this.supportsImages = true,
    this.supportsTools = true,
    this.compatOverrides,
    this.executionScope = const ExecutionScope(),
  });

  final PermissionMode mode;

  /// 计划来源运行固定的返回档位，批准后不读取其他会话或后来的选择。
  final PermissionMode planExecutionMode;
  final int? contextWindow;

  /// 窗口来源（ContextWindowSource.name）：user/catalog/localDefault；
  /// 老数据为 null 时按 contextWindow 非空→user、空→localDefault 解读。
  final String? contextWindowSource;

  /// models.dev 目录输出上限快照；只用于本地输出预留，绝不下发请求。
  final int? catalogMaxOutputTokens;
  final ContextPolicy contextPolicy;

  /// 窗口来源枚举视图；兼容老快照的 null 来源字段。
  ContextWindowSource get resolvedWindowSource => windowSourceFromSnapshot(
    contextWindowSource,
    contextWindow: contextWindow,
  );
  final String? planId;
  final int? planRevision;
  final String? approvedPlan;
  final MemoryScope memoryScope;
  final RunConnection connection;
  final ModelSelection modelSelection;
  final String systemPrompt;
  final Set<String> enabledTools;
  final List<ToolSnapshot> toolSnapshots;
  final List<McpServerProfile> mcpServers;
  final List<SkillSnapshot> skills;
  final WorkspaceSnapshot? workspace;

  /// 由会话模式解析的实际策略快照，不接受助手级覆盖。
  final Map<String, ToolPolicy> toolPolicies;
  final bool supportsReasoning;
  final bool supportsImages;
  final bool supportsTools;
  final OpenAiCompat? compatOverrides;
  final ExecutionScope executionScope;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'planExecutionMode': planExecutionMode.name,
    'contextWindow': contextWindow,
    'contextWindowSource': contextWindowSource,
    'catalogMaxOutputTokens': catalogMaxOutputTokens,
    'contextPolicy': contextPolicy.toJson(),
    'planId': planId,
    'planRevision': planRevision,
    'approvedPlan': approvedPlan,
    'memoryScope': memoryScope.name,
    'connection': connection.toJson(),
    'modelSelection': modelSelection.toJson(),
    'systemPrompt': systemPrompt,
    'enabledTools': enabledTools.toList(),
    'toolSnapshots': toolSnapshots.map((t) => t.toJson()).toList(),
    'mcpServers': mcpServers.map((s) => s.toJson()).toList(),
    'workspace': workspace?.toJson(),
    'skills': skills.map((s) => s.toJson()).toList(),
    'toolPolicies': {
      for (final entry in toolPolicies.entries) entry.key: entry.value.name,
    },
    'supportsReasoning': supportsReasoning,
    'supportsImages': supportsImages,
    'supportsTools': supportsTools,
    'compatOverrides': compatOverrides?.toJson(),
    'executionScope': executionScope.toJson(),
  };

  factory RunConfiguration.fromJson(
    Map<String, dynamic> json,
  ) => RunConfiguration(
    mode: PermissionMode.values.byName(json['mode'] as String? ?? 'basic'),
    planExecutionMode: PermissionMode.values.byName(
      json['planExecutionMode'] as String? ?? 'basic',
    ),
    contextWindow: json['contextWindow'] as int?,
    contextWindowSource: json['contextWindowSource'] as String?,
    catalogMaxOutputTokens: json['catalogMaxOutputTokens'] as int?,
    contextPolicy: json['contextPolicy'] == null
        ? const ContextPolicy()
        : ContextPolicy.fromJson(json['contextPolicy'] as Map<String, dynamic>),
    planId: json['planId'] as String?,
    planRevision: json['planRevision'] as int?,
    approvedPlan: json['approvedPlan'] as String?,
    memoryScope: MemoryScope.values.byName(
      json['memoryScope'] as String? ?? 'disabled',
    ),
    workspace: json['workspace'] == null
        ? null
        : WorkspaceSnapshot.fromJson(json['workspace'] as Map<String, dynamic>),
    executionScope: ExecutionScope.fromJson(
      (json['executionScope'] as Map<String, dynamic>?) ?? {},
    ),
    connection: RunConnection.fromJson(
      json['connection'] as Map<String, dynamic>,
    ),
    modelSelection: ModelSelection.fromJson(
      json['modelSelection'] as Map<String, dynamic>,
    ),
    systemPrompt: json['systemPrompt'] as String? ?? '',
    supportsReasoning: json['supportsReasoning'] as bool? ?? false,
    supportsImages: json['supportsImages'] as bool? ?? true,
    supportsTools: json['supportsTools'] as bool? ?? true,
    compatOverrides: json['compatOverrides'] == null
        ? null
        : OpenAiCompat.fromJson(
            json['compatOverrides'] as Map<String, dynamic>,
          ),
    toolSnapshots: [
      for (final t in json['toolSnapshots'] as List? ?? [])
        ToolSnapshot.fromJson(t as Map<String, dynamic>),
    ],
    skills: [
      for (final s in json['skills'] as List? ?? [])
        SkillSnapshot.fromJson(s as Map<String, dynamic>),
    ],
    mcpServers: [
      for (final s in json['mcpServers'] as List? ?? [])
        McpServerProfile.fromJson(s as Map<String, dynamic>),
    ],
    enabledTools: {
      for (final tool in json['enabledTools'] as List? ?? const [])
        tool as String,
    },
    toolPolicies: {
      for (final entry
          in (json['toolPolicies'] as Map<String, dynamic>? ?? const {})
              .entries)
        entry.key: toolPolicyFromName(entry.value as String?),
    },
  );
}

/// 一次用户发送产生的运行；保存循环位置与计数，供中断后按已存状态恢复。
class AgentRun {
  const AgentRun({
    required this.id,
    required this.conversationId,
    required this.inputMessageId,
    required this.configuration,
    required this.createdAt,
    this.assistantId,
    this.currentMessageId,
    this.activeToolCallId,
    this.status = RunStatus.running,
    this.finishReason,
    this.turnCount = 0,
    this.modelAttemptCount = 0,
    this.maxTurns = defaultMaxTurns,
    this.finishedAt,
  });

  /// 默认不按轮数截断任务；0 表示没有轮次上限。
  static const defaultMaxTurns = 0;

  final String id;
  final String conversationId;
  final String? assistantId;

  /// 触发该运行的用户消息。
  final String inputMessageId;

  /// 当前分支末尾的消息。
  final String? currentMessageId;

  /// 正在等待确认或执行的工具调用。
  final String? activeToolCallId;

  final RunConfiguration configuration;
  final RunStatus status;
  final RunFinishReason? finishReason;
  final int turnCount;
  final int modelAttemptCount;

  /// 0 表示不限轮次；正数是本次运行明确指定的总轮次预算。
  final int maxTurns;

  final DateTime createdAt;
  final DateTime? finishedAt;

  AgentRun copyWith({
    String? currentMessageId,
    String? activeToolCallId,
    RunStatus? status,
    RunFinishReason? finishReason,
    int? turnCount,
    int? modelAttemptCount,
    DateTime? finishedAt,
    bool clearActiveToolCall = false,
  }) {
    return AgentRun(
      id: id,
      conversationId: conversationId,
      assistantId: assistantId,
      inputMessageId: inputMessageId,
      currentMessageId: currentMessageId ?? this.currentMessageId,
      activeToolCallId: clearActiveToolCall
          ? null
          : activeToolCallId ?? this.activeToolCallId,
      configuration: configuration,
      status: status ?? this.status,
      finishReason: finishReason ?? this.finishReason,
      turnCount: turnCount ?? this.turnCount,
      modelAttemptCount: modelAttemptCount ?? this.modelAttemptCount,
      maxTurns: maxTurns,
      createdAt: createdAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}
