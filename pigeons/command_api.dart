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
    this.home,
  });
  String channel;
  String state;
  String message;
  int? uid;
  String? revision;
  String? home;
}

class ExternalCommandSpec {
  ExternalCommandSpec({
    required this.ownerId,
    required this.callId,
    required this.channel,
    required this.revision,
    required this.uid,
    required this.command,
    required this.cwd,
    required this.outputLimitBytes,
  });
  String ownerId;
  String callId;
  String channel;
  String revision;
  int uid;
  String command;
  String cwd;
  int outputLimitBytes;
}

class ChannelTransferSpec {
  ChannelTransferSpec({
    required this.ownerId,
    required this.callId,
    required this.channel,
    required this.revision,
    required this.uid,
    required this.localRoot,
    required this.path,
    required this.remotePath,
    required this.toChannel,
    required this.fileLimitBytes,
    required this.totalLimitBytes,
    required this.entryLimit,
  });
  String ownerId;
  String callId;
  String channel;
  String revision;
  int uid;
  String localRoot;
  String path;
  String remotePath;
  bool toChannel;
  int fileLimitBytes;
  int totalLimitBytes;
  int entryLimit;
}

enum CommandEventKind { stdout, stderr, progress, exited }

class ExternalCommandEvent {
  ExternalCommandEvent({
    required this.ownerId,
    required this.callId,
    required this.sequence,
    required this.kind,
    this.bytes,
    this.exitCode,
    this.signal,
    this.error,
    this.transferredBytes = 0,
    this.completedPaths = const [],
    this.cancelled = false,
    this.outputLimitExceeded = false,
    this.terminationAcknowledged = false,
  });
  String ownerId;
  String callId;
  int sequence;
  CommandEventKind kind;
  Uint8List? bytes;
  int? exitCode;
  int? signal;
  String? error;
  int transferredBytes;
  List<String> completedPaths;
  bool cancelled;
  bool outputLimitExceeded;
  bool terminationAcknowledged;
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
  @async
  void start(ExternalCommandSpec spec);
  @async
  void transfer(ChannelTransferSpec spec);
  @async
  void cancel(String ownerId, String callId);
  @async
  void endOwner(String ownerId);
}

@FlutterApi()
abstract class CommandChannelFlutterApi {
  @async
  void event(ExternalCommandEvent event);
  void statusChanged();
  void ownerStopped(String ownerId);
}
