import 'dart:convert';

/// 消息内容块：消息按 Part 顺序承载正文、附件与工具引用。
///
/// 工具 Part 只保存 [ToolCallRecord] 的 id，参数和结果不在消息里复制
/// （见 product_and_technical_design.md 第五部分 §2.3）。
sealed class MessagePart {
  const MessagePart();

  /// 与 design 的 Part 名称一致，用于 JSON 与数据库往返。
  String get type;

  Map<String, dynamic> toJson();
}

/// 助手可见正文。
class TextPart extends MessagePart {
  const TextPart({required this.text, this.partId});

  final String? partId;
  final String text;

  @override
  String get type => 'text';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    if (partId != null) 'partId': partId,
    'text': text,
  };

  factory TextPart.fromJson(Map<String, dynamic> json) => TextPart(
    partId: json['partId'] as String?,
    text: json['text'] as String? ?? '',
  );
}

/// 接口实际公开的思考文本/摘要；签名与加密字段属于 [ProviderPart]。
class ReasoningPart extends MessagePart {
  const ReasoningPart({
    required this.publicText,
    this.partId,
    this.providerData,
  });

  final String? partId;

  /// 实际公开的思考文本。
  final String publicText;

  /// 该块需要随后续请求回传的协议状态。
  final Map<String, dynamic>? providerData;

  @override
  String get type => 'reasoning';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    if (partId != null) 'partId': partId,
    'publicText': publicText,
    if (providerData != null) 'providerData': providerData,
  };

  factory ReasoningPart.fromJson(Map<String, dynamic> json) => ReasoningPart(
    partId: json['partId'] as String?,
    publicText: json['publicText'] as String? ?? '',
    providerData: json['providerData'] as Map<String, dynamic>?,
  );
}

/// 图片输入，正文本体在 AttachmentStorage。
class ImagePart extends MessagePart {
  const ImagePart({required this.attachmentId});

  final String attachmentId;

  @override
  String get type => 'image';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'attachmentId': attachmentId};

  factory ImagePart.fromJson(Map<String, dynamic> json) =>
      ImagePart(attachmentId: json['attachmentId'] as String);
}

/// 文本类文档输入（PDF/DOCX 抽取结果随附件保存）。
class DocumentPart extends MessagePart {
  const DocumentPart({required this.attachmentId});

  final String attachmentId;

  @override
  String get type => 'document';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'attachmentId': attachmentId};

  factory DocumentPart.fromJson(Map<String, dynamic> json) =>
      DocumentPart(attachmentId: json['attachmentId'] as String);
}

/// 引用一次工具调用；参数与结果在 tool_calls 表。
///
/// [providerData] 保存随后续请求回传的协议状态（如 Google 的
/// thoughtSignature），由 Provider 解析并写入对应工具记录。
class ToolCallPart extends MessagePart {
  const ToolCallPart({required this.toolCallId, this.providerData});

  final String toolCallId;
  final Map<String, dynamic>? providerData;

  @override
  String get type => 'toolCall';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'toolCallId': toolCallId,
    if (providerData != null) 'providerData': providerData,
  };

  factory ToolCallPart.fromJson(Map<String, dynamic> json) => ToolCallPart(
    toolCallId: json['toolCallId'] as String,
    providerData: json['providerData'] as Map<String, dynamic>?,
  );
}

/// 引用一条工具结果消息对应的工具记录。
class ToolResultPart extends MessagePart {
  const ToolResultPart({required this.toolCallId});

  final String toolCallId;

  @override
  String get type => 'toolResult';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'toolResultId': toolCallId};

  factory ToolResultPart.fromJson(Map<String, dynamic> json) =>
      ToolResultPart(toolCallId: json['toolResultId'] as String);
}

/// 协议要求保存的不透明内容（服务端搜索块、签名等），不作为思考展示。
class ProviderPart extends MessagePart {
  const ProviderPart({
    required this.protocol,
    required this.modelId,
    required this.data,
  });

  final String protocol;
  final String modelId;
  final Map<String, dynamic> data;

  @override
  String get type => 'provider';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'protocol': protocol,
    'modelId': modelId,
    'data': data,
  };

  factory ProviderPart.fromJson(Map<String, dynamic> json) => ProviderPart(
    protocol: json['protocol'] as String,
    modelId: json['modelId'] as String? ?? '',
    data: json['data'] as Map<String, dynamic>? ?? const {},
  );
}

/// 解码消息的 parts_json 列。
///
/// 未定义的 Part 类型是明确的协议/数据错误，不静默丢弃（避免正文悄悄缺失）。
List<MessagePart> decodeMessageParts(Object? json) {
  if (json == null) return const [];
  if (json is! List) {
    throw FormatException('parts 不是列表：${json.runtimeType}');
  }
  return [
    for (final item in json)
      if (item is Map<String, dynamic>) _partFromJson(item),
  ];
}

MessagePart _partFromJson(Map<String, dynamic> json) {
  return switch (json['type']) {
    'text' => TextPart.fromJson(json),
    'reasoning' => ReasoningPart.fromJson(json),
    'image' => ImagePart.fromJson(json),
    'document' => DocumentPart.fromJson(json),
    'toolCall' => ToolCallPart.fromJson(json),
    'toolResult' => ToolResultPart.fromJson(json),
    'provider' => ProviderPart.fromJson(json),
    final unknown => throw FormatException('未定义的内容块类型：$unknown'),
  };
}

String encodeMessageParts(List<MessagePart> parts) {
  return jsonEncode([for (final part in parts) part.toJson()]);
}
