import 'dart:convert';
import 'dart:io';

import '../../../data/models/agent_run.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_request.dart';
import '../../../data/models/message_part.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_source.dart';
import '../../../data/models/tool_policy.dart';
import '../../../data/models/workspace.dart';
import '../../../data/repositories/agent_run_repository.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../tools/tool.dart';
import 'read_history_tool.dart';

class HistoryResolver {
  const HistoryResolver({
    required this.repository,
    required this.runs,
    required this.profile,
    required this.registry,
  });
  final ConversationRepository repository;
  final AgentRunRepository runs;
  final ProviderProfile profile;
  final ToolRegistry registry;

  /// 当前分支 + 工具记录 → 一次请求的内容（design 第二部分 §3）。
  ///
  /// 工具调用与结果按记录成组保留：调用引用的记录与结果消息都存在才进入
  /// 请求，缺少结果消息时按已知记录补回错误，不留下孤立调用。
  Future<List<ResolvedMessage>> resolve(
    List<ChatMessage> messages,
    Map<String, Attachment> attachments, {
    required String currentModelId,
  }) async {
    final records = await historyRecords(repository, messages);
    final sourceRuns = <String, AgentRun?>{};
    final visualImageRecords = <String>{};
    String? visualImageTurn;
    for (final part
        in messages
            .expand((message) => message.parts)
            .whereType<ToolResultPart>()) {
      final record = records[part.toolCallId];
      if (record == null ||
          !visualOperationTools.contains(record.toolName) ||
          !record.artifacts.any((id) => attachments[id]?.isImage == true)) {
        continue;
      }
      // 同轮多张图要一起送达；后续失败或无图手势不能抹掉已取得的观察。
      // 只有新一轮实际返回图片时才替换，图片仍绑定原调用及其时间、应用元数据。
      if (visualImageTurn != record.assistantMessageId) {
        visualImageRecords.clear();
        visualImageTurn = record.assistantMessageId;
      }
      visualImageRecords.add(record.id);
    }
    // 结果文本以结果消息为准：拒绝等状态只写进结果消息，记录里可能没有。
    final results = <String, ResolvedToolResult>{};
    for (final message in messages) {
      for (final part in message.parts) {
        if (part is! ToolResultPart) continue;
        final record = records[part.toolCallId];
        final callId = record?.providerCallId;
        if (record == null || callId == null) continue;
        var environmentPrefix = '';
        final path = record.arguments['path'];
        if (record.source?.kind != ToolSourceKind.mcp &&
            const {
              'read_file',
              'list_files',
              'write_file',
              'edit_file',
              'prepare_skill',
            }.contains(record.toolName) &&
            !(path is String &&
                (path.startsWith('content://') ||
                    path.startsWith('attachment:'))) &&
            !record.arguments.containsKey('directory')) {
          if (!sourceRuns.containsKey(record.runId)) {
            sourceRuns[record.runId] = await runs.getById(record.runId);
          }
          final environment = sourceRuns[record.runId]
              ?.configuration
              .workspace
              ?.primaryEnvironment;
          if (environment != null) {
            environmentPrefix = '[本次调用工作区：${environment.label}]\n';
          }
        }
        results[part.toolCallId] = ResolvedToolResult(
          recordId: record.id,
          status: record.status.name,
          closed: !const {
            ToolCallStatus.prepared,
            ToolCallStatus.awaitingConfirmation,
            ToolCallStatus.executing,
          }.contains(record.status),
          callId: callId,
          images:
              visualImageRecords.contains(record.id) ||
                  record.source?.kind == ToolSourceKind.mcp
              ? [
                  for (final id in record.artifacts)
                    if (attachments[id]?.isImage == true) attachments[id]!,
                ]
              : const [],
          content:
              environmentPrefix +
              truncateToolResult(
                message.text.isNotEmpty
                    ? message.text
                    : (record.result ?? toolStatusText(record.status)),
                limit: toolResultLimit(record),
              ),
          artifactIds: record.artifacts,
          isError: record.status != ToolCallStatus.succeeded,
        );
      }
    }

    final resolved = <ResolvedMessage>[];
    for (final message in messages) {
      // 被中断（停止生成）或出错收场的那一轮：已经产出的正文、已经执行的调用与
      // 结果照常进上下文——用户看到的和模型知道的要对得上，否则模型不知道文件
      // 已经写过、请求已经发过，下一轮可能重做一遍。
      final interrupted =
          message.role == ChatRole.assistant && _isInterrupted(message);
      final parts = <ResolvedPart>[];
      // 有调用却没有结果的调用：补一条合成结果，而不是把调用删掉
      // （pi transform-messages 规则 5）。删掉会让模型以为自己没调用过，
      // 补上它才知道那次调用没有得到结果。
      final missingResults = <ResolvedToolCall, ToolCallRecord>{};
      for (final part in message.parts) {
        switch (part) {
          case TextPart(:final text):
            if (message.role != ChatRole.tool && text.isNotEmpty) {
              parts.add(ResolvedText(text));
            }
          case ReasoningPart(:final publicText, :final providerData):
            // 中断那一轮的思考是半截的：回放给模型会把它带回被打断的思路，
            // 而半截思考既没有完整签名也不该当正文发回去。
            if (interrupted) break;
            // 只有协议状态的块（redacted thinking、只带回加密载荷的推理）也要
            // 带上：它们没有可展示文本，但缺了下一轮请求会被判为配对缺失。
            if (publicText.isNotEmpty || providerData != null) {
              parts.add(
                ResolvedReasoning(publicText, providerData: providerData),
              );
            }
          case ImagePart(:final attachmentId):
            final attachment = attachments[attachmentId];
            if (attachment != null) parts.add(ResolvedImage(attachment));
          case DocumentPart(:final attachmentId):
            final text = _readExtractedText(attachments[attachmentId]);
            if (text != null) parts.add(ResolvedText(text));
          case ToolCallPart(:final toolCallId):
            final record = records[toolCallId];
            final callId = record?.providerCallId;
            // 记录缺失（调用没落库）的调用不进入请求：没有 id 就没法配对。
            if (record == null || callId == null) break;
            final call = ResolvedToolCall(
              recordId: record.id,
              historyReadOnly:
                  record.source?.kind != ToolSourceKind.mcp &&
                  historyReadOnlyTool(registry.byName(record.toolName)),
              callId: callId,
              toolName: record.toolName,
              arguments: record.arguments,
              providerData: record.providerData,
            );
            parts.add(call);
            if (!results.containsKey(toolCallId)) missingResults[call] = record;
          case ToolResultPart(:final toolCallId):
            // 结果由所在消息自己回填（协议要求它与调用分属不同角色）。
            final result = results[toolCallId];
            if (result != null) parts.add(result);
          case ProviderPart():
            // 协议块不进入请求。
            break;
        }
      }
      if (parts.isEmpty) continue;
      var sameModel = message.modelLabel == currentModelId;
      if (sameModel && message.runId != null) {
        final sourceId = message.runId!;
        if (!sourceRuns.containsKey(sourceId)) {
          sourceRuns[sourceId] = await runs.getById(sourceId);
        }
        final source = sourceRuns[sourceId]?.configuration;
        sameModel =
            source != null &&
            source.connection.profileId == profile.id &&
            source.connection.protocol == profile.protocol.name &&
            source.connection.baseUrl == profile.baseUrl &&
            source.modelSelection.modelId == currentModelId;
      } else if (message.runId == null) {
        sameModel = false;
      }
      resolved.add(
        ResolvedMessage(
          role: message.role,
          sourceMessageId: message.id,
          parts: parts,
          // 协议状态绑定配置、协议与模型；名称相同不代表签名可以跨端点回放。
          sameModel: sameModel,
        ),
      );
      if (missingResults.isNotEmpty) {
        resolved.add(
          ResolvedMessage(
            role: ChatRole.tool,
            sourceMessageId: message.id,
            sameModel: sameModel,
            parts: [
              for (final entry in missingResults.entries)
                ResolvedToolResult(
                  recordId: entry.value.id,
                  status: entry.value.status.name,
                  closed: !const {
                    ToolCallStatus.prepared,
                    ToolCallStatus.awaitingConfirmation,
                    ToolCallStatus.executing,
                  }.contains(entry.value.status),
                  callId: entry.key.callId,
                  artifactIds: entry.value.artifacts,
                  content: truncateToolResult(
                    entry.value.result ?? _noResultText,
                    limit: toolResultLimit(entry.value),
                  ),
                  isError: entry.value.status != ToolCallStatus.succeeded,
                ),
            ],
          ),
        );
      }
    }
    return resolved;
  }

  /// 调用没有得到结果时的合成回执：如实说明，不假装成功。
  static const _noResultText = '调用没有返回完整结果（尚未执行或运行已中断）。需要时先读取当前状态，不要直接重复提交动作。';

  /// 这一轮是否被中途打断（用户停止或出错收场）：它的思考块不完整，
  /// 不进上下文；已产出的正文与已执行的调用照常保留。
  static bool _isInterrupted(ChatMessage message) =>
      message.status == MessageStatus.failed ||
      message.status == MessageStatus.cancelled;

  /// 读取附件的文本内容。
  ///
  /// 文档用抽取结果（PDF/DOCX 在导入时抽取），文本文件直接读原文件；
  /// 抽取失败时把失败原因作为内容交给模型，让它知道这份文档没有文字，
  /// 而不是让请求里凭空少一份附件。
  String? _readExtractedText(Attachment? attachment) {
    if (attachment == null) return null;
    final error = attachment.extractionError;
    if (error != null) {
      return '【附件「${attachment.name}」未能提取文字：$error】';
    }
    final path = attachment.extractedTextPath ?? attachment.localPath;
    try {
      return File(path).readAsStringSync();
    } on FileSystemException {
      return '【附件「${attachment.name}」无法读取】';
    } on FormatException {
      return '【附件「${attachment.name}」不是可读取的 UTF-8 文本】';
    }
  }
}

const _maxToolResultBytes = 8 * 1024;

/// 回填给模型与结果消息的文本；记录里没有结果时按状态给出说明。
String toolResultText(ToolCallRecord record) => truncateToolResult(
  record.result ?? toolStatusText(record.status),
  limit: toolResultLimit(record),
);

int toolResultLimit(ToolCallRecord record) =>
    const {'read_file', 'list_files'}.contains(record.toolName)
    ? 128 * 1024
    : record.toolName == 'read_memory'
    ? 16 * 1024
    : record.channel == ExecutionChannel.accessibility ||
          record.toolName == 'list_apps'
    ? 64 * 1024
    : _maxToolResultBytes;

String toolStatusText(ToolCallStatus status) => switch (status) {
  ToolCallStatus.rejected => '用户拒绝了本次动作，没有执行。',
  ToolCallStatus.cancelled => '本次调用已取消，没有取得结果。',
  ToolCallStatus.prepared ||
  ToolCallStatus.awaitingConfirmation ||
  ToolCallStatus.executing => '本次调用没有返回内容。',
  ToolCallStatus.succeeded => '工具执行完成，但没有返回内容。',
  ToolCallStatus.failed => '工具执行失败，没有返回内容。',
};

/// 结果按上限截断：超出时附截断标记，不把整段输出塞进上下文。
String truncateToolResult(String text, {int limit = _maxToolResultBytes}) {
  final bytes = utf8.encode(text);
  if (bytes.length <= limit) return text;
  final head = utf8.decode(bytes.sublist(0, limit), allowMalformed: true);
  return '$head\n【结果已截断：超过 ${limit ~/ 1024}KB】';
}

/// 分支里引用到的工具记录：消息只存记录 id，参数与结果按 id 读回。
Future<Map<String, ToolCallRecord>> historyRecords(
  ConversationRepository repository,
  List<ChatMessage> messages,
) async {
  final ids = <String>{};
  for (final message in messages) {
    for (final part in message.parts) {
      switch (part) {
        case ToolCallPart(:final toolCallId):
        case ToolResultPart(:final toolCallId):
          ids.add(toolCallId);
        default:
          break;
      }
    }
  }
  if (ids.isEmpty) return const {};
  return repository.toolCallsByIds(ids);
}
