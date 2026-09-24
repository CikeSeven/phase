import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/tool_source.dart';
import '../tools/tool.dart';
import 'mcp_client.dart';

/// 目录定义和实际运行共享同一 Tool；页面目录实例不具备执行连接。
class McpTool extends Tool {
  McpTool({
    required this.definition,
    required this.serverName,
    this.invoke,
    this.supportsImages = false,
  });

  final ToolSnapshot definition;
  final String serverName;
  final bool supportsImages;
  final Future<Map<String, dynamic>> Function(
    Map<String, dynamic>,
    RunCancellation,
    ToolContext,
  )?
  invoke;

  @override
  String get name => definition.name;
  @override
  String get description => definition.description;
  @override
  Map<String, dynamic> get inputSchema => definition.inputSchema;
  @override
  ToolSource get source => definition.source;
  @override
  ToolSnapshot get snapshot => definition;
  @override
  Set<String> get requiredCapabilities => const {'network'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '$serverName · ${source.originalName}';

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    try {
      if (invoke == null) {
        throw const McpFailure('connectionMissing', 'MCP 工具尚未建立运行连接');
      }
      final result = await invoke!(arguments, cancellation, context);
      cancellation.throwIfCancelled();
      return await _result(result, context, cancellation);
    } on ToolCancelled {
      return const ToolOutcome.cancelled('已停止等待 MCP 结果；已派发的远端操作可能已生效。');
    } on McpFailure catch (failure) {
      return ToolOutcome.failure(failure.userMessage, errorCode: failure.code);
    }
  }

  Future<ToolOutcome> _result(
    Map<String, dynamic> result,
    ToolContext context,
    RunCancellation cancellation,
  ) async {
    final content = result['content'];
    if (content is! List ||
        content.length > 1000 ||
        (result['isError'] != null && result['isError'] is! bool)) {
      throw const McpFailure('invalidResult', 'MCP 工具结果格式无效');
    }
    final text = <String>[];
    final artifacts = <String>[];
    for (final block in content) {
      cancellation.throwIfCancelled();
      if (block is! Map<String, dynamic>) {
        throw const McpFailure('invalidContent', 'MCP 返回了无效的内容块');
      }
      switch (block['type']) {
        case 'text':
          if (block['text'] is! String) {
            throw const McpFailure('invalidContent', 'MCP 文本内容格式无效');
          }
          text.add(block['text'] as String);
        case 'image':
          if (!supportsImages) {
            text.add('工具返回了图片；当前模型已关闭图片能力，未读取或保存图片字节。');
            continue;
          }
          final mime = block['mimeType'];
          final extension = switch (mime) {
            'image/png' => 'png',
            'image/jpeg' => 'jpg',
            'image/webp' => 'webp',
            _ => null,
          };
          if (extension == null || block['data'] is! String) {
            text.add('MCP 返回了不支持的图片格式。');
            continue;
          }
          final List<int> bytes;
          try {
            bytes = base64Decode(block['data'] as String);
          } on FormatException {
            throw const McpFailure('invalidImage', 'MCP 图片编码无效');
          }
          final artifact = await context.storage.registerBytes(
            conversationId: context.conversationId,
            name: 'mcp-${context.toolCallId}-${artifacts.length}.$extension',
            mimeType: mime as String,
            bytes: bytes,
          );
          artifacts.add(artifact.id);
          text.add('图片：${artifact.name}（附件 ${artifact.id}）');
        case 'resource_link':
          text.add('资源链接（未下载）：${jsonEncode(block)}');
        default:
          text.add('未支持的 MCP 内容类型：${block['type']}');
      }
    }
    if (result['structuredContent'] case final Map structured) {
      text.add(jsonEncode(structured));
    } else if (result.containsKey('structuredContent')) {
      throw const McpFailure('invalidStructuredContent', 'MCP 结构化结果格式无效');
    }
    var output = text.join('\n\n');
    final outputBytes = utf8.encode(output);
    if (outputBytes.length > McpLimits.previewBytes) {
      final artifact = await context.storage.registerBytes(
        conversationId: context.conversationId,
        name: 'mcp-${context.toolCallId}.txt',
        mimeType: 'text/plain',
        bytes: outputBytes,
      );
      artifacts.add(artifact.id);
      var end = McpLimits.previewBytes;
      while (end > 0 && outputBytes[end] & 0xc0 == 0x80) {
        end--;
      }
      output =
          '[内容已截断，完整结果：${artifact.name}，附件 ${artifact.id}]\n\n${utf8.decode(outputBytes.sublist(0, end))}';
    }
    return ToolOutcome(
      ok: result['isError'] != true,
      content: output,
      artifacts: artifacts,
      errorCode: result['isError'] == true ? 'mcpToolError' : null,
    );
  }
}
