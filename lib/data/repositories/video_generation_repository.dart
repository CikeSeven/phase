import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../datasources/local/settings_storage.dart';
import '../datasources/remote/video_generation_client.dart';
import '../models/media_generation.dart';
import '../models/video_generation.dart';
import 'media_generation_repository.dart';
import 'provider_profile_repository.dart';

part 'video_generation_repository.g.dart';

class VideoGenerationRepository extends MediaGenerationRepository {
  const VideoGenerationRepository(
    SettingsStorage settings,
    Future<ProviderProfileRepository> Function() profiles,
  ) : super(MediaGenerationKind.video, settings, profiles);

  static const _client = VideoGenerationClient();

  Future<List<VideoCatalogModel>> listModels(
    String profileId,
    VideoGenerationProtocol protocol,
    Future<void> cancellation,
  ) async {
    final provider = await profile(profileId);
    if (provider == null || !supportsMediaGeneration(provider.protocol)) {
      throw const OperationFailure('请选择可用的视频服务商');
    }
    final base = MediaGenerationRepository.mediaBaseUri(
      provider.baseUrl,
      video: protocol,
    );
    if (base == null) throw const OperationFailure('视频服务商地址无效');
    final key = await profileKey(provider);
    if (provider.requiresKey && (key == null || key.trim().isEmpty)) {
      throw const OperationFailure('视频服务商尚未配置 API Key');
    }
    return _client.listModels(
      endpoint: base.resolve(
        protocol == VideoGenerationProtocol.openRouter
            ? 'videos/models'
            : 'models',
      ),
      protocol: protocol,
      apiKey: key,
      cancellation: cancellation,
    );
  }

  Future<void> generate({
    required MediaGenerationBinding binding,
    required String prompt,
    required Map<String, Object?> parameters,
    required File destination,
    required Future<void> cancellation,
    required void Function() checkCancellation,
    void Function(String)? onProgress,
  }) async {
    final key = await readApiKey(binding);
    checkCancellation();
    await _client.generate(
      endpoint: binding.endpoint,
      protocol: binding.video!.protocol,
      apiKey: key,
      modelId: binding.target.modelId,
      prompt: prompt,
      parameters: parameters,
      destination: destination,
      cancellation: cancellation,
      onProgress: onProgress,
    );
  }
}

@Riverpod(keepAlive: true, dependencies: [settingsStorage])
VideoGenerationRepository videoGenerationRepository(Ref ref) =>
    VideoGenerationRepository(
      ref.watch(settingsStorageProvider),
      () => ref.read(providerProfileRepositoryProvider.future),
    );
