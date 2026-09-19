import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/workspace/workspace_files.dart';

import '../../support/test_database.dart';

void main() {
  test('conversation workspaces are automatic, independent, copied and deleted with their owner', () async {
    final fixture = createTestDatabase();
    addTearDown(() async {
      await fixture.database.close();
      await fixture.directory.delete(recursive: true);
    });
    final repository = WorkspaceRepository(fixture.database, fixture.directory);
    final attachments = AttachmentStorage(
      Directory('${fixture.directory.path}/attachments'),
    );
    final chats = ConversationRepository(
      fixture.database,
      workspaces: repository,
      attachments: attachments,
    );
    final conversation = await chats.createConversation(title: 'test');
    final other = await chats.createConversation(title: 'other');
    final workspace = (await repository.get(conversation.workspaceId!))!;
    final otherWorkspace = (await repository.get(other.workspaceId!))!;
    expect(workspace.id, isNot(otherWorkspace.id));
    await Directory('${workspace.rootPath}/nested').create();
    await File('${workspace.rootPath}/nested/report').writeAsString('original');
    await Link('${workspace.rootPath}/report-link').create('nested/report');
    await repository.recordCopy(workspace.id, 'nested/report', {
      'kind': 'fixture',
    });
    final artifacts = Directory(
      '${attachments.root.path}/artifacts/${conversation.id}',
    );
    await artifacts.create(recursive: true);
    await File('${artifacts.path}/unregistered').writeAsString('partial');
    final lease = await repository.acquire(workspace.id);
    expect(lease.snapshot.linuxAvailable, isFalse);
    expect(
      () => repository.beginEnvironmentChange(),
      throwsA(isA<OperationFailure>()),
    );
    await expectLater(
      chats.deleteConversation(conversation.id),
      throwsA(isA<OperationFailure>()),
    );
    await expectLater(
      chats.duplicateConversation(conversation.id),
      throwsA(isA<OperationFailure>()),
    );
    expect(await repository.list(), hasLength(2));
    lease.close();
    final copy = await chats.duplicateConversation(conversation.id);
    final copiedWorkspace = (await repository.get(copy.workspaceId!))!;
    expect(copiedWorkspace.id, isNot(workspace.id));
    expect(
      await File('${copiedWorkspace.rootPath}/report-link').readAsString(),
      'original',
    );
    await File('${copiedWorkspace.rootPath}/nested/report')
        .writeAsString('copy');
    expect(
      await File('${workspace.rootPath}/nested/report').readAsString(),
      'original',
    );
    await chats.deleteConversation(conversation.id);
    expect(await chats.getThread(conversation.id), isNull);
    expect(await repository.get(workspace.id), isNull);
    expect(await Directory(workspace.rootPath).exists(), isFalse);
    expect(await artifacts.exists(), isFalse);
    expect(
      await File('${copiedWorkspace.rootPath}/nested/report').readAsString(),
      'copy',
    );
    expect(await Directory(otherWorkspace.rootPath).exists(), isTrue);
    expect(
      await fixture.database.select(fixture.database.workspaceCopies).get(),
      hasLength(1),
    );
    await chats.deleteConversation(copy.id);
    expect(
      await fixture.database.select(fixture.database.workspaceCopies).get(),
      isEmpty,
    );
  });

  test(
    'failed file cleanup keeps the conversation and deletion marker for retry',
    () async {
      final fixture = createTestDatabase();
      addTearDown(() async {
        await fixture.database.close();
        await fixture.directory.delete(recursive: true);
      });
      final repository = WorkspaceRepository(
        fixture.database,
        fixture.directory,
      );
      final storage = _FailingCleanup(fixture.directory);
      final chats = ConversationRepository(
        fixture.database,
        workspaces: repository,
        attachments: storage,
      );
      final conversation = await chats.createConversation();
      await expectLater(
        chats.deleteConversation(conversation.id),
        throwsA(isA<OperationFailure>()),
      );
      expect(await chats.getThread(conversation.id), isNotNull);
      expect(
        (await repository.get(conversation.workspaceId!))!.deleting,
        isTrue,
      );
      await expectLater(
        repository.acquire(conversation.workspaceId!),
        throwsA(isA<OperationFailure>()),
      );
      storage.fail = false;
      await chats.deleteConversation(conversation.id);
      expect(await chats.getThread(conversation.id), isNull);
      expect(await repository.get(conversation.workspaceId!), isNull);
    },
  );

  test('file tools reject escaping symlinks and lexical traversal', () async {
    final root = Directory.systemTemp.createTempSync('phase_paths_');
    addTearDown(() => root.delete(recursive: true));
    final workspace = await Directory('${root.path}/workspace').create();
    await File('${root.path}/outside').writeAsString('outside');
    await Link('${workspace.path}/escape').create('../outside');
    await expectLater(
      workspacePath(workspace.path, 'escape'),
      throwsA(isA<WorkspaceFailure>()),
    );
    await expectLater(
      workspacePath(workspace.path, '../outside'),
      throwsA(isA<WorkspaceFailure>()),
    );
  });

  test(
    'interrupted installation restores the previous ready pointer',
    () async {
      final fixture = createTestDatabase();
      addTearDown(() async {
        await fixture.database.close();
        await fixture.directory.delete(recursive: true);
      });
      final repository = WorkspaceRepository(
        fixture.database,
        fixture.directory,
      );
      await repository.saveEnvironment(
        const RuntimeEnvironment(
          phase: EnvironmentPhase.extracting,
          rootPath: '/fixture/rootfs',
          revision: 'old',
          installedBytes: 12,
        ),
      );
      await Directory('${fixture.directory.path}/staging/partial')
          .create(recursive: true);
      await repository.recoverInstallation();
      expect((await repository.environment()).ready, isTrue);
      expect((await repository.environment()).revision, 'old');
      expect(
        Directory('${fixture.directory.path}/staging').existsSync(),
        isFalse,
      );
    },
  );
}

class _FailingCleanup extends AttachmentStorage {
  _FailingCleanup(super.root);
  bool fail = true;
  @override
  Future<void> deleteConversationFiles(
    String conversationId,
    Iterable<String> paths,
  ) async {
    if (fail) throw const OperationFailure('fixture cleanup failure');
    await super.deleteConversationFiles(conversationId, paths);
  }
}
