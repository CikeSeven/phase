/// 统一的错误类型体系（AGENTS.md §4）。
///
/// repository 与 AiProvider 层把底层异常映射为 [Failure] 子类型，
/// UI 只面对 [Failure.userMessage] 展示文案，不处理裸异常。
sealed class Failure implements Exception {
  const Failure(this.message, {this.cause});

  /// 内部诊断信息（进日志，不直接展示给用户）。
  final String message;

  /// 原始异常，仅用于日志定位。
  final Object? cause;

  /// 用户可读文案。
  String get userMessage;

  @override
  String toString() => '$runtimeType: $message';
}

/// 会话、执行记录等应用状态存储失败；普通工具文件的 IO 失败不使用此类型。
final class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.cause});

  @override
  String get userMessage => '数据读取或保存失败，请稍后重试';
}

/// 已知的操作前置条件不满足；调用方只传固定、安全的用户提示。
final class OperationFailure extends Failure {
  const OperationFailure(super.message);

  @override
  String get userMessage => message;
}

/// 系统的应用列表授权或可见范围不足，不能作为正常名单展示。
enum ApplicationListFailureCode { permissionRequired, restricted }

final class ApplicationListFailure extends Failure {
  const ApplicationListFailure(this.code) : super('Application list access');

  final ApplicationListFailureCode code;

  @override
  String get userMessage => switch (code) {
    ApplicationListFailureCode.permissionRequired =>
      '未授权获取应用列表，请在系统应用权限设置中允许“获取应用列表”后重试',
    ApplicationListFailureCode.restricted =>
      '系统仅返回相月或基础系统应用，应用列表访问受限，请检查“获取应用列表”权限后重试',
  };
}

/// 网络不可达、超时、DNS 等连接层错误。
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause});

  @override
  String get userMessage => '网络连接失败，请检查网络后重试';
}

/// API Key 无效或权限不足（HTTP 401/403）。
final class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.cause});

  @override
  String get userMessage => 'API Key 无效或已过期，请检查服务商配置';
}

/// 触发服务商限流（HTTP 429）。
final class RateLimitFailure extends Failure {
  const RateLimitFailure(super.message, {super.cause});

  @override
  String get userMessage => '请求过于频繁，请稍后再试';
}

/// 服务商服务端错误（HTTP 5xx）。
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.cause});

  @override
  String get userMessage => '服务商暂时不可用，请稍后再试';
}

/// 用户主动取消（停止生成）。
final class CancelledFailure extends Failure {
  const CancelledFailure(super.message, {super.cause});

  @override
  String get userMessage => '已停止生成';
}

/// 无法归类的其他错误。
final class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.cause});

  @override
  String get userMessage => '出现未知错误，请稍后再试';
}

/// 有限的 Android 执行业务错误分类，不暴露平台异常。
enum ExecutionFailureCode {
  permissionRequired,
  unavailable,
  targetChanged,
  invalidArguments,
  timeout,
  executionFailed,
  cancelled,
}

final class ExecutionFailure extends Failure {
  const ExecutionFailure(this.code) : super('Android execution channel');
  final ExecutionFailureCode code;

  @override
  String get userMessage => switch (code) {
    ExecutionFailureCode.permissionRequired => '请开启任务通知或所需执行权限后重试',
    ExecutionFailureCode.targetChanged => '操作目标已改变，请重新观察',
    ExecutionFailureCode.invalidArguments => '执行请求无效',
    ExecutionFailureCode.timeout => '执行通道响应超时',
    ExecutionFailureCode.cancelled => '任务已停止',
    ExecutionFailureCode.unavailable => '执行通道不可用，请返回相月后重试',
    ExecutionFailureCode.executionFailed => 'Android 执行失败，请重试',
  };
}

/// MCP 边界只携带固定的安全文案；远程错误正文不进入诊断/UI 错误提示。
final class McpFailure extends Failure {
  const McpFailure(this.code, super.message);
  final String code;
  @override
  String get userMessage => message;
}

/// Skill 安装和资源操作失败；业务库故障仍使用 StorageFailure。
final class SkillFailure extends Failure {
  const SkillFailure(this.code, super.message);
  final String code;
  @override
  String get userMessage => message;
}

/// Linux 环境、进程和工作区文件失败；应用记录写入仍使用 StorageFailure。
final class WorkspaceFailure extends Failure {
  const WorkspaceFailure(this.code, super.message);
  final String code;
  @override
  String get userMessage => message;
}
