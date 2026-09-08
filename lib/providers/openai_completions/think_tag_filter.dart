import '../../data/models/chat_chunk.dart';

/// 把 content 流开头的 `<think>...</think>` 块拆分为 reasoningDelta。
///
/// Ollama、vLLM 等网关把推理内容以 think 标签混在正文里返回。
/// 仅当流的首个非空内容以 `<think>` 开头时才进入解析（与主流客户端一致，
/// 正文里用户自己输入的 think 字样不受影响）；标签可横跨多个 chunk。
/// chunk 自带的 reasoningDelta（reasoning_content 字段）优先透传。
Stream<ChatChunk> splitThinkTags(Stream<ChatChunk> source) async* {
  const openTag = '<think>';
  const closeTag = '</think>';

  var decided = false; // 是否已判定流的开头
  var thinking = false; // 是否处于 think 块内
  var buffer = '';

  await for (final chunk in source) {
    var content = '';
    var reasoning = chunk.reasoningDelta ?? '';
    buffer += chunk.delta;

    while (buffer.isNotEmpty) {
      if (!decided) {
        // 半截开标签不足以判定时先攒着，等后续 chunk。
        if (buffer.length < openTag.length && openTag.startsWith(buffer)) {
          break;
        }
        decided = true;
        if (buffer.startsWith(openTag)) {
          thinking = true;
          buffer = buffer.substring(openTag.length);
          continue;
        }
        content += buffer;
        buffer = '';
        break;
      }
      if (thinking) {
        final closeIndex = buffer.indexOf(closeTag);
        if (closeIndex >= 0) {
          reasoning += buffer.substring(0, closeIndex);
          buffer = buffer.substring(closeIndex + closeTag.length);
          thinking = false;
          continue;
        }
        // 末尾可能是半截闭标签，留下次再判定。
        final keep = _suffixPrefixOverlap(buffer, closeTag);
        reasoning += buffer.substring(0, buffer.length - keep);
        buffer = buffer.substring(buffer.length - keep);
        break;
      }
      content += buffer;
      buffer = '';
      break;
    }

    if (content.isNotEmpty ||
        reasoning.isNotEmpty ||
        chunk.done ||
        chunk.usage != null) {
      yield ChatChunk(
        delta: content,
        reasoningDelta: reasoning.isEmpty ? null : reasoning,
        done: chunk.done,
        usage: chunk.usage,
      );
    }
  }

  // 收尾：半截开标签按正文处理；think 块未闭合（截断）则整块算 reasoning。
  if (buffer.isNotEmpty) {
    if (thinking) {
      yield ChatChunk(delta: '', reasoningDelta: buffer);
    } else {
      yield ChatChunk(delta: buffer);
    }
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
