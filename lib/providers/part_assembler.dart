import '../data/models/chat_chunk.dart';
import '../data/models/chat_message.dart';
import '../data/models/message_part.dart';

/// 事件出口：组装出的事件立即交给调用方。
typedef ChunkEmitter = void Function(ChatChunk chunk);

/// 分块组装器：四个适配器共用的 partId 分配与事件顺序（design 第五部分 §4.3）。
///
/// 适配器每解析出一个内容片段就调用对应方法；[key] 是协议内的块标识
/// （Anthropic 的 content block index、OpenAI 的 tool_calls index、
/// Responses 的 part 对象等），同一个 key 的增量落到同一个 partId。
/// partId 按各类块在本响应内首现的顺序编号：`text_0`、`reasoning_0`、`tool_0`。
///
/// 约定：
/// - 首个增量前发 [PartStart]；文本/思考块的 [PartEnd] 由协议块结束标记
///   （如 content_block_stop）或 [finish] 触发，工具调用一律在 [finish] 收口；
/// - 工具参数只追加到缓冲，不在这里解析 JSON（上层负责累积）；
/// - [PartStart.initialContent] 保持为 null：四个协议的块首内容都以增量事件给出，
///   上层只按增量累积，不引入第二条内容通道；
/// - [finish] 补齐未结束的块后发一次 [UsageChunk]（有 usage 时）与一次 [ResponseEnd]。
class PartAssembler {
  PartAssembler(this._emit);

  final ChunkEmitter _emit;

  /// (块类型, 协议块标识) → 块状态；partId 只在块创建时分配一次。
  final _blocks = <(PartKind, Object), _Block>{};
  final _order = <_Block>[];

  var _nextText = 0;
  var _nextReasoning = 0;
  var _nextTool = 0;
  var _visible = false;
  var _finished = false;

  /// 正文增量。
  void text(Object key, String delta) {
    if (delta.isEmpty) return;
    final block = _block(key, PartKind.text);
    _start(block);
    block.text.write(delta);
    block.hasText = true;
    _visible = true;
    _emit(TextDelta(partId: block.partId, text: delta));
  }

  /// 公开思考增量；[providerData] 为该块要随响应一起保存的协议状态（如签名）。
  ///
  /// 只有协议状态、没有公开文本的块（如 Anthropic 的 redacted thinking）也能成立：
  /// 不发增量事件，由 [PartEnd] 带上状态。
  void reasoning(
    Object key,
    String delta, {
    Map<String, dynamic>? providerData,
  }) {
    if (delta.isEmpty && providerData == null) return;
    final block = _block(key, PartKind.reasoning);
    _start(block);
    if (providerData != null) {
      block.providerData = {...?block.providerData, ...providerData};
    }
    if (delta.isEmpty) return;
    block.text.write(delta);
    block.hasText = true;
    _visible = true;
    _emit(ReasoningDelta(partId: block.partId, text: delta));
  }

  /// 工具调用增量：callId/toolName 取最后一次非空值（都随增量交给上层），
  /// 参数片段只追加到缓冲。
  void toolCall(
    Object key, {
    String? callId,
    String? toolName,
    String? argumentsFragment,
    Map<String, dynamic>? providerData,
  }) {
    if (callId == null &&
        toolName == null &&
        argumentsFragment == null &&
        providerData == null) {
      return;
    }
    final block = _block(key, PartKind.toolCall);
    _start(block);
    if (callId != null && callId.isNotEmpty) block.callId = callId;
    if (argumentsFragment != null) block.text.write(argumentsFragment);
    // 协议状态绑定到该调用块：回填时随工具调用一起交给执行器。
    if (providerData != null) {
      block.providerData = {...?block.providerData, ...providerData};
    }
    _visible = true;
    _emit(
      ToolCallDelta(
        partId: block.partId,
        callId: callId,
        toolName: toolName,
        argumentsFragment: argumentsFragment,
        providerData: providerData,
      ),
    );
  }

  /// 查询某个块已分配的 partId；块还没创建时为 null。
  ///
  /// 协议状态需要绑定到具体块时使用（如 Google 的 functionCall 签名）。
  String? partIdOf(PartKind kind, Object key) => _blocks[(kind, key)]?.partId;

  /// 关闭 [key] 上已开始的块（协议给出块结束标记时调用）。
  void close(Object key) {
    for (final kind in PartKind.values) {
      final block = _blocks[(kind, key)];
      if (block != null) _end(block);
    }
  }

  /// 响应收口：补齐未结束的块 → Usage → ResponseEnd（一次响应只发一次）。
  void finish({TokenUsage? usage}) {
    if (_finished) return;
    _finished = true;
    for (final block in _order) {
      _end(block);
    }
    if (usage != null) _emit(UsageChunk(usage: usage));
    _emit(ResponseEnd(hasVisibleContent: _visible));
  }

  _Block _block(Object key, PartKind kind) {
    return _blocks.putIfAbsent((kind, key), () {
      final block = _Block(switch (kind) {
        PartKind.text => 'text_${_nextText++}',
        PartKind.reasoning => 'reasoning_${_nextReasoning++}',
        PartKind.toolCall => 'tool_${_nextTool++}',
        PartKind.provider => throw UnsupportedError('组装器不产生 provider 块'),
      }, kind);
      _order.add(block);
      return block;
    });
  }

  void _start(_Block block) {
    if (block.started) return;
    block.started = true;
    _emit(PartStart(partId: block.partId, kind: block.kind));
  }

  void _end(_Block block) {
    if (!block.started || block.ended) return;
    // 空块不发 PartEnd：既没有内容也没有协议状态的块不进入消息。
    if (block.kind != PartKind.toolCall &&
        !block.hasText &&
        block.providerData == null) {
      return;
    }
    block.ended = true;
    _emit(PartEnd(partId: block.partId, part: _partOf(block)));
  }

  MessagePart _partOf(_Block block) => switch (block.kind) {
    PartKind.text => TextPart(
      partId: block.partId,
      text: block.text.toString(),
    ),
    PartKind.reasoning => ReasoningPart(
      partId: block.partId,
      publicText: block.text.toString(),
      providerData: block.providerData,
    ),
    // ToolCallPart 只引用调用；协议没有调用 id 时（Google）回落到 partId，
    // 保证上层仍能把增量累积结果与这个块对应起来。
    // 协议状态（如 thoughtSignature）随块保存，回填时交回协议层。
    PartKind.toolCall => ToolCallPart(
      toolCallId: block.callId ?? block.partId,
      providerData: block.providerData,
    ),
    PartKind.provider => throw UnsupportedError('组装器不产生 provider 块'),
  };
}

class _Block {
  _Block(this.partId, this.kind);

  final String partId;
  final PartKind kind;
  final text = StringBuffer();
  Map<String, dynamic>? providerData;
  String? callId;
  var started = false;
  var ended = false;
  var hasText = false;
}
