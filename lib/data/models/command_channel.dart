import 'tool_call_record.dart';

/// Android 执行通道的应用内许可。
class CommandChannelSettings {
  const CommandChannelSettings({this.shizuku = false, this.root = false});
  final bool shizuku;
  final bool root;
  bool enabled(ExecutionChannel channel) => switch (channel) {
    ExecutionChannel.shizuku => shizuku && !root,
    ExecutionChannel.root => root,
    _ => false,
  };
  List<String> get channels => [
    if (enabled(ExecutionChannel.shizuku)) 'shizuku',
    if (root) 'root',
  ];
  Map<String, dynamic> toJson() => {'shizuku': shizuku, if (root) 'root': true};
  factory CommandChannelSettings.fromJson(Map<String, dynamic> json) =>
      CommandChannelSettings(
        shizuku: json['shizuku'] == true,
        root: json['root'] == true,
      );
}

/// 普通会话保存实际执行通道、设备契约修订和 UID。
class CommandChannelSnapshot {
  static const rootDevice = CommandChannelSnapshot(
    channel: ExecutionChannel.root,
    uid: 0,
    revision: 'root_device_v1',
  );

  const CommandChannelSnapshot({
    required this.channel,
    required this.uid,
    required this.revision,
  });
  final ExecutionChannel channel;
  final int uid;
  final String revision;
  Map<String, dynamic> toJson() => {
    'channel': channel.name,
    'uid': uid,
    'revision': revision,
  };
  factory CommandChannelSnapshot.fromJson(Map<String, dynamic> json) =>
      CommandChannelSnapshot(
        channel: ExecutionChannel.values.byName(json['channel'] as String),
        uid: json['uid'] as int,
        revision: json['revision'] as String,
      );
}
