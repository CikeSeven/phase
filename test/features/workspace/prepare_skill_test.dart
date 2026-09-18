import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/workspace/workspace_files.dart';

import '../skills/skill_test_support.dart';

void main() {
  test('copies pinned Skill version, records origin, and keeps installed originals intact', () async {
    final fixture = SkillFixture();
    addTearDown(fixture.close);
    final skill = await fixture.install(
      files: {'scripts/run.sh': utf8.encode('printf old')},
    );
    final lease = await fixture.repository.acquire({skill.id});
    addTearDown(lease.close);
    await fixture.install(
      files: {'scripts/run.sh': utf8.encode('printf new')},
      replaceId: skill.id,
    );
    final repository = WorkspaceRepository(
      fixture.database,
      Directory('${fixture.directory.path}/linux'),
    );
    final workspace = await repository.create('scripts');
    final snapshot = WorkspaceSnapshot(
      id: workspace.id,
      name: workspace.name,
      rootPath: workspace.rootPath,
      environmentRoot: '/fixture',
      environmentRevision: 'fixture',
    );
    var checks = 0;
    final path = await WorkspaceFiles(repository).prepareSkill(
      snapshot,
      lease.skills.single,
      RunCancellation(),
      checkPermission: () async {
        checks++;
      },
    );
    final copied = File(
      '${workspace.rootPath}${path.substring('/workspace'.length)}/scripts/run.sh',
    );
    expect(await copied.readAsString(), 'printf old');
    await copied.writeAsString('changed');
    expect(
      await File('${skill.snapshot.installedPath}/scripts/run.sh')
          .readAsString(),
      'printf old',
    );
    final copies = await fixture.database
        .select(fixture.database.workspaceCopies)
        .get();
    expect(copies.single.sourceJson, contains(skill.snapshot.revision));
    expect(checks, 2);
  });
  test('permission tightening during copy prevents publication', () async {
    final fixture = SkillFixture();
    addTearDown(fixture.close);
    final skill = await fixture.install(
      files: {'scripts/run.sh': utf8.encode('printf old')},
    );
    final repository = WorkspaceRepository(
      fixture.database,
      Directory('${fixture.directory.path}/linux'),
    );
    final workspace = await repository.create('scripts');
    var checks = 0;
    await expectLater(
      WorkspaceFiles(repository).prepareSkill(
        WorkspaceSnapshot(
          id: workspace.id,
          name: workspace.name,
          rootPath: workspace.rootPath,
          environmentRoot: '/fixture',
          environmentRevision: 'fixture',
        ),
        skill.snapshot,
        RunCancellation(),
        checkPermission: () async {
          if (++checks == 2) throw const OperationFailure('revoked');
        },
      ),
      throwsA(isA<OperationFailure>()),
    );
    expect(
      await fixture.database.select(fixture.database.workspaceCopies).get(),
      isEmpty,
    );
    expect(
      await Directory(workspace.rootPath)
          .list(recursive: true)
          .where((e) => e is File)
          .isEmpty,
      isTrue,
    );
  });
}
