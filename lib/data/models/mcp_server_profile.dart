import '../../core/error/failure.dart';
import 'tool_source.dart';

/// E1 开放 Streamable HTTP；E4 在原始进程管道上开放本地 stdio。
enum McpTransport { streamableHttp, stdio }

/// stdio 启动命令：executable + argv 与固定 guest cwd，不拼接 shell 命令。
/// environment 为明文变量；environmentSecretRefs 只保存安全存储引用。
class McpStdioCommand {
  const McpStdioCommand({
    required this.executable,
    this.args = const [],
    this.cwd = '/workspace',
    this.environment = const {},
    this.environmentSecretRefs = const {},
  });
  final String executable;
  final List<String> args;
  final String cwd;
  final Map<String, String> environment;
  final Map<String, String> environmentSecretRefs;

  McpStdioCommand copyWith({
    String? executable,
    List<String>? args,
    String? cwd,
    Map<String, String>? environment,
    Map<String, String>? environmentSecretRefs,
  }) => McpStdioCommand(
    executable: executable ?? this.executable,
    args: args ?? this.args,
    cwd: cwd ?? this.cwd,
    environment: environment ?? this.environment,
    environmentSecretRefs: environmentSecretRefs ?? this.environmentSecretRefs,
  );

  /// 仓储保存敏感环境变量引用时整体替换；空映射即清除全部引用。
  McpStdioCommand withSecretRefs(Map<String, String> refs) => McpStdioCommand(
    executable: executable,
    args: args,
    cwd: cwd,
    environment: environment,
    environmentSecretRefs: Map.unmodifiable(refs),
  );

  Map<String, dynamic> toJson() => {
    'executable': executable,
    'args': args,
    'cwd': cwd,
    'environment': environment,
    'environmentSecretRefs': environmentSecretRefs,
  };

  factory McpStdioCommand.fromJson(Map<String, dynamic> json) =>
      McpStdioCommand(
        executable: json['executable'] as String,
        args: List<String>.unmodifiable(
          (json['args'] as List? ?? const []).cast<String>(),
        ),
        cwd: json['cwd'] as String? ?? '/workspace',
        environment: Map<String, String>.unmodifiable(
          (json['environment'] as Map? ?? const {}).cast<String, String>(),
        ),
        environmentSecretRefs: Map<String, String>.unmodifiable(
          (json['environmentSecretRefs'] as Map? ?? const {})
              .cast<String, String>(),
        ),
      );
}

class McpServerProfile {
  McpServerProfile({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.definitionRevision,
    required this.createdAt,
    required this.updatedAt,
    this.transport = McpTransport.streamableHttp,
    this.command,
    this.enabled = true,
    this.requiresBearer = false,
    this.credentialRef,
    this.credentialRefs = const [],
    this.headerRefs = const {},
    this.connectTimeoutSeconds = 15,
    this.callTimeoutSeconds = 60,
    this.deleting = false,
  });

  final String id;
  final String name;

  /// stdio 传输不使用 endpoint，固定为空字符串。
  final String endpoint;
  final McpTransport transport;
  final McpStdioCommand? command;
  final String definitionRevision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool enabled;
  final bool requiresBearer;
  final String? credentialRef;
  final List<String> credentialRefs;
  final Map<String, String> headerRefs;
  final int connectTimeoutSeconds;
  final int callTimeoutSeconds;
  final bool deleting;

  void validate() {
    if (name.trim().isEmpty || name.length > 100) {
      throw const OperationFailure('MCP 服务名称应为 1–100 个字符');
    }
    if (connectTimeoutSeconds < 1 ||
        connectTimeoutSeconds > 120 ||
        callTimeoutSeconds < 1 ||
        callTimeoutSeconds > 300) {
      throw const OperationFailure('连接超时应为 1–120 秒，调用超时应为 1–300 秒');
    }
    if (transport == McpTransport.streamableHttp) {
      final uri = Uri.tryParse(endpoint);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          uri.hasQuery) {
        throw const OperationFailure('请填写不含凭据、查询参数或片段的 HTTP(S) 地址');
      }
      return;
    }
    final command = this.command;
    if (command == null) {
      throw const OperationFailure('stdio 服务需要启动命令');
    }
    if (!command.executable.startsWith('/') ||
        command.executable.contains('\u0000') ||
        command.executable.length > 4096) {
      throw const OperationFailure('启动程序应为 guest 内的绝对路径');
    }
    if (command.args.length > 128 ||
        command.args.fold(0, (total, arg) => total + arg.length) > 131072 ||
        command.args.any((arg) => arg.contains('\u0000'))) {
      throw const OperationFailure('启动参数过长或包含无效字符');
    }
    if (!command.cwd.startsWith('/') ||
        command.cwd.contains('\u0000') ||
        command.cwd.length > 4096) {
      throw const OperationFailure('guest 工作目录应为以 / 开头的路径');
    }
    if (command.environment.length > 32 ||
        command.environmentSecretRefs.length > 32) {
      throw const OperationFailure('环境变量最多 32 项');
    }
    for (final entry in {
      ...command.environment,
      ...command.environmentSecretRefs,
    }.entries) {
      if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(entry.key)) {
        throw const OperationFailure('环境变量名称只允许字母、数字与下划线，且不以数字开头');
      }
      if (command.environment.containsKey(entry.key) &&
          command.environmentSecretRefs.containsKey(entry.key)) {
        throw const OperationFailure('同名环境变量不能同时明文保存与加密保存');
      }
    }
    for (final value in command.environment.values) {
      if (value.contains('\u0000') || value.length > 32768) {
        throw const OperationFailure('环境变量值过长或包含无效字符');
      }
    }
  }

  McpServerProfile copyWith({
    String? name,
    String? endpoint,
    McpStdioCommand? command,
    bool dropCommand = false,
    String? definitionRevision,
    DateTime? updatedAt,
    bool? enabled,
    bool? requiresBearer,
    String? credentialRef,
    List<String>? credentialRefs,
    Map<String, String>? headerRefs,
    int? connectTimeoutSeconds,
    int? callTimeoutSeconds,
    bool? deleting,
  }) => McpServerProfile(
    id: id,
    name: name ?? this.name,
    endpoint: endpoint ?? this.endpoint,
    transport: transport,
    command: dropCommand ? null : (command ?? this.command),
    definitionRevision: definitionRevision ?? this.definitionRevision,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    enabled: enabled ?? this.enabled,
    requiresBearer: requiresBearer ?? this.requiresBearer,
    credentialRef: credentialRef ?? this.credentialRef,
    credentialRefs: credentialRefs ?? this.credentialRefs,
    headerRefs: headerRefs ?? this.headerRefs,
    connectTimeoutSeconds: connectTimeoutSeconds ?? this.connectTimeoutSeconds,
    callTimeoutSeconds: callTimeoutSeconds ?? this.callTimeoutSeconds,
    deleting: deleting ?? this.deleting,
  );

  Map<String, dynamic> toJson() {
    final command = this.command;
    return {
      'id': id,
      'name': name,
      'transport': transport.name,
      'endpoint': endpoint,
      if (command != null) 'command': command.toJson(),
      'definitionRevision': definitionRevision,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'enabled': enabled,
      'requiresBearer': requiresBearer,
      'credentialRef': credentialRef,
      'credentialRefs': credentialRefs,
      'headerRefs': headerRefs,
      'connectTimeoutSeconds': connectTimeoutSeconds,
      'callTimeoutSeconds': callTimeoutSeconds,
      'deleting': deleting,
    };
  }

  factory McpServerProfile.fromJson(Map<String, dynamic> json) {
    final transport = McpServerProfile._transport(json['transport'] as String?);
    return McpServerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      endpoint: json['endpoint'] as String? ?? '',
      transport: transport,
      command: json['command'] is Map<String, dynamic>
          ? McpStdioCommand.fromJson(json['command'] as Map<String, dynamic>)
          : null,
      definitionRevision: json['definitionRevision'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      enabled: json['enabled'] as bool,
      requiresBearer: json['requiresBearer'] as bool,
      credentialRef: json['credentialRef'] as String?,
      credentialRefs: List<String>.unmodifiable(
        (json['credentialRefs'] as List).cast<String>(),
      ),
      headerRefs: Map<String, String>.unmodifiable(
        (json['headerRefs'] as Map).cast<String, String>(),
      ),
      connectTimeoutSeconds: json['connectTimeoutSeconds'] as int,
      callTimeoutSeconds: json['callTimeoutSeconds'] as int,
      deleting: json['deleting'] as bool,
    );
  }

  static McpTransport _transport(String? name) => switch (name) {
    'stdio' => McpTransport.stdio,
    _ => McpTransport.streamableHttp,
  };
}

class McpServerEntry {
  McpServerEntry({
    required this.profile,
    this.tools = const [],
    this.protocolVersion,
  });

  final McpServerProfile profile;
  final List<ToolSnapshot> tools;
  final String? protocolVersion;
}

/// 名称只是模型侧别名；执行使用持久化的来源 ID 和原名，不反解别名。
String mcpToolName(String serverId, String originalName) {
  String fragment(String value, int length) {
    final clean = value.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_');
    return clean.substring(0, clean.length.clamp(0, length));
  }

  final digest = definitionDigest([serverId, originalName]).substring(0, 16);
  return 'mcp_${fragment(serverId, 8)}_${fragment(originalName, 32)}_$digest';
}

ToolSnapshot mcpToolSnapshot(
  McpServerProfile profile,
  Map<String, dynamic> tool,
) {
  final original = tool['name'];
  final schema = tool['inputSchema'];
  if (original is! String ||
      original.isEmpty ||
      schema is! Map<String, dynamic> ||
      schema['type'] != 'object' ||
      (tool['description'] != null && tool['description'] is! String)) {
    throw const McpFailure('invalidDefinition', 'MCP 返回了无效的工具定义');
  }
  return ToolSnapshot(
    name: mcpToolName(profile.id, original),
    description: tool['description'] as String? ?? '',
    inputSchema: schema,
    source: ToolSource(
      kind: ToolSourceKind.mcp,
      id: profile.id,
      originalName: original,
      definitionRevision: definitionDigest([profile.definitionRevision, tool]),
      // 服务端 annotations 不授予只读权限。
      effectClass: ToolEffectClass.unknown,
    ),
  );
}
