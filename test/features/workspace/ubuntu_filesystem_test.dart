import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/ubuntu_filesystem.dart';
import 'package:phase/data/models/ubuntu_filesystem_layout.dart';
import 'package:phase/features/tools/tool.dart';

void main() {
  late Directory root;
  late UbuntuFilesystem filesystem;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('phase_ufs_');
    filesystem = UbuntuFilesystem(root);
    addTearDown(() => root.delete(recursive: true));
  });

  Future<Directory> staged() async =>
      Directory(p.join(filesystem.layout.staging, 'install-fixture', 'rootfs'))
          .create(recursive: true);

  Future<void> content(
    Directory directory,
    String relative,
    String text,
  ) async {
    final file = File(p.join(directory.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  test(
    'layout maps session identity and service defaults to the fixed root',
    () {
      expect(
        filesystem.layout.rootfs,
        p.join(root.path, 'environments', 'ubuntu', 'rootfs'),
      );
      expect(
        filesystem.layout.sessionDirectory('a'),
        p.join(filesystem.layout.rootfs, 'sessions', 'a'),
      );
      expect(UbuntuFilesystemLayout.sessionGuestPath('a'), '/sessions/a');
      expect(
        UbuntuFilesystemLayout.mcpGuestPath('server'),
        '/services/mcp/server',
      );
      for (final id in ['', '../a', 'a/b', '.', 'a\u0000b']) {
        expect(
          () => filesystem.layout.sessionDirectory(id),
          throwsA(isA<FormatException>()),
        );
      }
    },
  );

  test(
    'commit and uninstall preserve existing session/service subtrees and links',
    () async {
      final session = await filesystem.createSession('a');
      final service = await filesystem.ensureMcpService('server');
      await content(session, 'report', 'session');
      await Link(p.join(session.path, 'report-link')).create('report');
      await content(service, 'server.js', 'service');
      final staging = await staged();
      await content(staging, 'usr/bin/tool', 'system');
      await content(staging, 'etc/os-release', 'fixture');
      await Link(p.join(staging.path, 'bin')).create('usr/bin');
      await content(Directory(filesystem.layout.rootfs), 'root/partial', 'old');
      await filesystem.commitSystem(staging, check: () {});
      expect(
        await File(p.join(filesystem.layout.rootfs, 'bin/tool')).readAsString(),
        'system',
      );
      expect(
        await File(p.join(filesystem.layout.rootfs, 'root/partial')).exists(),
        isFalse,
      );
      expect(
        await File(p.join(session.path, 'report-link')).readAsString(),
        'session',
      );
      expect(
        await File(p.join(service.path, 'server.js')).readAsString(),
        'service',
      );
      await content(
        Directory(filesystem.layout.rootfs),
        'root/global',
        'global',
      );
      await filesystem.removeSystem();
      expect(
        await File(p.join(session.path, 'report')).readAsString(),
        'session',
      );
      expect(
        await File(p.join(service.path, 'server.js')).readAsString(),
        'service',
      );
      expect(
        await File(p.join(filesystem.layout.rootfs, 'root/global')).exists(),
        isFalse,
      );
      expect(
        (await Directory(
          filesystem.layout.rootfs,
        ).list().toList()).map((entry) => p.basename(entry.path)).toSet(),
        {'sessions', 'services'},
      );
      expect(await filesystem.createSession('b'), isA<Directory>());
    },
  );

  for (final reserved in UbuntuFilesystemLayout.persistentRootNames) {
    test(
      'manifest rejects reserved $reserved before changing system or files',
      () async {
        final session = await filesystem.createSession('a');
        await content(session, 'report', 'keep');
        final system = Directory(filesystem.layout.rootfs);
        await content(system, 'etc/keep', 'old-system');
        final staging = await staged();
        await content(staging, '$reserved/override', 'forbidden');
        await expectLater(
          filesystem.commitSystem(staging, check: () {}),
          throwsA(isA<WorkspaceFailure>()),
        );
        expect(
          await File(p.join(session.path, 'report')).readAsString(),
          'keep',
        );
        expect(
          await File(p.join(system.path, 'etc/keep')).readAsString(),
          'old-system',
        );
      },
    );
  }

  test(
    'interrupted commit is retryable without moving or deleting sessions',
    () async {
      final session = await filesystem.createSession('a');
      await content(session, 'report', 'keep');
      final staging = await staged();
      await content(staging, 'etc/first', 'partial');
      await content(staging, 'usr/second', 'pending');
      await expectLater(
        filesystem.commitSystem(
          staging,
          check: () {
            if (File(p.join(filesystem.layout.rootfs, 'etc/first'))
                .existsSync()) {
              throw const ToolCancelled();
            }
          },
        ),
        throwsA(isA<ToolCancelled>()),
      );
      expect(await File(p.join(session.path, 'report')).readAsString(), 'keep');
      await content(staging, 'etc/first', 'retry');
      await filesystem.commitSystem(staging, check: () {});
      expect(
        await File(p.join(filesystem.layout.rootfs, 'etc/first'))
            .readAsString(),
        'retry',
      );
      expect(await File(p.join(session.path, 'report')).readAsString(), 'keep');
    },
  );

  test(
    'host operations do not follow substituted session or rootfs links',
    () async {
      final first = await filesystem.createSession('a');
      final other = await filesystem.createSession('b');
      await content(other, 'report', 'other');
      await first.delete();
      await Link(first.path).create(other.path);
      await expectLater(
        filesystem.session('a'),
        throwsA(isA<WorkspaceFailure>()),
      );
      await filesystem.deleteSession('a');
      expect(await File(p.join(other.path, 'report')).readAsString(), 'other');
      final outside = await Directory(p.join(root.path, 'outside')).create();
      await content(outside, 'keep', 'outside');
      await Directory(filesystem.layout.rootfs)
          .rename('${filesystem.layout.rootfs}-saved');
      await Link(filesystem.layout.rootfs).create(outside.path);
      await expectLater(
        filesystem.createSession('c'),
        throwsA(isA<WorkspaceFailure>()),
      );
      await expectLater(
        filesystem.removeSystem(),
        throwsA(isA<WorkspaceFailure>()),
      );
      expect(
        await File(p.join(outside.path, 'keep')).readAsString(),
        'outside',
      );
    },
  );
}
