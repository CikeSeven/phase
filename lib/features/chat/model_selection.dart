import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/datasources/local/settings_storage.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/models/reasoning_effort.dart';
import '../../../data/repositories/provider_profile_repository.dart';

part 'model_selection.g.dart';

/// 当前生效的「服务商 × 模型 × 推理等级」组合。
class ChatModelSelection {
  const ChatModelSelection({
    required this.profile,
    required this.model,
    required this.supportsReasoning,
    required this.effort,
  });

  final ProviderProfile profile;
  final String model;

  /// 当前模型是否声明支持推理；false 时 effort 不下发。
  final bool supportsReasoning;

  final ReasoningEffort effort;
}

/// 模型选择：优先「最近使用」（shared_preferences），
/// 否则回退到第一个服务商的默认模型 / 候选模型第一个。
@Riverpod(dependencies: [settingsStorage])
class ModelSelection extends _$ModelSelection {
  @override
  Future<ChatModelSelection?> build() async {
    final profiles = await ref.watch(providerProfilesProvider.future);
    if (profiles.isEmpty) {
      return null;
    }
    final settings = ref.watch(settingsStorageProvider);
    final lastProfileId = settings.readLastProfileId();
    final lastModel = settings.readLastModel();

    var profile = profiles.first;
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
      model =
          profile.defaultModel ??
          (profile.modelCandidates.isEmpty
              ? null
              : profile.modelCandidates.first.id);
    }
    if (model == null) {
      return null;
    }

    var supportsReasoning = guessSupportsReasoning(model);
    var effort = ReasoningEffort.fromName(settings.readLastReasoningEffort());
    for (final candidate in profile.modelCandidates) {
      if (candidate.id == model) {
        supportsReasoning = candidate.supportsReasoning;
        // 模型未开放持久化的等级时按「关」处理，不下发不支持的值。
        if (effort != ReasoningEffort.off &&
            !candidate.allowedEfforts.contains(effort)) {
          effort = ReasoningEffort.off;
        }
        break;
      }
    }

    return ChatModelSelection(
      profile: profile,
      model: model,
      supportsReasoning: supportsReasoning,
      effort: effort,
    );
  }

  /// 用户显式选择后持久化，并让派生状态重建。
  Future<void> select(String profileId, String model) async {
    await ref
        .read(settingsStorageProvider)
        .writeLastModelSelection(profileId: profileId, model: model);
    ref.invalidateSelf();
  }

  /// 推理等级全局最近使用，持久化后重建派生状态。
  Future<void> selectEffort(ReasoningEffort effort) async {
    await ref
        .read(settingsStorageProvider)
        .writeLastReasoningEffort(effort.name);
    ref.invalidateSelf();
  }
}
