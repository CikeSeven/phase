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
  String commandFor(DependencyStep step, DependencyProfile profile) =>
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

  test('successful run records version and cleans staging', () async {
    final steps = <DependencyStep>[];
    final record =
        await installer(
          scripts: {
            DependencyStep.repairing: 'printf repairing',
            DependencyStep.updating: 'printf updating',
            DependencyStep.installing: 'printf installing',
            DependencyStep.verifying: 'printf "Python 3.12.3\\nextra"',
          },
        ).install(DependencyProfile.python, RunCancellation(), (step, line) {
          steps.add(step);
        });
    expect(record.version, 'Python 3.12.3');
    final env = await repository.environment();
    expect(env.installedDependencies['python']?.version, 'Python 3.12.3');
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
    expect(driver.calls.first.timeoutMs, isNull);
    final staging = Directory('${fixture.directory.path}/staging');
    expect(
      await staging.exists() ? await staging.list().isEmpty : true,
      isTrue,
    );
  });

  test('repeated install keeps latest record for the profile', () async {
    final first = await installer().install(
      DependencyProfile.gitTools,
      RunCancellation(),
      (_, _) {},
    );
    expect(first.version, isNull);
    final second = await installer(
      scripts: {DependencyStep.verifying: 'printf "git version 2.43.0"'},
    ).install(DependencyProfile.gitTools, RunCancellation(), (_, _) {});
    expect(second.version, 'git version 2.43.0');
    final env = await repository.environment();
    expect(env.installedDependencies.keys, ['git-tools']);
    expect(
      env.installedDependencies['git-tools']?.version,
      'git version 2.43.0',
    );
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
        .install(DependencyProfile.python, cancellation, (_, _) {});
    while (driver.active.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    cancellation.cancel();
    await expectLater(pending, throwsA(isA<ToolCancelled>()));
    final env = await repository.environment();
    expect(env.installedDependencies['python'], isNull);
    expect(
      env.installedDependencies['git-tools']?.version,
      'git version 2.43.0',
    );
    expect(driver.active, isEmpty);
  });

  test('apt update failure keeps previous records', () async {
    final result = installer(scripts: {DependencyStep.updating: 'exit 100'})
        .install(DependencyProfile.node, RunCancellation(), (_, _) {});
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
        .install(DependencyProfile.node, RunCancellation(), (_, _) {});
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
        .install(DependencyProfile.python, RunCancellation(), (_, _) {});
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
    final record =
        await installer(
          scripts: {
            DependencyStep.repairing: 'exit 1',
            DependencyStep.verifying: 'printf "Python 3.12.3"',
          },
        ).install(DependencyProfile.python, RunCancellation(), (_, line) {
          lines.add(line);
        });
    expect(record.version, 'Python 3.12.3');
    expect(lines, contains('警告：dpkg 修复未完全成功，继续尝试安装'));
  });

  test('carriage returns split into lines like newlines', () async {
    final lines = <String>[];
    await installer(scripts: {DependencyStep.installing: 'printf "a\\rb\\nc"'})
        .install(DependencyProfile.node, RunCancellation(), (_, line) {
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
    final result = installer().install(
      DependencyProfile.python,
      RunCancellation(),
      (_, _) {},
    );
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
