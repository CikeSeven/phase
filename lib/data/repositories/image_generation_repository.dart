import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../datasources/local/settings_storage.dart';
import '../datasources/remote/openai_image_client.dart';
import '../models/image_generation.dart';
import '../models/media_generation.dart';
import 'media_generation_repository.dart';
import 'provider_profile_repository.dart';

part 'image_generation_repository.g.dart';

class ImageGenerationRepository extends MediaGenerationRepository {
  const ImageGenerationRepository(
    SettingsStorage settings,
    Future<ProviderProfileRepository> Function() profiles,
  ) : super(MediaGenerationKind.image, settings, profiles);

  static const _client = OpenAiImageClient();

  Future<GeneratedImage> generate({
    required MediaGenerationBinding binding,
    required ImageGenerationRequest request,
    required Future<void> cancellation,
    required void Function() checkCancellation,
  }) async {
    final apiKey = await readApiKey(binding);
    checkCancellation();
    return _client.generate(
      endpoint: binding.endpoint,
      modelId: binding.target.modelId,
      apiKey: apiKey,
      request: request,
      cancellation: cancellation,
    );
  }
}

@Riverpod(keepAlive: true, dependencies: [settingsStorage])
ImageGenerationRepository imageGenerationRepository(Ref ref) =>
    ImageGenerationRepository(
      ref.watch(settingsStorageProvider),
      () => ref.read(providerProfileRepositoryProvider.future),
    );
