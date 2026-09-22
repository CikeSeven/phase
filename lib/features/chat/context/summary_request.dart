import '../../../data/models/token_usage.dart';

import 'dart:async';

import '../../../core/error/failure.dart';
import '../../../data/models/chat_chunk.dart';
import '../../../data/models/chat_request.dart';
import '../../../data/models/message_part.dart';
import '../../../providers/ai_provider.dart';
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
  RunCancellation cancellation, {
  Future<bool> Function()? onStart,
  Future<void> Function(
    String text,
    TokenUsage? usage,
    int revision,
    String? responseModel,
  )?
  onProgress,
}) async {
  final done = Completer<void>();
  final texts = <String, String>{};
  TokenUsage? usage;
  String? responseModel;
  var revision = 0;
  Timer? flushTimer;
  Future<void> pending = Future.value();
  StorageFailure? storageError;
  StackTrace? storageTrace;
  var complete = false;
  var failed = false;
  var accepting = true;
  StreamSubscription<ChatChunk>? subscription;
  void flush() {
    flushTimer?.cancel();
    flushTimer = null;
    final text = texts.values.join('\n');
    final snapshot = usage;
    final sample = revision;
    final model = responseModel;
    pending = pending.then((_) async {
      if (storageError != null) return;
      try {
        await onProgress?.call(text, snapshot, sample, model);
      } catch (e, st) {
        storageError = e is StorageFailure
            ? e
            : StorageFailure('保存摘要进度失败', cause: e);
        storageTrace = st;
        accepting = false;
        if (!done.isCompleted) done.complete();
      }
    });
  }

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
    if (onStart != null && !await onStart()) {
      return const SummaryResponse('', null, false, true);
    }
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
                revision++;
              case ResponseModel(:final modelId):
                responseModel = modelId;
                revision++;
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
            if (onProgress != null) {
              flushTimer ??= Timer(const Duration(milliseconds: 100), flush);
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
  } on StorageFailure catch (e, st) {
    storageError = e;
    storageTrace = st;
  } catch (_) {
    failed = true;
  } finally {
    accepting = false;
    flushTimer?.cancel();
    try {
      await subscription?.cancel();
    } catch (_) {
      failed = true;
    }
  }
  if (onProgress != null) {
    flush();
    await pending;
  }
  if (storageError case final error?) {
    Error.throwWithStackTrace(error, storageTrace!);
  }
  final text = texts.values.join('\n');
  return SummaryResponse(
    text,
    usage,
    complete && !failed && text.trim().isNotEmpty,
    cancellation.isCancelled,
  );
}
