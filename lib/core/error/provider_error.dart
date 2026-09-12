/// 协议错误的业务分类（design 第五部分 §5.2）。
///
/// 分类来自 HTTP 状态码或协议明确的错误字段；不按错误文本匹配变体。
enum ProviderErrorCategory {
  network,
  timeout,
  auth,
  rateLimit,
  invalidRequest,

  /// 超出模型上下文容量。
  contextLimit,
  providerError,
  cancelled,
  config,
}

/// 带业务分类的协议错误，供 UI 决定重试与提示方式。
class ProviderError implements Exception {
  const ProviderError(this.category, this.message, {this.cause});

  final ProviderErrorCategory category;

  /// 协议给出的诊断文案（如错误对象的 message 字段），仅用于日志定位。
  final String message;

  final Object? cause;

  /// 面向用户的文案：按分类给出安全说明，不回显网关原文。
  String get userMessage => switch (category) {
    ProviderErrorCategory.network => '网络连接失败，请检查网络后重试',
    ProviderErrorCategory.timeout => '请求超时，请稍后重试',
    ProviderErrorCategory.auth => 'API Key 无效或已过期，请检查服务商配置',
    ProviderErrorCategory.rateLimit => '请求过于频繁，请稍后再试',
    ProviderErrorCategory.invalidRequest => '请求参数不被接受，请检查模型与设置',
    ProviderErrorCategory.contextLimit => '上下文超出模型容量，请减少附件或新建会话',
    ProviderErrorCategory.providerError => '服务商暂时不可用，请稍后再试',
    ProviderErrorCategory.cancelled => '已停止生成',
    ProviderErrorCategory.config => '服务商配置不完整，请先完成配置',
  };

  /// 尚未产生输出时可以按有限策略重试。
  bool get retryable =>
      category == ProviderErrorCategory.network ||
      category == ProviderErrorCategory.rateLimit;

  @override
  String toString() => 'ProviderError(${category.name}): $message';
}
