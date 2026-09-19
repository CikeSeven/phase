import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/mcp_server_profile.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/mcp_server_repository.dart';
import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:phase/features/mcp/mcp_client.dart';
import 'package:phase/features/mcp/mcp_connections.dart';
import 'package:phase/features/mcp/mcp_stdio_client.dart';
import 'package:phase/features/tools/tool.dart';

import '../tools/tool_loop_harness.dart';
import '../workspace/local_process_driver.dart';
import '../../support/test_database.dart';

void main() {
  // 真实本机进程 + 固定 Python/Node 固件；缺少运行时的部分跳过。
  final nodeAvailable = File('/usr/bin/node').existsSync();
  if (!File('/usr/bin/python3').existsSync()) {
    test('stdio 固件需要 python3', () {}, skip: '缺少 /usr/bin/python3');
    return;
  }
  final fixtures = Directory(
    p.join(Directory.current.path, 'test', 'features', 'mcp'),
  );

  late ({AppDatabase database, Directory directory}) fixture;
  late LocalProcessDriver driver;
  late WorkspaceRepository repository;
  late Directory workspace;
  late File logFile;
  setUp(() async {
    fixture = createTestDatabase(name: 'mcp_stdio');
    driver = LocalProcessDriver();
    addTearDown(() async {
      await driver.dispose();
      await fixture.database.close();
      await fixture.directory.delete(recursive: true);
    });
    repository = WorkspaceRepository(fixture.database, fixture.directory);
    await repository.saveEnvironment(
      const RuntimeEnvironment(
        phase: EnvironmentPhase.ready,
        rootPath: 'fixture-root',
        revision: 'fixture',
      ),
    );
    workspace = Directory(
      p.join(fixture.directory.path, 'workspaces', 'mcp', 'stdio-1'),
    );
    await workspace.create(recursive: true);
    await File(p.join(fixtures.path, 'mcp_stdio_server.py'))
        .copy(p.join(workspace.path, 'server.py'));
    await File(p.join(fixtures.path, 'mcp_stdio_server.mjs'))
        .copy(p.join(workspace.path, 'server.mjs'));
    logFile = File(p.join(fixture.directory.path, 'stdio-log.txt'));
    if (await logFile.exists()) await logFile.delete();
  });

  McpServerProfile profile({
    String mode = 'basic',
    String marker = '',
    String runtime = 'python',
    int callTimeoutSeconds = 60,
    Map<String, String> extraEnvironment = const {},
  }) => McpServerProfile(
    id: 'stdio-1',
    name: '本地样本',
    endpoint: '',
    transport: McpTransport.stdio,
    command: McpStdioCommand(
      executable: runtime == 'node' ? '/usr/bin/node' : '/usr/bin/python3',
      args: [
        if (runtime == 'node')
          '/workspace/server.mjs'
        else
          '/workspace/server.py',
      ],
      environment: {
        'FIXTURE_MODE': mode,
        if (marker.isNotEmpty) 'FIXTURE_MARKER': marker,
        'FIXTURE_LOG': logFile.path,
        ...extraEnvironment,
      },
    ),
    definitionRevision: 'revision-1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    connectTimeoutSeconds: 10,
    callTimeoutSeconds: callTimeoutSeconds,
  );

  McpStdioClient build(McpServerProfile value) => McpStdioClient(
    value,
    driver: driver,
    rootfs: 'fixture-root',
    workspace: workspace.path,
    environment: value.command!.environment,
  );

  Future<void> waitUntil(bool Function() test) async {
    for (var i = 0; i < 500 && !test(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(test(), isTrue, reason: '条件在 5 秒内未满足');
  }

  test('握手、目录、调用与环境变量透传；关闭回收进程与任务', () async {
    final value = profile(marker: '标记-7a');
    final client = build(value);
    final tools = await client.connect(RunCancellation());
    expect(tools, hasLength(1));
    expect(tools.single.source.originalName, 'echo');
    expect(client.protocolVersion, '2025-06-18');
    final result = await client.callTool(
      tools.single,
      {'text': '月相记录'},
      RunCancellation(),
      beforeDispatch: () async {},
    );
    expect(result['content'][0]['text'], '月相记录标记-7a');
    expect(result['structuredContent']['echo'], '月相记录标记-7a');
    await client.close();
    expect(driver.active, isEmpty);
    expect(driver.owners, isEmpty);
  });

  test('分块 UTF-8 输出完整回填', () async {
    final client = build(profile(mode: 'chunked', marker: '月相'));
    final tools = await client.connect(RunCancellation());
    final result = await client.callTool(
      tools.single,
      {'text': '记录'},
      RunCancellation(),
      beforeDispatch: () async {},
    );
    final text = result['content'][0]['text'] as String;
    expect(text.length, ('记录月相'.length) * 200);
    expect(text, startsWith('记录月相'));
    await client.close();
  });

  test('RPC 错误映射为 rpcError', () async {
    final client = build(profile(mode: 'rpc_error'));
    final tools = await client.connect(RunCancellation());
    await expectLater(
      client.callTool(
        tools.single,
        {'text': 'x'},
        RunCancellation(),
        beforeDispatch: () async {},
      ),
      throwsA(
        isA<McpFailure>().having((error) => error.code, 'code', 'rpcError'),
      ),
    );
    await client.close();
  });

  test('超时明确失败且迟到响应被忽略', () async {
    final client = build(profile(mode: 'late', callTimeoutSeconds: 1));
    final tools = await client.connect(RunCancellation());
    await expectLater(
      client.callTool(
        tools.single,
        {'text': 'x'},
        RunCancellation(),
        beforeDispatch: () async {},
      ),
      throwsA(
        isA<McpFailure>().having((error) => error.code, 'code', 'timeout'),
      ),
    );
    // 迟到响应在 3 秒后到达；连接保持可用并正常关闭。
    await Future<void>.delayed(const Duration(milliseconds: 3500));
    expect(client.state, McpConnectionState.ready);
    await client.close();
    expect(driver.active, isEmpty);
  });

  test('停止发送协议取消通知且不重发调用', () async {
    final client = build(profile(mode: 'hang'));
    final tools = await client.connect(RunCancellation());
    final cancellation = RunCancellation();
    final pending = client.callTool(
      tools.single,
      {'text': 'x'},
      cancellation,
      beforeDispatch: () async {},
    );
    await waitUntil(
      () =>
          logFile.existsSync() &&
          logFile.readAsStringSync().contains('call-arrived'),
    );
    cancellation.cancel();
    await expectLater(pending, throwsA(isA<ToolCancelled>()));
    await waitUntil(
      () => logFile.readAsStringSync().contains(RegExp('cancelled:[0-9]+')),
    );
    await client.close();
  });

  test('进程退出时错误包含退出码与 stderr 尾部', () async {
    final client = build(profile(mode: 'exit_after_init'));
    await expectLater(
      client.connect(RunCancellation()),
      throwsA(
        isA<McpFailure>()
            .having((error) => error.code, 'code', 'processExit')
            .having((error) => error.userMessage, 'message', contains('boom'))
            .having((error) => error.userMessage, 'message', contains('2')),
      ),
    );
    expect(driver.active, isEmpty);
  });

  test('stdout 出现非 JSON 内容时连接明确失败', () async {
    final client = build(profile(mode: 'garbage'));
    final tools = await client.connect(RunCancellation());
    await expectLater(
      client.callTool(
        tools.single,
        {'text': 'x'},
        RunCancellation(),
        beforeDispatch: () async {},
      ),
      throwsA(
        isA<McpFailure>().having(
          (error) => error.code,
          'code',
          'invalidResponse',
        ),
      ),
    );
    expect(client.state, McpConnectionState.failed);
    await client.close();
    expect(driver.active, isEmpty);
  });

  test('list_changed 通知使旧目录快照失效', () async {
    final client = build(profile(mode: 'list_changed'));
    final tools = await client.connect(RunCancellation());
    // 第二次目录读取后服务端推送通知；定义未变但目录代次变化同样阻止调用。
    await expectLater(
      client.callTool(
        tools.single,
        {'text': 'x'},
        RunCancellation(),
        beforeDispatch: () async {},
      ),
      throwsA(
        isA<McpFailure>().having(
          (error) => error.code,
          'code',
          'definitionChanged',
        ),
      ),
    );
    expect(client.catalogGeneration, 1);
    await client.close();
  });

  test('服务器 ping 请求被应答后调用完成', () async {
    final client = build(profile(mode: 'ping', marker: '标记-p'));
    final tools = await client.connect(RunCancellation());
    final result = await client.callTool(
      tools.single,
      {'text': '正文'},
      RunCancellation(),
      beforeDispatch: () async {},
    );
    expect(result['content'][0]['text'], '应答后完成标记-p');
    await waitUntil(() => logFile.readAsStringSync().contains('ping-answered'));
    await client.close();
  });

  test('Node 运行时完成握手、调用与环境变量透传', () async {
    final client = build(profile(runtime: 'node', marker: '标记-node'));
    final tools = await client.connect(RunCancellation());
    final result = await client.callTool(
      tools.single,
      {'text': '月相'},
      RunCancellation(),
      beforeDispatch: () async {},
    );
    expect(result['content'][0]['text'], '月相标记-node');
    await client.close();
    expect(driver.active, isEmpty);
  }, skip: nodeAvailable ? false : '缺少 /usr/bin/node');

  test('Node 运行时映射 RPC 错误并应答服务器 ping', () async {
    final client = build(profile(runtime: 'node', mode: 'rpc_error'));
    final tools = await client.connect(RunCancellation());
    await expectLater(
      client.callTool(
        tools.single,
        {'text': 'x'},
        RunCancellation(),
        beforeDispatch: () async {},
      ),
      throwsA(
        isA<McpFailure>().having((error) => error.code, 'code', 'rpcError'),
      ),
    );
    await client.close();

    final pingClient = build(
      profile(runtime: 'node', mode: 'ping', marker: '标记-np'),
    );
    final pingTools = await pingClient.connect(RunCancellation());
    final result = await pingClient.callTool(
      pingTools.single,
      {'text': 'x'},
      RunCancellation(),
      beforeDispatch: () async {},
    );
    expect(result['content'][0]['text'], '应答后完成标记-np');
    await pingClient.close();
  }, skip: nodeAvailable ? false : '缺少 /usr/bin/node');

  test('环境未就绪时启动器明确失败', () async {
    await repository.saveEnvironment(
      const RuntimeEnvironment(phase: EnvironmentPhase.notInstalled),
    );
    final launcher = McpStdioLauncher(
      openDriver: () => driver,
      openRepository: () async => repository,
    );
    await expectLater(
      launcher.create(profile(), const {}),
      throwsA(
        isA<WorkspaceFailure>().having(
          (error) => error.code,
          'code',
          'environmentMissing',
        ),
      ),
    );
  });

  test('stdio 真实进程经运行时闭环：确认调用、落库与最终回答', () async {
    // 闭环只使用 harness 自己的数据库；提前关闭 fixture 库避免并行打开。
    await fixture.database.close();
    final value = profile(marker: '标记-loop');
    // 闭环用独立目录与连接工厂；日志仍在 fixture 目录内便于断言。
    final loopWorkspace = await Directory.systemTemp.createTemp(
      'phase_stdio_loop',
    );
    addTearDown(() => loopWorkspace.delete(recursive: true));
    await File(p.join(fixtures.path, 'mcp_stdio_server.py'))
        .copy(p.join(loopWorkspace.path, 'server.py'));
    final connections = McpConnections(
      createStdioClient: (profile, environment) async => McpStdioClient(
        profile,
        driver: driver,
        rootfs: 'fixture-root',
        workspace: loopWorkspace.path,
        environment: environment,
      ),
    );
    addTearDown(connections.close);
    final h = await ToolLoopHarness.create(
      mcpConnections: connections,
      models: const [ProfileModel(id: 'model-a', supportsTools: true)],
    );
    final mcpRepository = await h.container.read(
      mcpServerRepositoryProvider.future,
    );
    final saved = await mcpRepository.save(value);
    final discover = await connections.create(
      saved,
      environment: value.command!.environment,
    );
    final tools = await discover.connect(RunCancellation());
    await mcpRepository.saveCatalog(saved, tools, '2025-06-18');
    await connections.release(discover);
    final assistants = await h.container.read(
      assistantRepositoryProvider.future,
    );
    final assistant = await assistants.ensureDefault();
    await assistants.save(
      assistant.copyWith(
        toolPolicy: assistant.toolPolicy.withPolicy(
          tools.single.name,
          ToolPolicy.ask,
        ),
      ),
    );
    h.provider.turns.add(
      toolTurn(
        callId: 'call_1',
        toolName: tools.single.name,
        arguments: jsonEncode({'text': '月相'}),
      ),
    );
    h.provider.turns.add(textTurn('已读取回显结果'));
    var confirmed = 0;
    h.onConfirmation = (request) async {
      confirmed++;
      return ToolDecision.approved;
    };
    await h.controller().send('回显月相');
    expect(confirmed, 1);
    final record = (await h.recordsByCall()).values.single;
    expect(record.status, ToolCallStatus.succeeded);
    expect(record.source?.originalName, 'echo');
    expect(record.result, contains('月相标记-loop'));
    expect((await h.latestRun()).status, RunStatus.completed);
    expect((await h.branch()).last.text, '已读取回显结果');
    // 运行收口后连接释放，服务进程被回收。
    expect(driver.active, isEmpty);
  });
}
