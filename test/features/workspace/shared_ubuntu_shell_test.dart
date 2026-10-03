import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/artifact_storage.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/workspace/shell_tool.dart';
import 'package:phase/features/workspace/workspace_files.dart';

import '../../support/test_database.dart';
import 'local_process_driver.dart';

void main() {
  test('shared rootfs, session defaults, explicit cwd, independent calls and artifact ownership', () async {
    final fixture = createTestDatabase();
    final driver = LocalProcessDriver();
    addTearDown(() async {
      await driver.dispose();
      await fixture.database.close();
      await fixture.directory.delete(recursive: true);
    });
    final repository = WorkspaceRepository(fixture.database, fixture.directory);
    final a = await repository.create('A', id: 'a');
    final b = await repository.create('B', id: 'b');
    final rootfs = repository.filesystem.layout.rootfs;
    for (final path in ['tmp', 'root']) {
      await Directory('$rootfs/$path').create();
    }
    await repository.saveEnvironment(
      RuntimeEnvironment(
        phase: EnvironmentPhase.ready,
        rootPath: rootfs,
        revision: 'fixture',
      ),
    );
    final artifacts = <Attachment>[];
    final storage = ArtifactStorage(
      root: Directory('${fixture.directory.path}/artifacts'),
      loadAttachments: (_) async => artifacts,
      saveAttachment: (attachment) async => artifacts.add(attachment),
    );
    final tools = {
      for (final session in [a, b])
        session.id: ShellTool(
          workspace: await repository.snapshot(session.id),
          driver: driver,
          files: WorkspaceFiles(repository),
        ),
    };
    var call = 0;
    Future<ToolOutcome> execute(
      String session,
      String command, {
      String? cwd,
    }) => tools[session]!.execute(
      {'command': command, 'cwd': ?cwd},
      ToolContext(
        conversationId: session,
        runId: 'run',
        toolCallId: 'call-${call++}',
        storage: storage,
        attachments: const [],
      ),
      RunCancellation(),
    );
    Map<String, dynamic> body(ToolOutcome outcome) =>
        (jsonDecode(outcome.content) as Map).cast<String, dynamic>();

    await driver.beginTask('run', 'fixture');
    final created = await execute(
      'a',
      'printf alpha > shared.txt; printf global > /root/shared.txt; pwd',
    );
    expect(created.ok, isTrue);
    expect(body(created)['cwd'], '/sessions/a');
    expect(driver.calls.last.cwd, '/sessions/a');
    expect(driver.calls.last.rootfs, rootfs);
    expect(created.artifacts, hasLength(1));
    expect(artifacts.single.name, 'shared.txt');
    final shared = await execute(
      'b',
      'cat /sessions/a/shared.txt /root/shared.txt',
    );
    expect(shared.ok, isTrue);
    expect(body(shared)['stdout'], 'alphaglobal');
    expect(body(shared)['cwd'], '/sessions/b');
    expect(shared.artifacts, isEmpty);
    expect(await Directory(b.rootPath).list().isEmpty, isTrue);

    final changed = await execute('a', 'cd /tmp && export TRANSIENT=1 && pwd');
    expect(body(changed)['stdout'], '$rootfs/tmp\n');
    expect(body(changed)['cwd'], '/sessions/a');
    final next = await execute('a', r'printf "%s\n" "${TRANSIENT-unset}"; pwd');
    expect(body(next)['stdout'], 'unset\n${a.rootPath}\n');
    expect(driver.calls.last.cwd, '/sessions/a');
    final explicit = await execute('b', 'pwd', cwd: '/root');
    expect(body(explicit)['cwd'], '/root');
    expect(body(explicit)['stdout'], '$rootfs/root\n');
    expect(driver.calls.last.cwd, '/root');
    final otherSession = await execute('b', 'pwd', cwd: '/sessions/a');
    expect(otherSession.ok, isTrue);
    expect(driver.calls.last.cwd, '/sessions/a');
    final failed = await execute('a', 'touch forbidden', cwd: '/missing');
    expect(failed.ok, isFalse);
    expect(body(failed)['cwd'], '/missing');
    expect(await Directory('$rootfs/missing').exists(), isFalse);
    expect(await File('${a.rootPath}/forbidden').exists(), isFalse);
    await File('$rootfs/root/not-a-directory').writeAsString('file');
    expect(
      (await execute('b', 'touch forbidden', cwd: '/root/not-a-directory')).ok,
      isFalse,
    );
    expect(await File('${b.rootPath}/forbidden').exists(), isFalse);
    final copied = await execute('b', 'cp /root/shared.txt global-copy.txt');
    expect(copied.artifacts, hasLength(1));
    expect(artifacts.last.name, 'global-copy.txt');
    expect(await File('$rootfs/root/shared.txt').readAsString(), 'global');
    expect(
      tools['a']!.describeAction({'command': 'pwd'}),
      contains('/sessions/a'),
    );
    expect(
      tools['a']!.validateArguments({'command': 'pwd', 'cwd': '/root'}),
      isNull,
    );
    expect(
      tools['a']!.validateArguments({'command': 'pwd', 'cwd': '../root'}),
      isNotNull,
    );
    expect(driver.active, isEmpty);
  });
}
