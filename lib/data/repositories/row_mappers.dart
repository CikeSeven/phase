import '../models/memory_entry.dart';

import 'dart:convert';

import 'package:drift/drift.dart';

import '../datasources/local/app_database.dart';
import '../models/agent_run.dart';
import '../models/api_protocol.dart';
import '../models/assistant.dart';
import '../models/attachment.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/message_part.dart';
import '../models/model_selection.dart';
import '../models/openai_compat.dart';
import '../models/profile_model.dart';
import '../models/provider_profile.dart';
import '../models/tool_call_record.dart';
import '../models/tool_source.dart';

/// drift 行与业务模型之间的映射；JSON 列在此处集中编解码。
///
/// 解码失败抛出 [FormatException]（数据损坏），由 repository 转成 Failure。

Conversation conversationFromRow(ConversationRow row) => Conversation(
  workspaceId: row.workspaceId,
  id: row.id,
  title: row.title,
  assistantId: row.assistantId,
  currentMessageId: row.currentMessageId,
  modelSelectionOverride: _decodeSelection(row.selectionJson),
  pinned: row.pinned,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
);

ChatMessage messageFromRow(MessageRow row) => ChatMessage(
  id: row.id,
  conversationId: row.conversationId,
  parentId: row.parentId,
  runId: row.runId,
  role: row.role,
  status: row.status,
  parts: decodeMessageParts(jsonDecode(row.partsJson)),
  modelLabel: row.modelLabel,
  usage: _decodeUsage(row.usageJson),
  thinkingDurationMs: row.thinkingDurationMs,
  createdAt: row.createdAt,
);

Assistant assistantFromRow(AssistantRow row) => Assistant(
  id: row.id,
  name: row.name,
  systemPrompt: row.systemPrompt,
  defaultModelSelection: _decodeSelection(row.defaultSelectionJson),
  toolPolicy: ToolPolicyConfig.decode(row.toolPolicyJson),
  memoryScope: MemoryScope.values.byName(row.memoryScope),
  skillIds: (jsonDecode(row.skillIdsJson) as List).cast<String>().toSet(),
  createdAt: row.createdAt,
);

Attachment attachmentFromRow(AttachmentRow row) => Attachment(
  id: row.id,
  conversationId: row.conversationId,
  kind: attachmentKindFromName(row.kind),
  name: row.name,
  mimeType: row.mimeType,
  size: row.size,
  localPath: row.localPath,
  sha256: row.sha256,
  extractedTextPath: row.extractedTextPath,
  extractionError: row.extractionError,
  width: row.width,
  height: row.height,
  createdAt: row.createdAt,
);

ToolCallRecord toolCallFromRow(ToolCallRow row) => ToolCallRecord(
  id: row.id,
  runId: row.runId,
  assistantMessageId: row.assistantMessageId,
  resultMessageId: row.resultMessageId,
  providerCallId: row.providerCallId,
  toolName: row.toolName,
  source: row.sourceJson == null
      ? null
      : ToolSource.fromJson(_decodeMap(row.sourceJson!)),
  arguments: _decodeMap(row.argumentsJson),
  providerData: row.providerDataJson == null
      ? null
      : _decodeMap(row.providerDataJson!),
  target: row.target,
  channel: row.channel,
  defaultPolicy: row.defaultPolicy,
  status: row.status,
  decision: row.decision,
  confirmationRequestedAt: row.confirmationRequestedAt,
  confirmationExpiresAt: row.confirmationExpiresAt,
  decidedAt: row.decidedAt,
  result: row.result,
  artifacts: _decodeStringList(row.artifactsJson),
  errorCode: row.errorCode,
  createdAt: row.createdAt,
  startedAt: row.startedAt,
  finishedAt: row.finishedAt,
);

AgentRun agentRunFromRow(AgentRunRow row) => AgentRun(
  id: row.id,
  conversationId: row.conversationId,
  assistantId: row.assistantId,
  inputMessageId: row.inputMessageId,
  currentMessageId: row.currentMessageId,
  activeToolCallId: row.activeToolCallId,
  configuration: RunConfiguration.fromJson(
    jsonDecode(row.configurationJson) as Map<String, dynamic>,
  ),
  status: row.status,
  finishReason: row.finishReason,
  turnCount: row.turnCount,
  modelAttemptCount: row.modelAttemptCount,
  maxTurns: row.maxTurns,
  usage: _decodeUsage(row.usageJson),
  createdAt: row.createdAt,
  finishedAt: row.finishedAt,
);

ProviderProfile providerProfileFromRow(
  ProviderProfileRow row,
  List<ProfileModel> models,
) => ProviderProfile(
  id: row.id,
  name: row.name,
  protocol: apiProtocolFromName(row.protocol),
  baseUrl: row.baseUrl,
  requiresKey: row.requiresKey,
  presetId: row.presetId,
  models: models,
  defaultModel: row.defaultModel,
  compatOverrides: row.compatJson == null
      ? null
      : OpenAiCompat.fromJson(_decodeMap(row.compatJson!)),
  createdAt: row.createdAt,
);

ProfileModel profileModelFromRow(ModelRow row) => ProfileModel(
  id: row.modelId,
  displayName: row.displayName,
  enabled: row.enabled,
  supportsReasoning: row.supportsReasoning,
  supportsTools: row.supportsTools,
  supportsImages: row.supportsImages,
  contextWindow: row.contextWindow,
  maxOutputTokens: row.maxOutputTokens,
  temperature: row.temperature,
);

// --- companion 构造 ---

ModelsCompanion modelCompanion(String profileId, ProfileModel model) =>
    ModelsCompanion(
      profileId: Value(profileId),
      modelId: Value(model.id),
      displayName: Value(model.displayName),
      enabled: Value(model.enabled),
      supportsReasoning: Value(model.supportsReasoning),
      supportsTools: Value(model.supportsTools),
      supportsImages: Value(model.supportsImages),
      contextWindow: Value(model.contextWindow),
      maxOutputTokens: Value(model.maxOutputTokens),
      temperature: Value(model.temperature),
    );

ConversationsCompanion conversationCompanion(Conversation conversation) =>
    ConversationsCompanion(
      id: Value(conversation.id),
      assistantId: Value(conversation.assistantId),
      workspaceId: Value(conversation.workspaceId),
      title: Value(conversation.title),
      currentMessageId: Value(conversation.currentMessageId),
      selectionJson: Value(
        _encodeSelection(conversation.modelSelectionOverride),
      ),
      pinned: Value(conversation.pinned),
      createdAt: Value(conversation.createdAt),
      updatedAt: Value(conversation.updatedAt),
    );

MessagesCompanion messageCompanion(ChatMessage message) => MessagesCompanion(
  id: Value(message.id),
  conversationId: Value(message.conversationId),
  parentId: Value(message.parentId),
  runId: Value(message.runId),
  role: Value(message.role),
  status: Value(message.status),
  partsJson: Value(encodeMessageParts(message.parts)),
  modelLabel: Value(message.modelLabel),
  usageJson: Value(_encodeUsageJson(message.usage)),
  thinkingDurationMs: Value(message.thinkingDurationMs),
  createdAt: Value(message.createdAt),
);

AssistantsCompanion assistantCompanion(Assistant assistant) =>
    AssistantsCompanion(
      id: Value(assistant.id),
      name: Value(assistant.name),
      systemPrompt: Value(assistant.systemPrompt),
      defaultSelectionJson: Value(
        _encodeSelection(assistant.defaultModelSelection),
      ),
      toolPolicyJson: Value(assistant.toolPolicy.encode()),
      memoryScope: Value(assistant.memoryScope.name),
      skillIdsJson: Value(jsonEncode(assistant.skillIds.toList())),
      createdAt: Value(assistant.createdAt),
    );

AgentRunsCompanion agentRunCompanion(AgentRun run) => AgentRunsCompanion(
  id: Value(run.id),
  conversationId: Value(run.conversationId),
  assistantId: Value(run.assistantId),
  inputMessageId: Value(run.inputMessageId),
  currentMessageId: Value(run.currentMessageId),
  activeToolCallId: Value(run.activeToolCallId),
  configurationJson: Value(jsonEncode(run.configuration.toJson())),
  status: Value(run.status),
  finishReason: Value(run.finishReason),
  turnCount: Value(run.turnCount),
  modelAttemptCount: Value(run.modelAttemptCount),
  maxTurns: Value(run.maxTurns),
  usageJson: Value(_encodeUsageJson(run.usage)),
  createdAt: Value(run.createdAt),
  finishedAt: Value(run.finishedAt),
);

ToolCallsCompanion toolCallCompanion(ToolCallRecord record) =>
    ToolCallsCompanion(
      id: Value(record.id),
      runId: Value(record.runId),
      assistantMessageId: Value(record.assistantMessageId),
      resultMessageId: Value(record.resultMessageId),
      providerCallId: Value(record.providerCallId),
      toolName: Value(record.toolName),
      sourceJson: Value(
        record.source == null ? null : jsonEncode(record.source!.toJson()),
      ),
      argumentsJson: Value(jsonEncode(record.arguments)),
      providerDataJson: Value(
        record.providerData == null ? null : jsonEncode(record.providerData),
      ),
      target: Value(record.target),
      channel: Value(record.channel),
      defaultPolicy: Value(record.defaultPolicy),
      status: Value(record.status),
      decision: Value(record.decision),
      confirmationRequestedAt: Value(record.confirmationRequestedAt),
      confirmationExpiresAt: Value(record.confirmationExpiresAt),
      decidedAt: Value(record.decidedAt),
      result: Value(record.result),
      artifactsJson: Value(jsonEncode(record.artifacts)),
      errorCode: Value(record.errorCode),
      createdAt: Value(record.createdAt),
      startedAt: Value(record.startedAt),
      finishedAt: Value(record.finishedAt),
    );

AttachmentsCompanion attachmentCompanion(Attachment attachment) =>
    AttachmentsCompanion(
      id: Value(attachment.id),
      // 附件落库前必须已认领会话（见 Attachment.withConversation）。
      conversationId: Value(attachment.conversationId!),
      kind: Value(attachment.kind.name),
      name: Value(attachment.name),
      mimeType: Value(attachment.mimeType),
      size: Value(attachment.size),
      localPath: Value(attachment.localPath),
      sha256: Value(attachment.sha256),
      extractedTextPath: Value(attachment.extractedTextPath),
      extractionError: Value(attachment.extractionError),
      width: Value(attachment.width),
      height: Value(attachment.height),
      createdAt: Value(attachment.createdAt),
    );

// --- JSON 列 ---

/// usage_json 列的编码；运行与消息共用。
String encodeUsageJson(TokenUsage usage) => jsonEncode(usage.toJson());

String? _encodeSelection(ModelSelection? selection) =>
    selection == null ? null : jsonEncode(selection.toJson());

ModelSelection? _decodeSelection(String? json) {
  if (json == null || json.isEmpty) return null;
  return ModelSelection.fromJson(_decodeMap(json));
}

String? _encodeUsageJson(TokenUsage? usage) =>
    usage == null ? null : encodeUsageJson(usage);

TokenUsage? _decodeUsage(String? json) {
  if (json == null || json.isEmpty) return null;
  return TokenUsage.fromJson(_decodeMap(json));
}

Map<String, dynamic> _decodeMap(String json) =>
    jsonDecode(json) as Map<String, dynamic>;

List<String> _decodeStringList(String json) => [
  for (final item in jsonDecode(json) as List) item as String,
];
