import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';

/// 测试数据库：临时目录里的加密库，与生产打开路径一致。
///
/// 返回的 AppDatabase 由调用方关闭；测试结束时删除临时目录。
({AppDatabase database, Directory directory}) createTestDatabase({
  String name = 'phase',
}) {
  final directory = Directory.systemTemp.createTempSync('phase_test_$name');
  final database = openAppDatabase(
    path: p.join(directory.path, '$name.sqlite'),
    hexKey: '0123456789abcdef' * 4,
  );
  return (database: database, directory: directory);
}

/// 测试用附件存储：写到临时目录，不触碰平台目录。
AttachmentStorage testAttachmentStorage(Directory directory) {
  return AttachmentStorage(Directory(p.join(directory.path, 'attachments')));
}

/// 测试用消息：默认是一条已完成的助手回答。
ChatMessage testMessage({
  String id = 'm1',
  String conversationId = 'c1',
  ChatRole role = ChatRole.assistant,
  String? parentId,
  String? runId,
  String text = '回答',
  String? thinking,
  MessageStatus status = MessageStatus.completed,
  String? modelLabel = 'model-a',
  List<MessagePart>? parts,
  DateTime? createdAt,
}) {
  return ChatMessage(
    id: id,
    conversationId: conversationId,
    role: role,
    parentId: parentId,
    runId: runId,
    status: status,
    modelLabel: modelLabel,
    parts:
        parts ??
        [
          if (thinking != null) ReasoningPart(publicText: thinking),
          if (text.isNotEmpty) TextPart(text: text),
        ],
    createdAt: createdAt ?? DateTime(2026, 9, 12),
  );
}
