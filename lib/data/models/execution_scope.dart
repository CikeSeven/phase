import 'application_access_policy.dart';

/// 文件授权范围与应用名单。运行保存快照；名单收紧还会立即同步到原生校验。
class ExecutionScope {
  const ExecutionScope({
    this.appPolicy = const ApplicationAccessPolicy(),
    this.fileUris = const [],
  });
  final ApplicationAccessPolicy appPolicy;
  final List<String> fileUris;

  Map<String, dynamic> toJson() => {
    'appPolicy': appPolicy.toJson(),
    'fileUris': fileUris,
  };

  factory ExecutionScope.fromJson(Map<String, dynamic> json) => ExecutionScope(
    appPolicy: ApplicationAccessPolicy.fromJson(
      (json['appPolicy'] as Map<String, dynamic>?) ?? {},
    ),
    fileUris: (json['fileUris'] as List? ?? const []).cast<String>(),
  );
}
