import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/artifact_storage.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/workspace/process_api.g.dart';
import 'package:phase/features/workspace/shell_tool.dart';
import 'package:phase/features/workspace/workspace_files.dart';

import '../../support/test_database.dart';
import 'local_process_driver.dart';

void main() {
  for (final scenario in [
    'stop',
    'timeout',
    'limit',
    'independent',
    'beforeStart',
    'empty',
    'previewBoundary',
    'largeStderr',
  ]) {
    test('real shell $scenario preserves output and closes process', () async {
      final fixture = createTestDatabase();
      final driver = LocalProcessDriver();
      addTearDown(() async {
        await driver.dispose();
        await fixture.database.close();
        await fixture.directory.delete(recursive: true);
      });
      final repository = WorkspaceRepository(
        fixture.database,
        fixture.directory,
      );
      final workspace = await repository.create('test');
      final binding = WorkspaceSnapshot(
        id: workspace.id,
        name: workspace.name,
        rootPath: workspace.rootPath,
        environmentRoot: '/fixture',
        environmentRevision: 'fixture',
      );
      final attachments = <Attachment>[];
      final storage = ArtifactStorage(
        root: Directory('${fixture.directory.path}/artifacts'),
        loadAttachments: (_) async => attachments,
        saveAttachment: (a) async {
          attachments.add(a);
        },
      );
      final cancel = RunCancellation();
      final tool = ShellTool(
        workspace: binding,
        driver: driver,
        files: scenario == 'beforeStart'
            ? _CancelDuringPreparation(repository, cancel)
            : WorkspaceFiles(repository),
      );
      ToolContext context(String id) => ToolContext(
        conversationId: 'c',
        runId: 'r',
        toolCallId: id,
        storage: storage,
        attachments: attachments,
      );
      await driver.beginTask('r', 'test');
      final pending = tool.execute(
        {
          'command': switch (scenario) {
            'limit' => 'head -c 10000000 /dev/zero',
            'independent' => 'export PHASE_TRANSIENT=1; cd /tmp; printf first',
            'empty' => 'true',
            'previewBoundary' => 'head -c 65536 /dev/zero',
            'largeStderr' => 'head -c 65537 /dev/zero >&2',
            _ => 'printf partial; sleep 60',
          },
          'timeoutMs': scenario == 'timeout' ? 50 : 60000,
        },
        context('first'),
        cancel,
      );
      if (scenario == 'stop') {
        while (driver.active.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        cancel.cancel();
      }
      final result = await pending;
      if (scenario == 'beforeStart') {
        expect(result.cancelled, isTrue);
        expect(driver.calls, isEmpty);
        return;
      }
      final body = jsonDecode(result.content) as Map<String, dynamic>;
      expect(driver.active, isEmpty);
      if (scenario == 'stop') {
        expect(result.cancelled, isTrue);
        expect(body['stdout'], 'partial');
      }
      if (scenario == 'timeout') {
        expect(body['timedOut'], isTrue);
        expect(body['stdout'], 'partial');
      }
      if (scenario == 'limit') {
        expect(body['outputLimitExceeded'], isTrue);
        expect(body['stdoutBytes'], ShellLimits.outputBytes);
        expect((body['stdout'] as String).length, ShellLimits.previewBytes);
        expect(
          await File(attachments.single.localPath).length(),
          ShellLimits.outputBytes,
        );
      }
      if (scenario == 'independent') {
        final next = await tool.execute(
          {
            'command':
                'printf "value=%s cwd=%s" "\${PHASE_TRANSIENT-unset}" "\$PWD"',
          },
          context('second'),
          RunCancellation(),
        );
        expect(next.content, contains('value=unset'));
        expect(next.content, contains(workspace.rootPath));
      }
      if (scenario == 'largeStderr') {
        expect(body['stdout'], isEmpty);
        expect((body['stderr'] as String).length, ShellLimits.previewBytes);
        expect(body['previewTruncated'], isTrue);
        expect(attachments.single.name, 'first-stderr.txt');
        expect(
          await File(attachments.single.localPath).readAsBytes(),
          List<int>.filled(ShellLimits.previewBytes + 1, 0),
        );
      }
      if (scenario != 'limit' && scenario != 'largeStderr') {
        expect(result.artifacts, isEmpty);
        expect(attachments, isEmpty);
        final directory = Directory(context('first').artifactsDirectory);
        expect(
          await directory.exists() ? await directory.list().toList() : [],
          isEmpty,
        );
      }
    });
  }
  test(
    'raw stdin and byte chunks retain multibyte UTF-8 until decoding',
    () async {
      final directory = Directory.systemTemp.createTempSync('phase_pipes_');
      final driver = LocalProcessDriver();
      addTearDown(() async {
        await driver.dispose();
        await directory.delete(recursive: true);
      });
      await driver.beginTask('owner', 'test');
      final bytes = BytesBuilder();
      final process = await driver.start(
        LinuxProcessSpec(
          ownerId: 'owner',
          processId: 'pipes',
          rootfs: '/fixture',
          workspace: directory.path,
          executable: '/bin/sh',
          argv: ['-c', 'cat'],
          cwd: '/workspace',
          environment: {},
          timeoutMs: 1000,
          outputLimitBytes: 10000,
        ),
        (_, data) async {
          bytes.add(data);
        },
      );
      final text = utf8.encode('相月');
      for (final byte in text) {
        await process.write(Uint8List.fromList([byte]));
      }
      await process.closeInput();
      expect((await process.exited).exitCode, 0);
      expect(utf8.decode(bytes.takeBytes()), '相月');
    },
  );
}

class _CancelDuringPreparation extends WorkspaceFiles {
  _CancelDuringPreparation(super.repository, this.cancellation);
  final RunCancellation cancellation;
  @override
  Future<Map<String, String>> outputs(WorkspaceSnapshot workspace) async {
    cancellation.cancel();
    return {};
  }
}
