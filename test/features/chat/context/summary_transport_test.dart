import 'dart:convert';

import 'package:phase/data/models/profile_model.dart';
import 'package:phase/features/tools/tool.dart';

import '../../tools/tool_loop_harness.dart';

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/context_summary.dart';
import 'package:phase/data/repositories/agent_context_repository.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';

void main() {
  for (final headers in [false, true]) {
    test('自动摘要真实连接停止：${headers ? '空闲 SSE' : '等待响应'}，保存取消且无后续聊天', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final ready = Completer<void>();
      final disconnected = Completer<void>();
      Socket? socket;
      StreamSubscription<List<int>>? events;
      var requests = 0;
      final listener = server.listen((request) async {
        await request.drain<void>();
        requests++;
        if (requests < 3) {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          final body = requests == 1 ? 'old ' * 1900 : 'recent ' * 320;
          request.response.write(
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': body},
                },
              ],
            })}\n\n'
            'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n',
          );
          await request.response.close();
          return;
        }
        if (headers) {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.headers.chunkedTransferEncoding = false;
          request.response.persistentConnection = false;
        }
        socket = await request.response.detachSocket(writeHeaders: headers);
        events = socket!.listen(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            if (disconnected.isCompleted) return;
            if (error is SocketException) {
              disconnected.complete();
            } else {
              disconnected.completeError(error, stackTrace);
            }
          },
          onDone: () {
            if (!disconnected.isCompleted) disconnected.complete();
          },
        );
        if (headers) {
          socket!.write(
            'data: {"choices":[{"delta":{"content":"partial summary"}}]}\n\n',
          );
          await socket!.flush();
        }
        ready.complete();
      });
      final dio = Dio();
      final h = await ToolLoopHarness.create(
        registry: ToolRegistry([]),
        models: const [
          ProfileModel(
            id: 'model-a',
            contextWindow: 14000,
            maxOutputTokens: 1000,
          ),
        ],
        factory: (profile, key) => OpenAiCompletionsProvider(
          profile: profile.copyWith(
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
            requiresKey: false,
          ),
          apiKey: '',
          dio: dio,
        ),
      );
      await h.controller().send('约束：不要付费或重复外部动作');
      await h.controller().send('继续保留此要求');
      final sending = h.controller().send('继续');
      try {
        await ready.future.timeout(const Duration(seconds: 5));
        h.controller().stop();
        await sending.timeout(const Duration(seconds: 2));
        await disconnected.future.timeout(const Duration(seconds: 2));
        final summary = (await AgentContextRepository(
          h.database,
        ).list(h.conversationId()!)).single;
        expect(summary.status, SummaryStatus.cancelled);
        expect(
          (await (await h.runs()).getById(summary.runId))!.status,
          RunStatus.stopped,
        );
        expect(requests, 3);
      } finally {
        h.controller().stop();
        await sending.timeout(const Duration(seconds: 5));
        dio.close(force: true);
        await events?.cancel();
        socket?.destroy();
        await listener.cancel();
        await server.close(force: true);
      }
    });
  }
}
