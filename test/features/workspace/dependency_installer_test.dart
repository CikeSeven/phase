import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/workspace/dependency_installer.dart';
import 'package:phase/features/workspace/dependency_profiles.dart';

import '../../support/test_database.dart';
import 'local_process_driver.dart';

/// 覆写 commandFor 注入本地可运行的假命令，不触碰真实 apt。
class ScriptedDependencyInstaller extends DependencyInstaller {
  ScriptedDependencyInstaller(super.repository, super.driver, this.scripts);
  final Map<DependencyStep, String> scripts;
  @override
  String commandFor(DependencyStep step, List<DependencyProfile> profiles) =>
      scripts[step] ?? 'true';
}

void main() {
  late ({AppDatabase database, Directory directory}) fixture;
  late LocalProcessDriver driver;
  late WorkspaceRepository repository;
  setUpAll(() {
    addTearDown(() async {
      await driver.dispose();
      await fixture.database.close();
      await fixture.directory.delete(recursive: true);
    });
  });
  setUp(() async {
    fixture = createTestDatabase();
    driver = LocalProcessDriver();
    repository = WorkspaceRepository(fixture.database, fixture.directory);
    await repository.saveEnvironment(
      const RuntimeEnvironment(
        phase: EnvironmentPhase.ready,
        rootPath: 'fixture-root',
        revision: 'fixture',
      ),
    );
  });
  DependencyInstaller installer({
    Map<DependencyStep, String> scripts = const {},
  }) => ScriptedDependencyInstaller(repository, driver, scripts);

  test('successful run records all groups and cleans staging', () async {
    final steps = <DependencyStep>[];
    final records =
        await installer(
          scripts: {
            DependencyStep.repairing: 'printf repairing',
            DependencyStep.updating: 'printf updating',
            DependencyStep.installing: 'printf installing',
            DependencyStep.verifying: 'printf "tool 1.2.3\\nextra"',
          },
        ).install(RunCancellation(), (step, line) {
          steps.add(step);
        });
    final env = await repository.environment();
    expect(env.installedDependencies.keys, [
      for (final profile in DependencyProfile.all) profile.id,
    ]);
    for (final profile in DependencyProfile.all) {
      expect(records[profile.id]?.version, 'tool 1.2.3');
      expect(env.installedDependencies[profile.id]?.version, 'tool 1.2.3');
    }
    expect(
      steps,
      containsAllInOrder([
        DependencyStep.repairing,
        DependencyStep.updating,
        DependencyStep.installing,
        DependencyStep.verifying,
      ]),
    );
    expect(driver.calls.first.rootfs, 'fixture-root');
    expect(driver.calls.first.cwd, '/workspace');
    final staging = Directory('${fixture.directory.path}/staging');
    expect(
      await staging.exists() ? await staging.list().isEmpty : true,
      isTrue,
    );
  });

  test(
    'merged install issues one apt command and one verify process per group',
    () async {
      final real = DependencyInstaller(repository, driver);
      final command = real.commandFor(
        DependencyStep.installing,
        DependencyProfile.all,
      );
      expect(command, contains('install -y'));
      for (final package in DependencyProfile.all.expand(
        (profile) => profile.packages,
      )) {
        expect(command, contains(package));
      }
      expect(
        real.commandFor(DependencyStep.verifying, [DependencyProfile.python]),
        DependencyProfile.python.verifyCommand,
      );
      // 脚本把每步替换为一个进程：修复、更新、安装各一次，验证按组三次。
      await installer().install(RunCancellation(), (_, _) {});
      expect(driver.calls, hasLength(6));
    },
  );

  test('repeated install keeps latest records for every group', () async {
    final first = await installer().install(RunCancellation(), (_, _) {});
    expect(first.values.every((record) => record.version == null), isTrue);
    final second = await installer(
      scripts: {DependencyStep.verifying: 'printf "tool 2.0.0"'},
    ).install(RunCancellation(), (_, _) {});
    final env = await repository.environment();
    expect(env.installedDependencies.keys, [
      for (final profile in DependencyProfile.all) profile.id,
    ]);
    for (final record in second.values) {
      expect(record.version, 'tool 2.0.0');
    }
  });

  test('cancel keeps previous records and throws', () async {
    await repository.saveEnvironment(
      (await repository.environment()).withDependencies(
        DependencyProfile.gitTools.id,
        InstalledDependency(
          installedAt: DateTime.fromMillisecondsSinceEpoch(0),
          version: 'git version 2.43.0',
        ),
      ),
    );
    final cancellation = RunCancellation();
    final pending = installer(scripts: {DependencyStep.verifying: 'sleep 30'})
        .install(cancellation, (_, _) {});
    while (driver.active.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    cancellation.cancel();
    await expectLater(pending, throwsA(isA<ToolCancelled>()));
    final env = await repository.environment();
    expect(env.installedDependencies['python'], isNull);
    expect(env.installedDependencies['node'], isNull);
    expect(
      env.installedDependencies['git-tools']?.version,
      'git version 2.43.0',
    );
    expect(driver.active, isEmpty);
  });

  test('apt update failure keeps previous records', () async {
    final result = installer(scripts: {DependencyStep.updating: 'exit 100'})
        .install(RunCancellation(), (_, _) {});
    await expectLater(
      result,
      throwsA(
        isA<WorkspaceFailure>().having(
          (error) => error.code,
          'code',
          'aptUpdate',
        ),
      ),
    );
    expect((await repository.environment()).installedDependencies, isEmpty);
  });

  test('install step failure keeps previous records', () async {
    final result = installer(scripts: {DependencyStep.installing: 'exit 100'})
        .install(RunCancellation(), (_, _) {});
    await expectLater(
      result,
      throwsA(
        isA<WorkspaceFailure>().having(
          (error) => error.code,
          'code',
          'aptInstall',
        ),
      ),
    );
  });

  test('verify failure reports without recording version', () async {
    final result = installer(scripts: {DependencyStep.verifying: 'exit 3'})
        .install(RunCancellation(), (_, _) {});
    await expectLater(
      result,
      throwsA(
        isA<WorkspaceFailure>().having(
          (error) => error.code,
          'code',
          'verifyFailed',
        ),
      ),
    );
    expect((await repository.environment()).installedDependencies, isEmpty);
  });

  test('dpkg repair failure degrades to a warning and continues', () async {
    final lines = <String>[];
    final records =
        await installer(
          scripts: {
            DependencyStep.repairing: 'exit 1',
            DependencyStep.verifying: 'printf "Python 3.12.3"',
          },
        ).install(RunCancellation(), (_, line) {
          lines.add(line);
        });
    expect(records[DependencyProfile.python.id]?.version, 'Python 3.12.3');
    expect(lines, contains('警告：dpkg 修复未完全成功，继续尝试安装'));
  });

  test('carriage returns split into lines like newlines', () async {
    final lines = <String>[];
    await installer(scripts: {DependencyStep.installing: 'printf "a\\rb\\nc"'})
        .install(RunCancellation(), (_, line) {
          lines.add(line);
        });
    expect(lines, containsAll(['a', 'b', 'c']));
  });

  test(
    'dependency change and environment change are mutually exclusive',
    () async {
      repository.beginDependencyChange();
      expect(
        () => repository.beginEnvironmentChange(),
        throwsA(isA<OperationFailure>()),
      );
      repository.endDependencyChange();
      repository.beginEnvironmentChange();
      expect(
        () => repository.beginDependencyChange(),
        throwsA(isA<OperationFailure>()),
      );
      repository.endEnvironmentChange();
    },
  );

  test('missing environment fails before creating a task', () async {
    await repository.saveEnvironment(
      const RuntimeEnvironment(phase: EnvironmentPhase.failed),
    );
    final result = installer().install(RunCancellation(), (_, _) {});
    await expectLater(
      result,
      throwsA(
        isA<WorkspaceFailure>().having(
          (error) => error.code,
          'code',
          'environmentMissing',
        ),
      ),
    );
    expect(driver.owners, isEmpty);
  });
}
