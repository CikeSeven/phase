import 'tool_call_record.dart';

/// 用户的全局开放范围与系统授权分开；运行只保存已经取得的能力快照。
class CommandChannelSettings {
  const CommandChannelSettings({this.shizuku = false, this.termux = false});
  final bool shizuku;
  final bool termux;
  bool enabled(ExecutionChannel channel) => switch (channel) {
    ExecutionChannel.shizuku => shizuku,
    ExecutionChannel.termux => termux,
    _ => false,
  };
  List<String> get channels => [if (shizuku) 'shizuku', if (termux) 'termux'];
  CommandChannelSettings select(ExecutionChannel channel, bool enabled) =>
      CommandChannelSettings(
        shizuku: channel == ExecutionChannel.shizuku ? enabled : shizuku,
        termux: channel == ExecutionChannel.termux ? enabled : termux,
      );
  Map<String, dynamic> toJson() => {'shizuku': shizuku, 'termux': termux};
  factory CommandChannelSettings.fromJson(Map<String, dynamic> json) =>
      CommandChannelSettings(
        shizuku: json['shizuku'] == true,
        termux: json['termux'] == true,
      );
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
