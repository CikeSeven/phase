/// API 协议类型。
///
/// 协议与服务商正交：一个协议实现被多个服务商预设复用，
/// 服务商差异声明为数据（预设 / compat），不写分支。
enum ApiProtocol {
  /// OpenAI 兼容 chat/completions（DeepSeek、Ollama、自定义网关等）。
  openaiCompletions,

  /// OpenAI Responses API（/responses）。
  openaiResponses,

  /// Anthropic Messages API（/v1/messages）。
  anthropicMessages,

  /// Google Generative AI（/v1beta models:streamGenerateContent）。
  googleGenerativeAi,
}

/// 从持久化的 name 还原协议，未知值回退到 OpenAI 兼容（老数据行为）。
ApiProtocol apiProtocolFromName(String name) {
  for (final protocol in ApiProtocol.values) {
    if (protocol.name == name) {
      return protocol;
    }
  }
  return ApiProtocol.openaiCompletions;
}
