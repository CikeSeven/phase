import '../../core/error/failure.dart';
import 'tool_source.dart';

/// E1 只开放 Streamable HTTP；stdio 随原始进程桥单独实现。
enum McpTransport { streamableHttp }

class McpServerProfile {
  McpServerProfile({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.definitionRevision,
    required this.createdAt,
    required this.updatedAt,
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
  final String endpoint;
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
  McpTransport get transport => McpTransport.streamableHttp;

  void validate() {
    final uri = Uri.tryParse(endpoint);
    if (name.trim().isEmpty || name.length > 100) {
      throw const OperationFailure('MCP 服务名称应为 1–100 个字符');
    }
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery) {
      throw const OperationFailure('请填写不含凭据、查询参数或片段的 HTTP(S) 地址');
    }
    if (connectTimeoutSeconds < 1 ||
        connectTimeoutSeconds > 120 ||
        callTimeoutSeconds < 1 ||
        callTimeoutSeconds > 300) {
      throw const OperationFailure('连接超时应为 1–120 秒，调用超时应为 1–300 秒');
    }
  }

  McpServerProfile copyWith({
    String? name,
    String? endpoint,
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'transport': transport.name,
    'endpoint': endpoint,
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

  factory McpServerProfile.fromJson(Map<String, dynamic> json) {
    if (json['transport'] != McpTransport.streamableHttp.name) {
      throw const FormatException('Unsupported MCP transport');
    }
    return McpServerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      endpoint: json['endpoint'] as String,
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
