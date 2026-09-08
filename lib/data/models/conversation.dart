/// 一个会话（聊天线程）。
///
/// 由 drift 的 Conversations 表映射而来（见 conversation_repository.dart）。
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation copyWith({String? title, bool? pinned, DateTime? updatedAt}) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
