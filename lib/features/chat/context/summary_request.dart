import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../../../data/models/chat_chunk.dart';
import '../../../../data/models/chat_message.dart';
import '../../../../data/models/chat_request.dart';
import '../../../../data/models/message_part.dart';
import '../../../../providers/ai_provider.dart';
import '../../tools/tool.dart';

class SummaryResponse {
  const SummaryResponse(this.text, this.usage, this.completed, this.cancelled);
  final String text;
  final TokenUsage? usage;
  final bool completed;
  final bool cancelled;
}

/// 独立的可取消请求；不会借用聊天缓冲区，也不会派发工具或进行自动重试。
Future<SummaryResponse> requestSummary(
  AiProvider provider,
  ChatRequest request,
  RunCancellation cancellation,
) async {
  final done = Completer<void>();
  final texts = <String, String>{};
  TokenUsage? usage;
  var complete = false;
  var failed = false;
  var accepting = true;
  StreamSubscription<ChatChunk>? subscription;
  void finish() {
    accepting = false;
    if (!done.isCompleted) done.complete();
  }

  unawaited(
    cancellation.whenCancelled.then((_) {
      if (!accepting) return;
      accepting = false;
      finish();
    }),
  );
  try {
    if (cancellation.isCancelled) {
      return const SummaryResponse('', null, false, true);
    }
    subscription = provider
        .streamChat(request)
        .listen(
          (event) {
            if (!accepting || cancellation.isCancelled) return;
            switch (event) {
              case PartStart(
                :final partId,
                kind: PartKind.text,
                :final initialContent,
              ):
                texts.putIfAbsent(partId, () => initialContent ?? '');
              case TextDelta(:final partId, :final text):
                texts[partId] = '${texts[partId] ?? ''}$text';
              case PartEnd(:final partId, part: TextPart(:final text)):
                texts[partId] = text;
              case UsageChunk(usage: final value):
                usage = value;
              case ResponseEnd(complete: final value):
                complete = value;
                finish();
              case ResponseError():
                failed = true;
                finish();
              case ToolCallDelta():
              case PartStart(kind: PartKind.toolCall):
              case PartEnd(part: ToolCallPart()):
                failed = true;
                finish();
              default:
                break;
            }
            // 对异常服务端忽略输出上限也有本地界限。
            if (texts.values.fold(0, (n, s) => n + s.length) > 16000) {
              failed = true;
              final preview = texts.values.join('\n').substring(0, 16000);
              texts
                ..clear()
                ..['truncated'] = '$preview\n[摘要输出超限]';
              finish();
            }
          },
          onError: (Object e, StackTrace st) {
            if (e is StorageFailure) {
              if (!done.isCompleted) done.completeError(e, st);
            } else {
              failed = true;
              finish();
            }
          },
          onDone: finish,
          cancelOnError: true,
        );
    await done.future;
  } on StorageFailure {
    rethrow;
  } catch (_) {
    failed = true;
  } finally {
    accepting = false;
    try {
      await subscription?.cancel();
    } catch (_) {
      failed = true;
    }
  }
  final text = texts.values.join('\n');
  return SummaryResponse(
    text,
    usage,
    complete && !failed && text.trim().isNotEmpty,
    cancellation.isCancelled,
  );
}
