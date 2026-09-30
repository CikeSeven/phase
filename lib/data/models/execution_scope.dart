/// 文件授权范围；运行保存固定快照。
class ExecutionScope {
  const ExecutionScope({this.fileUris = const []});
  final List<String> fileUris;

  Map<String, dynamic> toJson() => {'fileUris': fileUris};

  factory ExecutionScope.fromJson(Map<String, dynamic> json) => ExecutionScope(
    fileUris: (json['fileUris'] as List? ?? const []).cast<String>(),
  );
}
