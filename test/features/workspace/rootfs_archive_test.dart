import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/workspace/rootfs_archive.dart';

void main() {
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('phase_rootfs_');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  Future<File> package(List<ArchiveFile> entries) async {
    final archive = Archive();
    for (final entry in entries) {
      archive.add(entry);
    }
    return File('${root.path}/root.tar.gz')
        .writeAsBytes(gzip.encode(TarEncoder().encode(archive)));
  }

  Future<int> extract(File file, {RunCancellation? cancellation}) =>
      RootfsArchive().extract(
        file,
        Directory('${root.path}/staging'),
        cancellation ?? RunCancellation(),
        setModes: (_, _) async {},
        progress: (_) {},
      );

  test('regular files and guest absolute links stay under rootfs', () async {
    final file = await package([
      ArchiveFile.string('usr/bin/example', 'payload'),
      ArchiveFile.symlink('bin', 'usr/bin'),
      ArchiveFile.symlink('usr/bin/alias', '/usr/bin/example'),
    ]);
    expect(await extract(file), 7);
    expect(
      await File('${root.path}/staging/bin/alias').readAsString(),
      'payload',
    );
    expect(
      await Link('${root.path}/staging/usr/bin/alias').target(),
      'example',
    );
  });
  test('directory entries keep the archive modes', () async {
    final received = <String, int>{};
    final archive = Archive();
    archive.add(ArchiveFile.string('var/lib/dpkg/status', 'x')..mode = 0x1a4);
    final dpkgDir = ArchiveFile.directory('var/lib/dpkg/')..mode = 0x1ed;
    // Directory.create obeys the process umask; the extractor must restore
    // the archive's 0755 so dpkg can update its database inside the guest.
    archive.add(dpkgDir);
    final file = File('${root.path}/dirs.tar.gz');
    await file.writeAsBytes(gzip.encode(TarEncoder().encode(archive)));
    await RootfsArchive().extract(
      file,
      Directory('${root.path}/staging'),
      RunCancellation(),
      setModes: (paths, modes) async {
        for (var i = 0; i < paths.length; i++) {
          received[paths[i]] = modes[i];
        }
      },
      progress: (_) {},
    );
    expect(received['${root.path}/staging/var/lib/dpkg'], 0x1ed);
  });
  test('rejects traversal', () async {
    await expectLater(
      extract(await package([ArchiveFile.string('../escape', 'bad')])),
      throwsA(isA<WorkspaceFailure>()),
    );
    expect(File('${root.path}/escape').existsSync(), isFalse);
  });
  test(
    'rejects escaping link targets and files written beneath links',
    () async {
      await expectLater(
        extract(await package([ArchiveFile.symlink('escape', '../outside')])),
        throwsA(isA<WorkspaceFailure>()),
      );
      await Directory('${root.path}/staging').delete(recursive: true);
      await expectLater(
        extract(
          await package([
            ArchiveFile.symlink('bin', 'usr/bin'),
            ArchiveFile.string('bin/unsafe', 'bad'),
          ]),
        ),
        throwsA(isA<WorkspaceFailure>()),
      );
    },
  );
  test('cancelled extraction never publishes an installation', () async {
    final cancellation = RunCancellation()..cancel();
    await expectLater(
      extract(
        await package([ArchiveFile.string('file', 'data')]),
        cancellation: cancellation,
      ),
      throwsA(isA<ToolCancelled>()),
    );
    expect(File('${root.path}/staging/file').existsSync(), isFalse);
  });
  test('rejects corrupt tar header', () async {
    final file = await package([ArchiveFile.string('file', 'data')]);
    final bytes = gzip.decode(await file.readAsBytes());
    bytes[0] ^= 1;
    await file.writeAsBytes(gzip.encode(bytes));
    await expectLater(extract(file), throwsA(isA<WorkspaceFailure>()));
  });
}
