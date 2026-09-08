import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// 统一的分级日志封装（AGENTS.md §5：禁止 print）。
///
/// 安全纪律：调用方不得把 API Key、Authorization 头等密钥传入日志。
abstract final class AppLogger {
  static void debug(String message) => _log(LogLevel.debug, message);

  static void info(String message) => _log(LogLevel.info, message);

  static void warning(String message) => _log(LogLevel.warning, message);

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message);
    if (error != null) {
      _log(LogLevel.error, '  cause: $error');
    }
    if (stackTrace != null) {
      _log(LogLevel.error, '  $stackTrace');
    }
  }

  static void _log(LogLevel level, String message) {
    debugPrint('[${level.name}] $message');
  }
}
