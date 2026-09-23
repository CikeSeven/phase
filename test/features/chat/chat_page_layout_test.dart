import 'dart:async';
import 'dart:io';

import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/core/theme/app_spacing.dart';
import 'package:phase/core/theme/app_motion.dart';
import 'package:phase/core/theme/app_radius.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/theme/frosted_surface.dart';
import 'package:phase/core/widgets/app_background.dart';
import 'package:phase/core/widgets/app_top_bar.dart';
import 'package:phase/core/widgets/app_dialog.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/datasources/local/model_catalog_cache.dart';
import 'package:phase/data/models/model_catalog.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/context_summary.dart';
import 'package:phase/data/models/model_request_record.dart';
import 'package:phase/data/models/token_usage.dart';
import 'package:phase/data/repositories/agent_context_repository.dart';
import 'package:phase/data/repositories/model_request_repository.dart';
import 'package:phase/features/chat/context/context_preview.dart';
import 'package:phase/data/models/attachment.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_message.dart';
import 'package:phase/data/models/message_part.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/conversation.dart';
import 'package:phase/data/models/model_selection.dart' as model;
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/models/tool_call_record.dart';
import 'package:phase/data/repositories/agent_run_repository.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/data/repositories/tool_call_repository.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/chat_page.dart';
import 'package:phase/features/chat/chat_send_button.dart';
import 'package:phase/features/chat/chat_transcript.dart';
import 'package:phase/features/chat/model_picker_sheet.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_secure_storage.dart';
import '../../support/memory_assistants.dart';

final _profile = ProviderProfile(
  id: 'profile',
  name: '长名称服务商配置用于验证模型入口不会挤压按钮',
  protocol: ApiProtocol.openaiCompletions,
  baseUrl: 'https://example.com/v1',
  defaultModel:
      'very-long-reasoning-model-name-2026-preview-with-extra-context',
  createdAt: DateTime(2026),
);

/// 内存版运行仓储：布局测试只走发送流程，运行状态与计数留在内存。
///
/// 真实仓储的行为由 repositories_test 与工具循环测试覆盖。
class _MemoryRequests implements ModelRequestRepository {
  @override
  Future<void> prepare(ModelRequestRecord record) async {}
  @override
  Future<void> start(String id, {Future<void> Function()? onStart}) async =>
      onStart?.call();
  @override
  Future<void> sample(
    String id,
    TokenUsage? usage,
    int revision, {
    String? responseModelId,
  }) async {}
  @override
  Future<List<ModelRequestRecord>> list(String id) async => [];
  @override
  Future<void> interruptPending({
    String? runId,
    String errorCode = 'interrupted',
  }) async {}
  @override
  Future<void> settle(
    String id, {
    required ModelRequestStatus status,
    required TokenUsage? usage,
    required int revision,
    bool usageComplete = false,
    String? responseModelId,
    String? errorCode,
    Future<void> Function()? persistResult,
  }) async => persistResult?.call();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemorySummaries implements AgentContextRepository {
  @override
  Future<List<ContextSummary>> list(String id) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryRuns implements AgentRunRepository {
  final runs = <String, AgentRun>{};

  @override
  Future<List<RecoveredRun>> recover({
    bool afterRestart = false,
    String? activeRunId,
  }) async => const [];

  @override
  Future<AgentRun> create(AgentRun run) async {
    runs[run.id] = run;
    return run;
  }

  @override
  Future<AgentRun> beginTurn(String runId) =>
      _update(runId, (run) => run.copyWith(turnCount: run.turnCount + 1));

  @override
  Future<AgentRun> countModelAttempt(String runId) => _update(
    runId,
    (run) => run.copyWith(modelAttemptCount: run.modelAttemptCount + 1),
  );

  @override
  Future<AgentRun> finishTurn(String runId, {String? currentMessageId}) =>
      _update(
        runId,
        (run) => run.copyWith(
          currentMessageId: currentMessageId,
          activeToolCallId: null,
        ),
      );

  @override
  Future<AgentRun> resume(String runId) => _update(
    runId,
    (run) => run.copyWith(status: RunStatus.running, clearActiveToolCall: true),
  );

  @override
  Future<AgentRun> awaitConfirmation(String runId, String toolCallId) =>
      _update(
        runId,
        (run) => run.copyWith(
          status: RunStatus.awaitingConfirmation,
          activeToolCallId: toolCallId,
        ),
      );

  @override
  Future<AgentRun> finish(
    String runId, {
    required RunStatus status,
    RunFinishReason? finishReason,
    String? currentMessageId,
  }) => _update(
    runId,
    (run) => run.copyWith(
      status: status,
      finishReason: finishReason,
      currentMessageId: currentMessageId,
      clearActiveToolCall: true,
      finishedAt: DateTime.now(),
    ),
  );

  Future<AgentRun> _update(
    String runId,
    AgentRun Function(AgentRun run) change,
  ) async {
    final updated = change(runs[runId]!);
    runs[runId] = updated;
    return updated;
  }

  /// 布局测试不涉及恢复、等待确认与结果核验。
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('布局测试不涉及运行仓储');
}

/// 布局测试的脚本里没有工具调用：工具记录通道用不到。
class _UnusedToolCalls implements ToolCallRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('布局测试不涉及工具记录');
}

/// 内存版会话仓储：布局测试只需要可控的会话与消息视图，
/// 不走真实数据库（其行为由 repositories_test 覆盖）。
class _MemoryConversations implements ConversationRepository {
  @override
  WorkspaceRepository get workspaces => throw UnimplementedError('布局测试不涉及工作区');
  @override
  Future<void> completeToolTurn({
    required String messageId,
    required String runId,
    required List<MessagePart> parts,
    required List<ToolCallRecord> calls,
    int? thinkingDurationMs,
  }) => updateMessage(
    messageId: messageId,
    parts: parts,
    status: MessageStatus.completed,
    thinkingDurationMs: thinkingDurationMs,
  );

  final items = <Conversation>[];
  final messages = <String, List<ChatMessage>>{};
  final _changes = StreamController<void>.broadcast(sync: true);
  Completer<void>? createGate;
  Failure? createFailure;
  Failure? deleteFailure;
  int createCalls = 0;
  int renameCalls = 0;
  int pinCalls = 0;
  int deleteCalls = 0;

  @override
  AttachmentStorage? get attachments => null;

  void seed(int count) {
    for (var index = 0; index < count; index++) {
      items.add(
        Conversation(
          id: 'seed-$index',
          title: index == 0 ? '旅行灵感' : '历史会话 $index',
          pinned: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026, 9, 9).subtract(Duration(minutes: index)),
        ),
      );
    }
  }

  List<Conversation> _snapshot() => [...items]
    ..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Stream<List<Conversation>> watchConversations() async* {
    yield _snapshot();
    await for (final _ in _changes.stream) {
      yield _snapshot();
    }
  }

  @override
  Stream<ConversationThread?> watchThread(String conversationId) async* {
    ChatMessage? current() => messages[conversationId]?.last;
    ConversationThread build() {
      final branch = [...?messages[conversationId]];
      final conversation = items.firstWhere(
        (item) => item.id == conversationId,
        orElse: () => Conversation(
          id: conversationId,
          title: '',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      return ConversationThread(
        conversation: conversation,
        messages: branch,
        branch: branch,
        currentMessageId: current()?.id,
      );
    }

    yield build();
    await for (final _ in _changes.stream) {
      yield build();
    }
  }

  @override
  Future<ConversationThread?> getThread(String conversationId) =>
      watchThread(conversationId).first;

  @override
  Future<Conversation> createConversation({
    String title = '新会话',
    String? assistantId,
    model.ModelSelection? modelSelectionOverride,
  }) async {
    createCalls++;
    await createGate?.future;
    if (createFailure case final failure?) throw failure;
    final conversation = Conversation(
      id: 'created-$createCalls',
      title: title,
      assistantId: assistantId,
      modelSelectionOverride: modelSelectionOverride,
      createdAt: DateTime(2026, 9, 9),
      updatedAt: DateTime(2026, 9, 9),
    );
    items.add(conversation);
    _notify();
    return conversation;
  }

  @override
  Future<void> updateConversation(Conversation conversation) async {
    final index = items.indexWhere((item) => item.id == conversation.id);
    if (index >= 0) items[index] = conversation;
    _notify();
  }

  @override
  Future<void> setModelSelection(
    String id,
    model.ModelSelection selection,
  ) async {
    final index = items.indexWhere((item) => item.id == id);
    items[index] = items[index].copyWith(modelSelectionOverride: selection);
    _notify();
  }

  @override
  Future<ChatMessage> appendMessage(
    ChatMessage message, {
    bool updateTitle = false,
  }) async {
    final stored = message.copyWith(
      parts: message.parts.isEmpty ? const [] : message.parts,
    );
    messages.putIfAbsent(message.conversationId, () => []).add(stored);
    final index = items.indexWhere((item) => item.id == message.conversationId);
    if (index >= 0) {
      items[index] = items[index].copyWith(
        currentMessageId: stored.id,
        title: updateTitle && stored.text.trim().isNotEmpty
            ? stored.text.trim()
            : items[index].title,
        updatedAt: message.createdAt,
      );
    }
    _notify();
    return stored;
  }

  @override
  Future<void> updateMessage({
    required String messageId,
    required List<MessagePart> parts,
    required MessageStatus status,
    int? thinkingDurationMs,
  }) async {
    for (final entries in messages.values) {
      final index = entries.indexWhere((message) => message.id == messageId);
      if (index < 0) continue;
      entries[index] = entries[index].copyWith(
        parts: parts,
        status: status,
        thinkingDurationMs: thinkingDurationMs,
      );
    }
    _notify();
  }

  @override
  Future<void> setCurrentMessage(
    String conversationId,
    String messageId,
  ) async {
    final index = items.indexWhere((item) => item.id == conversationId);
    if (index >= 0) {
      items[index] = items[index].copyWith(currentMessageId: messageId);
    }
    _notify();
  }

  @override
  Future<void> saveAttachment(Attachment attachment) async {}

  @override
  Future<void> updateAttachmentExtraction(
    String attachmentId, {
    String? extractedTextPath,
    String? error,
  }) async {}

  @override
  Future<Conversation> duplicateConversation(String id) async {
    final index = items.indexWhere((item) => item.id == id);
    final copy = items[index].copyWith(title: '${items[index].title}（副本）');
    items.add(copy);
    _notify();
    return copy;
  }

  @override
  Future<List<Attachment>> attachmentsFor(String conversationId) async =>
      const [];

  // 布局测试不涉及工具循环：装配上下文与结果回填由控制器测试覆盖。
  @override
  Future<Map<String, ToolCallRecord>> toolCallsByIds(
    Iterable<String> ids,
  ) async => const {};

  @override
  Future<ToolCallRecord> saveToolResult({
    required String toolCallId,
    required ChatMessage message,
  }) {
    throw UnimplementedError('布局测试不涉及工具结果回写');
  }

  @override
  Future<void> renameConversation(String id, String title) async {
    renameCalls++;
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) items[index] = items[index].copyWith(title: title);
    _notify();
  }

  @override
  Future<void> setPinned(String id, {required bool pinned}) async {
    pinCalls++;
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) items[index] = items[index].copyWith(pinned: pinned);
    _notify();
  }

  @override
  Future<void> deleteConversation(String id) async {
    deleteCalls++;
    if (deleteFailure case final failure?) throw failure;
    items.removeWhere((item) => item.id == id);
    messages.remove(id);
    _notify();
  }

  Future<void> close() => _changes.close();
}

class _MemoryKeys extends SecureKeyStorage {
  _MemoryKeys() : super(FakeSecureStorage());
}

class _StreamingAi implements AiProvider {
  final chunks = StreamController<ChatChunk>.broadcast();
  final requests = <ChatRequest>[];

  @override
  ApiProtocol get protocol => ApiProtocol.openaiCompletions;

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) {
    requests.add(request);
    return chunks.stream;
  }

  @override
  Future<List<ProfileModel>> listModels() async => const [];
}

class _Harness {
  const _Harness(this.repository, this.ai, this.container, this.router);

  final _MemoryConversations repository;
  final _StreamingAi ai;
  final ProviderContainer container;
  final GoRouter router;
}

void main() {
  Future<_Harness> pumpChat(
    WidgetTester tester, {
    Size size = const Size(360, 780),
    double scale = 1,
    bool dark = false,
    bool reducedEffects = true,
    bool configured = true,
    _MemoryConversations? repository,
    Stream<List<ProviderProfile>>? profiles,
    Map<String, Object> values = const {},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    SharedPreferences.setMockInitialValues(values);
    final preferences = await SharedPreferences.getInstance();
    final conversations = repository ?? _MemoryConversations();
    final ai = _StreamingAi();
    // 发送会创建 AgentRun：运行与工具记录也用内存仓储，本文件只验证界面流程。
    final tempDir = Directory.systemTemp.createTempSync('phase_chat_layout');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const ChatPage()),
        GoRoute(
          path: '/assistants',
          builder: (context, state) => const Scaffold(body: Text('助手入口')),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Scaffold(body: Text('设置入口')),
        ),
        GoRoute(
          path: '/settings/providers',
          builder: (context, state) => const Scaffold(body: Text('服务商配置入口')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          modelCatalogProvider.overrideWith((ref) async => ModelCatalog.empty),
          sharedPreferencesProvider.overrideWith((ref) => preferences),
          attachmentStorageProvider.overrideWith(
            (ref) =>
                AttachmentStorage(Directory(p.join(tempDir.path, 'files'))),
          ),
          conversationRepositoryProvider.overrideWith((ref) => conversations),
          agentRunRepositoryProvider.overrideWith((ref) => _MemoryRuns()),
          modelRequestRepositoryProvider.overrideWith(
            (ref) => _MemoryRequests(),
          ),
          agentContextRepositoryProvider.overrideWith(
            (ref) => _MemorySummaries(),
          ),
          contextPreviewProvider.overrideWith((ref, id) async => null),
          toolCallRepositoryProvider.overrideWith((ref) => _UnusedToolCalls()),
          assistantRepositoryProvider.overrideWith((ref) => MemoryAssistants()),
          providerProfilesProvider.overrideWith(
            (ref) => profiles ?? Stream.value(configured ? [_profile] : []),
          ),
          secureKeyStorageProvider.overrideWith((ref) => _MemoryKeys()),
          aiProviderFactoryProvider.overrideWith(
            (ref) =>
                (profile, apiKey) => ai,
          ),
        ],
        child: MaterialApp.router(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedEffects,
            ),
            child: AppMotionTheme(child: child!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatPage)),
    );
    addTearDown(() async {
      await ai.chunks.close();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await conversations.close();
    });
    return _Harness(conversations, ai, container, router);
  }

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byTooltip('打开会话列表'));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('会话菜单').first);
    await tester.pumpAndSettle();
  }

  Future<void> enterDraft(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const ValueKey('chat-message-input')),
      text,
    );
    await tester.pump();
  }

  testWidgets('侧栏在手指松开前连续跟随位移，反向拖动与取消均可回到关闭状态', (tester) async {
    await pumpChat(tester, repository: _MemoryConversations()..seed(12));
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    final drag = await tester.startGesture(const Offset(100, 300));
    await drag.moveBy(const Offset(24, 0));
    await tester.pump();
    await drag.moveBy(const Offset(64, 0));
    await tester.pump();
    final drawer = find.byType(Drawer);
    final firstRight = tester.getRect(drawer).right;
    expect(firstRight, greaterThan(20));
    expect(firstRight, lessThan(tester.getSize(drawer).width));
    await drag.moveBy(const Offset(55, 0));
    await tester.pump();
    expect(tester.getRect(drawer).right - firstRight, closeTo(55, 2));
    await drag.moveBy(const Offset(-90, 0));
    await tester.pump();
    expect(tester.getRect(drawer).right, lessThan(firstRight));
    await tester.pump(const Duration(milliseconds: 300));
    await drag.up();
    await tester.pumpAndSettle();
    expect(scaffold.isDrawerOpen, isFalse);

    final cancelled = await tester.startGesture(const Offset(100, 300));
    await cancelled.moveBy(const Offset(24, 0));
    await tester.pump();
    await cancelled.moveBy(const Offset(45, 0));
    await tester.pump();
    expect(tester.getRect(drawer).right, greaterThan(0));
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(scaffold.isDrawerOpen, isFalse);

    await openDrawer(tester);
    final closing = await tester.startGesture(const Offset(240, 650));
    await closing.moveBy(const Offset(-25, 0));
    await tester.pump();
    await closing.moveBy(const Offset(-200, 0));
    await tester.pump();
    expect(tester.getRect(drawer).right, lessThan(250));
    await closing.up();
    await tester.pumpAndSettle();
    expect(scaffold.isDrawerOpen, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('侧栏开关不再把焦点恢复到输入框，键盘保持收起', (tester) async {
    await pumpChat(tester, repository: _MemoryConversations()..seed(3));

    bool inputHasPrimaryFocus() {
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('chat-message-input')),
          matching: find.byType(EditableText),
        ),
      );
      return editable.focusNode.hasPrimaryFocus;
    }

    // 按钮打开 + 关闭按钮关闭
    await tester.tap(find.byKey(const ValueKey('chat-message-input')));
    await tester.pumpAndSettle();
    expect(inputHasPrimaryFocus(), isTrue);
    await openDrawer(tester);
    expect(inputHasPrimaryFocus(), isFalse);
    await tester.tap(find.byTooltip('关闭侧栏'));
    await tester.pumpAndSettle();
    expect(inputHasPrimaryFocus(), isFalse);
    expect(find.byType(Drawer), findsNothing);

    // 聚焦输入框后拖拽打开 + 点遮罩关闭
    await tester.tap(find.byKey(const ValueKey('chat-message-input')));
    await tester.pumpAndSettle();
    final drag = await tester.startGesture(const Offset(100, 300));
    await drag.moveBy(const Offset(260, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(inputHasPrimaryFocus(), isFalse);
    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(inputHasPrimaryFocus(), isFalse);

    // 搜索框聚焦后关闭再打开，输入框与搜索框都不抢焦点
    await openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('conversation-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭侧栏'));
    await tester.pumpAndSettle();
    expect(inputHasPrimaryFocus(), isFalse);
    await openDrawer(tester);
    expect(inputHasPrimaryFocus(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('侧栏打开时系统返回只关闭侧栏，不退出根页面', (tester) async {
    final harness = await pumpChat(
      tester,
      repository: _MemoryConversations()..seed(3),
    );
    await openDrawer(tester);
    expect(find.byType(Drawer), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(ChatPage), findsOneWidget);
    expect(
      harness.router.routerDelegate.currentConfiguration.uri.toString(),
      '/',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('侧栏进入设置后返回，侧栏保持打开且不抢焦点', (tester) async {
    await pumpChat(tester, repository: _MemoryConversations()..seed(3));
    await openDrawer(tester);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('设置入口'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('设置入口'), findsNothing);
    expect(find.byType(Drawer), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 侧栏仍处于打开状态，系统返回依然可以关闭它。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(ChatPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('紧凑会话行保留48触区，更多菜单对齐按钮而非会话左边', (tester) async {
    await pumpChat(tester, repository: _MemoryConversations()..seed(20));
    await openDrawer(tester);
    final row = find.byKey(const ValueKey('conversation-row-seed-0'));
    final button = find.byKey(const ValueKey('conversation-menu-seed-0'));
    expect(tester.getSize(row).height, inInclusiveRange(48, 60));
    expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(48));
    final buttonRect = tester.getRect(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final item = find.widgetWithText(MenuItemButton, '重命名');
    final menuItemRect = tester.getRect(item);
    expect(menuItemRect.left, greaterThan(tester.getRect(row).left + 80));
    expect(menuItemRect.right, lessThanOrEqualTo(buttonRect.right + 8));
    expect(menuItemRect.top, greaterThanOrEqualTo(buttonRect.bottom - 1));
    await tester.tapAt(const Offset(355, 680));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('旅行灵感'));
    await tester.pumpAndSettle();
    expect(tester.getRect(item).left, closeTo(menuItemRect.left, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('靠近侧栏底部的菜单向上避让，不偏到左侧或超出屏幕', (tester) async {
    await pumpChat(tester, repository: _MemoryConversations()..seed(30));
    await openDrawer(tester);
    final button = find.byKey(const ValueKey('conversation-menu-seed-6'));
    await Scrollable.ensureVisible(tester.element(button), alignment: 1);
    await tester.pumpAndSettle();
    final buttonRect = tester.getRect(button);
    expect(buttonRect.top, greaterThan(580));
    await tester.tap(button);
    await tester.pumpAndSettle();
    final first = tester.getRect(find.widgetWithText(MenuItemButton, '重命名'));
    final last = tester.getRect(find.widgetWithText(MenuItemButton, '删除'));
    expect(first.left, greaterThan(80));
    expect(first.right, lessThanOrEqualTo(buttonRect.right + 8));
    expect(first.top, greaterThanOrEqualTo(0));
    expect(last.bottom, lessThanOrEqualTo(780));
    expect(first.top, lessThan(buttonRect.top));
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('会话菜单 ${dark ? "深色" : "浅色"} 按压形变、反向开关与逐层返回', (tester) async {
      final host = await pumpChat(
        tester,
        dark: dark,
        reducedEffects: false,
        repository: _MemoryConversations()..seed(20),
      );
      await openDrawer(tester);
      final button = find.byKey(const ValueKey('conversation-menu-seed-0'));
      final row = find.byKey(const ValueKey('conversation-row-seed-0'));
      final item = find.widgetWithText(MenuItemButton, '重命名');
      await tester.longPress(row);
      await tester.pumpAndSettle();

      Material itemMaterial() => tester.widget<Material>(
        find.descendant(of: item, matching: find.byType(Material)).first,
      );
      expect(
        (itemMaterial().shape! as RoundedRectangleBorder).borderRadius,
        AppRadius.mediumAll,
      );
      final rect = tester.getRect(item);
      final press = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(AppMotion.effects);
      expect(tester.getRect(item), rect);
      expect(
        (itemMaterial().shape! as RoundedRectangleBorder).borderRadius,
        AppRadius.smallAll,
      );
      await press.cancel();
      await tester.pumpAndSettle();
      expect(host.repository.renameCalls, 0);

      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(item, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(item, findsNothing);
      expect(find.byType(Drawer), findsOneWidget);

      // 点击其他会话只关闭菜单，不能透传成切换会话。
      await tester.tap(button);
      await tester.pumpAndSettle();
      final active = host.container.read(activeConversationProvider);
      await tester.tapAt(
        tester.getTopLeft(
              find.byKey(const ValueKey('conversation-row-seed-1')),
            ) +
            const Offset(8, 8),
      );
      await tester.pumpAndSettle();
      expect(host.container.read(activeConversationProvider), active);
      expect(find.byType(Drawer), findsOneWidget);
      expect(item, findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 760), const Size(780, 360)]) {
    testWidgets('会话菜单 $size 两倍字号、减少动画下仍可取消与置顶', (tester) async {
      final host = await pumpChat(
        tester,
        size: size,
        scale: 2,
        repository: _MemoryConversations()..seed(20),
      );
      await openDrawer(tester);
      final button = find.byKey(const ValueKey('conversation-menu-seed-0'));
      await tester.scrollUntilVisible(
        button,
        100,
        scrollable: find
            .descendant(
              of: find.descendant(
                of: find.byType(Drawer),
                matching: find.byType(CustomScrollView),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      final anchor = tester.widget<MenuAnchor>(
        find.ancestor(of: button, matching: find.byType(MenuAnchor)),
      );
      expect(anchor.animated, isFalse);
      final item = find.widgetWithText(MenuItemButton, '重命名');
      expect(tester.getRect(item).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(item).right, lessThanOrEqualTo(size.width));
      expect(
        Theme.of(tester.element(item)).menuButtonTheme.style!.animationDuration,
        Duration.zero,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(host.repository.pinCalls, 0);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final pin = find.widgetWithText(MenuItemButton, '置顶');
      await tester.ensureVisible(pin);
      await tester.pumpAndSettle();
      await tester.tap(pin);
      await tester.pumpAndSettle();
      expect(host.repository.pinCalls, 1);
      expect(find.byType(MenuItemButton), findsNothing);
      expect(find.byType(Drawer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('输入栏和侧栏不再展示重复教程或标语', (tester) async {
    await pumpChat(tester);
    expect(find.text('支持多行输入'), findsNothing);
    expect(find.text('正在生成回复'), findsNothing);
    await openDrawer(tester);
    expect(find.text('留住灵感，继续每一次对话'), findsNothing);
    expect(find.text('暂无会话'), findsOneWidget);
  });

  for (final size in [const Size(320, 720), const Size(360, 780)]) {
    for (final scale in [1.3, 2.0]) {
      testWidgets('空态/长模型名 ${size.width}dp ${scale}x 与键盘布局', (tester) async {
        await pumpChat(tester, size: size, scale: scale, dark: scale == 2);
        expect(find.byType(AppBackground), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('向相月提问，或选择一个助手'), findsOneWidget);
        expect(find.text('选择助手'), findsOneWidget);
        final attach = find.byTooltip('附件');
        expect(attach, findsOneWidget);
        // 附件按钮在输入栏内，不挤压发送触区。
        expect(
          tester.getRect(attach).right,
          lessThanOrEqualTo(tester.getRect(find.byType(ChatSendButton)).left),
        );
        final sendIcon = find.byIcon(Symbols.arrow_upward);
        final attachIcon = find.byIcon(Symbols.attach_file);
        expect(tester.getSize(sendIcon), tester.getSize(attachIcon));
        expect(tester.getCenter(sendIcon).dy, tester.getCenter(attachIcon).dy);
        final sendSurface = find.descendant(
          of: find.byType(ChatSendButton),
          matching: find.byType(Material),
        );
        expect(tester.getSize(sendSurface), const Size.square(40));
        expect(
          tester.getSize(find.byType(ChatSendButton)),
          const Size.square(56),
        );
        // 助手行与模型行各有一个展开图标：模型行的那个在模型选择器内。
        final modelIcon = find.descendant(
          of: find.byKey(const ValueKey('chat-model-picker')),
          matching: find.byIcon(Symbols.expand_more),
        );
        expect(modelIcon, findsOneWidget);
        expect(find.byIcon(Symbols.expand_more), findsNWidgets(2));
        final modelText = tester.widget<Text>(
          find.text(_profile.defaultModel!),
        );
        expect(modelText.overflow, TextOverflow.ellipsis);
        expect(modelText.maxLines, 1);
        final modelParagraph = tester.renderObject<RenderParagraph>(
          find.text(_profile.defaultModel!),
        );
        expect(modelParagraph.didExceedMaxLines, isTrue);
        final iconRect = tester.getRect(modelIcon);
        expect(
          iconRect.left -
              tester.getRect(find.text(_profile.defaultModel!)).right,
          closeTo(4, 0.5),
        );
        expect(
          iconRect.right,
          lessThanOrEqualTo(tester.getRect(find.byTooltip('新会话')).left),
        );
        expect(
          tester.getSize(find.byTooltip('打开会话列表')).shortestSide,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);

        await tester.enterText(
          find.byKey(const ValueKey('chat-message-input')),
          '第一行内容\n第二行内容\n第三行内容\n第四行内容\n第五行内容\n第六行内容',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('chat-message-input')),
        );
        expect(field.maxLines, 5);
        expect(
          tester.getSize(find.byType(TextField)).width,
          greaterThan(size.width - 80),
        );
        expect(
          tester.getBottomRight(find.byTooltip('发送')).dy,
          lessThanOrEqualTo(size.height - 260),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('横屏与键盘下空态可滚动，选择助手是真实入口', (tester) async {
    await pumpChat(tester, size: const Size(680, 360), scale: 2);
    tester.view.viewInsets = const FakeViewPadding(bottom: 100);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('选择助手'));
    await tester.tap(find.text('选择助手'));
    await tester.pumpAndSettle();
    expect(find.text('助手入口'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 680.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('短模型名下拉图标紧邻文字 ${width}dp ${scale}x', (tester) async {
        const model = 'gpt-5';
        await pumpChat(
          tester,
          size: Size(width, 780),
          scale: scale,
          profiles: Stream.value([_profile.copyWith(defaultModel: model)]),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(model),
        );
        final textBox = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: model.length),
            )
            .single;
        final textRight = paragraph.localToGlobal(Offset(textBox.right, 0)).dx;
        final icon = find.descendant(
          of: find.byKey(const ValueKey('chat-model-picker')),
          matching: find.byIcon(Symbols.expand_more),
        );
        final iconRect = tester.getRect(icon);
        expect(iconRect.left - textRight, closeTo(4, 0.5));
        expect(
          iconRect.right,
          lessThanOrEqualTo(tester.getRect(find.byTooltip('新会话')).left),
        );
        // 顶栏默认高度下两行紧凑排布；字号放大时按文字实际高度增高。
        final toolbarHeight = tester.getSize(find.byType(AppTopBar)).height;
        expect(toolbarHeight, scale == 1 ? 64 : greaterThanOrEqualTo(64));
        final assistantRect = tester.getRect(
          find.byKey(const ValueKey('chat-assistant-picker')),
        );
        final modelRect = tester.getRect(
          find.byKey(const ValueKey('chat-model-picker')),
        );
        expect(modelRect.top - assistantRect.bottom, lessThanOrEqualTo(4));
        await tester.tap(icon);
        await tester.pumpAndSettle();
        expect(find.byType(ModelPickerSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('顶栏在模型名右侧用不同颜色显示当前推理等级', (tester) async {
    final profile = ProviderProfile(
      protocol: ApiProtocol.openaiCompletions,
      createdAt: DateTime(2026),
      id: 'profile',
      name: '服务商',
      baseUrl: 'https://example.com/v1',
      defaultModel: 'think-model',
      models: [ProfileModel(id: 'think-model', supportsReasoning: true)],
    );
    await pumpChat(
      tester,
      values: const {'last_reasoning_effort': 'high'},
      profiles: Stream.value([profile]),
    );
    final effort = find.byKey(const ValueKey('chat-reasoning-effort'));
    expect(effort, findsOneWidget);
    expect(tester.widget<Text>(effort).data, '高');
    // 跟在模型名右侧，颜色与模型名不同。
    final modelRect = tester.getRect(find.text('think-model'));
    expect(tester.getRect(effort).left, greaterThan(modelRect.right));
    final colors = Theme.of(tester.element(effort)).colorScheme;
    expect(tester.widget<Text>(effort).style?.color, isNot(colors.primary));
    expect(
      tester.widget<Text>(find.text('think-model')).style?.color,
      colors.primary,
    );
  });

  testWidgets('顶栏对关闭或不支持推理的模型不显示推理等级', (tester) async {
    // 支持推理但等级为关。
    await pumpChat(
      tester,
      profiles: Stream.value([
        ProviderProfile(
          protocol: ApiProtocol.openaiCompletions,
          createdAt: DateTime(2026),
          id: 'profile',
          name: '服务商',
          baseUrl: 'https://example.com/v1',
          defaultModel: 'think-model',
          models: [ProfileModel(id: 'think-model', supportsReasoning: true)],
        ),
      ]),
    );
    expect(find.text('think-model'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-reasoning-effort')), findsNothing);
  });

  testWidgets('输入栏悬浮于消息区之上，列表按其实测高度留白', (tester) async {
    final repository = _MemoryConversations()..seed(1);
    repository.messages['seed-0'] = [
      ChatMessage(
        id: 'saved',
        conversationId: 'seed-0',
        role: ChatRole.assistant,
        parts: const [TextPart(text: '已有的回复')],
        createdAt: DateTime(2026),
      ),
    ];
    await pumpChat(tester, repository: repository);
    await openDrawer(tester);
    await tester.tap(find.text('旅行灵感'));
    await tester.pumpAndSettle();

    // 消息区延伸到屏幕底部，发送按钮悬浮在消息区之上（而不是把消息区顶上去）。
    final transcriptRect = tester.getRect(find.byType(ChatTranscript));
    final sendCenter = tester.getCenter(find.byTooltip('发送'));
    expect(transcriptRect.contains(sendCenter), isTrue);

    // 列表底部留白 ≥ 输入栏高度，末条消息可以滚出遮挡区。
    final listView = tester.widget<ListView>(
      find.descendant(
        of: find.byType(ChatTranscript),
        matching: find.byType(ListView),
      ),
    );
    final composerHeight = tester
        .getRect(find.byKey(const ValueKey('chat-message-input')))
        .height;
    expect(
      listView.padding!.resolve(TextDirection.ltr).bottom,
      greaterThan(composerHeight + AppSpacing.m),
    );
  });

  testWidgets('切换会话后思考默认收起，已记录耗时仍显示且正文可读', (tester) async {
    final repository = _MemoryConversations()..seed(2);
    repository.messages['seed-0'] = [
      ChatMessage(
        id: 'reasoning-history',
        conversationId: 'seed-0',
        role: ChatRole.assistant,
        parts: const [
          ReasoningPart(publicText: '历史公开思考'),
          TextPart(text: '历史正文'),
        ],
        thinkingDurationMs: 1300,
        createdAt: DateTime(2026),
      ),
    ];
    await pumpChat(tester, repository: repository);
    await openDrawer(tester);
    await tester.tap(find.text('旅行灵感'));
    await tester.pumpAndSettle();
    expect(find.text('已思考 1.3 秒'), findsOneWidget);
    expect(find.text('历史公开思考'), findsNothing);
    await tester.tap(find.text('已思考 1.3 秒'));
    await tester.pumpAndSettle();
    expect(find.text('历史公开思考'), findsOneWidget);
    await openDrawer(tester);
    await tester.tap(find.text('历史会话 1'));
    await tester.pumpAndSettle();
    await openDrawer(tester);
    await tester.tap(find.text('旅行灵感'));
    await tester.pumpAndSettle();
    expect(find.text('已思考 1.3 秒'), findsOneWidget);
    expect(find.text('历史公开思考'), findsNothing);
    expect(find.text('历史正文', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('模型下拉入口保留 showModelPickerSheet 接口', (tester) async {
    await pumpChat(tester);
    await tester.tap(find.byKey(const ValueKey('chat-model-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(ModelPickerSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('透明玻璃上的正文、提示和配置入口保持对比度 ${dark ? '深色' : '浅色'}', (tester) async {
      await pumpChat(
        tester,
        dark: dark,
        reducedEffects: false,
        configured: false,
      );
      final input = find.byKey(const ValueKey('chat-message-input'));
      final field = tester.widget<TextField>(input);
      final surface = find.ancestor(
        of: input,
        matching: find.byType(FrostedSurface),
      );
      final material = tester.widget<Material>(
        find.descendant(of: surface, matching: find.byType(Material)).first,
      );
      final ink = tester.widget<Ink>(
        find.descendant(of: surface, matching: find.byType(Ink)).first,
      );
      final glaze = (ink.decoration! as BoxDecoration).gradient!;
      final configure = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '配置模型'),
      );
      final colors = Theme.of(tester.element(input)).colorScheme;
      for (final backdrop in [Colors.black, Colors.white, colors.surface]) {
        for (final highlight in glaze.colors) {
          final background = Color.alphaBlend(
            highlight,
            Color.alphaBlend(material.color!, backdrop),
          );
          for (final foreground in [
            field.style!.color!,
            field.decoration!.hintStyle!.color!,
            configure.style!.foregroundColor!.resolve({})!,
          ]) {
            final text = Color.alphaBlend(foreground, background);
            final a = text.computeLuminance();
            final b = background.computeLuminance();
            final contrast = a > b
                ? (a + 0.05) / (b + 0.05)
                : (b + 0.05) / (a + 0.05);
            expect(contrast, greaterThanOrEqualTo(4.5));
          }
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('玻璃输入栏保留草稿、附件取消与键盘焦点 ${dark ? '深色' : '浅色'}', (tester) async {
      await pumpChat(tester, dark: dark, reducedEffects: false);
      final input = find.byKey(const ValueKey('chat-message-input'));
      final surface = find.ancestor(
        of: input,
        matching: find.byType(FrostedSurface),
      );
      expect(
        find.descendant(of: surface, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );
      await enterDraft(tester, '透过月色，继续输入\n保留第二行');
      final editor = find.descendant(
        of: input,
        matching: find.byType(EditableText),
      );
      final editorState = tester.state(editor);
      final field = tester.widget<TextField>(input);
      final draft = field.controller!.text;

      await tester.tap(find.byTooltip('附件'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('attach-file')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(field.controller!.text, draft);
      expect(tester.state(editor), same(editorState));

      await tester.tap(input);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isTrue);
      expect(field.controller!.text, draft);
      expect(tester.state(editor), same(editorState));
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Symbols.arrow_upward),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('输入框聚焦时外边框变为主色，失焦后恢复 ${dark ? '深色' : '浅色'}', (tester) async {
      await pumpChat(tester, dark: dark);
      final input = find.byKey(const ValueKey('chat-message-input'));
      final surface = find.ancestor(
        of: input,
        matching: find.byType(FrostedSurface),
      );
      final colors = Theme.of(tester.element(input)).colorScheme;
      final size = tester.getSize(surface);
      Color borderColor() {
        final material = tester.widget<Material>(
          find.descendant(of: surface, matching: find.byType(Material)).first,
        );
        return (material.shape! as RoundedRectangleBorder).side.color;
      }

      final idleColor = borderColor();
      expect(idleColor, isNot(colors.primary));
      await tester.tap(input);
      await tester.pumpAndSettle();
      expect(borderColor(), colors.primary);
      expect(tester.getSize(surface), size);
      await tester.enterText(input, '保留草稿');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(borderColor(), colors.primary);

      await openDrawer(tester);
      expect(borderColor(), idleColor);
      await tester.tap(find.byTooltip('关闭侧栏'));
      await tester.pumpAndSettle();
      expect(borderColor(), idleColor);
      expect(tester.widget<TextField>(input).controller!.text, '保留草稿');
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(input);
      await tester.pumpAndSettle();
      expect(borderColor(), colors.primary);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('输入栏在短视口与键盘切换时保留编辑状态和焦点', (tester) async {
    await pumpChat(tester, scale: 2);
    await enterDraft(tester, '第一行\n第二行\n第三行');
    final editor = find.descendant(
      of: find.byKey(const ValueKey('chat-message-input')),
      matching: find.byType(EditableText),
    );
    final editorState = tester.state(editor);
    final focus = tester.widget<EditableText>(editor).focusNode;
    expect(focus.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 580);
    await tester.pumpAndSettle();
    expect(tester.state(editor), same(editorState));
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(tester.state(editor), same(editorState));
    expect(focus.hasFocus, isTrue);
    tester.testTextInput.enterText('保留焦点后继续输入');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '保留焦点后继续输入',
    );
  });

  testWidgets('未配置发送保留草稿并提供去配置导航', (tester) async {
    final harness = await pumpChat(tester, configured: false);
    await enterDraft(tester, '尚未发送的草稿');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('请先在设置中配置服务商与模型'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '尚未发送的草稿',
    );
    expect(harness.repository.createCalls, 0);
    await tester.tap(find.text('去配置'));
    await tester.pumpAndSettle();
    expect(find.text('服务商配置入口'), findsOneWidget);
  });

  testWidgets('模型读取错误显示失败而非无配置，发送不清草稿', (tester) async {
    final harness = await pumpChat(
      tester,
      profiles: Stream.error(const NetworkFailure('profile stream')),
    );
    expect(find.text('模型加载失败'), findsOneWidget);
    expect(find.text('检查配置'), findsOneWidget);
    await enterDraft(tester, '保留内容');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '保留内容',
    );
    expect(harness.repository.createCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('快速连点本地防重，接收后才清草稿，停止保留双通道和下一条草稿', (tester) async {
    final repository = _MemoryConversations()..createGate = Completer<void>();
    final harness = await pumpChat(tester, repository: repository);
    await enterDraft(tester, '第一条问题');
    await tester.tap(find.byTooltip('发送'));
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(repository.createCalls, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '第一条问题',
    );
    expect(harness.ai.requests, isEmpty);

    repository.createGate!.complete();
    await tester.pumpAndSettle();
    expect(harness.ai.requests, hasLength(1));
    expect(repository.messages.values.single, hasLength(2));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.byTooltip('停止生成'), findsOneWidget);
    expect(
      harness.container.read(chatControllerProvider).streamingParts,
      isEmpty,
    );
    await enterDraft(tester, '下一条草稿');
    harness.ai.chunks.add(
      const PartStart(partId: 'reasoning_0', kind: PartKind.reasoning),
    );
    harness.ai.chunks.add(
      const PartStart(partId: 'text_0', kind: PartKind.text),
    );
    harness.ai.chunks.add(
      const ReasoningDelta(partId: 'reasoning_0', text: '推演过程'),
    );
    harness.ai.chunks.add(const TextDelta(partId: 'text_0', text: '答案'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.text('答案', findRichText: true), findsOneWidget);
    expect(find.textContaining('已思考'), findsOneWidget);
    expect(find.text('推演过程'), findsNothing);

    await tester.tap(find.byTooltip('停止生成'));
    await tester.pumpAndSettle();
    // 取消现在先等待订阅释放，再保存终态；动画结束不等于异步 IO 已收尾。
    await tester.runAsync(() async {
      for (
        var i = 0;
        i < 100 && harness.container.read(chatControllerProvider).isGenerating;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(
      harness.container.read(chatControllerProvider).isGenerating,
      isFalse,
    );
    final reply = repository.messages.values.single.last;
    // 用户停止的运行按已取消记录，已收内容保留。
    expect(reply.status, MessageStatus.cancelled);
    expect(reply.text, '答案');
    expect(reply.parts.whereType<ReasoningPart>().single.publicText, '推演过程');
    expect(find.textContaining('已思考'), findsOneWidget);
    // 停止后保持默认收起，思考耗时已随消息落库。
    expect(find.text('推演过程'), findsNothing);
    expect(reply.thinkingDurationMs, isNotNull);
    await tester.tap(find.textContaining('已思考'));
    await tester.pumpAndSettle();
    expect(find.text('推演过程'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '下一条草稿',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('发送前落库失败显示 Failure 且保留草稿和重试能力', (tester) async {
    final repository = _MemoryConversations()
      ..createFailure = const NetworkFailure('create');
    await pumpChat(tester, repository: repository);
    await enterDraft(tester, '不能丢的草稿');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('网络连接失败，请检查网络后重试'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '不能丢的草稿',
    );
    expect(repository.items, isEmpty);
    await tester.drag(find.byType(SnackBar), const Offset(0, 100));
    await tester.pumpAndSettle();
    repository.createFailure = null;
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(repository.createCalls, 2);
    expect(find.byTooltip('停止生成'), findsOneWidget);
    await tester.tap(find.byTooltip('停止生成'));
    await tester.pumpAndSettle();
  });

  testWidgets('侧栏搜索惰性列表，重命名取消/保存/置顶/删除都调用真实动作', (tester) async {
    final repository = _MemoryConversations()..seed(80);
    repository.messages['seed-0'] = [
      ChatMessage(
        id: 'saved',
        conversationId: 'seed-0',
        role: ChatRole.assistant,
        parts: const [TextPart(text: '已有的旅行建议')],
        createdAt: DateTime(2026),
      ),
    ];
    final harness = await pumpChat(tester, repository: repository);
    await openDrawer(tester);
    expect(find.byKey(const ValueKey('seed-79')), findsNothing);
    expect(find.text('设置'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('conversation-search')),
      '旅行',
    );
    await tester.pumpAndSettle();
    expect(find.text('旅行灵感'), findsOneWidget);
    expect(find.text('历史会话 1'), findsNothing);

    await openMenu(tester);
    // 导出入口与其它会话操作同在一个菜单里。
    expect(find.text('导出会话'), findsOneWidget);
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('conversation-name-input')),
      '不应保存',
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.renameCalls, 0);
    expect(repository.items.first.title, '旅行灵感');
    expect(tester.takeException(), isNull);

    await openMenu(tester);
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('conversation-name-input')),
      '新的旅行计划',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.renameCalls, 1);
    expect(find.text('新的旅行计划'), findsOneWidget);
    await openMenu(tester);
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();
    expect(repository.pinCalls, 1);
    expect(repository.items.first.pinned, isTrue);

    await tester.tap(find.text('新的旅行计划'));
    await tester.pumpAndSettle();
    expect(
      harness.container.read(activeConversationProvider).conversationId,
      'seed-0',
    );
    expect(find.text('已有的旅行建议', findRichText: true), findsOneWidget);
    await openDrawer(tester);
    await openMenu(tester);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    final deleteButton = find.widgetWithText(FilledButton, '删除');
    final colors = Theme.of(tester.element(deleteButton)).colorScheme;
    expect(
      tester
          .widget<FilledButton>(deleteButton)
          .style!
          .backgroundColor!
          .resolve({}),
      colors.error,
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 1);
    expect(repository.items.any((item) => item.id == 'seed-0'), isFalse);
    expect(repository.messages.containsKey('seed-0'), isFalse);
    expect(
      harness.container.read(activeConversationProvider).conversationId,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp 2x 键盘下重命名取消不提前销毁编辑 controller', (tester) async {
    final repository = _MemoryConversations()..seed(1);
    await pumpChat(
      tester,
      repository: repository,
      size: const Size(320, 720),
      scale: 2,
    );
    await openDrawer(tester);
    await tester.ensureVisible(find.byTooltip('会话菜单'));
    await openMenu(tester);
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('conversation-name-input')),
      '临时修改',
    );
    await tester.ensureVisible(find.text('取消'));
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(repository.renameCalls, 0);
    expect(find.byType(AppDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除失败保留当前会话并显示错误，设置往返保留侧栏', (tester) async {
    final repository = _MemoryConversations()..seed(1);
    final harness = await pumpChat(tester, repository: repository);
    await openDrawer(tester);
    await tester.tap(find.text('旅行灵感'));
    await tester.pumpAndSettle();
    await openDrawer(tester);
    repository.deleteFailure = const NetworkFailure('delete');
    await openMenu(tester);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(
      harness.container.read(activeConversationProvider).conversationId,
      'seed-0',
    );
    expect(repository.items, hasLength(1));
    expect(find.text('网络连接失败，请检查网络后重试'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('设置入口'), findsOneWidget);
    harness.router.pop();
    await tester.pumpAndSettle();
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    expect(scaffold.isDrawerOpen, isTrue);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
