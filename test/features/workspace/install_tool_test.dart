import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/workspace/dependency_installer.dart';
import 'package:phase/features/workspace/dependency_profiles.dart';
import 'package:phase/features/workspace/install_tool.dart';

import '../../support/test_database.dart';
import 'local_process_driver.dart';

class _ScriptedInstaller extends DependencyInstaller {
  _ScriptedInstaller(super.repository, super.driver, this.scripts);
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
  const binding = WorkspaceSnapshot(
    id: 'w',
    name: '会话工作区',
    rootPath: '/fixture/workspace',
    environmentRoot: 'fixture-root',
    environmentRevision: 'fixture',
  );
  InstallTool tool({Map<DependencyStep, String> scripts = const {}}) =>
      InstallTool(
        workspace: binding,
        repository: repository,
        driver: driver,
        installer: _ScriptedInstaller(repository, driver, scripts),
      );

  test('missing environment reports environmentMissing', () async {
    const bare = InstallTool();
    final outcome = await bare.execute(
      {},
      _context('c', 'r', 't'),
      RunCancellation(),
    );
    expect(outcome.ok, isFalse);
    expect(outcome.errorCode, 'environmentMissing');
  });

  test('arguments must stay empty', () {
    expect(tool().validateArguments({}), isNull);
    expect(tool().validateArguments({'profile': 'python'}), '该工具不需要参数');
  });

  test(
    'successful install returns per-group records and output tail',
    () async {
      final outcome = await tool(
        scripts: {
          DependencyStep.verifying: 'printf "Python 3.12.3"',
          DependencyStep.installing: 'printf installing',
        },
      ).execute({}, _context('c', 'r', 't'), RunCancellation());
      expect(outcome.ok, isTrue);
      final body = jsonDecode(outcome.content) as Map<String, dynamic>;
      final profiles = (body['profiles'] as List).cast<Map<String, dynamic>>();
      expect(profiles.map((profile) => profile['id']).toList(), [
        for (final profile in DependencyProfile.all) profile.id,
      ]);
      expect(
        profiles.every((profile) => profile['version'] == 'Python 3.12.3'),
        isTrue,
      );
      expect((body['outputTail'] as List).last, '验证: Python 3.12.3');
    },
  );

  test('apt failure maps to a failed outcome with its code', () async {
    final outcome = await tool(scripts: {DependencyStep.updating: 'exit 100'})
        .execute({}, _context('c', 'r', 't'), RunCancellation());
    expect(outcome.ok, isFalse);
    expect(outcome.errorCode, 'aptUpdate');
    expect(outcome.content, contains('软件源更新失败'));
  });

  test('cancellation returns a cancelled outcome', () async {
    final cancellation = RunCancellation();
    final pending = tool(scripts: {DependencyStep.verifying: 'sleep 30'})
        .execute({}, _context('c', 'r', 't'), cancellation);
    while (driver.active.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    cancellation.cancel();
    final outcome = await pending;
    expect(outcome.cancelled, isTrue);
    expect(outcome.ok, isFalse);
    expect(driver.active, isEmpty);
  });

  test('describeAction lists every package', () {
    final action = tool().describeAction({});
    expect(action, contains('Ubuntu fixture'));
    expect(action, contains('git、ripgrep'));
    expect(action, contains('python3、python3-pip、python3-venv'));
  });
}

ToolContext _context(String conversationId, String runId, String toolCallId) =>
    ToolContext(
      conversationId: conversationId,
      runId: runId,
      toolCallId: toolCallId,
      storage: _NoopStorage(),
      attachments: <Attachment>[],
    );

class _NoopStorage implements ToolStorage {
  @override
  Future<List<Attachment>> attachments(String conversationId) async => [];
  @override
  String artifactsDirectory(String conversationId) => Directory.systemTemp.path;
  @override
  Future<Attachment> registerArtifact({
    required String conversationId,
    required String path,
    required String name,
    String? sha256,
    String? extractedTextPath,
    String? extractionError,
  }) => throw UnimplementedError();
  @override
  Future<Attachment> registerBytes({
    required String conversationId,
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) => throw UnimplementedError();
}
