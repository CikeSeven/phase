import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:phase/data/datasources/local/artifact_storage.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/features/tools/file_text.dart';
import 'package:phase/features/tools/file_tools.dart';
import 'package:phase/features/tools/tool.dart';

void main() {
  late Directory root;
  late Directory workspace;
  late ToolContext context;
  late ArtifactStorage storage;
  late Map<String, Attachment> attachments;
  late RunCancellation cancellation;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('phase_file_tools');
    workspace = await Directory(p.join(root.path, 'workspace')).create();
    attachments = {};
    storage = ArtifactStorage(
      root: root,
      loadAttachments: (_) async => attachments.values.toList(),
      saveAttachment: (attachment) async =>
          attachments[attachment.id] = attachment,
    );
    context = ToolContext(
      conversationId: 'conversation',
      runId: 'run',
      toolCallId: 'call',
      storage: storage,
      attachments: [],
      workspaceDirectory: workspace.path,
    );
    cancellation = RunCancellation();
  });
  tearDown(() => root.delete(recursive: true));

  Future<ToolOutcome> write(String path, String content) =>
      const WriteFileTool().execute(
        {'path': path, 'content': content},
        context,
        cancellation,
      );
  Future<ToolOutcome> read(String path, {int? offset, int? limit}) =>
      const ReadFileTool().execute(
        {'path': path, 'offset': ?offset, 'limit': ?limit},
        context,
        cancellation,
      );
  Future<ToolOutcome> edit(String path, List<Map<String, String>> edits) =>
      const EditFileTool().execute(
        {'path': path, 'edits': edits},
        context,
        cancellation,
      );
  File workspaceFile(String path) => File(p.join(workspace.path, path));

  test('exact paths, empty and whitespace content, nested parents and no implicit artifacts', () async {
    for (final path in [
      'README',
      '.env',
      'src/script.py',
      ' 文 件 ',
      '..config',
    ]) {
      expect((await write(path, '')).ok, isTrue);
      expect(await workspaceFile(path).readAsString(), '');
      expect(await workspaceFile('$path.txt').exists(), isFalse);
      expect((await read(path)).ok, isTrue);
    }
    final result = await write('README', '月色\n');
    expect(result.artifacts, isEmpty);
    expect(await workspaceFile('README').length(), utf8.encode('月色\n').length);
    expect(attachments, isEmpty);
    expect((await write('.env', ' \n\t')).ok, isTrue);
    expect(await workspaceFile('.env').readAsString(), ' \n\t');
    expect(
      (await write('large', '月' * (maxFileWriteBytes ~/ 3 + 1))).errorCode,
      'contentTooLarge',
    );
    expect(await workspaceFile('large').exists(), isFalse);
  });

  test('multi edits match original file, preserve BOM and CRLF, and allow deletion', () async {
    await write('code', '\ufeffalpha\r\nbeta\r\ngamma\r\n');
    final result = await edit('code', [
      {'oldText': 'alpha\nbeta', 'newText': 'beta\nnew'},
      {'oldText': 'gamma\n', 'newText': ''},
    ]);
    expect(result.ok, isTrue);
    expect(
      await workspaceFile('code').readAsBytes(),
      utf8.encode('\ufeffbeta\r\nnew\r\n'),
    );
    expect(
      await workspaceFile('code').length(),
      utf8.encode('\ufeffbeta\r\nnew\r\n').length,
    );
  });

  test('missing, ambiguous and overlapping replacements leave the entire file untouched', () async {
    const original = 'one two one\nunique block\n';
    await write('code', original);
    for (final (edits, error) in [
      (
        [
          {'oldText': 'unique', 'newText': 'changed'},
          {'oldText': 'absent', 'newText': 'x'},
        ],
        'textNotFound',
      ),
      (
        [
          {'oldText': 'one', 'newText': 'x'},
        ],
        'ambiguousEdit',
      ),
      (
        [
          {'oldText': 'unique block', 'newText': 'x'},
          {'oldText': 'block', 'newText': 'y'},
        ],
        'overlappingEdits',
      ),
    ]) {
      expect((await edit('code', edits)).errorCode, error);
      expect(await workspaceFile('code').readAsString(), original);
    }
    await write('overlap', 'aaa');
    expect(
      (await edit('overlap', [
        {'oldText': 'aa', 'newText': 'x'},
      ])).errorCode,
      'ambiguousEdit',
    );
  });

  test(
    'read pages use 1-based complete lines and expose a usable continuation',
    () async {
      await write('data', '第一行\n第二行\n第三行');
      expect(
        (await read('data', offset: 2, limit: 1)).content,
        '第二行\n\n[第 2–2 行；继续读取：offset=3]',
      );
      expect((await read('data', offset: 3)).content, '第三行\n\n[第 3–3 行；已到结尾]');
      expect((await read('data', offset: 4)).errorCode, 'offsetOutOfRange');
      await write('data', List.filled(20, '月' * 1000).join('\n'));
      final page = await readFilePage(workspaceFile('data'), {}, cancellation);
      expect(page.text.split('\n'), hasLength(5));
      expect(page.toJson()['nextOffset'], 6);
      expect(page.text, isNot(contains('\ufffd')));
      expect(
        (await read('data', offset: 6, limit: 1)).content,
        startsWith('月' * 1000),
      );
    },
  );

  test(
    'large files can be paged without the old whole-file 4 MiB rejection',
    () async {
      final file = File(p.join(workspace.path, 'large.log'));
      final output = file.openWrite();
      for (var i = 0; i < 5000; i++) {
        output.writeln('$i ${'x' * 1000}');
      }
      await output.close();
      final result = await read('large.log', offset: 4501, limit: 2);
      expect(result.ok, isTrue);
      expect(result.content, startsWith('4500 '));
      expect(result.content, contains('offset=4503'));
    },
  );

  test(
    'read_file detects a workspace image and registers a model-sized artifact',
    () async {
      final bytes = img.encodePng(
        img.Image(width: 24, height: 12, numChannels: 4),
      );
      await workspaceFile('picture.png').writeAsBytes(bytes);

      final result = await read('picture.png');

      expect(result.ok, isTrue);
      expect(result.artifacts, hasLength(1));
      final output = jsonDecode(result.content) as Map<String, dynamic>;
      expect(output['type'], 'image');
      expect(output['mimeType'], 'image/png');
      expect(output['width'], 24);
      expect(output['height'], 12);
      final artifact = attachments[result.artifacts.single]!;
      expect(artifact.isImage, isTrue);
      expect(artifact.mimeType, 'image/png');
      expect(
        img.decodeImage(await File(artifact.localPath).readAsBytes()),
        isNotNull,
      );
    },
  );

  test('read_file resolves an image attachment by attachment id', () async {
    final bytes = img.encodeJpg(img.Image(width: 10, height: 6), quality: 90);
    final source = await storage.registerBytes(
      conversationId: 'conversation',
      name: 'source.jpg',
      mimeType: 'image/jpeg',
      bytes: bytes,
    );
    context = ToolContext(
      conversationId: 'conversation',
      runId: 'run',
      toolCallId: 'call',
      storage: storage,
      attachments: [source],
      workspaceDirectory: workspace.path,
    );

    final result = await read('attachment:${source.id}');

    expect(result.ok, isTrue);
    expect(result.artifacts, hasLength(1));
    final output = jsonDecode(result.content) as Map<String, dynamic>;
    expect(output['type'], 'image');
    expect(output['mimeType'], 'image/jpeg');
    expect(output['width'], 10);
    expect(output['height'], 6);
    expect(attachments[result.artifacts.single]!.isImage, isTrue);
  });

  test('read_file recognizes every supported raster image format', () async {
    final image = img.Image(width: 10, height: 6);
    final fixtures = <String, List<int>>{
      'picture.jpg': img.encodeJpg(image, quality: 90),
      'picture.gif': img.encodeGif(image),
      'picture.webp': img.encodeWebP(image),
      'picture.bmp': img.encodeBmp(image),
    };

    for (final entry in fixtures.entries) {
      await workspaceFile(entry.key).writeAsBytes(entry.value);

      final result = await read(entry.key);

      expect(result.ok, isTrue, reason: entry.key);
      expect(result.artifacts, hasLength(1), reason: entry.key);
      final output = jsonDecode(result.content) as Map<String, dynamic>;
      expect(output['type'], 'image', reason: entry.key);
      expect(output['width'], 10, reason: entry.key);
      expect(output['height'], 6, reason: entry.key);
      expect(attachments[result.artifacts.single]!.isImage, isTrue);
    }
  });

  test(
    'read_file reports malformed recognized images instead of throwing',
    () async {
      await workspaceFile('broken.png')
          .writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);

      final result = await read('broken.png');

      expect(result.ok, isFalse);
      expect(result.errorCode, 'invalidImage');
    },
  );

  test('oversize lines and binary inputs have actionable errors', () async {
    await write('long', '月' * maxFileReadBytes);
    expect((await read('long')).errorCode, 'lineTooLong');
    await write('boundary', '${'x' * maxFileReadBytes}\n');
    final boundary = await readFilePage(
      workspaceFile('boundary'),
      {},
      cancellation,
    );
    expect(utf8.encode(boundary.text), hasLength(maxFileReadBytes));
    expect(boundary.toJson()['nextOffset'], 2);
    expect((await read('boundary', offset: 2)).ok, isTrue);
    await workspaceFile('binary').writeAsBytes([0xff, 0xfe]);
    expect((await read('binary')).errorCode, 'notText');
    await workspaceFile('binary').writeAsBytes([65, 0, 66]);
    expect((await read('binary')).errorCode, 'notText');
    await workspaceFile('unknown').writeAsBytes([0x00, 0x01, 0x02]);
    expect((await read('unknown')).errorCode, 'notText');
  });

  test('workspace paths agree with shell, list supports directories and pagination', () async {
    await write('src/.env', 'TOKEN=fixture');
    expect(
      await File(p.join(workspace.path, 'src/.env')).readAsString(),
      'TOKEN=fixture',
    );
    expect(attachments, isEmpty);
    expect(
      (await edit('src/.env', [
        {'oldText': 'fixture', 'newText': 'test'},
      ])).ok,
      isTrue,
    );
    final listing = await const ListFilesTool().execute(
      {'path': 'src'},
      context,
      cancellation,
    );
    expect(jsonDecode(listing.content)['files'], [
      {'path': 'src/.env', 'type': 'file'},
    ]);
    await write('a', 'a');
    await write('b', 'b');
    await write('dir/c', 'c');
    final first = jsonDecode(
      (await const ListFilesTool().execute(
        {'limit': 2},
        context,
        cancellation,
      )).content,
    );
    expect(first['nextOffset'], 2);
    final next = jsonDecode(
      (await const ListFilesTool().execute(
        {'offset': 2, 'limit': 2},
        context,
        cancellation,
      )).content,
    );
    expect(next['files'], [
      {'path': 'dir', 'type': 'directory'},
      {'path': 'src', 'type': 'directory'},
    ]);
  });

  test('path escapes and symlink escapes fail before read or write', () async {
    await write('inside', 'safe');
    final outside = await File(p.join(root.path, 'outside'))
        .writeAsString('original');
    await Link(p.join(workspace.path, 'link')).create(outside.path);
    await Link(p.join(workspace.path, 'dirlink')).create(root.path);
    for (final path in [
      '../outside',
      outside.path,
      'link',
      'dirlink/new',
      '/workspace/../outside',
      '/workspace/inside',
      '/sessions/c/inside',
      '/root/global',
    ]) {
      expect((await write(path, 'changed')).errorCode, 'invalidPath');
      expect((await read(path)).errorCode, 'invalidPath');
    }
    expect(await outside.readAsString(), 'original');
    expect(await File(p.join(workspace.path, 'new')).exists(), isFalse);
    expect((await write('attachment:id', 'x')).errorCode, 'readOnlyAttachment');
  });

  test('cancelled mutations do not change disk', () async {
    await write('data', 'before');
    cancellation.cancel();
    await expectLater(write('data', 'after'), throwsA(isA<ToolCancelled>()));
    await expectLater(
      edit('data', [
        {'oldText': 'before', 'newText': 'after'},
      ]),
      throwsA(isA<ToolCancelled>()),
    );
    expect(await workspaceFile('data').readAsString(), 'before');
  });
}
