enum MemoryScope {
  disabled,
  assistant,
  assistantAndGlobal;

  String get label => switch (this) {
    disabled => '关闭记忆',
    assistant => '仅此助手',
    assistantAndGlobal => '此助手与全局',
  };
}

class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.assistantId,
    this.sourceMessageId,
    this.sourceRunId,
    this.enabled = true,
  });
  final String id;
  final String content;

  /// null 为全局；与来源无关，不因删除来源会话自动扩大范围。
  final String? assistantId;
  final String? sourceMessageId;
  final String? sourceRunId;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
}
