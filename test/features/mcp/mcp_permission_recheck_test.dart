import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/features/chat/chat_providers.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/assistant.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/mcp_server_repository.dart';
import 'package:phase/features/mcp/mcp_client.dart';
import 'package:phase/features/mcp/mcp_connections.dart';
import 'package:phase/features/mcp/mcp_runtime.dart';
import 'package:phase/features/tools/tool.dart';

import '../tools/tool_loop_harness.dart';
import 'mcp_memory_transport.dart';

void main() {
  for (final stage in ['tools/list', 'sourceCheck']) {
    test('MCP 在 $stage 等待期间撤权，真正 tools/call 前必须再次判定', () async {
      final transport = McpMemoryTransport();
      final connections = McpConnections(
        createClient: (profile, bearer, headers) => McpHttpClient(
          profile,
          bearer: bearer,
          headers: headers,
          dio: Dio()..httpClientAdapter = transport,
        ),
      );
      addTearDown(connections.close);
      final h = await ToolLoopHarness.create(mcpConnections: connections);
      final repository = await h.container.read(
        mcpServerRepositoryProvider.future,
      );
      final profile = await repository.save(transport.profile());
      final discovery = await connections.create(
        profile,
        bearer: null,
        headers: {},
      );
      final tools = await discovery.connect(RunCancellation());
      await repository.saveCatalog(profile, tools, discovery.protocolVersion!);
      await connections.release(discovery);
      final assistants = await h.container.read(
        assistantRepositoryProvider.future,
      );
      final assistant = await assistants.ensureDefault();
      await assistants.save(assistant.copyWith(mcpServerIds: {profile.id}));
      var revoked = false;
      var listCount = 0;
      transport.onList = () async {
        if (++listCount == 2 && stage == 'tools/list') revoked = true;
      };
      final runtime = McpRunRuntime(
        run: AgentRun(
          id: 'run',
          conversationId: 'conversation',
          inputMessageId: 'input',
          assistantId: assistant.id,
          createdAt: DateTime.now(),
          configuration: RunConfiguration(
            connection: const RunConnection(
              profileId: 'p',
              protocol: 'openaiCompletions',
              baseUrl: 'https://example.com',
              requiresKey: false,
            ),
            modelSelection: const ModelSelection(profileId: 'p', modelId: 'm'),
            systemPrompt: '',
            toolSnapshots: tools,
            mcpServers: [profile],
          ),
        ),
        repository: repository,
        assistants: _CheckedAssistants(h.database, () async {
          if (stage == 'sourceCheck') revoked = true;
        }),
        connections: connections,
      );
      addTearDown(runtime.close);
      await expectLater(
        runtime.tools().single.execute(
          {},
          ToolContext(
            conversationId: 'conversation',
            runId: 'run',
            toolCallId: 'call',
            storage: await h.container.read(artifactStorageProvider.future),
            attachments: const [],
            confirmed: true,
            checkPermission: () async {
              if (revoked) throw const OperationFailure('fixture revoked');
            },
          ),
          RunCancellation(),
        ),
        throwsA(isA<OperationFailure>()),
      );
      expect(transport.calls, 0);
    });
  }
}

class _CheckedAssistants extends AssistantRepository {
  _CheckedAssistants(super.db, this.beforeReturn);
  final Future<void> Function() beforeReturn;
  @override
  Future<Assistant?> getById(String id) async {
    final assistant = await super.getById(id);
    await beforeReturn();
    return assistant;
  }
}
