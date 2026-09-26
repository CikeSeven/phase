import '../../../data/models/context_policy.dart';
import '../../../data/models/model_catalog.dart';
import '../../../data/models/model_request_record.dart';
import '../../../data/models/token_usage.dart';
import '../../../providers/request_plan.dart';
import '../../../providers/tool_result_images.dart';

enum ContextMeasurementSource { estimated, usageAnchored }

class ContextMeasurement {
  const ContextMeasurement({
    required this.conversationId,
    required this.branchHeadId,
    required this.generation,
    required this.configurationFingerprint,
    required this.configurationSnapshot,
    required this.inputFingerprint,
    required this.messageIds,
    required this.localInputTokens,
    required this.estimatedInputTokens,
    required this.windowTokens,
    required this.outputReserveTokens,
    required this.marginTokens,
    required this.windowSource,
    required this.outputReserveSource,
    required this.systemTokens,
    required this.toolTokens,
    required this.messageTokens,
    required this.imageTokens,
    required this.measuredAt,
    required this.triggerTokens,
    required this.targetTokens,
    this.anchorRequestId,
  });
  static const algorithmVersion = 1;
  final String conversationId;
  final String? branchHeadId;
  final String generation;
  final String configurationFingerprint;
  final Map<String, dynamic> configurationSnapshot;
  final String inputFingerprint;
  final List<String?> messageIds;
  final int localInputTokens;
  final int estimatedInputTokens;
  final int windowTokens;
  final int outputReserveTokens;
  final int marginTokens;
  final ContextWindowSource windowSource;
  final OutputReserveSource outputReserveSource;
  final int systemTokens;
  final int toolTokens;
  final int messageTokens;
  final int imageTokens;
  final DateTime measuredAt;
  final int triggerTokens;
  final int targetTokens;
  final String? anchorRequestId;
  int get inputBudget => windowTokens - outputReserveTokens - marginTokens;
  ContextMeasurementSource get source => anchorRequestId == null
      ? ContextMeasurementSource.estimated
      : ContextMeasurementSource.usageAnchored;
  Map<String, dynamic> toSnapshot() => {
    'algorithmVersion': algorithmVersion,
    'generation': generation,
    'configurationFingerprint': configurationFingerprint,
    'configuration': configurationSnapshot,
    'inputFingerprint': inputFingerprint,
    'messageIds': messageIds,
    'localInputTokens': localInputTokens,
    'branchHeadId': branchHeadId,
    'windowTokens': windowTokens,
    'outputReserveTokens': outputReserveTokens,
    'marginTokens': marginTokens,
    'windowSource': windowSource.name,
    'outputReserveSource': outputReserveSource.name,
  };
}

class ContextMeter {
  const ContextMeter();
  Future<ContextMeasurement> measure({
    required String conversationId,
    required RequestPlan plan,
    required String generation,
    required Iterable<ModelRequestRecord> requests,
    int? contextWindow,
    ContextWindowSource? windowSource,
    int? catalogMaxOutputTokens,
    ContextPolicy policy = const ContextPolicy(),
  }) async {
    final ids = plan.request.messages.map((m) => m.sourceMessageId).toList();
    final local = plan.estimatedInputTokens;
    var estimated = local;
    String? anchorId;
    for (final record in requests) {
      if (!record.isActual ||
          record.conversationId != conversationId ||
          record.assistantMessageId == null ||
          !ids.contains(record.assistantMessageId) ||
          record.status != ModelRequestStatus.completed ||
          record.purpose != ModelRequestPurpose.chat ||
          record.usage?.value(UsageField.promptTokens) == null) {
        continue;
      }
      final s = record.contextSnapshot;
      if (s['algorithmVersion'] != ContextMeasurement.algorithmVersion ||
          s['generation'] != generation ||
          s['configurationFingerprint'] != plan.configurationFingerprint) {
        continue;
      }
      final oldIds = (s['messageIds'] as List?) ?? const [];
      if (oldIds.isEmpty || oldIds.length > ids.length) continue;
      if (List.generate(
        oldIds.length,
        (i) => oldIds[i] == ids[i],
      ).any((same) => !same)) {
        continue;
      }
      // 按基准输入范围还原当时的设备观察，不能用新截图淘汰旧图后的前缀校验。
      // 仍以实际协议负载指纹验证，编辑历史/图片或切离分支不能复用基准。
      final prefix = await planRequest(
        plan.profile,
        plan.request.copyWith(
          messages: projectVisualToolImages(
            plan.request.messages.take(oldIds.length).toList(),
          ),
        ),
      );
      if (prefix.inputFingerprint != s['inputFingerprint'] ||
          s['localInputTokens'] is! int) {
        continue;
      }
      estimated =
          (record.usage!.promptTokens! + local - (s['localInputTokens'] as int))
              .clamp(0, 9007199254740991);
      anchorId = record.id;
      break;
    }
    // 生效窗口：解析值优先（用户 > 目录 > 本地默认 128000）；
    // 输出预留：协议实参 > 目录上限 > 本地 4096。目录值只进预留，不下发请求。
    final window = contextWindow ?? ModelCatalog.localDefaultWindow;
    final reserve =
        plan.effectiveOutputTokens ??
        catalogMaxOutputTokens ??
        ModelCatalog.localDefaultOutputReserve;
    final resolvedWindowSource =
        windowSource ??
        (contextWindow != null
            ? ContextWindowSource.user
            : ContextWindowSource.localDefault);
    final resolvedReserveSource = plan.effectiveOutputTokens != null
        ? OutputReserveSource.protocol
        : catalogMaxOutputTokens != null
        ? OutputReserveSource.catalog
        : OutputReserveSource.localDefault;
    return ContextMeasurement(
      conversationId: conversationId,
      branchHeadId: ids.lastOrNull,
      generation: generation,
      configurationFingerprint: plan.configurationFingerprint,
      configurationSnapshot: plan.configurationSnapshot,
      inputFingerprint: plan.inputFingerprint,
      messageIds: ids,
      localInputTokens: local,
      estimatedInputTokens: estimated,
      windowTokens: window,
      outputReserveTokens: reserve,
      marginTokens: policy.margin,
      windowSource: resolvedWindowSource,
      outputReserveSource: resolvedReserveSource,
      systemTokens: plan.systemTokens,
      toolTokens: plan.toolTokens,
      messageTokens: plan.messageTokens,
      imageTokens: plan.imageTokens,
      measuredAt: DateTime.now(),
      triggerTokens: ((window - reserve - policy.margin) * policy.trigger)
          .floor(),
      targetTokens: ((window - reserve - policy.margin) * policy.target)
          .floor(),
      anchorRequestId: anchorId,
    );
  }
}
