import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/workspace/dependency_controller.dart';
import 'package:phase/features/workspace/dependency_profiles.dart';
import 'package:phase/features/workspace/process_api.g.dart';
import 'package:phase/features/workspace/process_driver.dart';

import '../../support/test_database.dart';
import 'local_process_driver.dart';

void main() {
  test(
    'more than five apt lines keep the newest output; cancellation retains it',
    () async {
      final fixture = createTestDatabase();
      final repository = WorkspaceRepository(
        fixture.database,
        fixture.directory,
      );
      final driver = _AptOutputDriver();
      final container = ProviderContainer(
        overrides: [
          workspaceRepositoryProvider.overrideWith((_) async => repository),
          processDriverProvider.overrideWith((_) => driver),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await driver.dispose();
        await fixture.database.close();
        await fixture.directory.delete(recursive: true);
      });
      await repository.saveEnvironment(
        const RuntimeEnvironment(
          phase: EnvironmentPhase.ready,
          rootPath: 'fixture-root',
          revision: 'fixture',
        ),
      );
      final output = Completer<void>();
      container.listen(dependencyControllerProvider, (_, state) {
        if (state.logTail.contains('Get: 9') && !output.isCompleted) {
          output.complete();
        }
      });
      final controller = container.read(dependencyControllerProvider.notifier);
      final pending = controller.install();
      await output.future.timeout(const Duration(seconds: 5));
      final state = container.read(dependencyControllerProvider);
      expect(state.step, DependencyStep.updating);
      expect(state.logTail, ['Get: 5', 'Get: 6', 'Get: 7', 'Get: 8', 'Get: 9']);
      expect(state.stepStartedAt, isNotNull);
      expect(state.lastOutputAt, isNotNull);
      controller.cancel();
      await pending;
      final stopped = container.read(dependencyControllerProvider);
      expect(stopped.busy, isFalse);
      expect(stopped.failed, isTrue);
      expect(stopped.step, DependencyStep.updating);
      expect(stopped.logTail, state.logTail);
      expect(driver.owners, isEmpty);
    },
  );
}

class _AptOutputDriver extends LocalProcessDriver {
  @override
  Future<LinuxProcess> start(
    LinuxProcessSpec spec,
    Future<void> Function(bool, Uint8List) onBytes,
  ) {
    spec.argv = [
      '-c',
      calls.isEmpty
          ? 'true'
          : r'for i in 1 2 3 4 5 6 7 8 9; do echo "Get: $i"; done; sleep 30',
    ];
    return super.start(spec, onBytes);
  }
}
