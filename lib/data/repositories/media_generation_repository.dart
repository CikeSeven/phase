import '../../core/error/failure.dart';
import '../datasources/local/settings_storage.dart';
import '../models/media_generation.dart';
import '../models/provider_profile.dart';
import '../models/tool_source.dart';
import '../models/video_generation.dart';
import 'provider_profile_repository.dart';

typedef MediaGenerationBinding = ({
  MediaGenerationTarget target,
  Uri endpoint,
  bool requiresKey,
  VideoGenerationOptions? video,
  String revision,
});

abstract class MediaGenerationRepository {
  const MediaGenerationRepository(this.kind, this._settings, this._profiles);

  final MediaGenerationKind kind;
  final SettingsStorage _settings;
  final Future<ProviderProfileRepository> Function() _profiles;

  MediaGenerationSettings? read() => _settings.readMediaGeneration(kind);

  Future<ProviderProfile?> profile(String id) async =>
      (await _profiles()).getProfile(id);

  Future<String?> profileKey(ProviderProfile profile) async =>
      profile.requiresKey ? (await _profiles()).readApiKey(profile.id) : null;

  Future<void> save(MediaGenerationSettings? settings) async {
    if (settings != null && await _bindingFor(settings) == null) {
      throw OperationFailure('请选择有效的服务商和${kind.modelLabel}');
    }
    await _settings.writeMediaGeneration(kind, settings);
  }

  Future<MediaGenerationBinding?> binding() async {
    final settings = read();
    if (settings == null) return null;
    final binding = await _bindingFor(settings);
    return identical(settings, read()) ? binding : null;
  }

  Future<MediaGenerationBinding?> _bindingFor(
    MediaGenerationSettings settings,
  ) async {
    final target = settings.target;
    final video = settings.video;
    if ((kind == MediaGenerationKind.video) != (video != null) ||
        target.modelId.trim().isEmpty ||
        target.modelId.length > 256) {
      return null;
    }
    final profile = await this.profile(target.profileId);
    if (profile == null ||
        !supportsMediaGeneration(profile.protocol) ||
        (kind == MediaGenerationKind.image &&
            !profile.models.any((model) => model.id == target.modelId))) {
      return null;
    }
    final baseUri = mediaBaseUri(profile.baseUrl, video: video?.protocol);
    if (baseUri == null) return null;
    final endpoint = baseUri.resolve(video?.protocol.endpoint ?? kind.endpoint);
    return (
      target: target,
      endpoint: endpoint,
      requiresKey: profile.requiresKey,
      video: video,
      revision: definitionDigest([
        target.profileId,
        target.modelId,
        endpoint.toString(),
        profile.requiresKey,
        if (video != null) video.toJson(),
      ]),
    );
  }

  static Uri? mediaBaseUri(String url, {VideoGenerationProtocol? video}) {
    final baseUri = Uri.tryParse(url);
    if (baseUri == null ||
        !const {'http', 'https'}.contains(baseUri.scheme) ||
        baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment) {
      return null;
    }
    final path = baseUri.path;
    final basePath =
        (path.isEmpty || path == '/') &&
            video == VideoGenerationProtocol.seedance
        ? '/api/v3/'
        : path.endsWith('/')
        ? path
        : '$path/';
    return baseUri.replace(path: basePath);
  }

  Future<String?> readApiKey(MediaGenerationBinding target) async {
    if (read()?.target != target.target) throw _changed;
    final key = target.requiresKey
        ? await (await _profiles()).readApiKey(target.target.profileId)
        : null;
    if ((await binding())?.revision != target.revision) throw _changed;
    if (target.requiresKey && (key == null || key.trim().isEmpty)) {
      throw OperationFailure('${kind.label}服务商尚未配置 API Key');
    }
    return key;
  }

  OperationFailure get _changed =>
      OperationFailure('${kind.modelLabel}设置已变化，请在新消息里重试');
}
