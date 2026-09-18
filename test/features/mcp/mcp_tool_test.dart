import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/mcp_server_profile.dart';
import 'package:phase/features/mcp/mcp_tool.dart';
import 'package:phase/features/tools/tool.dart';

import 'mcp_memory_transport.dart';

class _Storage implements ToolStorage {
  final saved = <List<int>>[];
  Object? failure;
  @override
  Future<Attachment> registerBytes({
    required String conversationId,
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) async {
    if (failure != null) throw failure!;
    saved.add(bytes);
    return Attachment(
      id: 'artifact-${saved.length}',
      conversationId: conversationId,
      kind: AttachmentKind.artifact,
      name: name,
      mimeType: mimeType,
      size: bytes.length,
      localPath: '/unused/$name',
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<List<Attachment>> attachments(String conversationId) async => [];
  @override
  String artifactsDirectory(String conversationId) => '/unused';
  @override
  Future<Attachment> registerArtifact({
    required String conversationId,
    required String path,
    required String name,
    String? sha256,
    String? extractedTextPath,
    String? extractionError,
  }) => throw UnimplementedError();
}

void main() {
  late _Storage storage;
  late ToolContext context;
  final fixture = McpMemoryTransport();
  setUp(() {
    storage = _Storage();
    context = ToolContext(
      conversationId: 'c',
      runId: 'r',
      toolCallId: 't',
      storage: storage,
      attachments: [],
    );
  });
  McpTool tool(Map<String, dynamic> result, {bool images = false}) => McpTool(
    definition: mcpToolSnapshot(fixture.profile(), fixture.tool()),
    serverName: '样本',
    supportsImages: images,
    invoke: (_, _, _) async => result,
  );

  test('大结果保存完整 UTF-8 产物，引用位于有界预览开头', () async {
    final text = '月相🌙' * 5000;
    final outcome = await tool({
      'content': [
        {'type': 'text', 'text': text},
      ],
      'structuredContent': {'pages': 2},
      'isError': true,
    }).execute({}, context, RunCancellation());
    expect(outcome.ok, isFalse);
    expect(outcome.errorCode, 'mcpToolError');
    expect(outcome.artifacts, ['artifact-1']);
    expect(outcome.content, startsWith('[内容已截断'));
    expect(utf8.encode(outcome.content).length, lessThan(8 * 1024));
    expect(outcome.content, isNot(contains('\uFFFD')));
    expect(utf8.decode(storage.saved.single), contains(text));
    expect(utf8.decode(storage.saved.single), contains('"pages":2'));
  });

  test('关闭图片能力不解码无效图片；资源链接不作为本机文件读取', () async {
    final outcome = await tool({
      'content': [
        {'type': 'image', 'mimeType': 'image/png', 'data': 'not-base64'},
        {
          'type': 'resource_link',
          'uri': 'file:///private/secret',
          'name': 'external',
        },
        {'type': 'audio', 'data': 'unsupported'},
      ],
    }).execute({}, context, RunCancellation());
    expect(outcome.ok, isTrue);
    expect(storage.saved, isEmpty);
    expect(outcome.content, contains('当前模型已关闭图片能力'));
    expect(outcome.content, contains('未下载'));
    expect(outcome.content, contains('未支持的 MCP 内容类型'));
  });

  test('工具文件失败保留具体操作错误，应用状态写入失败仍向上传递', () async {
    final image = {
      'content': [
        {
          'type': 'image',
          'mimeType': 'image/png',
          'data': base64Encode([1, 2]),
        },
      ],
    };
    storage.failure = const OperationFailure('无法保存这份图片文件');
    await expectLater(
      tool(image, images: true).execute({}, context, RunCancellation()),
      throwsA(isA<OperationFailure>()),
    );
    storage.failure = const StorageFailure('附件记录失败');
    await expectLater(
      tool(image, images: true).execute({}, context, RunCancellation()),
      throwsA(isA<StorageFailure>()),
    );
  });
}
