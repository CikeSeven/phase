import 'tool_call_record.dart';

/// Shizuku 虚拟屏的应用内许可。
class CommandChannelSettings {
  const CommandChannelSettings({this.shizuku = false});
  final bool shizuku;
  bool enabled(ExecutionChannel channel) => switch (channel) {
    ExecutionChannel.shizuku => shizuku,
    _ => false,
  };
  List<String> get channels => [if (shizuku) 'shizuku'];
  Map<String, dynamic> toJson() => {'shizuku': shizuku};
  factory CommandChannelSettings.fromJson(Map<String, dynamic> json) =>
      CommandChannelSettings(shizuku: json['shizuku'] == true);
}

/// Shizuku 绑定设备契约修订与 UID。
class CommandChannelSnapshot {
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
