import 'dart:async';

import '../../../data/models/attachment.dart';
import '../../../data/models/chat_request.dart';
import '../../../data/models/tool_policy.dart';

/// 工具需要的存储能力：读会话附件、定位产物目录、登记产物。
abstract interface class ToolStorage {
  /// 本会话可读的附件。
  Future<List<Attachment>> attachments(String conversationId);

  /// 本会话产物目录（应用私有，按会话隔离）。
  String artifactsDirectory(String conversationId);

  /// 把产物文件登记成附件，返回附件记录。
  Future<Attachment> registerArtifact({
    required String conversationId,
    required String path,
    required String name,
  });

  /// 把内存中的字节登记成附件（截断的响应正文等）。
  Future<Attachment> registerBytes({
    required String conversationId,
    required String name,
    required String mimeType,
    required List<int> bytes,
  });
}

/// 一次工具调用可用的上下文：会话、运行、本次调用与附件访问。
class ToolContext {
  const ToolContext({
    required this.conversationId,
    required this.runId,
    required this.toolCallId,
    required this.storage,
    required this.attachments,
    this.workspaceDirectory = '',
  });

  final String conversationId;
  final String runId;

  /// 本次调用的应用侧 id：产物、日志与界面都用它关联。
  final String toolCallId;

  final ToolStorage storage;

  /// 当前会话的附件（read_file / list_files 只读这些）。
  final List<Attachment> attachments;

  /// 允许读写的应用私有工作目录。
  final String workspaceDirectory;

  String get artifactsDirectory => storage.artifactsDirectory(conversationId);

  /// 按引用（附件 id 或文件名）找到附件。
  Attachment? attachmentBy(String reference) {
    for (final attachment in attachments) {
      if (attachment.id == reference) return attachment;
    }
    for (final attachment in attachments) {
      if (attachment.name == reference) return attachment;
    }
    return null;
  }
}

/// 工具执行结果：成功、失败或结果未知，附带产物与说明。
class ToolOutcome {
  const ToolOutcome({
    required this.ok,
    required this.content,
    this.artifacts = const [],
    this.errorCode,
    this.unknown = false,
  });

  const ToolOutcome.success(this.content, {this.artifacts = const []})
    : ok = true,
      unknown = false,
      errorCode = null;

  const ToolOutcome.failure(this.content, {this.errorCode})
    : ok = false,
      unknown = false,
      artifacts = const [];

  /// 已派发但结果不可靠：界面提示核验，不自动重做动作。
  const ToolOutcome.unknown(this.content, {this.errorCode})
    : ok = false,
      unknown = true,
      artifacts = const [];

  final bool ok;
  final String content;

  /// 产物附件 id（写文件、下载等）。
  final List<String> artifacts;
  final String? errorCode;

  /// 结果是否未确认。
  final bool unknown;
}

/// 工具执行中可选的进度上报（章节、字节等）。
typedef ToolProgress = void Function(String message);

/// 一个可被模型调用的工具。
abstract class Tool {
  String get name;
  String get description;

  /// JSON Schema 形式的参数定义。
  Map<String, dynamic> get inputSchema;

  /// 执行需要的通道能力（文件、网络、系统信息等）。
  Set<String> get requiredCapabilities;

  /// 未配置助手策略时使用的默认策略。
  ToolPolicy get defaultPolicy;

  /// 确认页展示给用户的一句话动作摘要。
  String describeAction(Map<String, dynamic> arguments);

  /// 执行工具；抛异常按失败处理，超时与用户停止由调用方取消。
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  });
}

/// 协作式取消：工具在长任务里轮询它，停止时本轮的模型请求与动作一起结束。
class RunCancellation {
  RunCancellation();

  final _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// 等待取消；已取消时立即返回，供工具在分段之间让出控制权。
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }

  /// 已取消时抛出，让调用方走统一的停止路径。
  void throwIfCancelled() {
    if (isCancelled) throw const _ToolCancelled();
  }
}

class _ToolCancelled implements Exception {
  const _ToolCancelled();
}

/// 参数读取辅助：缺失或类型不符时抛出明确的参数错误。
class ToolArguments {
  ToolArguments(this.raw, this.toolName);

  final Map<String, dynamic> raw;
  final String toolName;

  String string(String key, {bool required = true, String? fallback}) {
    final value = raw[key];
    if (value is String && value.trim().isNotEmpty) return value;
    if (!required && fallback != null) return fallback;
    throw ToolArgumentException(toolName, '缺少参数 $key');
  }

  String? optionalString(String key) {
    final value = raw[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  int? optionalInt(String key) {
    final value = raw[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool boolValue(String key, {bool fallback = false}) {
    final value = raw[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  /// 只保留声明过的参数，避免把未定义字段带进执行。
  Map<String, dynamic> allow(Iterable<String> keys) => {
    for (final key in keys)
      if (raw.containsKey(key)) key: raw[key],
  };
}

/// 参数错误：模型给错参数时如实返回失败，不尝试从文本里猜命令。
class ToolArgumentException implements Exception {
  const ToolArgumentException(this.toolName, this.message);

  final String toolName;
  final String message;

  @override
  String toString() => '参数错误（$toolName）：$message';
}

/// 当前系统时间与设备信息。
class SystemInfoTool implements Tool {
  const SystemInfoTool();

  @override
  String get name => 'system_info';

  @override
  String get description => '查询当前时间与设备信息（时区、型号、系统版本、应用版本）。';

  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {},
    'additionalProperties': false,
  };

  @override
  Set<String> get requiredCapabilities => const {'system_info'};

  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;

  @override
  String describeAction(Map<String, dynamic> arguments) => '读取当前时间与设备信息';

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    cancellation.throwIfCancelled();
    final now = DateTime.now();
    final local = now.toLocal();
    return ToolOutcome.success(
      '当前时间：${local.toIso8601String()}（时区 ${local.timeZoneName}，'
      'UTC 偏移 ${local.timeZoneOffset.inMinutes} 分钟）',
    );
  }
}

/// 按名称注册工具；未注册的工具名不会被执行。
class ToolRegistry {
  ToolRegistry(Iterable<Tool> tools)
    : _tools = {for (final tool in tools) tool.name: tool};

  final Map<String, Tool> _tools;

  Iterable<Tool> get tools => _tools.values;

  Tool? byName(String name) => _tools[name];

  bool contains(String name) => _tools.containsKey(name);

  /// 本次运行开放给模型的工具定义：策略为 deny 的不下发。
  List<ToolDefinition> definitionsFor(
    Set<String> enabledTools,
    Map<String, ToolPolicy> overrides,
  ) {
    return [
      for (final tool in _tools.values)
        if (policyFor(tool, enabledTools, overrides) != ToolPolicy.deny)
          _DefinitionOf(tool),
    ];
  }

  /// 工具策略：助手显式覆盖优先，其次「是否在助手工具范围里」，最后工具默认。
  ToolPolicy policyFor(
    Tool tool,
    Set<String> enabledTools,
    Map<String, ToolPolicy> overrides,
  ) {
    final override = overrides[tool.name];
    if (override != null) return override;
    // 助手声明了工具范围且不含该工具：不开放，避免执行未配置的能力。
    if (enabledTools.isNotEmpty && !enabledTools.contains(tool.name)) {
      return ToolPolicy.deny;
    }
    return tool.defaultPolicy;
  }
}

/// 把 [Tool] 适配成协议层需要的定义。
class _DefinitionOf implements ToolDefinition {
  const _DefinitionOf(this._tool);

  final Tool _tool;

  @override
  String get name => _tool.name;

  @override
  String get description => _tool.description;

  @override
  Map<String, dynamic> get inputSchema => _tool.inputSchema;

  @override
  Set<String> get requiredCapabilities => _tool.requiredCapabilities;

  @override
  ToolPolicy get defaultPolicy => _tool.defaultPolicy;

  @override
  String describeAction(Map<String, dynamic> arguments) =>
      _tool.describeAction(arguments);
}
