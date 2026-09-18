import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/logger.dart';
import '../../data/models/attachment.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/conversation.dart';
import '../../data/models/message_part.dart';
import '../../data/models/tool_call_record.dart';
import '../../data/repositories/conversation_repository.dart';
import '../tools/tool_presentation.dart';

part 'conversation_export.g.dart';

/// 会话导出格式。
enum ConversationExportFormat { markdown, json }

/// 一次导出的结果：写到磁盘的文件与这次导出的规模。
class ConversationExportResult {
  const ConversationExportResult({
    required this.format,
    required this.path,
    required this.messageCount,
    required this.toolCallCount,
  });

  final ConversationExportFormat format;

  /// 导出文件的绝对路径（应用私有目录）。
  final String path;

  /// 导出的消息条数（含其他分支）。
  final int messageCount;
  final int toolCallCount;

  String get formatLabel => switch (format) {
    ConversationExportFormat.markdown => 'Markdown',
    ConversationExportFormat.json => 'JSON',
  };
}

/// 会话导出：把业务模型写成 Markdown 或 JSON 文件。
///
/// 只读会话、消息、附件索引与工具记录；密钥不在导出范围内——导出流程不读取
/// 安全存储，也不解析或改写工具参数与结果（design 第一部分 §7）。
/// 协议回传的不透明状态（签名等）不进导出：它不是用户内容，也不是执行记录。
class ConversationExporter {
  ConversationExporter({required this.conversations, required this.directory});

  final ConversationRepository conversations;

  /// 导出目录（应用私有），由装配点注入。
  final Directory directory;

  /// 导出一次会话，返回写入的文件。
  Future<ConversationExportResult> export(
    String conversationId,
    ConversationExportFormat format,
  ) {
    return _guard('导出会话失败', () async {
      final thread = await conversations.getThread(conversationId);
      if (thread == null) {
        throw const UnknownFailure('会话不存在或已删除');
      }
      final attachments = await conversations.attachmentsFor(conversationId);
      final toolCalls = await conversations.toolCallsByIds(
        _referencedToolCallIds(thread.messages),
      );
      final exportedAt = DateTime.now();
      final content = switch (format) {
        ConversationExportFormat.markdown => conversationMarkdown(
          thread,
          toolCalls: toolCalls,
          attachments: attachments,
          exportedAt: exportedAt,
        ),
        ConversationExportFormat.json => conversationJson(
          thread,
          toolCalls: toolCalls,
          attachments: attachments,
          exportedAt: exportedAt,
        ),
      };
      await directory.create(recursive: true);
      final file = File(
        p.join(
          directory.path,
          _fileName(thread.conversation, format, exportedAt),
        ),
      );
      await file.writeAsString(content, flush: true);
      return ConversationExportResult(
        format: format,
        path: file.path,
        messageCount: thread.messages.length,
        toolCallCount: toolCalls.length,
      );
    });
  }

  /// 消息引用到的工具记录 id：调用与结果引用的是同一份记录。
  Set<String> _referencedToolCallIds(List<ChatMessage> messages) {
    return {
      for (final message in messages)
        for (final part in message.parts)
          ?switch (part) {
            ToolCallPart(:final toolCallId) => toolCallId,
            ToolResultPart(:final toolCallId) => toolCallId,
            _ => null,
          },
    };
  }

  Future<T> _guard<T>(String message, Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on Exception catch (e, st) {
      AppLogger.error(message, e, st);
      throw UnknownFailure(message, cause: e);
    }
  }
}

/// Markdown 导出：标题、时间，以及当前分支的正文、思考、附件名与工具调用。
///
/// 工具结果消息（role: tool）是回填给模型的上下文，其内容已随调用记录导出，
/// 不重复成段。工具调用的参数与结果按原文写入，不做替换或脱敏。
String conversationMarkdown(
  ConversationThread thread, {
  required Map<String, ToolCallRecord> toolCalls,
  required List<Attachment> attachments,
  required DateTime exportedAt,
}) {
  final attachmentsById = {
    for (final attachment in attachments) attachment.id: attachment,
  };
  final branch = [
    for (final message in thread.branch)
      if (message.role != ChatRole.tool) message,
  ];
  final records = _orderedRecords(thread.branch, toolCalls);
  final buffer = StringBuffer()
    ..writeln('# ${thread.conversation.title}')
    ..writeln()
    ..writeln('- 会话 ID：`${thread.conversation.id}`')
    ..writeln('- 创建时间：${_formatTime(thread.conversation.createdAt)}')
    ..writeln('- 最后更新：${_formatTime(thread.conversation.updatedAt)}')
    ..writeln('- 导出时间：${_formatTime(exportedAt)}')
    ..writeln(
      '- 消息数：${thread.messages.length}'
      '（当前分支 ${branch.length} 条）',
    )
    ..writeln('- 工具调用：${records.length} 次')
    ..writeln()
    ..writeln('> 由「相月」导出，不含 API Key 与鉴权信息。')
    ..writeln()
    ..writeln('---')
    ..writeln();

  for (final message in branch) {
    final title = switch (message.role) {
      ChatRole.user => '用户',
      ChatRole.assistant =>
        '助手${message.modelLabel == null ? '' : ' · ${message.modelLabel}'}',
      ChatRole.system => '系统',
      ChatRole.tool => '工具',
    };
    buffer
      ..writeln('## $title')
      ..writeln()
      ..writeln('> ${_formatTime(message.createdAt)}')
      ..writeln();
    for (final part in message.parts) {
      switch (part) {
        case ReasoningPart(:final publicText):
          if (publicText.trim().isEmpty) break;
          buffer
            ..writeln('### 思考')
            ..writeln()
            ..writeln(publicText.trim())
            ..writeln();
        case TextPart(:final text):
          if (text.trim().isEmpty) break;
          buffer
            ..writeln(text.trim())
            ..writeln();
        case ImagePart() || DocumentPart():
          break;
        case ToolCallPart(:final toolCallId):
          _writeToolCall(buffer, toolCalls[toolCallId], attachmentsById);
        case ToolResultPart() || ProviderPart():
          break;
      }
    }
    _writeAttachments(buffer, message, attachmentsById);
  }
  return buffer.toString();
}

/// JSON 导出：会话、全部消息（含内容块）与工具记录，结构固定。
String conversationJson(
  ConversationThread thread, {
  required Map<String, ToolCallRecord> toolCalls,
  required List<Attachment> attachments,
  required DateTime exportedAt,
}) {
  return const JsonEncoder.withIndent('  ').convert(
    conversationExportJson(
      thread,
      toolCalls: toolCalls,
      attachments: attachments,
      exportedAt: exportedAt,
    ),
  );
}

/// 导出结构：会话 + 消息数组（含 parts）+ 工具记录数组 + 附件元数据。
///
/// 附件只导出名称与类型，不导出磁盘路径。
Map<String, dynamic> conversationExportJson(
  ConversationThread thread, {
  required Map<String, ToolCallRecord> toolCalls,
  required List<Attachment> attachments,
  required DateTime exportedAt,
}) {
  final attachmentsById = {
    for (final attachment in attachments) attachment.id: attachment,
  };
  return {
    'format': 'xiangyue.conversation.export',
    'version': 1,
    'exportedAt': exportedAt.toIso8601String(),
    'conversation': {
      'id': thread.conversation.id,
      'title': thread.conversation.title,
      'assistantId': thread.conversation.assistantId,
      'pinned': thread.conversation.pinned,
      'createdAt': thread.conversation.createdAt.toIso8601String(),
      'updatedAt': thread.conversation.updatedAt.toIso8601String(),
      'currentMessageId': thread.conversation.currentMessageId,
      'branchMessageIds': [for (final message in thread.branch) message.id],
      'modelSelectionOverride': thread.conversation.modelSelectionOverride
          ?.toJson(),
    },
    'messages': [for (final message in thread.messages) _messageJson(message)],
    'toolCalls': [
      for (final record in _orderedRecords(thread.messages, toolCalls))
        _toolCallJson(record, attachmentsById),
    ],
    'attachments': [
      for (final attachment in attachments)
        {
          'id': attachment.id,
          'kind': attachment.kind.name,
          'name': attachment.name,
          'mimeType': attachment.mimeType,
          'size': attachment.size,
          'createdAt': attachment.createdAt.toIso8601String(),
        },
    ],
  };
}

Map<String, dynamic> _messageJson(ChatMessage message) {
  return {
    'id': message.id,
    'parentId': message.parentId,
    'runId': message.runId,
    'role': message.role.name,
    'status': message.status.name,
    'modelLabel': message.modelLabel,
    'createdAt': message.createdAt.toIso8601String(),
    'thinkingDurationMs': message.thinkingDurationMs,
    'usage': message.usage?.toJson(),
    'parts': [for (final part in message.parts) ?_partJson(part)],
  };
}

/// 内容块：协议回传状态不进导出，其余按业务模型的结构写出。
Map<String, dynamic>? _partJson(MessagePart part) {
  if (part is ProviderPart) return null;
  return part.toJson()..remove('providerData');
}

Map<String, dynamic> _toolCallJson(
  ToolCallRecord record,
  Map<String, Attachment> attachmentsById,
) {
  return {
    'id': record.id,
    'runId': record.runId,
    'assistantMessageId': record.assistantMessageId,
    'resultMessageId': record.resultMessageId,
    'providerCallId': record.providerCallId,
    'toolName': record.toolName,
    'source': record.source?.toJson(),
    'arguments': record.arguments,
    'target': record.target,
    'channel': record.channel.name,
    'defaultPolicy': record.defaultPolicy.name,
    'status': record.status.name,
    'decision': record.decision?.name,
    'confirmationRequestedAt': record.confirmationRequestedAt
        ?.toIso8601String(),
    'confirmationExpiresAt': record.confirmationExpiresAt?.toIso8601String(),
    'decidedAt': record.decidedAt?.toIso8601String(),
    'result': record.result,
    'errorCode': record.errorCode,
    'artifactIds': record.artifacts,
    'artifactNames': [
      for (final id in record.artifacts)
        attachmentsById[id]?.name ?? '（产物已删除：$id）',
    ],
    'createdAt': record.createdAt.toIso8601String(),
    'startedAt': record.startedAt?.toIso8601String(),
    'finishedAt': record.finishedAt?.toIso8601String(),
  };
}

/// 导出目录里的文件名：会话标题 + 导出时刻，格式扩展名区分两种导出。
String _fileName(
  Conversation conversation,
  ConversationExportFormat format,
  DateTime at,
) {
  final stamp =
      '${at.year}${_two(at.month)}${_two(at.day)}-'
      '${_two(at.hour)}${_two(at.minute)}${_two(at.second)}';
  final title = _safeName(conversation.title);
  final extension = format == ConversationExportFormat.markdown ? 'md' : 'json';
  return '${title.isEmpty ? '会话' : title}-$stamp.$extension';
}

/// 去掉文件名里不便的字符；标题仍保持可辨认。
String _safeName(String title) {
  final cleaned = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final runes = cleaned.runes.toList();
  return runes.length <= 40 ? cleaned : String.fromCharCodes(runes.take(40));
}

void _writeToolCall(
  StringBuffer buffer,
  ToolCallRecord? record,
  Map<String, Attachment> attachmentsById,
) {
  if (record == null) {
    // 记录缺失是数据问题：如实写出，不猜这次调用的内容。
    buffer
      ..writeln('### 工具调用')
      ..writeln()
      ..writeln('> 记录已缺失，只保留了调用引用。')
      ..writeln();
    return;
  }
  buffer
    ..writeln(
      '### 工具调用：${ToolPresentation.recordLabel(record)}'
      '（${record.toolName}）',
    )
    ..writeln()
    ..writeln('- 记录 ID：`${record.id}`')
    ..writeln('- 状态：${ToolPresentation.statusLabel(record.status)}')
    ..writeln('- 决定：${ToolPresentation.decisionLabel(record.decision)}')
    ..writeln('- 执行通道：${ToolPresentation.channelLabel(record.channel)}')
    ..writeln('- 创建时间：${_formatTime(record.createdAt)}');
  final target = (record.target ?? '').trim();
  if (target.isNotEmpty) {
    buffer.writeln('- 目标：$target');
  }
  final finishedAt = record.finishedAt;
  if (finishedAt != null) {
    buffer.writeln('- 结束时间：${_formatTime(finishedAt)}');
  }
  if (record.errorCode != null) {
    buffer.writeln('- 错误代码：${record.errorCode}');
  }
  buffer
    ..writeln()
    ..writeln('**参数**')
    ..writeln()
    ..writeln(
      _fenced(const JsonEncoder.withIndent('  ').convert(record.arguments)),
    )
    ..writeln();
  final result = record.result;
  if (result != null && result.trim().isNotEmpty) {
    buffer
      ..writeln('**结果**')
      ..writeln()
      ..writeln(_fenced(result))
      ..writeln();
  }
  if (record.artifacts.isNotEmpty) {
    buffer
      ..writeln('**产物**')
      ..writeln();
    for (final id in record.artifacts) {
      final attachment = attachmentsById[id];
      buffer.writeln('- ${attachment?.name ?? '（产物已删除：$id）'}');
    }
    buffer.writeln();
  }
}

void _writeAttachments(
  StringBuffer buffer,
  ChatMessage message,
  Map<String, Attachment> attachmentsById,
) {
  final names = <String>[];
  for (final part in message.parts) {
    final id = switch (part) {
      ImagePart(:final attachmentId) ||
      DocumentPart(:final attachmentId) => attachmentId,
      _ => null,
    };
    if (id == null) continue;
    final attachment = attachmentsById[id];
    names.add(
      attachment == null
          ? '（附件已删除：$id）'
          : '${attachment.name}（${_kindLabel(attachment)}）',
    );
  }
  if (names.isEmpty) return;
  buffer
    ..writeln('**附件**')
    ..writeln();
  for (final name in names) {
    buffer.writeln('- $name');
  }
  buffer.writeln();
}

String _kindLabel(Attachment attachment) => switch (attachment.kind) {
  AttachmentKind.image => '图片',
  AttachmentKind.pdf => 'PDF',
  AttachmentKind.docx => 'DOCX',
  AttachmentKind.artifact => '产物',
  AttachmentKind.text => '文本',
};

/// 用比内容更长的围栏包住代码块，结果里的反引号不会提前结束它。
String _fenced(String content) {
  var fence = '```';
  for (final match in RegExp('`+').allMatches(content)) {
    final length = match.group(0)!.length;
    if (length >= fence.length) fence = '`' * (length + 1);
  }
  return '$fence\n$content\n$fence';
}

/// 被消息引用到的记录，按调用时间排序。
List<ToolCallRecord> _orderedRecords(
  List<ChatMessage> messages,
  Map<String, ToolCallRecord> toolCalls,
) {
  final ids = <String>[];
  for (final message in messages) {
    for (final part in message.parts) {
      final id = switch (part) {
        ToolCallPart(:final toolCallId) => toolCallId,
        ToolResultPart(:final toolCallId) => toolCallId,
        _ => null,
      };
      if (id != null && !ids.contains(id)) ids.add(id);
    }
  }
  final records = [for (final id in ids) ?toolCalls[id]];
  records.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return records;
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  return '${local.year}-${_two(local.month)}-${_two(local.day)} '
      '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

/// 导出目录：应用私有目录下的 `exports/`。
///
/// 首版不接系统分享（S5 再做）；导出后由界面提示这里的路径。
@Riverpod(keepAlive: true)
Future<Directory> exportDirectory(Ref ref) async {
  final documents = await getApplicationDocumentsDirectory();
  return Directory(p.join(documents.path, 'exports'));
}

/// 会话导出器：会话仓储 + 导出目录。
@Riverpod(keepAlive: true)
Future<ConversationExporter> conversationExporter(Ref ref) async {
  final repository = await ref.watch(conversationRepositoryProvider.future);
  final directory = await ref.watch(exportDirectoryProvider.future);
  return ConversationExporter(conversations: repository, directory: directory);
}
