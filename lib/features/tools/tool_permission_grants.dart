import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_permission.dart';
import '../../../data/models/tool_source.dart';
import 'tool.dart';
import 'tool_permission_policy.dart';

/// 一次连续驱动的授权；取消、驱动切换或规则变化时失效。
class ToolPermissionGrants {
  String? _runId;
  RunCancellation? _cancellation;
  final List<PermissionGrant> _grants = [];
  final _grantLifetimes = Expando<Object>();
  Object _lifetime = Object();

  void clear() {
    _lifetime = Object();
    _grants.clear();
    _runId = null;
    _cancellation = null;
  }

  void bind(String runId, RunCancellation cancellation) {
    if (_runId == runId && identical(_cancellation, cancellation)) return;
    clear();
    _runId = runId;
    _cancellation = cancellation;
    cancellation.whenCancelled.then((_) {
      if (identical(_cancellation, cancellation)) _grants.clear();
    });
  }

  String _definitionKey(Tool tool) => definitionDigest([
    tool.source.kind.name,
    tool.source.id,
    tool.source.originalName,
    tool.channel.name,
  ]);

  bool covers(
    PermissionGrant grant, {
    required ToolCallRecord record,
    required Tool tool,
    required ToolPermissionDecision decision,
    required String rulesRevision,
  }) {
    if (_cancellation?.isCancelled != false ||
        !identical(_grantLifetimes[grant], _lifetime) ||
        _runId != record.runId ||
        grant.runId != record.runId ||
        grant.rulesRevision != rulesRevision ||
        grant.definitionRevisions[_definitionKey(tool)] !=
            tool.source.definitionRevision) {
      return false;
    }
    return switch (grant.scope) {
      PermissionGrantScope.once =>
        grant.approvedCallId == record.id &&
            grant.argumentsDigest == definitionDigest(record.arguments),
      PermissionGrantScope.run =>
        decision.canApproveForRun &&
            grant.approvalCategory == decision.request.approvalCategory,
    };
  }

  PermissionGrant? find({
    required ToolCallRecord record,
    required Tool tool,
    required ToolPermissionDecision decision,
    required String rulesRevision,
  }) {
    _grants.removeWhere((grant) {
      if (grant.rulesRevision == rulesRevision) return false;
      _grantLifetimes[grant] = null;
      return true;
    });
    for (final grant in _grants) {
      if (covers(
        grant,
        record: record,
        tool: tool,
        decision: decision,
        rulesRevision: rulesRevision,
      )) {
        return grant;
      }
    }
    return null;
  }

  PermissionGrant issue({
    required ToolCallRecord record,
    required Tool tool,
    required ToolPermissionDecision decision,
    required PermissionGrantScope scope,
    required String rulesRevision,
    required ToolRegistry registry,
    required Set<String> enabledTools,
  }) {
    final category = decision.request.approvalCategory;
    final grant = PermissionGrant(
      runId: record.runId,
      approvedCallId: record.id,
      scope: scope,
      rulesRevision: rulesRevision,
      argumentsDigest: scope == PermissionGrantScope.once
          ? definitionDigest(record.arguments)
          : null,
      approvalCategory: scope == PermissionGrantScope.run ? category : null,
      definitionRevisions: {
        if (scope == PermissionGrantScope.once)
          _definitionKey(tool): tool.source.definitionRevision,
        if (scope == PermissionGrantScope.run)
          for (final candidate in registry.tools)
            if (enabledTools.contains(candidate.name) &&
                candidate.source.kind == tool.source.kind &&
                candidate.source.id == tool.source.id &&
                permissionRequestFor(candidate, const {}).approvalCategory ==
                    category)
              _definitionKey(candidate): candidate.source.definitionRevision,
      },
    );
    _grantLifetimes[grant] = _lifetime;
    if (scope == PermissionGrantScope.run) _grants.add(grant);
    return grant;
  }
}
