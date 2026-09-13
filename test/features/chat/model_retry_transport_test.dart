import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/providers/openai_completions/openai_completions_provider.dart';

import '../tools/tool_loop_harness.dart';

void main() {
  for (final sendHeaders in [false, true]) {
    test('模型重试后的真实连接停止：${sendHeaders ? '空闲流' : '等待响应'}', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final ready = Completer<void>();
      final disconnected = Completer<void>();
      Socket? connection;
      StreamSubscription<List<int>>? socketEvents;
      var attempts = 0;
      final requests = server.listen((request) async {
        try {
          await request.drain<void>();
          if (++attempts == 1) {
            request.response.statusCode = 503;
            request.response.write('{"error":{"code":"server_error"}}');
            await request.response.close();
            return;
          }
          if (sendHeaders) {
            request.response.headers.contentType = ContentType(
              'text',
              'event-stream',
            );
            request.response.headers.chunkedTransferEncoding = false;
            request.response.persistentConnection = false;
          }
          connection = await request.response.detachSocket(
            writeHeaders: sendHeaders,
          );
          socketEvents = connection!.listen(
            (_) {},
            onDone: disconnected.complete,
          );
          if (sendHeaders) {
            connection!.write(
              'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n',
            );
            await connection!.flush();
          }
          ready.complete();
        } catch (error, stackTrace) {
          if (!ready.isCompleted) ready.completeError(error, stackTrace);
        }
      });
      final dio = Dio();
      final h = await ToolLoopHarness.create(
        factory: (profile, key) => OpenAiCompletionsProvider(
          profile: profile.copyWith(
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
            requiresKey: false,
          ),
          apiKey: '',
          dio: dio,
        ),
      );
      final sending = h.controller().send('test');
      try {
        await ready.future.timeout(const Duration(seconds: 5));
        if (sendHeaders) {
          await h.waitUntil(() => h.state().streamingParts.isNotEmpty);
        }
        h.controller().stop();
        await sending.timeout(const Duration(seconds: 2));
        await disconnected.future.timeout(const Duration(seconds: 2));
        expect(attempts, 2);
        final run = await h.latestRun();
        expect(run.status, RunStatus.stopped);
        expect(run.turnCount, 1);
        expect(run.modelAttemptCount, 2);
        final answer = (await h.branch()).last;
        expect(answer.status, MessageStatus.cancelled);
        expect(answer.text, sendHeaders ? 'partial' : '');
      } finally {
        h.controller().stop();
        await sending.timeout(const Duration(seconds: 5));
        dio.close(force: true);
        await socketEvents?.cancel();
        connection?.destroy();
        await requests.cancel();
        await server.close(force: true);
      }
    });
  }
}
