import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/features/workspace/process_api.g.dart',
  kotlinOut: 'android/app/src/main/kotlin/app/xiangyue/phase/bridge/ProcessApi.g.kt',
  kotlinOptions: KotlinOptions(package: 'app.xiangyue.phase.bridge.process'),
  dartPackageName: 'phase',
))
class LinuxPlatformInfo {
  LinuxPlatformInfo({required this.rootDirectory, required this.abi, required this.available, required this.freeBytes});
  String rootDirectory;
  String abi;
  bool available;
  int freeBytes;
}

class LinuxProcessSpec {
  LinuxProcessSpec({required this.ownerId, required this.processId, required this.rootfs, required this.workspace, required this.executable, required this.argv, required this.cwd, required this.environment, required this.timeoutMs, required this.outputLimitBytes});
  String ownerId;
  String processId;
  String rootfs;
  String workspace;
  String executable;
  List<String> argv;
  String cwd;
  Map<String, String> environment;

  /// 超时毫秒数；null 表示不设超时（产品决策：命令不设超时，靠用户
  /// 停止与任务收尾终止进程）。宿主只校验为正数，不设上限。
  int? timeoutMs;
  int? outputLimitBytes;
}

enum LinuxEventKind { started, stdout, stderr, exited }
class LinuxProcessEvent {
  LinuxProcessEvent({required this.ownerId, required this.processId, required this.sequence, required this.kind, this.bytes, this.exitCode, this.signal, this.error, this.cancelled = false, this.timedOut = false, this.outputLimitExceeded = false});
  String ownerId;
  String processId;
  int sequence;
  LinuxEventKind kind;
  Uint8List? bytes;
  int? exitCode;
  int? signal;
  String? error;
  bool cancelled;
  bool timedOut;
  bool outputLimitExceeded;
}

@HostApi()
abstract class LinuxProcessHostApi {
  LinuxPlatformInfo platformInfo();
  @async
  void setModes(List<String> paths, List<int> modes);
  @async
  void beginTask(String ownerId, String label);
  @async
  void endTask(String ownerId);
  @async
  void start(LinuxProcessSpec spec);
  @async
  void writeStdin(String ownerId, String processId, Uint8List bytes);
  @async
  void closeStdin(String ownerId, String processId);
  @async
  void cancel(String ownerId, String processId);
}

@FlutterApi()
abstract class LinuxProcessFlutterApi {
  @async
  void event(LinuxProcessEvent event);
  void taskStopped(String ownerId);
}
