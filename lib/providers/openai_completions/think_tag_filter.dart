/// 把正文流开头的 `<think>...</think>` 块拆到思考通道。
///
/// Ollama、vLLM 等网关把推理内容以 think 标签混在正文里返回。
/// 仅当流的首个非空内容以 `<think>` 开头时才进入解析（与主流客户端一致，
/// 正文里用户自己输入的 think 字样不受影响）；标签可横跨多个片段。
///
/// 适配器把协议解析出的正文增量依次交给 [push]，流末尾调用 [flush]，
/// 拆出的思考走 reasoning 通道，正文走 text 通道。
class ThinkTagSplitter {
  static const _openTag = '<think>';
  static const _closeTag = '</think>';

  var _decided = false; // 是否已判定流的开头
  var _thinking = false; // 是否处于 think 块内
  var _buffer = '';

  /// 处理一段正文增量，返回本次拆出的（正文, 思考）。
  ({String content, String reasoning}) push(String delta) {
    final content = StringBuffer();
    final reasoning = StringBuffer();
    _buffer += delta;

    while (_buffer.isNotEmpty) {
      if (!_decided) {
        // 半截开标签不足以判定时先攒着，等后续片段。
        if (_buffer.length < _openTag.length && _openTag.startsWith(_buffer)) {
          break;
        }
        _decided = true;
        if (_buffer.startsWith(_openTag)) {
          _thinking = true;
          _buffer = _buffer.substring(_openTag.length);
          continue;
        }
        content.write(_buffer);
        _buffer = '';
        break;
      }
      if (_thinking) {
        final closeIndex = _buffer.indexOf(_closeTag);
        if (closeIndex >= 0) {
          reasoning.write(_buffer.substring(0, closeIndex));
          _buffer = _buffer.substring(closeIndex + _closeTag.length);
          _thinking = false;
          continue;
        }
        // 末尾可能是半截闭标签，留下次再判定。
        final keep = _suffixPrefixOverlap(_buffer, _closeTag);
        reasoning.write(_buffer.substring(0, _buffer.length - keep));
        _buffer = _buffer.substring(_buffer.length - keep);
        break;
      }
      content.write(_buffer);
      _buffer = '';
      break;
    }

    return (content: content.toString(), reasoning: reasoning.toString());
  }

  /// 流末尾收尾：半截开标签按正文处理；think 块未闭合（截断）则整块算思考。
  ({String content, String reasoning}) flush() {
    if (_buffer.isEmpty) return (content: '', reasoning: '');
    final text = _buffer;
    _buffer = '';
    return _thinking
        ? (content: '', reasoning: text)
        : (content: text, reasoning: '');
  }
}

/// text 的最长后缀、同时是 tag 的前缀的长度（用于识别半截标签）。
int _suffixPrefixOverlap(String text, String tag) {
  final max = text.length < tag.length ? text.length : tag.length - 1;
  for (var length = max; length > 0; length--) {
    if (tag.startsWith(text.substring(text.length - length))) {
      return length;
    }
  }
  return 0;
}
