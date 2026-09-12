import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/repositories/conversation_repository.dart';

/// 附件落盘与归属：文件本体在私有目录，数据库只保存引用。
void main() {
  late Directory tempDir;
  late AppDatabase db;
  late AttachmentStorage storage;
  late ConversationRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('phase_attachment');
    db = openAppDatabase(
      path: p.join(tempDir.path, 'phase.sqlite'),
      hexKey: '0123456789abcdef' * 4,
    );
    storage = AttachmentStorage(Directory(p.join(tempDir.path, 'attachments')));
    repository = ConversationRepository(db, attachments: storage);
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  test('落盘的附件在认领会话后可查询', () async {
    final conversation = await repository.createConversation();
    final saved = await storage.save(
      name: '笔记.md',
      mimeType: 'text/markdown',
      kind: AttachmentKind.text,
      bytes: const [35, 32, 116, 105, 116, 108, 101],
    );

    // 落盘时还没有会话：文件先写，归属在发送时认领。
    expect(saved.conversationId, isNull);
    expect(File(saved.localPath).existsSync(), isTrue);
    expect(saved.size, 7);

    final claimed = saved.withConversation(conversation.id);
    await repository.saveAttachment(claimed);

    final stored = await repository.attachmentsFor(conversation.id);
    expect(stored, hasLength(1));
    expect(stored.single.id, saved.id);
    expect(stored.single.kind, AttachmentKind.text);
    expect(stored.single.name, '笔记.md');
    expect(stored.single.localPath, saved.localPath);
    expect(stored.single.conversationId, conversation.id);
  });

  test('删除会话后附件记录与文件一并清理', () async {
    final conversation = await repository.createConversation();
    final saved = await storage.save(
      name: 'photo.jpg',
      mimeType: 'image/jpeg',
      kind: AttachmentKind.image,
      bytes: const [1, 2, 3],
    );
    await repository.saveAttachment(saved.withConversation(conversation.id));
    expect(File(saved.localPath).existsSync(), isTrue);

    await repository.deleteConversation(conversation.id);

    expect(await repository.attachmentsFor(conversation.id), isEmpty);
    expect(File(saved.localPath).existsSync(), isFalse);
  });

  test('未知附件类型按文本处理，不冒充图片', () {
    expect(attachmentKindFromName('pdf'), AttachmentKind.text);
    expect(attachmentKindFromName('image'), AttachmentKind.image);
    expect(attachmentKindFromName('artifact'), AttachmentKind.artifact);
  });
}
