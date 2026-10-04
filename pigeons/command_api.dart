import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/features/commands/command_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/app/xiangyue/phase/bridge/CommandApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'app.xiangyue.phase.bridge.commands'),
    dartPackageName: 'phase',
  ),
)
class CommandChannelStatus {
  CommandChannelStatus({
    required this.channel,
    required this.state,
    required this.message,
    this.uid,
    this.revision,
  });
  String channel;
  String state;
  String message;
  int? uid;
  String? revision;
}

@HostApi()
abstract class CommandChannelHostApi {
  @async
  List<CommandChannelStatus> status();
  @async
  void authorize(String channel);
  @async
  void initialize(String channel);
  void openSettings(String channel);
  @async
  void setEnabled(List<String> channels);
}

@FlutterApi()
abstract class CommandChannelFlutterApi {
  void statusChanged();
}
