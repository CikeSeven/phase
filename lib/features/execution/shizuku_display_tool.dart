import '../../../data/models/command_channel.dart';
import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_policy.dart';
import '../tools/tool.dart';
import 'channel_driver.dart';
import 'execution_api.g.dart';
import 'visual_tools.dart';

/// Explicit virtual-display backend; never falls back to the physical display.
class ShizukuDisplayTool extends Tool {
  const ShizukuDisplayTool(this.binding, this.driver);
  final CommandChannelSnapshot binding;
  final ChannelDriver Function() driver;

  @override
  String get name => 'shizuku_display';
  @override
  ExecutionChannel get channel => ExecutionChannel.shizuku;
  @override
  String get policyKey => applicationOperationsPolicyKey;
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.ask;
  @override
  Set<String> get requiredCapabilities => const {
    'applications',
    'shizuku_device',
    'vision',
  };
  @override
  String get description =>
      '以 Shizuku UID ${binding.uid} 控制本次运行专属的 Android 虚拟屏，不操作主屏。'
      '先用 list_apps 选择允许的应用，launch 创建虚拟屏并启动；capture 重新观察。'
      'tap/swipe/key/text 必须引用此屏最近返回的 screenshotId，坐标为返回图片的像素。'
      '每次操作后返回可获得的真实截图；观察失败不代表动作未执行，不得直接重放。'
      'key 仅接受 back/enter/tab/delete/escape/up/down/left/right；text 仅支持系统键盘能映射的字符，中文或 Emoji 可能不支持，不使用剪贴板。'
      '支付、密码和验证码仍由用户手动处理，不通过此工具绕过。'
      '虚拟屏不隔离账号和数据，应用可能复用系统任务。close 或运行结束释放屏幕，不撤销外部效果。';

  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['launch', 'capture', 'tap', 'swipe', 'key', 'text', 'close'],
      },
      'packageName': {
        'type': 'string',
        'description': '除 close 外必填；launch 指定要启动的允许应用，其余操作必须匹配虚拟屏实际前台应用',
      },
      'screenshotId': {
        'type': 'string',
        'description': '输入动作必填，本次运行最近取得的虚拟屏截图 ID',
      },
      'x': {'type': 'integer', 'minimum': 0, 'maximum': 719},
      'y': {'type': 'integer', 'minimum': 0, 'maximum': 1279},
      'endX': {'type': 'integer', 'minimum': 0, 'maximum': 719},
      'endY': {'type': 'integer', 'minimum': 0, 'maximum': 1279},
      'durationMs': {'type': 'integer', 'minimum': 50, 'maximum': 2000},
      'key': {
        'type': 'string',
        'enum': [
          'back',
          'enter',
          'tab',
          'delete',
          'escape',
          'up',
          'down',
          'left',
          'right',
        ],
      },
      'text': {'type': 'string', 'minLength': 1, 'maxLength': 500},
    },
    'required': ['action'],
  };

  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final action = arguments['action'];
    final fields = switch (action) {
      'launch' || 'capture' => {'action', 'packageName'},
      'tap' => {'action', 'packageName', 'screenshotId', 'x', 'y'},
      'swipe' => {
        'action',
        'packageName',
        'screenshotId',
        'x',
        'y',
        'endX',
        'endY',
        'durationMs',
      },
      'key' => {'action', 'packageName', 'screenshotId', 'key'},
      'text' => {'action', 'packageName', 'screenshotId', 'text'},
      'close' => {'action'},
      _ => <String>{},
    };
    if (fields.isEmpty || arguments.keys.any((key) => !fields.contains(key))) {
      return '请仅填写当前虚拟屏动作需要的参数';
    }
    for (final key in fields.difference({'durationMs'})) {
      if (!arguments.containsKey(key)) return '虚拟屏动作缺少 $key';
    }
    for (final key in ['packageName', 'screenshotId', 'text']) {
      final value = arguments[key];
      if (fields.contains(key) &&
          (value is! String || value.isEmpty || value.contains('\u0000'))) {
        return '$key 不能为空或包含空字符';
      }
    }
    final package = arguments['packageName'];
    if (package is String &&
        !RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$')
            .hasMatch(package)) {
      return '请提供有效的 Android 应用包名';
    }
    for (final key in ['x', 'y', 'endX', 'endY']) {
      if (!fields.contains(key)) continue;
      final value = arguments[key];
      final maximum = key == 'x' || key == 'endX' ? 719 : 1279;
      if (value is! int || value < 0 || value > maximum) {
        return '$key 必须是 0–$maximum 的整数图片坐标';
      }
    }
    final duration = arguments['durationMs'];
    if (arguments.containsKey('durationMs') &&
        (duration is! int || duration < 50 || duration > 2000)) {
      return '滑动时长必须是 50–2000 毫秒的整数';
    }
    if (action == 'key' &&
        !const {
          'back',
          'enter',
          'tab',
          'delete',
          'escape',
          'up',
          'down',
          'left',
          'right',
        }.contains(arguments['key'])) {
      return '请使用工具声明的虚拟屏按键';
    }
    if (arguments['text'] case final String text when text.length > 500) {
      return '单次输入不能超过 500 字符';
    }
    if (arguments['screenshotId'] case final String id when id.length > 100) {
      return '请引用最近返回的虚拟屏截图 ID';
    }
    return null;
  }

  @override
  String describeAction(Map<String, dynamic> arguments) =>
      'Shizuku 虚拟屏 · UID ${binding.uid}\n'
      '${arguments['action']} ${arguments['packageName'] ?? ''}'
      '${arguments['text'] == null ? '' : '\n${arguments['text']}'}'
      '\n操作后截图会发送给所选模型；停止不撤销已发生的效果';

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    final validation = validateArguments(arguments);
    if (validation != null) {
      return ToolOutcome.failure(validation, errorCode: 'invalidArguments');
    }
    final result = await driver().execute(
      ExecutionRequest(
        runId: context.runId,
        toolCallId: context.toolCallId,
        action: ExecutionAction.controlDisplay,
        arguments: {
          ...arguments,
          'uid': binding.uid,
          'revision': binding.revision,
        },
        target: ExecutionTarget(
          packageName: arguments['packageName'] as String?,
        ),
        timeoutMs: 30000,
      ),
      cancellation,
      onProgress: (event) => onProgress?.call(event.payload),
    );
    return visualResultOutcome(
      result,
      context,
      cancellation,
      captureRequired: arguments['action'] == 'capture',
    );
  }
}
