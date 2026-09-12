import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/features/execution/execution_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/app/xiangyue/phase/bridge/ExecutionApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'app.xiangyue.phase.bridge'),
    dartPackageName: 'phase',
  ),
)
enum ExecutionAction {
  inspectUi,
  clickNode,
  scroll,
  inputText,
  readFile,
  writeFile,
  listFiles,
}

enum ExecutionStatus { succeeded, failed, cancelled, unknown }

enum ChannelError {
  permissionRequired,
  unavailable,
  targetChanged,
  invalidArguments,
  timeout,
  executionFailed,
  cancelled,
  resultUnknown,
}

enum ProgressKind { stage, progress }

enum ConfirmationDecision { approve, reject, stop }

/// 机器校验的目标，不使用动作摘要代替目标身份。节点只在对应快照内有效。
class ExecutionTarget {
  ExecutionTarget({
    this.packageName,
    this.windowId,
    this.snapshotId,
    this.nodeId,
    this.uri,
  });
  String? packageName;
  int? windowId;
  String? snapshotId;
  String? nodeId;
  String? uri;
}

class ExecutionRequest {
  ExecutionRequest({
    required this.runId,
    required this.toolCallId,
    required this.action,
    required this.arguments,
    required this.target,
    required this.timeoutMs,
  });
  String runId;
  String toolCallId;
  ExecutionAction action;
  Map<String, Object?> arguments;
  ExecutionTarget target;
  int timeoutMs;
}

class ExecutionArtifact {
  ExecutionArtifact({
    required this.uri,
    required this.name,
    required this.size,
    this.sha256,
  });
  String uri;
  String name;
  int size;
  String? sha256;
}

class ExecutionResult {
  ExecutionResult({
    required this.toolCallId,
    required this.status,
    required this.result,
    required this.artifacts,
    this.error,
  });
  String toolCallId;
  ExecutionStatus status;
  Map<String, Object?> result;
  List<ExecutionArtifact> artifacts;
  ChannelError? error;
}

class ExecutionProgress {
  ExecutionProgress({
    required this.toolCallId,
    required this.sequence,
    required this.kind,
    required this.payload,
  });
  String toolCallId;
  int sequence;
  ProgressKind kind;
  String payload;
}

class ExecutionCapabilities {
  ExecutionCapabilities({
    required this.actions,
    required this.notificationsAllowed,
    required this.activityResumed,
  });
  List<ExecutionAction> actions;
  bool notificationsAllowed;
  bool activityResumed;
}

class ExecutionConfirmation {
  ExecutionConfirmation({
    required this.runId,
    required this.toolCallId,
    required this.toolName,
    required this.summary,
    required this.arguments,
    required this.targetLabel,
    required this.expiresAtMs,
  });
  String runId;
  String toolCallId;
  String toolName;
  String summary;
  Map<String, Object?> arguments;
  String? targetLabel;
  int expiresAtMs;
}

class HostReply {
  HostReply({this.error});
  ChannelError? error;
}

@HostApi()
abstract class ExecutionHostApi {
  @async
  ExecutionResult execute(ExecutionRequest request);
  void cancel(String toolCallId);
  ExecutionCapabilities queryCapabilities();
  @async
  HostReply startRun(String runId);
  void endRun(String runId);
  void setConfirmation(ExecutionConfirmation? confirmation);
}

@FlutterApi()
abstract class ExecutionFlutterApi {
  void progress(ExecutionProgress progress);
  void capabilityChanged(ExecutionCapabilities capabilities);
  void confirmationDecision(
    String runId,
    String toolCallId,
    ConfirmationDecision decision,
  );
  void stopRequested(String runId);
}
