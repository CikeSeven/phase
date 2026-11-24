import 'dart:async';

import '../../core/error/failure.dart';
import '../../data/models/command_channel.dart';
import '../../data/models/tool_call_record.dart';
import '../../data/models/tool_policy.dart';
import '../tools/tool.dart';
import '../tools/tool_output_limits.dart';
import 'root_command_driver.dart';

class AndroidShellTool extends Tool {
  const AndroidShellTool(this.binding, this.isEnabled);

  final CommandChannelSnapshot binding;
  final bool Function() isEnabled;
  static const _driver = RootCommandDriver();
  static final _command = RegExp(r'^[a-zA-Z0-9.,_\t -]{1,320}$');

  @override
  String get name => 'android_shell';

  @override
  ExecutionChannel get channel => binding.channel;

  @override
  Set<String> get requiredCapabilities => const {'android_shell'};

  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;

  @override
  String get description => '在手机的 Android 系统中执行诊断命令，返回输出和退出码。';

  @override
  String get promptSnippet =>
      '查询 Android 当前进程用 ps -A，查询已安装应用用 pm list packages。';

  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'command': {
        'type': 'string',
        'description':
            '单条命令，可带 adb shell 前缀。支持 id、ps -A、pidof 包名、'
            'top -b -n 1、pm list packages、pm path 包名、dumpsys battery、dumpsys meminfo、'
            'df -h、uptime、wm size、wm density，以及 getprop 查询 '
            'ro.build.version.release、ro.build.version.sdk、ro.product.manufacturer、ro.product.model。',
      },
    },
    'required': ['command'],
  };

  String get _identity => channel == ExecutionChannel.root
      ? 'Root · UID ${binding.uid}'
      : 'Shizuku · UID ${binding.uid}';

  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '$_identity\n${arguments['command']}';

  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final command = arguments['command'];
    if (arguments.length != 1 ||
        command is! String ||
        !_command.hasMatch(command) ||
        command.trim().isEmpty) {
      return '请输入一条 Android Shell 命令';
    }
    return null;
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
        'Android 命令通道已关闭',
        errorCode: 'channelDisabled',
      );
    }
    final id = context.toolCallId;
    var active = true;
    try {
      final execution = _driver.executeAndroidShell(
        binding: binding,
        id: id,
        command: arguments['command'] as String,
      );
      unawaited(
        cancellation.whenCancelled.then((_) async {
          if (!active) return;
          try {
            await _driver.cancelDeviceAction(id);
          } on Failure {
            // The command remains subject to the native execution deadline.
          }
        }),
      );
      final result = await execution;
      final preview = truncateToolText(result.output.trimRight());
      final output = preview.text.isEmpty ? '' : '\n${preview.text}';
      final limit = preview.truncated || result.truncated ? '\n输出已截断' : '';
      final detail = '$_identity$output$limit';
      return switch (result.status) {
        RootCommandStatus.exited when result.exitCode == 0 =>
          ToolOutcome.success('退出码 0 · $detail'),
        RootCommandStatus.exited => ToolOutcome.failure(
          '退出码 ${result.exitCode} · $detail',
          errorCode: 'executionFailed',
        ),
        RootCommandStatus.cancelled => ToolOutcome.cancelled(
          'Android 命令已停止 · $detail',
        ),
        RootCommandStatus.timedOut => ToolOutcome.failure(
          'Android 命令超时 · $detail',
          errorCode: 'timeout',
        ),
        RootCommandStatus.unconfirmed => const ToolOutcome.failure(
          '未收到 Android 命令结束回执',
          errorCode: 'unconfirmed',
        ),
      };
    } on Failure catch (error) {
      return ToolOutcome.failure(
        error.userMessage,
        errorCode: 'androidShellFailed',
      );
    } finally {
      active = false;
    }
  }
}
