import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/permission_mode.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/models/tool_permission.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/tool_source.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/tools/http_tool.dart';
import 'package:phase/features/tools/tool.dart';
import 'package:phase/features/tools/tool_executor.dart';
import 'package:phase/features/tools/tool_permission_policy.dart';
import 'package:phase/features/tools/tool_registry.dart';

import '../../support/fake_channel_driver.dart';
import 'tool_loop_harness.dart';

void main() {
  late ToolLoopHarness h;
  late FakeChannelDriver driver;
  late ToolRegistry registry;
  late RunCancellation cancellation;
  late ToolExecutor executor;
  final fetched = <HttpFetchRequest>[];
  final executed = <ExecutionRequest>[];
  final confirmations = <ToolConfirmationRequest>[];
  List<ToolPermissionRule> liveRules = [];
  Future<ToolDecision> Function(ToolConfirmationRequest)? decide;
  final prepared = <String>[];

  setUp(() async {
    fetched.clear();
    executed.clear();
    confirmations.clear();
    prepared.clear();
    liveRules = [];
    decide = null;
    driver = FakeChannelDriver()
      ..executeHandler = (request, _) async {
        executed.add(request);
        return ExecutionResult(
          toolCallId: request.toolCallId,
          status: ExecutionStatus.succeeded,
          result: {},
          artifacts: [],
        );
      };
    registry = buildBuiltInRegistry(
      platform: () => driver,
      httpFetch: (request) async {
        fetched.add(request);
        return HttpFetchResult(
          statusCode: 200,
          body: [111, 107],
          truncated: false,
        );
      },
    );
    h = await ToolLoopHarness.create(registry: registry);
    final conversation = await (await h.conversations()).createConversation();
    await (await h.runs()).create(
      AgentRun(
        id: 'run',
        conversationId: conversation.id,
        inputMessageId: 'input',
        createdAt: DateTime.now(),
        configuration: const RunConfiguration(
          connection: RunConnection(
            profileId: 'p',
            protocol: 'openaiCompletions',
            baseUrl: 'https://example.com',
            requiresKey: false,
          ),
          modelSelection: ModelSelection(profileId: 'p', modelId: 'm'),
          systemPrompt: '',
        ),
      ),
    );
    cancellation = RunCancellation();
    executor = ToolExecutor(
      registry: registry,
      toolCalls: await h.toolCalls(),
      currentRules: () => liveRules,
      onConfirmationRequired: (request) async {
        confirmations.add(request);
        return decide == null ? ToolDecision.approved : await decide!(request);
      },
      prepareChannel: (tool, args) async => prepared.add(tool.name),
    );
  });
  tearDown(() => driver.dispose());

  ToolPermissionRule rule(String name, ToolPolicy policy, {String? action}) =>
      ToolPermissionRule(
        sourceKind: ToolSourceKind.builtIn,
        sourceId: 'builtIn',
        toolName: name,
        action: action,
        policy: policy,
      );
  Future<ToolExecutionResult> call(
    String name, {
    Map<String, dynamic>? args,
    String? recordId,
    ToolExecutor? using,
    Set<String>? enabled,
  }) async {
    final conversationId = (await (await h.runs()).getById('run'))!
        .conversationId;
    final tool = registry.byName(name)!;
    return (using ?? executor).execute(
      ToolExecutionRequest(
        runId: 'run',
        assistantMessageId: 'message',
        toolName: name,
        arguments:
            args ??
            (name == 'http_request'
                ? {'url': 'https://example.com'}
                : {'packageName': 'fixture.app'}),
        channel: tool.channel,
        conversationId: conversationId,
        attachments: const [],
        storage: _UnusedStorage(),
        enabledTools: enabled ?? registry.tools.map((t) => t.name).toSet(),
        toolPolicies: policiesForMode(
          (using ?? executor).permissionMode,
          registry.tools,
        ),
        recordId: recordId,
      ),
      cancellation,
    );
  }

  test('基础 HTTP 需批准，参数校验在通道准备和确认前完成', () async {
    for (final args in [
      {'url': 'https://example.com', 'method': 'PATCH'},
      {'url': 'file:///private/data'},
      {'url': 'https://example.com', 'method': 1},
    ]) {
      expect(
        (await call('http_request', args: args)).record.errorCode,
        'invalidArguments',
      );
    }
    expect(confirmations, isEmpty);
    expect(prepared, isEmpty);
    expect(fetched, isEmpty);
    final result = await call('http_request');
    expect(fetched, hasLength(1));
    expect(confirmations, hasLength(1));
    expect(result.record.decision, ToolDecision.approved);
    expect(result.record.permission!.grantScope, PermissionGrantScope.once);
    expect(result.record.permission!.grantSourceCallId, result.record.id);
  });

  test('显式 allow 放行 GET，deny 拒绝 DELETE 且不准备通道', () async {
    liveRules = [
      rule('http_request', ToolPolicy.allow, action: 'GET'),
      rule('http_request', ToolPolicy.deny, action: 'DELETE'),
    ];
    executor = ToolExecutor(
      registry: registry,
      toolCalls: await h.toolCalls(),
      permissionRules: List.of(liveRules),
      currentRules: () => liveRules,
      prepareChannel: (tool, _) async => prepared.add(tool.name),
    );
    final allowed = await call('http_request');
    final denied = await call(
      'http_request',
      args: {'url': 'https://example.com', 'method': 'DELETE'},
    );
    expect(allowed.record.status, ToolCallStatus.succeeded);
    expect(allowed.record.permission!.ruleKey, liveRules.first.key);
    expect(denied.record.status, ToolCallStatus.rejected);
    expect(denied.record.permission!.policy, ToolPolicy.deny);
    expect(fetched, hasLength(1));
    expect(prepared, ['http_request']);
    expect(confirmations, isEmpty);
  });

  test('全权限仍遵守显式 ask/deny，不允许规则扩大运行工具范围', () async {
    final full = ToolExecutor(
      registry: registry,
      toolCalls: await h.toolCalls(),
      permissionMode: PermissionMode.fullAccess,
      currentRules: () => liveRules,
      onConfirmationRequired: (request) async {
        confirmations.add(request);
        return ToolDecision.approved;
      },
    );
    liveRules = [rule('http_request', ToolPolicy.ask)];
    expect(
      (await call('http_request', using: full)).record.decision,
      ToolDecision.approved,
    );
    liveRules = [rule('http_request', ToolPolicy.deny)];
    expect(
      (await call('http_request', using: full)).record.status,
      ToolCallStatus.rejected,
    );
    liveRules = [rule('http_request', ToolPolicy.allow)];
    expect(
      (await call('http_request', using: full, enabled: {})).record.status,
      ToolCallStatus.rejected,
    );
    expect(fetched, hasLength(1));
    expect(confirmations, hasLength(1));
  });

  for (final choice in [ToolDecision.approved, ToolDecision.approvedForRun]) {
    test('${choice.name} 按范围执行，本轮复用记录来源但不伪造用户决定', () async {
      decide = (_) async => choice;
      final first = await call('open_app');
      final second = await call('inspect_ui');
      expect(executed, hasLength(2));
      expect(confirmations, hasLength(choice == ToolDecision.approved ? 2 : 1));
      expect(first.record.decision, choice);
      expect(
        second.record.decision,
        choice == ToolDecision.approved ? choice : isNull,
      );
      expect(
        second.record.permission!.grantSourceCallId,
        choice == ToolDecision.approved ? second.record.id : first.record.id,
      );
      expect(
        second.record.permission!.grantScope,
        choice == ToolDecision.approved
            ? PermissionGrantScope.once
            : PermissionGrantScope.run,
      );
    });
  }

  test('显式每次确认不接受本轮批准，也不授予后续应用操作', () async {
    liveRules = [rule('open_app', ToolPolicy.ask)];
    decide = (_) async => ToolDecision.approvedForRun;
    final first = await call('open_app');
    expect(confirmations.single.applicationOperationsForRun, isFalse);
    expect(first.record.errorCode, 'invalidGrantScope');
    expect(executed, isEmpty);
    decide = (_) async => ToolDecision.approved;
    await call('inspect_ui');
    expect(confirmations, hasLength(2));
    expect(executed, hasLength(1));
  });

  test('规则变化和新驱动使本轮授权失效，必须重新批准', () async {
    decide = (_) async => ToolDecision.approvedForRun;
    await call('open_app');
    liveRules = [rule('read_file', ToolPolicy.ask)];
    await call('inspect_ui');
    expect(confirmations, hasLength(2));
    final restored = ToolExecutor(
      registry: registry,
      toolCalls: await h.toolCalls(),
      currentRules: () => liveRules,
      onConfirmationRequired: (request) async {
        confirmations.add(request);
        return ToolDecision.approved;
      },
    );
    await call('inspect_ui', using: restored);
    expect(confirmations, hasLength(3));
    executor.revokeGrants();
    await call('open_app');
    expect(confirmations, hasLength(4));
  });

  test('等待确认期间改为 deny，即使批准返回也不会派发', () async {
    decide = (_) async {
      liveRules = [rule('http_request', ToolPolicy.deny)];
      return ToolDecision.approved;
    };
    final result = await call('http_request');
    expect(result.record.status, ToolCallStatus.rejected);
    expect(result.record.errorCode, 'policyChanged');
    expect(fetched, isEmpty);
  });

  test('规则放宽只影响新运行，不放宽原运行的规则快照', () async {
    final fixed = [rule('http_request', ToolPolicy.ask)];
    liveRules = [rule('http_request', ToolPolicy.allow)];
    final strict = ToolExecutor(
      registry: registry,
      toolCalls: await h.toolCalls(),
      permissionRules: fixed,
      currentRules: () => liveRules,
      onConfirmationRequired: (request) async {
        confirmations.add(request);
        return ToolDecision.approved;
      },
    );
    await call('http_request', using: strict);
    expect(confirmations, hasLength(1));
  });

  test('异步来源复检期间撤权，返回后重新读取规则并拒绝', () async {
    liveRules = [rule('http_request', ToolPolicy.allow)];
    final entered = Completer<void>();
    final release = Completer<void>();
    final checked = ToolExecutor(
      registry: registry,
      toolCalls: await h.toolCalls(),
      currentRules: () => liveRules,
      currentPolicy: (_) async {
        entered.complete();
        await release.future;
        return ToolPolicy.allow;
      },
    );
    final result = call('http_request', using: checked);
    await entered.future;
    liveRules = [rule('http_request', ToolPolicy.deny)];
    release.complete();
    expect((await result).record.status, ToolCallStatus.rejected);
    expect(fetched, isEmpty);
  });

  for (final choice in [ToolDecision.rejected, ToolDecision.expired]) {
    test('${choice.name} 不派发也不授予本轮范围，后续动作重新询问', () async {
      decide = (_) async => choice;
      expect((await call('open_app')).record.status, ToolCallStatus.rejected);
      decide = (_) async => ToolDecision.approved;
      await call('inspect_ui');
      expect(confirmations, hasLength(2));
      expect(executed, hasLength(1));
    });
  }

  test('确认落库失败不签发授权；解除故障后下一调用重新确认', () async {
    await h.database.customStatement(
      "CREATE TRIGGER fail_decision BEFORE UPDATE OF decision ON tool_calls WHEN NEW.decision IS NOT NULL BEGIN SELECT RAISE(ABORT, 'fixture'); END",
    );
    decide = (_) async => ToolDecision.approvedForRun;
    await expectLater(call('open_app'), throwsA(isA<StorageFailure>()));
    expect(executed, isEmpty);
    await h.database.customStatement('DROP TRIGGER fail_decision');
    await call('inspect_ui');
    expect(confirmations, hasLength(2));
    expect(executed, hasLength(1));
  });

  test('规则读取失败 fail closed，未知错误不伪装成功', () async {
    final broken = ToolExecutor(
      registry: registry,
      toolCalls: await h.toolCalls(),
      currentRules: () => throw const StorageFailure('fixture'),
    );
    await expectLater(
      call('http_request', using: broken),
      throwsA(isA<StorageFailure>()),
    );
    expect(fetched, isEmpty);
  });

  test('批准的参数不可被确认回调篡改，实际执行与落库一致', () async {
    final mutable = {'url': 'https://example.com/original', 'method': 'POST'};
    decide = (request) async {
      expect(
        () => request.record.arguments['url'] = 'https://example.com/modified',
        throwsUnsupportedError,
      );
      mutable['url'] = 'https://example.com/modified';
      return ToolDecision.approved;
    };
    final result = await call('http_request', args: mutable);
    expect(fetched.single.uri.path, '/original');
    expect(result.record.arguments['url'], 'https://example.com/original');
  });

  test('等待确认取消后不派发，迟到批准不能恢复授权', () async {
    final entered = Completer<void>();
    final approval = Completer<ToolDecision>();
    decide = (_) {
      entered.complete();
      return approval.future;
    };
    final result = call('open_app');
    await entered.future;
    cancellation.cancel();
    expect((await result).record.status, ToolCallStatus.cancelled);
    approval.complete(ToolDecision.approvedForRun);
    expect(executed, isEmpty);
    cancellation = RunCancellation();
    decide = (_) async => ToolDecision.approved;
    await call('inspect_ui');
    expect(confirmations, hasLength(2));
  });
}

class _UnusedStorage implements ToolStorage {
  @override
  Future<List<Attachment>> attachments(String conversationId) async => [];
  @override
  String artifactsDirectory(String conversationId) => '/unused';
  @override
  Future<Attachment> registerArtifact({
    required String conversationId,
    required String path,
    required String name,
    String? sha256,
    String? extractedTextPath,
    String? extractionError,
  }) => throw StateError('Unused storage');
  @override
  Future<Attachment> registerBytes({
    required String conversationId,
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) => throw StateError('Unused storage');
}
