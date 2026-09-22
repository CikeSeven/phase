import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/agent_context_repository.dart';
import '../../../data/repositories/model_request_repository.dart';
import '../../../data/repositories/skill_repository.dart';
import '../../../data/repositories/mcp_server_repository.dart';
import '../../../providers/provider_factory.dart';
import '../../tools/tool.dart';
import '../../workspace/workspace_controller.dart';
import '../chat_controller.dart';
import '../model_selection.dart';
import 'compaction_coordinator.dart';
import 'context_builder.dart';

part 'context_preview.g.dart';

@Riverpod(
  dependencies: [
    ChatController,
    ModelSelection,
    currentAssistant,
    ActiveConversation,
    conversationThread,
  ],
)
Future<ContextBuild?> contextPreview(Ref ref, String conversationId) async {
  final active = ref.watch(activeConversationProvider);
  if (active.conversationId != conversationId) return null;
  final running = ref.watch(
    chatControllerProvider.select(
      (s) => (
        s.isGenerating,
        s.runningConversationId,
        s.contextBuild,
        s.contextConversationId,
        s.mode,
      ),
    ),
  );
  if (running.$1) {
    return running.$2 == conversationId && running.$4 == conversationId
        ? running.$3
        : null;
  }
  // 仅空闲时重建；正文流式期间不逐字符测量、读附件或扫描统计表。
  final selected = await ref.watch(modelSelectionProvider.future);
  if (!ref.mounted) return null;
  final thread = await ref.watch(
    conversationThreadProvider(conversationId).future,
  );
  if (!ref.mounted) return null;
  final assistant = ref.watch(currentAssistantProvider(active));
  if (selected == null || thread == null) return null;
  ref.watch(runtimeEnvironmentProvider);
  if (assistant?.skillIds.isNotEmpty ?? false) {
    ref.watch(skillInstallationsProvider);
  }
  if (assistant?.toolPolicy.enabledTools.any((t) => t.startsWith('mcp_')) ??
      false) {
    ref.watch(mcpServersProvider);
  }
  final prepared = await ref
      .read(chatControllerProvider.notifier)
      .prepareContext(conversationId);
  if (!ref.mounted || prepared == null) return null;
  final cancellation = RunCancellation();
  ref.onDispose(cancellation.cancel);
  final summaries = ref.watch(agentContextRepositoryProvider.future);
  final requests = ref.watch(modelRequestRepositoryProvider.future);
  final provider = ref.read(aiProviderFactoryProvider)(prepared.profile, '');
  return CompactionCoordinator(
    summaries: await summaries,
    requests: await requests,
  ).build(
    conversationId: conversationId,
    runId: null,
    branchHeadId: prepared.branchHeadId,
    profile: prepared.profile,
    provider: provider,
    request: prepared.request,
    cancellation: cancellation,
    protectedIds: prepared.protectedIds,
    canReadHistory: prepared.canReadHistory,
    contextWindow: prepared.configuration.contextWindow,
    policy: prepared.configuration.contextPolicy,
    measureOnly: true,
  );
}
