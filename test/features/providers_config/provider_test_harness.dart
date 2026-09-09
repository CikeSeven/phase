import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/models/ai_model.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/openai_compat.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/providers_config/provider_edit_page.dart';
import 'package:phase/features/providers_config/providers_page.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/provider_factory.dart';

class ProviderTestHarness {
  ProviderTestHarness({
    Stream<List<ProviderProfile>> Function()? profileStream,
  }) {
    repository = ProviderProfileRepository(database, keyStorage);
    container = ProviderContainer(
      overrides: [
        providerProfileRepositoryProvider.overrideWith((ref) => repository),
        aiProviderFactoryProvider.overrideWith(
          (ref) => (profile, apiKey) {
            requests.add((profile: profile, apiKey: apiKey));
            return provider;
          },
        ),
        if (profileStream != null)
          providerProfilesProvider.overrideWith((ref) => profileStream()),
      ],
    );
    router = GoRouter(
      initialLocation: '/settings/providers',
      routes: [
        GoRoute(
          path: '/settings/providers',
          pageBuilder: (_, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const ProvidersPage(),
          ),
          routes: [
            GoRoute(
              path: 'new',
              pageBuilder: (_, state) => MaterialPage<void>(
                key: state.pageKey,
                child: const ProviderEditPage(),
              ),
            ),
            GoRoute(
              path: ':id',
              pageBuilder: (_, state) => MaterialPage<void>(
                key: state.pageKey,
                child: ProviderEditPage(profileId: state.pathParameters['id']),
              ),
            ),
          ],
        ),
      ],
    );
  }

  final database = AppDatabase(NativeDatabase.memory());
  final keyStorage = MemoryKeyStorage();
  final provider = FakeAiProvider();
  final requests = <({ProviderProfile profile, String apiKey})>[];
  late final ProviderProfileRepository repository;
  late final ProviderContainer container;
  late final GoRouter router;

  Future<void> dispose() async {
    router.dispose();
    container.dispose();
    await database.close();
  }

  Future<void> seed(
    WidgetTester tester, {
    String id = 'p1',
    String name = '我的服务商',
    String baseUrl = 'https://example.com/v1',
    String presetId = 'custom',
    ApiProtocol protocol = ApiProtocol.openaiCompletions,
    List<ProfileModel> models = const [],
    String? defaultModel,
    OpenAiCompat? compatOverrides,
    String? apiKey,
  }) async {
    await tester.runAsync(() async {
      await repository.saveProfile(
        id: id,
        name: name,
        baseUrl: baseUrl,
        presetId: presetId,
        protocol: protocol,
        models: models,
        defaultModel: defaultModel,
        compatOverrides: compatOverrides,
      );
      if (apiKey != null) await repository.writeApiKey(id, apiKey);
    });
  }

  Future<void> pump(
    WidgetTester tester, {
    ThemeData? theme,
    Size size = const Size(360, 800),
    double scale = 1,
    double keyboard = 0,
    bool settle = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    setKeyboard(tester, keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    if (settle) await settleProviderUi(tester);
  }
}

class MemoryKeyStorage extends SecureKeyStorage {
  final keys = <String, String>{};
  Object? readError;
  Object? writeError;
  Completer<void>? writeGate;
  int writeCount = 0;
  int deleteCount = 0;

  @override
  Future<String?> readApiKey(String providerProfileId) async {
    if (readError case final error?) throw error;
    return keys[providerProfileId];
  }

  @override
  Future<void> writeApiKey(String providerProfileId, String apiKey) async {
    writeCount++;
    await writeGate?.future;
    if (writeError case final error?) throw error;
    keys[providerProfileId] = apiKey;
  }

  @override
  Future<void> deleteApiKey(String providerProfileId) async {
    deleteCount++;
    keys.remove(providerProfileId);
  }
}

class FakeAiProvider implements AiProvider {
  Future<List<AiModel>> Function() listModelsHandler = () async => const [];
  int listModelsCount = 0;

  @override
  String get id => 'fake';

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities();

  @override
  Future<List<AiModel>> listModels() async {
    listModelsCount++;
    return await listModelsHandler();
  }

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) =>
      throw StateError('配置页面不应调用生成接口');

  @override
  Future<void> validateKey() => throw StateError('使用模型列表接口测试');
}

Finder keyed(String value) => find.byKey(ValueKey(value), skipOffstage: false);
Finder get baseUrlField => find.widgetWithText(TextFormField, 'Base URL');

Future<void> settleProviderUi(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });
  await tester.pumpAndSettle();
}

Future<void> revealProviderControl(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final view = [
      keyed('preset-scroll'),
      keyed('provider-edit-scroll'),
      keyed('providers-scroll'),
    ].firstWhere((view) => view.evaluate().isNotEmpty);
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find
          .descendant(of: view, matching: find.byType(Scrollable))
          .first,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
}

Future<void> tapProviderControl(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
  Alignment alignment = Alignment.center,
}) async {
  await revealProviderControl(tester, finder);
  expect(finder.hitTestable(at: alignment), findsOneWidget);
  final rect = tester.getRect(finder);
  await tester.tapAt(rect.topLeft + alignment.alongSize(rect.size));
  if (settle) {
    await settleProviderUi(tester);
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> fillProviderField(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await revealProviderControl(tester, finder);
  await tester.enterText(finder, text);
  await settleProviderUi(tester);
}

Future<void> choosePreset(WidgetTester tester, String id) async {
  await tapProviderControl(tester, keyed('choose-provider-preset'));
  await fillProviderField(tester, keyed('preset-search'), id);
  await tapProviderControl(tester, keyed('preset-$id'));
}

Future<void> chooseProtocol(
  WidgetTester tester,
  ApiProtocol protocol, {
  bool pendingRequest = false,
}) async {
  await tapProviderControl(
    tester,
    keyed('choose-protocol'),
    settle: !pendingRequest,
  );
  if (pendingRequest) {
    // 获取中的进度动画让 pumpAndSettle 永不稳定，手动推完面板动画。
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tapProviderControl(
    tester,
    keyed('protocol-${protocol.name}'),
    settle: !pendingRequest,
  );
}

/// 当前表单上展示的协议标签文本。
String currentProtocolLabel(WidgetTester tester) =>
    tester.widget<Text>(keyed('protocol-label')).data!;

void setKeyboard(WidgetTester tester, double keyboard) {
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.view.padding = FakeViewPadding(
    top: 24,
    bottom: keyboard == 0 ? 24 : 0,
  );
}

Future<void> searchModels(WidgetTester tester, String query) async {
  await fillProviderField(tester, keyed('provider-model-search'), query);
}

Future<void> addModel(
  WidgetTester tester,
  String id, {
  bool toggleReasoning = false,
}) async {
  await tapProviderControl(tester, keyed('add-provider-model'));
  await fillProviderField(tester, keyed('new-model-id'), id);
  if (toggleReasoning) {
    await tapProviderControl(tester, keyed('new-model-reasoning'));
  }
  await tapProviderControl(tester, keyed('confirm-add-model'));
}
