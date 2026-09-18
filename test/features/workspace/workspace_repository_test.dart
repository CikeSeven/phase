import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/workspace/workspace_files.dart';

import '../../support/test_database.dart';

void main() {
  test(
    'binding, lease, copy, and delete preserve history and guard active use',
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
      final chats = ConversationRepository(fixture.database);
      final workspace = await repository.create('任务文件');
      final conversation = await chats.createConversation(title: 'test');
      await repository.bind(conversation.id, workspace.id);
      expect(
        (await chats.getThread(conversation.id))!.conversation.workspaceId,
        workspace.id,
      );
      expect(await repository.acquire(workspace.id), isNull);
      await repository.saveEnvironment(
        RuntimeEnvironment(
          phase: EnvironmentPhase.ready,
          rootPath: '${fixture.directory.path}/environment',
          revision: 'fixture',
        ),
      );
      final lease = (await repository.acquire(workspace.id))!;
      expect(
        () => repository.beginEnvironmentChange(),
        throwsA(isA<OperationFailure>()),
      );
      await expectLater(
        repository.delete(workspace.id),
        throwsA(isA<OperationFailure>()),
      );
      await repository.bind(conversation.id, null);
      expect(lease.snapshot.id, workspace.id);
      lease.close();
      await repository.bind(conversation.id, workspace.id);
      final copy = await chats.duplicateConversation(conversation.id);
      expect(copy.workspaceId, workspace.id);
      await repository.delete(workspace.id);
      expect(
        (await chats.getThread(conversation.id))!.conversation.workspaceId,
        isNull,
      );
      expect((await chats.getThread(copy.id))!.conversation.title, 'test（副本）');
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
