import 'chat_message.dart';
import 'model_selection.dart';
import 'tool_policy.dart';
import 'openai_compat.dart';

enum RunStatus {
  running,
  awaitingConfirmation,

  /// 动作已派发但结果未取得，运行暂停等待核验。
  awaitingResult,
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
    this.toolPolicies = const {},
    this.supportsReasoning = false,
    this.supportsImages = true,
    this.supportsTools = true,
    this.compatOverrides,
  });

  final RunConnection connection;
  final ModelSelection modelSelection;
  final String systemPrompt;
  final Set<String> enabledTools;

  /// 工具级策略覆盖；未列出的工具按定义的默认策略。
  final Map<String, ToolPolicy> toolPolicies;
  final bool supportsReasoning;
  final bool supportsImages;
  final bool supportsTools;
  final OpenAiCompat? compatOverrides;

  Map<String, dynamic> toJson() => {
    'connection': connection.toJson(),
    'modelSelection': modelSelection.toJson(),
    'systemPrompt': systemPrompt,
    'enabledTools': enabledTools.toList(),
    'toolPolicies': {
      for (final entry in toolPolicies.entries) entry.key: entry.value.name,
    },
    'supportsReasoning': supportsReasoning,
    'supportsImages': supportsImages,
    'supportsTools': supportsTools,
    'compatOverrides': compatOverrides?.toJson(),
  };

  factory RunConfiguration.fromJson(Map<String, dynamic> json) =>
      RunConfiguration(
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
    this.usage,
    this.finishedAt,
  });

  /// 首版轮次上限（design 第二部分 §7）。
  static const defaultMaxTurns = 30;

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
  final int maxTurns;

  /// 整个运行的用量汇总；接口未提供时为 null。
  final TokenUsage? usage;
  final DateTime createdAt;
  final DateTime? finishedAt;

  AgentRun copyWith({
    String? currentMessageId,
    String? activeToolCallId,
    RunStatus? status,
    RunFinishReason? finishReason,
    int? turnCount,
    int? modelAttemptCount,
    TokenUsage? usage,
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
      usage: usage ?? this.usage,
      createdAt: createdAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}
