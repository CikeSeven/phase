import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/repositories/conversation_repository.dart';

void main() {
  late Directory directory;
  late AppDatabase db;
  late AttachmentStorage storage;
  late ConversationRepository repository;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('phase_copy_');
    db = openAppDatabase(
      path: p.join(directory.path, 'copy.sqlite'),
      hexKey: '0123456789abcdef' * 4,
    );
    storage = AttachmentStorage(
      Directory(p.join(directory.path, 'attachments')),
    );
    repository = ConversationRepository(db, attachments: storage);
  });

  tearDown(() async {
    await db.close();
    directory.deleteSync(recursive: true);
  });

  Future<String> seedConversation() async {
    final conversation = await repository.createConversation(title: 'Original');
    final parts = <MessagePart>[const TextPart(text: 'Read these files')];
    for (final kind in [
      AttachmentKind.image,
      AttachmentKind.text,
      AttachmentKind.pdf,
      AttachmentKind.docx,
    ]) {
      var attachment = (await storage.save(
        name: 'sample.${kind.name}',
        mimeType: kind == AttachmentKind.image ? 'image/png' : 'text/plain',
        kind: kind,
        bytes: utf8.encode('original-${kind.name}'),
        width: kind == AttachmentKind.image ? 16 : null,
        height: kind == AttachmentKind.image ? 12 : null,
      )).withConversation(conversation.id);
      if (attachment.isDocument) {
        attachment = attachment.withExtraction(
          extractedTextPath: await storage.saveExtractedText(
            attachment.id,
            'extracted-${kind.name}',
          ),
        );
      }
      await repository.saveAttachment(attachment);
      parts.add(
        attachment.isImage
            ? ImagePart(attachmentId: attachment.id)
            : DocumentPart(attachmentId: attachment.id),
      );
    }
    final createdAt = DateTime(2026, 9, 12);
    await repository.appendMessage(
      ChatMessage(
        id: 'input',
        conversationId: conversation.id,
        role: ChatRole.user,
        status: MessageStatus.completed,
        parts: parts,
        createdAt: createdAt,
      ),
    );
    for (final id in ['old-answer', 'current-answer']) {
      await repository.appendMessage(
        ChatMessage(
          id: id,
          conversationId: conversation.id,
          parentId: 'input',
          role: ChatRole.assistant,
          status: MessageStatus.completed,
          parts: parts,
          createdAt: createdAt,
        ),
      );
    }
    return conversation.id;
  }

  List<String> pathsOf(List<Attachment> attachments) => [
    for (final attachment in attachments) ...[
      attachment.localPath,
      if (attachment.extractedTextPath != null) attachment.extractedTextPath!,
    ],
  ];

  for (final deleteOriginal in [false, true]) {
    test(
      'copy remaps every branch and owns files; delete original=$deleteOriginal',
      () async {
        final sourceId = await seedConversation();
        final source = (await repository.getThread(sourceId))!;
        final originals = await repository.attachmentsFor(sourceId);
        final copy = await repository.duplicateConversation(sourceId);
        final copied = (await repository.getThread(copy.id))!;
        final attachments = await repository.attachmentsFor(copy.id);
        final ids = attachments.map((attachment) => attachment.id).toSet();
        expect(attachments, hasLength(4));
        expect(copied.messages, hasLength(3));
        expect(copied.branch, hasLength(2));
        expect(copied.branch.last.id, copied.currentMessageId);
        for (final message in copied.messages) {
          expect(
            source.messages.map((item) => item.id),
            isNot(contains(message.id)),
          );
          if (message.role == ChatRole.assistant) {
            expect(message.parentId, copied.branch.first.id);
          }
          expect(
            message.parts.first.toJson(),
            source.branch.first.parts.first.toJson(),
          );
          expect(
            message.parts.whereType<ImagePart>().single.attachmentId,
            isIn(ids),
          );
          for (final part in message.parts.whereType<DocumentPart>()) {
            expect(part.attachmentId, isIn(ids));
          }
        }
        for (final original in originals) {
          final duplicate = attachments.singleWhere(
            (item) => item.kind == original.kind,
          );
          expect(duplicate.id, isNot(original.id));
          expect(duplicate.localPath, isNot(original.localPath));
          expect(duplicate.size, original.size);
          expect(duplicate.width, original.width);
          expect(duplicate.height, original.height);
          expect(duplicate.createdAt, original.createdAt);
          expect(
            await File(duplicate.localPath).readAsBytes(),
            await File(original.localPath).readAsBytes(),
          );
          if (original.extractedTextPath != null) {
            expect(
              duplicate.extractedTextPath,
              isNot(original.extractedTextPath),
            );
            expect(
              await File(duplicate.extractedTextPath!).readAsString(),
              await File(original.extractedTextPath!).readAsString(),
            );
          }
        }

        final removedId = deleteOriginal ? sourceId : copy.id;
        final keptId = deleteOriginal ? copy.id : sourceId;
        final removedFiles = pathsOf(deleteOriginal ? originals : attachments);
        final keptFiles = pathsOf(deleteOriginal ? attachments : originals);
        await repository.deleteConversation(removedId);
        expect(await repository.getThread(removedId), isNull);
        expect(await repository.attachmentsFor(keptId), hasLength(4));
        expect(removedFiles.every((path) => !File(path).existsSync()), isTrue);
        expect(keptFiles.every((path) => File(path).existsSync()), isTrue);
        await repository.deleteConversation(keptId);
        expect(await storage.root.list().toList(), isEmpty);
      },
    );
  }

  test('copying a missing extraction cleans partial files and creates no conversation', () async {
    final sourceId = await seedConversation();
    final pdf = (await repository.attachmentsFor(sourceId))
        .singleWhere((attachment) => attachment.kind == AttachmentKind.pdf);
    await File(pdf.extractedTextPath!).delete();
    final before = (await storage.root.list().toList())
        .map((file) => file.path)
        .toSet();
    await expectLater(
      repository.duplicateConversation(sourceId),
      throwsA(isA<Failure>()),
    );
    expect(await db.select(db.conversations).get(), hasLength(1));
    expect(
      (await storage.root.list().toList()).map((file) => file.path).toSet(),
      before,
    );
    expect((await repository.getThread(sourceId))!.messages, hasLength(3));
  });

  test(
    'database failure rolls back the copy and removes only copied files',
    () async {
      final sourceId = await seedConversation();
      final before = (await storage.root.list().toList())
          .map((file) => file.path)
          .toSet();
      await db.customStatement(
        'CREATE TRIGGER reject_copy BEFORE INSERT ON messages '
        "BEGIN SELECT RAISE(ABORT, 'copy rejected by test'); END",
      );
      await expectLater(
        repository.duplicateConversation(sourceId),
        throwsA(isA<Failure>()),
      );
      expect(await db.select(db.conversations).get(), hasLength(1));
      expect(await db.select(db.messages).get(), hasLength(3));
      expect(await repository.attachmentsFor(sourceId), hasLength(4));
      expect(
        (await storage.root.list().toList()).map((file) => file.path).toSet(),
        before,
      );
    },
  );
}
