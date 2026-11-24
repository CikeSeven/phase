import 'dart:async';

import '../../core/error/failure.dart';
import '../../data/models/tool_call_record.dart';
import '../../data/models/tool_policy.dart';
import '../tools/tool.dart';
import 'root_command_driver.dart';

class RootDeviceTool extends Tool {
  const RootDeviceTool(
    this.isEnabled, {
    this.driver = const RootCommandDriver(),
  });

  final bool Function() isEnabled;
  final RootCommandDriver driver;

  @override
  String get name => 'root_device';
  @override
  ExecutionChannel get channel => ExecutionChannel.root;
  @override
  Set<String> get requiredCapabilities => const {'root_device'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;
  @override
  String get description => '以 Root 权限查询 Android 设备状态及管理应用。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'action': {
        'type': 'string',
        'enum': [for (final action in RootDeviceAction.values) action.value],
        'description':
            'list_apps 列出应用，app_path 查询安装包路径，processes 列出当前进程，battery 查询电池，'
            'storage 查询存储，launch_app 启动应用，force_stop_app 强行停止应用。',
      },
      'packageName': {
        'type': 'string',
        'description': 'app_path、launch_app、force_stop_app 的目标 Android 应用包名。',
      },
    },
    'required': ['action'],
  };

  static final _package = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$');

  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final action = RootDeviceAction.parse(arguments['action']);
    if (action == null ||
        arguments.keys.any(
          (key) => !const {'action', 'packageName'}.contains(key),
        )) {
      return '请选择有效的 Root 操作';
    }
    final package = arguments['packageName'];
    if (action.takesPackage) {
      if (package is! String ||
          package.length > 255 ||
          !_package.hasMatch(package)) {
        return '请提供有效的 Android 应用包名';
      }
    } else if (arguments.containsKey('packageName')) {
      return '此操作无需应用包名';
    }
    return null;
  }

  @override
  String describeAction(Map<String, dynamic> arguments) {
    final action = RootDeviceAction.parse(arguments['action']);
    final package = arguments['packageName'];
    return 'Root · UID 0 · ${action?.label ?? '设备操作'}'
        '${package is String ? '\n$package' : ''}';
  }

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final error = validateArguments(arguments);
    if (error != null) {
      return ToolOutcome.failure(error, errorCode: 'invalidArguments');
    }
    await context.checkPermission?.call();
    cancellation.throwIfCancelled();
    if (!isEnabled()) {
      return const ToolOutcome.failure(
        'Root 模式已关闭',
        errorCode: 'channelDisabled',
      );
    }
    final id = context.toolCallId;
    final action = RootDeviceAction.parse(arguments['action'])!;
    var active = true;
    try {
      final pending = driver.executeDeviceAction(
        id: id,
        action: action,
        packageName: arguments['packageName'] as String?,
      );
      unawaited(
        cancellation.whenCancelled.then((_) async {
          if (!active) return;
          try {
            await driver.cancelDeviceAction(id);
          } on Failure {
            // The operation still waits for the native process report.
          }
        }),
      );
      final result = await pending;
      final output = result.output.trimRight();
      final detail = output.isEmpty
          ? ''
          : '\n$output${result.truncated ? '\n输出已截断' : ''}';
      return switch (result.status) {
        RootCommandStatus.exited when result.exitCode == 0 =>
          ToolOutcome.success('Root 操作已完成$detail'),
        RootCommandStatus.exited => ToolOutcome.failure(
          'Root 操作退出码 ${result.exitCode}$detail',
          errorCode: 'executionFailed',
        ),
        RootCommandStatus.cancelled => ToolOutcome.cancelled(
          'Root 操作已停止$detail',
        ),
        RootCommandStatus.timedOut => const ToolOutcome.failure(
          'Root 操作超时',
          errorCode: 'timeout',
        ),
        RootCommandStatus.unconfirmed => const ToolOutcome.failure(
          '未收到 Root 进程结束回执',
          errorCode: 'unconfirmed',
        ),
      };
    } on Failure catch (error) {
      return ToolOutcome.failure(
        error.userMessage,
        errorCode: 'rootUnavailable',
      );
    } finally {
      active = false;
    }
  }
}
