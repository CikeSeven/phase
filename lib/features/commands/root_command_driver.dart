import 'package:flutter/services.dart';

import '../../core/error/failure.dart';
import '../../data/models/command_channel.dart';

enum RootCommandStatus { exited, cancelled, timedOut, unconfirmed }

enum RootDeviceAction {
  listApps('list_apps', '列出应用'),
  appPath('app_path', '查看应用安装包路径', takesPackage: true),
  processes('processes', '列出当前进程'),
  battery('battery', '读取电池状态'),
  storage('storage', '读取存储空间'),
  launchApp('launch_app', '启动应用', takesPackage: true),
  forceStopApp('force_stop_app', '强行停止应用', takesPackage: true);

  const RootDeviceAction(this.value, this.label, {this.takesPackage = false});

  final String value;
  final String label;
  final bool takesPackage;

  bool get writesState => this == launchApp || this == forceStopApp;

  static RootDeviceAction? parse(Object? value) =>
      values.where((action) => action.value == value).firstOrNull;
}

class RootCommandResult {
  const RootCommandResult({
    required this.status,
    required this.exitCode,
    required this.output,
    required this.truncated,
  });

  final RootCommandStatus status;
  final int? exitCode;
  final String output;
  final bool truncated;
}

class RootCommandDriver {
  const RootCommandDriver();

  static const _channel = MethodChannel('app.xiangyue.phase/root_commands');

  Future<RootCommandResult> execute(String command) =>
      _result('execute', command);

  Future<void> authorize() async {
    final result = await _result('authorize');
    if (result.status != RootCommandStatus.exited ||
        result.exitCode != 0 ||
        !result.output.split('\n').any((line) => line.trim() == '0')) {
      throw const OperationFailure('未确认 Root 授权，请检查 Root 管理器');
    }
  }

  Future<RootCommandResult> executeDeviceAction({
    required String id,
    required RootDeviceAction action,
    String? packageName,
  }) => _result('executeDeviceAction', {
    'id': id,
    'action': action.value,
    'packageName': ?packageName,
  });

  Future<RootCommandResult> executeAndroidShell({
    required CommandChannelSnapshot binding,
    required String id,
    required String command,
  }) => _result('executeAndroidShell', {
    'id': id,
    'channel': binding.channel.name,
    'uid': binding.uid,
    'revision': binding.revision,
    'command': command,
  });

  Future<void> cancelDeviceAction([String? id]) async {
    await _invoke('cancelDeviceAction', id);
  }

  Future<RootCommandResult> _result(String method, [Object? arguments]) async {
    final result = await _invoke(method, arguments);
    if (result case {
      'status': final String status,
      'exitCode': final int? exitCode,
      'output': final String output,
      'truncated': final bool truncated,
    }) {
      final parsed = RootCommandStatus.values
          .where((value) => value.name == status)
          .firstOrNull;
      if (parsed != null &&
          (parsed != RootCommandStatus.exited || exitCode != null)) {
        return RootCommandResult(
          status: parsed,
          exitCode: exitCode,
          output: output,
          truncated: truncated,
        );
      }
    }
    throw OperationFailure(
      method == 'executeAndroidShell' ? '无法读取 Android 命令结果' : '无法读取 Root 命令结果',
    );
  }

  Future<void> cancel() async {
    await _invoke('cancel');
  }

  Future<Object?> _invoke(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (error) {
      final androidShell = method == 'executeAndroidShell';
      throw OperationFailure(switch (error.code) {
        'invalidCommand' => '命令为空或超过 16 KiB，或包含无效字符',
        'invalidAction' => 'Root 操作或目标应用无效',
        'channelDisabled' => androidShell ? 'Android 命令通道已关闭' : 'Root 模式已关闭',
        'busy' => androidShell ? '已有 Android 命令正在运行' : '已有 Root 命令正在运行',
        'suUnavailable' => '找不到可用的 su，请确认设备已 Root',
        'permissionRequired' => '无法确认 Root 执行身份，请检查 Root 管理器中的授权',
        'unsupported' => '此设备缺少 Root 命令执行组件',
        'unsupportedShellCommand' => '此 Android Shell 命令或参数组合暂未开放',
        'identityChanged' => 'Shizuku 执行身份已变化，请检查授权后重新开始任务',
        'shizukuUnavailable' => 'Shizuku 服务连接失败，请检查服务状态及授权',
        'unconfirmed' => '未收到 Android 命令结束回执',
        _ => androidShell ? 'Android 命令执行失败' : 'Root 命令操作失败',
      });
    } on MissingPluginException {
      throw const OperationFailure('此平台不支持 Android Root 模式');
    }
  }
}
