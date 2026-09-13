import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/artifact_storage.dart';

void main() {
  late Directory temporary;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('phase_artifact_failure');
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  test('产物目录不可写属于文件处理错误，不能伪装成应用记录存储故障', () async {
    final blocker = File('${temporary.path}/artifacts')
      ..writeAsStringSync('keep');
    var registered = false;
    final storage = ArtifactStorage(
      root: temporary,
      loadAttachments: (_) async => [],
      saveAttachment: (_) async => registered = true,
    );
    await expectLater(
      storage.registerBytes(
        conversationId: 'conversation',
        name: 'notes.txt',
        mimeType: 'text/plain',
        bytes: [1, 2, 3],
      ),
      throwsA(isA<OperationFailure>()),
    );
    expect(registered, isFalse);
    expect(blocker.readAsStringSync(), 'keep');
  });

  test('文件丢失时不登记不存在的附件，也不抛全局 StorageFailure', () async {
    var registered = false;
    final storage = ArtifactStorage(
      root: temporary,
      loadAttachments: (_) async => [],
      saveAttachment: (_) async => registered = true,
    );
    await expectLater(
      storage.registerArtifact(
        conversationId: 'conversation',
        path: '${temporary.path}/missing.txt',
        name: 'notes.txt',
      ),
      throwsA(isA<OperationFailure>()),
    );
    expect(registered, isFalse);
  });

  test('同样的文件系统异常来自记录存储边界时仍是 StorageFailure', () async {
    final file = File('${temporary.path}/notes.txt')
      ..writeAsStringSync('content');
    final storage = ArtifactStorage(
      root: temporary,
      loadAttachments: (_) async => [],
      saveAttachment: (_) async => throw const FileSystemException('fixture'),
    );
    await expectLater(
      storage.registerArtifact(
        conversationId: 'conversation',
        path: file.path,
        name: 'notes.txt',
      ),
      throwsA(isA<StorageFailure>()),
    );
    expect(file.readAsStringSync(), 'content');
  });
}
