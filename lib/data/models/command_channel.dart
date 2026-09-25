import 'tool_call_record.dart';

/// 仅 Shizuku 保留应用内开关；Termux 由系统授权和运行时就绪状态守门。
class CommandChannelSettings {
  const CommandChannelSettings({this.shizuku = false});
  final bool shizuku;
  bool enabled(ExecutionChannel channel) => switch (channel) {
    ExecutionChannel.shizuku => shizuku,
    ExecutionChannel.termux => true,
    _ => false,
  };
  List<String> get channels => [if (shizuku) 'shizuku', 'termux'];
  Map<String, dynamic> toJson() => {'shizuku': shizuku};
  factory CommandChannelSettings.fromJson(Map<String, dynamic> json) =>
      CommandChannelSettings(shizuku: json['shizuku'] == true);
}

class CommandChannelSnapshot {
  const CommandChannelSnapshot({
    required this.channel,
    required this.uid,
    required this.revision,
    required this.home,
  });
  final ExecutionChannel channel;
  final int uid;
  final String revision;
  final String home;
  Map<String, dynamic> toJson() => {
    'channel': channel.name,
    'uid': uid,
    'revision': revision,
    'home': home,
  };
  factory CommandChannelSnapshot.fromJson(Map<String, dynamic> json) =>
      CommandChannelSnapshot(
        channel: ExecutionChannel.values.byName(json['channel'] as String),
        uid: json['uid'] as int,
        revision: json['revision'] as String,
        home: json['home'] as String,
      );
}
