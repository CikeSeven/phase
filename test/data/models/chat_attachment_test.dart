import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/models/chat_attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  group('附件持久化（drift v5）', () {
    test('v4 库升级新增 attachmentsJson 列，老消息附件为空', () async {
      final file = File(
        '${Directory.systemTemp.path}/phase-migration-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      addTearDown(() => file.existsSync() ? file.deleteSync() : null);
      // 手工构造 v4 老库：没有 attachments_json 列。
      final old = sqlite3.sqlite3.open(file.path);
      old.execute('''
        CREATE TABLE conversations (id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL, pinned INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
        CREATE TABLE messages (id TEXT NOT NULL PRIMARY KEY, conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, role TEXT NOT NULL, content TEXT NOT NULL, status TEXT NOT NULL, model_name TEXT, reasoning TEXT, created_at INTEGER NOT NULL);
        CREATE TABLE provider_profiles (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, base_url TEXT NOT NULL, protocol TEXT NOT NULL DEFAULT 'openaiCompletions', preset_id TEXT NOT NULL DEFAULT 'custom', models_json TEXT NOT NULL DEFAULT '[]', default_model TEXT, compat_json TEXT, created_at INTEGER NOT NULL);
        PRAGMA user_version = 4;
      ''');
      final now = DateTime.now().millisecondsSinceEpoch;
      old.execute(
        "INSERT INTO conversations VALUES ('c1', '老会话', 0, $now, $now)",
      );
      old.execute(
        "INSERT INTO messages VALUES ('m1', 'c1', 'user', '老消息', 'done', NULL, NULL, $now)",
      );
      old.dispose();

      final db = AppDatabase(NativeDatabase(File(file.path)));
      addTearDown(db.close);
      final repository = ConversationRepository(db);
      final messages = await repository.getMessages('c1');
      expect(messages.single.id, 'm1');
      expect(messages.single.content, '老消息');
      expect(messages.single.attachments, isEmpty);
    });

    test('带附件的消息往返持久化，删除会话清理附件文件', () async {
      final temp = Directory.systemTemp.createTempSync('phase-attachments');
      addTearDown(() => temp.deleteSync(recursive: true));
      final storage = AttachmentStorage(Directory('${temp.path}/attachments'));
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = ConversationRepository(db, attachments: storage);

      final image = await storage.save(
        name: 'photo.jpg',
        mimeType: 'image/jpeg',
        type: ChatAttachmentType.image,
        bytes: [1, 2, 3],
      );
      expect(File(image.path).existsSync(), isTrue);

      await repository.createConversation(title: 't');
      final conversation = (await repository.watchConversations().first).single;
      await repository.appendMessage(
        conversationId: conversation.id,
        role: ChatRole.user,
        content: '看图',
        attachments: [image],
      );
      final message = (await repository.getMessages(conversation.id)).single;
      expect(message.attachments.single.id, image.id);
      expect(message.attachments.single.type, ChatAttachmentType.image);
      expect(message.attachments.single.path, image.path);
      expect(message.attachments.single.size, 3);

      await repository.deleteConversation(conversation.id);
      expect(File(image.path).existsSync(), isFalse);
    });
  });
}
