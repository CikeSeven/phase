import 'tool_policy.dart';
import 'tool_source.dart';

enum ToolEffect {
  informationRead,
  fileRead,
  fileWrite,
  codeExecution,
  networkRequest,
  deviceObservation,
  deviceInteraction,
  stateWrite,
  userHandoff,
  unknown,
}

enum PermissionGrantScope { once, run }

/// 宿主描述实际调用的效果，不从工具名称或第三方 annotations 推断只读。
class ToolPermissionRequest {
  ToolPermissionRequest({
    required this.action,
    required Set<ToolEffect> effects,
    this.approvalCategory,
  }) : effects = Set.unmodifiable(effects);

  final String action;
  final Set<ToolEffect> effects;

  /// 非空时可明确批准本轮该类别；不表示任意代码具有目录隔离。
  final String? approvalCategory;
}

/// 精确匹配来源、原始工具名和可选动作；不支持正则、前缀或脚本分析。
class ToolPermissionRule {
  const ToolPermissionRule({
    required this.sourceKind,
    required this.sourceId,
    required this.toolName,
    required this.policy,
    this.action,
    this.definitionRevision,
  });

  final ToolSourceKind sourceKind;
  final String sourceId;
  final String toolName;
  final String? action;
  final String? definitionRevision;
  final ToolPolicy policy;

  String get key =>
      definitionDigest([sourceKind.name, sourceId, toolName, action]);

  bool matches(ToolSource source, ToolPermissionRequest request) =>
      source.kind == sourceKind &&
      source.id == sourceId &&
      source.originalName == toolName &&
      (policy != ToolPolicy.allow ||
          definitionRevision == null ||
          definitionRevision == source.definitionRevision) &&
      (action == null || action == request.action);

  ToolPermissionRule withPolicy(ToolPolicy value) => ToolPermissionRule(
    sourceKind: sourceKind,
    sourceId: sourceId,
    toolName: toolName,
    action: action,
    definitionRevision: definitionRevision,
    policy: value,
  );

  Map<String, dynamic> toJson() => {
    'sourceKind': sourceKind.name,
    'sourceId': sourceId,
    'toolName': toolName,
    if (action != null) 'action': action,
    if (definitionRevision != null) 'definitionRevision': definitionRevision,
    'policy': policy.name,
  };

  factory ToolPermissionRule.fromJson(Map<String, dynamic> json) {
    final rule = ToolPermissionRule(
      sourceKind: ToolSourceKind.values.byName(json['sourceKind'] as String),
      sourceId: json['sourceId'] as String,
      toolName: json['toolName'] as String,
      action: json['action'] as String?,
      definitionRevision: json['definitionRevision'] as String?,
      policy: ToolPolicy.values.byName(json['policy'] as String),
    );
    if (rule.sourceId.isEmpty ||
        rule.toolName.isEmpty ||
        rule.action?.isEmpty == true ||
        rule.definitionRevision?.isEmpty == true) {
      throw const FormatException('Invalid tool permission rule');
    }
    return rule;
  }
}

/// 非敏感的调用判定与授权来源，随工具记录保存，不进入协议 providerData。
class ToolPermissionDecision {
  const ToolPermissionDecision({
    required this.policy,
    required this.request,
    required this.reason,
    this.ruleKey,
    this.grantScope,
    this.grantSourceCallId,
  });

  final ToolPolicy policy;
  final ToolPermissionRequest request;
  final String reason;
  final String? ruleKey;
  final PermissionGrantScope? grantScope;
  final String? grantSourceCallId;

  bool get canApproveForRun =>
      policy == ToolPolicy.ask &&
      ruleKey == null &&
      request.approvalCategory != null;

  ToolPermissionDecision withGrant(PermissionGrant grant) =>
      ToolPermissionDecision(
        policy: policy,
        request: request,
        reason: reason,
        ruleKey: ruleKey,
        grantScope: grant.scope,
        grantSourceCallId: grant.approvedCallId,
      );

  Map<String, dynamic> toJson() => {
    'policy': policy.name,
    'action': request.action,
    'effects': request.effects.map((effect) => effect.name).toList()..sort(),
    'reason': reason,
    if (request.approvalCategory != null)
      'approvalCategory': request.approvalCategory,
    if (ruleKey != null) 'ruleKey': ruleKey,
    if (grantScope != null) 'grantScope': grantScope!.name,
    if (grantSourceCallId != null) 'grantSourceCallId': grantSourceCallId,
  };

  factory ToolPermissionDecision.fromJson(Map<String, dynamic> json) =>
      ToolPermissionDecision(
        policy: ToolPolicy.values.byName(json['policy'] as String),
        request: ToolPermissionRequest(
          action: json['action'] as String,
          effects: Set.unmodifiable([
            for (final name in json['effects'] as List)
              ToolEffect.values.byName(name as String),
          ]),
          approvalCategory: json['approvalCategory'] as String?,
        ),
        reason: json['reason'] as String,
        ruleKey: json['ruleKey'] as String?,
        grantScope: json['grantScope'] == null
            ? null
            : PermissionGrantScope.values.byName(json['grantScope'] as String),
        grantSourceCallId: json['grantSourceCallId'] as String?,
      );
}

/// 仅存于本次运行驱动内存；审计可以保存，但授权不能从历史恢复。
class PermissionGrant {
  PermissionGrant({
    required this.runId,
    required this.approvedCallId,
    required this.scope,
    required this.rulesRevision,
    required Map<String, String> definitionRevisions,
    this.argumentsDigest,
    this.approvalCategory,
  }) : definitionRevisions = Map.unmodifiable(definitionRevisions);

  final String runId;
  final String approvedCallId;
  final PermissionGrantScope scope;
  final String rulesRevision;
  final Map<String, String> definitionRevisions;
  final String? argumentsDigest;
  final String? approvalCategory;
}
