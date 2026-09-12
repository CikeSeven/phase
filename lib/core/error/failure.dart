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

/// 已知的操作前置条件不满足；调用方只传固定、安全的用户提示。
final class OperationFailure extends Failure {
  const OperationFailure(super.message);

  @override
  String get userMessage => message;
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
