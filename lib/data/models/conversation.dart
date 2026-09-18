import 'model_selection.dart';

/// 一个会话（聊天线程）。
///
/// 采用父指针消息树：[currentMessageId] 指向当前分支末尾；单条会话内的
/// 模型选择覆盖优先于助手默认值。
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.assistantId,
    this.workspaceId,
    this.currentMessageId,
    this.modelSelectionOverride,
    this.pinned = false,
  });

  final String id;
  final String title;

  /// 会话使用的助手；助手被删除后为 null，可重新选择。
  final String? assistantId;
  final String? workspaceId;

  /// 当前分支末尾的消息 id。
  final String? currentMessageId;

  /// 会话内覆盖的模型选择；为 null 时用助手默认值或最近选择。
  final ModelSelection? modelSelectionOverride;

  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation copyWith({
    String? title,
    String? assistantId,
    String? currentMessageId,
    ModelSelection? modelSelectionOverride,
    bool? pinned,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      assistantId: assistantId ?? this.assistantId,
      workspaceId: workspaceId,
      currentMessageId: currentMessageId ?? this.currentMessageId,
      modelSelectionOverride:
          modelSelectionOverride ?? this.modelSelectionOverride,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
