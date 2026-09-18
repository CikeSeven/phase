import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/workspace/linux_installer.dart';

import '../../support/test_database.dart';
import 'local_process_driver.dart';

void main() {
  test('real HTTP, checksum, staging, shell check and uninstall preserve workspace', () async {
    final fixture = createTestDatabase();
    final driver = LocalProcessDriver();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dio = Dio();
    addTearDown(() async {
      dio.close(force: true);
      await server.close(force: true);
      await driver.dispose();
      await fixture.database.close();
      await fixture.directory.delete(recursive: true);
    });
    final archive = Archive()
      ..add(ArchiveFile.string('etc/os-release', 'fixture'));
    final bytes = gzip.encode(TarEncoder().encode(archive));
    server.listen((request) async {
      request.response.add(bytes);
      await request.response.close();
    });
    final image = LinuxImage(
      revision: 'fixture',
      url: 'http://127.0.0.1:${server.port}/rootfs',
      digest: sha256.convert(bytes).toString(),
      downloadBytes: bytes.length,
    );
    final repository = WorkspaceRepository(fixture.database, fixture.directory);
    final workspace = await repository.create('keep');
    await File('${workspace.rootPath}/keep.txt').writeAsString('keep');
    final installer = LinuxInstaller(repository, driver, dio, image: image);
    final phases = <EnvironmentPhase>[];
    await installer.install(
      RunCancellation(),
      (phase, _, _) => phases.add(phase),
    );
    expect((await repository.environment()).ready, isTrue);
    expect(
      phases,
      containsAllInOrder([
        EnvironmentPhase.downloading,
        EnvironmentPhase.verifying,
        EnvironmentPhase.extracting,
        EnvironmentPhase.checking,
        EnvironmentPhase.ready,
      ]),
    );
    expect(driver.active, isEmpty);
    await installer.uninstall();
    expect(
      (await repository.environment()).phase,
      EnvironmentPhase.notInstalled,
    );
    expect(await File('${workspace.rootPath}/keep.txt').readAsString(), 'keep');
  });
  for (final stop in [false, true]) {
    test(
      '${stop ? 'cancelled' : 'corrupt'} replacement retains ready environment and files',
      () async {
        final fixture = createTestDatabase();
        final driver = LocalProcessDriver();
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final dio = Dio();
        addTearDown(() async {
          dio.close(force: true);
          await server.close(force: true);
          await driver.dispose();
          await fixture.database.close();
          await fixture.directory.delete(recursive: true);
        });
        server.listen((request) async {
          request.response.add([1, 2, 3]);
          await request.response.close();
        });
        final repository = WorkspaceRepository(
          fixture.database,
          fixture.directory,
        );
        final old = await Directory(
          '${fixture.directory.path}/environments/old',
        ).create(recursive: true);
        await File('${old.path}/keep').writeAsString('old');
        await repository.saveEnvironment(
          RuntimeEnvironment(
            phase: EnvironmentPhase.ready,
            rootPath: old.path,
            revision: 'old',
          ),
        );
        final cancellation = RunCancellation();
        final installer = LinuxInstaller(
          repository,
          driver,
          dio,
          image: LinuxImage(
            revision: 'new',
            url: 'http://127.0.0.1:${server.port}/rootfs',
            digest: 'wrong',
            downloadBytes: 3,
          ),
        );
        await expectLater(
          installer.install(cancellation, (phase, _, _) {
            if (stop && phase == EnvironmentPhase.verifying) {
              cancellation.cancel();
            }
          }),
          throwsA(stop ? isA<ToolCancelled>() : isA<WorkspaceFailure>()),
        );
        final env = await repository.environment();
        expect(env.ready, isTrue);
        expect(env.revision, 'old');
        expect(await File('${old.path}/keep').readAsString(), 'old');
        expect(repository.busy, isFalse);
        expect(driver.owners, isEmpty);
        expect(
          await Directory('${fixture.directory.path}/staging').list().isEmpty,
          isTrue,
        );
      },
    );
  }
}
