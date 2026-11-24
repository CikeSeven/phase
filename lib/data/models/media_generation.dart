import 'api_protocol.dart';
import 'video_generation.dart';

typedef MediaGenerationTarget = ({String profileId, String modelId});

class MediaGenerationSettings {
  const MediaGenerationSettings(this.target, {this.video});

  final MediaGenerationTarget target;
  final VideoGenerationOptions? video;

  Map<String, Object?> toJson() => {
    'profileId': target.profileId,
    'modelId': target.modelId,
    if (video case final options?) 'video': options.toJson(),
  };
}

enum MediaGenerationKind {
  image('图像生成', '图像模型', 'images/generations'),
  video('视频生成', '视频模型', 'videos');

  const MediaGenerationKind(this.label, this.modelLabel, this.endpoint);

  final String label;
  final String modelLabel;
  final String endpoint;
}

bool supportsMediaGeneration(ApiProtocol protocol) =>
    protocol == ApiProtocol.openaiCompletions ||
    protocol == ApiProtocol.openaiResponses;
