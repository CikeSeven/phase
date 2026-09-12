import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/datasources/local/settings_storage.dart';
import '../../../data/models/model_selection.dart' as model;
import '../../../data/models/provider_profile.dart';
import '../../../data/models/reasoning_effort.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/provider_profile_repository.dart';
import 'chat_controller.dart';

part 'model_selection.g.dart';

/// 当前生效的「服务商 × 模型 × 推理等级」组合。
class ChatModelSelection {
  const ChatModelSelection({
    required this.profile,
    required this.model,
    required this.supportsReasoning,
    required this.supportsImages,
    required this.effort,
  });

  final ProviderProfile profile;
  final String model;

  /// 当前模型是否声明支持推理；false 时 effort 不下发。
  final bool supportsReasoning;

  /// 当前模型是否声明支持图片输入；false 时附件入口拦截图片。
  final bool supportsImages;

  final ReasoningEffort effort;
}

/// 模型选择：会话显式覆盖优先于助手默认，再取「最近使用」，
/// 否则回退到第一个服务商的默认模型 / 候选模型第一个。
@Riverpod(
  keepAlive: true,
  dependencies: [
    settingsStorage,
    providerProfiles,
    assistants,
    conversationThread,
    ActiveConversation,
  ],
)
class ModelSelection extends _$ModelSelection {
  @override
  Future<ChatModelSelection?> build() async {
    final active = ref.watch(activeConversationProvider);
    final profiles = await ref.watch(providerProfilesProvider.future);
    if (profiles.isEmpty) {
      return null;
    }
    final settings = ref.watch(settingsStorageProvider);
    final lastProfileId = settings.readLastProfileId();
    final lastModel = settings.readLastModel();

    // 等待会话和助手就绪，避免把加载中的覆盖配置误判为未设置。
    final assistants = await ref.watch(assistantsProvider.future);
    final conversationId = active.conversationId;
    final thread = conversationId == null
        ? null
        : await ref.watch(conversationThreadProvider(conversationId).future);
    final assistant = resolveAssistant(
      assistants,
      draftAssistantId: active.draftAssistantId,
      boundAssistantId: thread?.conversation.assistantId,
    );
    final override =
        active.draftModelSelection ??
        thread?.conversation.modelSelectionOverride;
    var profile = profiles.first;
    for (final selection in [override, assistant?.defaultModelSelection]) {
      if (selection == null) continue;
      for (final candidate in profiles) {
        if (candidate.id == selection.profileId) {
          return _describe(
            profile: candidate,
            model: selection.modelId,
            effort: selection.reasoningEffort,
          );
        }
      }
    }

    for (final candidate in profiles) {
      if (candidate.id == lastProfileId) {
        profile = candidate;
        break;
      }
    }

    // 上次手输的模型未必在候选列表里，仍然尊重。
    String? model;
    if (profile.id == lastProfileId &&
        lastModel != null &&
        lastModel.isNotEmpty) {
      model = lastModel;
    } else {
      // 回退顺序：启用的默认模型 → 第一个启用的模型 → 列表外的默认模型
      // （默认模型被停用时不再直接采用它）。
      final enabled = profile.enabledModels;
      final fallback = profile.defaultModel;
      if (fallback != null && enabled.any((entry) => entry.id == fallback)) {
        model = fallback;
      } else if (enabled.isNotEmpty) {
        model = enabled.first.id;
      } else {
        model = (fallback != null && fallback.isNotEmpty) ? fallback : null;
      }
    }
    if (model == null) {
      return null;
    }

    return _describe(
      profile: profile,
      model: model,
      effort: ReasoningEffort.fromName(settings.readLastReasoningEffort()),
    );
  }

  /// 组装一次选择：能力以模型配置为准，已登记但与所选模型无关时不影响。
  ///
  /// 未登记的（手输或列表外）模型保留原型的宽松默认：默认支持推理与图片，
  /// 是否合规交给服务商服务器判断。
  ChatModelSelection _describe({
    required ProviderProfile profile,
    required String model,
    required ReasoningEffort effort,
  }) {
    var supportsReasoning = true;
    var supportsImages = true;
    for (final candidate in profile.models) {
      if (candidate.id == model) {
        supportsReasoning = candidate.supportsReasoning;
        supportsImages = candidate.supportsImages;
        break;
      }
    }
    return ChatModelSelection(
      profile: profile,
      model: model,
      supportsReasoning: supportsReasoning,
      supportsImages: supportsImages,
      effort: effort,
    );
  }

  /// 确认模型与推理等级后保存为会话覆盖，不修改助手默认值。
  Future<void> select(
    String profileId,
    String modelId, {
    ReasoningEffort? effort,
  }) async {
    final active = ref.read(activeConversationProvider);
    final current = await future;
    await _saveSelection(
      model.ModelSelection(
        profileId: profileId,
        modelId: modelId,
        reasoningEffort: effort ?? current?.effort ?? ReasoningEffort.off,
      ),
      active,
    );
  }

  /// 单独修改推理等级时保留当前模型，同样作为会话显式选择。
  Future<void> selectEffort(ReasoningEffort effort) async {
    final active = ref.read(activeConversationProvider);
    final current = await future;
    if (current == null) return;
    await _saveSelection(
      model.ModelSelection(
        profileId: current.profile.id,
        modelId: current.model,
        reasoningEffort: effort,
      ),
      active,
    );
  }

  Future<void> _saveSelection(
    model.ModelSelection selection,
    ActiveConversationState active,
  ) async {
    final conversationId = active.conversationId;
    if (conversationId != null) {
      final repository = await ref.read(conversationRepositoryProvider.future);
      await repository.setModelSelection(conversationId, selection);
      if (!ref.mounted) return;
      ref.invalidate(conversationThreadProvider(conversationId));
    }
    final settings = ref.read(settingsStorageProvider);
    await settings.writeLastModelSelection(
      profileId: selection.profileId,
      model: selection.modelId,
    );
    if (!ref.mounted) return;
    await settings.writeLastReasoningEffort(selection.reasoningEffort.name);
    if (!ref.mounted) return;
    if (conversationId == null &&
        identical(active, ref.read(activeConversationProvider))) {
      ref.read(activeConversationProvider.notifier).draftModel(selection);
    }
    ref.invalidateSelf();
  }
}
