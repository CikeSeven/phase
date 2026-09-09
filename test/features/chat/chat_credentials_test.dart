import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/ai_model.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/model_selection.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Keys extends SecureKeyStorage {
  var reads = 0;
  final stored = 'retained-test-credential';

  @override
  Future<String?> readApiKey(String providerProfileId) async {
    reads++;
    return stored;
  }
}

class _Provider implements AiProvider {
  @override
  String get id => 'test-profile';

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities();

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) =>
      Stream.value(const ChatChunk(delta: '回复', done: true));

  @override
  Future<List<AiModel>> listModels() async => const [];

  @override
  Future<void> validateKey() async {}
}

void main() {
  for (final presetId in ['ollama', 'custom']) {
    test('$presetId 按预设决定使用凭证，免 Key 配置不读取或发送旧凭证', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final keys = _Keys();
      await ProviderProfileRepository(db, keys).saveProfile(
        id: 'test-profile',
        name: '测试配置',
        baseUrl: 'https://example.invalid/v1',
        presetId: presetId,
        defaultModel: 'test-model',
        models: const [ProfileModel(id: 'test-model')],
      );
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      String? passedKey;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => preferences),
          appDatabaseProvider.overrideWith((ref) => db),
          secureKeyStorageProvider.overrideWith((ref) => keys),
          aiProviderFactoryProvider.overrideWith(
            (ref) => (profile, key) {
              passedKey = key;
              return _Provider();
            },
          ),
        ],
      );
      final subscription = container.listen(chatControllerProvider, (_, _) {});
      final selectionSubscription = container.listen(
        modelSelectionProvider,
        (_, _) {},
      );
      try {
        await container.read(chatControllerProvider.notifier).send('你好');
        expect(passedKey, presetId == 'ollama' ? isEmpty : keys.stored);
        expect(keys.reads, presetId == 'ollama' ? 0 : 1);
        expect(keys.stored, 'retained-test-credential');
      } finally {
        selectionSubscription.close();
        subscription.close();
        container.dispose();
        await db.close();
      }
    });
  }
}
