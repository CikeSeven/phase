import 'dart:io';

import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/model_catalog_cache.dart';
import 'package:phase/data/models/model_catalog.dart';
import 'package:phase/data/datasources/local/attachment_storage.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/chat_chunk.dart';
import 'package:phase/data/models/chat_request.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/model_selection.dart';
import 'package:phase/providers/ai_provider.dart';
import 'package:phase/providers/provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_secure_storage.dart';

/// 记录读取次数、始终返回同一份凭证的密钥库。
class _Keys extends SecureKeyStorage {
  _Keys() : super(FakeSecureStorage({'api_key_test-profile': stored}));

  static const stored = 'retained-test-credential';
  var reads = 0;

  @override
  Future<String?> read(String providerProfileId) async {
    reads++;
    return stored;
  }
}

class _Provider implements AiProvider {
  @override
  ApiProtocol get protocol => ApiProtocol.openaiCompletions;

  @override
  Future<List<ProfileModel>> listModels() async => const [];

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) => Stream.fromIterable([
    const PartStart(partId: 'text_0', kind: PartKind.text),
    const TextDelta(partId: 'text_0', text: '回复'),
    const ResponseEnd(),
  ]);
}

void main() {
  for (final requiresKey in [true, false]) {
    test('requiresKey=$requiresKey 决定是否读取并发送凭证', () async {
      final tempDir = Directory.systemTemp.createTempSync('phase_credentials');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final db = openAppDatabase(
        path: p.join(tempDir.path, 'phase.sqlite'),
        hexKey: '0123456789abcdef' * 4,
      );
      final keys = _Keys();
      await ProviderProfileRepository(db, keys).createProfile(
        name: '测试配置',
        baseUrl: 'https://example.invalid/v1',
        protocol: ApiProtocol.openaiCompletions,
        requiresKey: requiresKey,
        defaultModel: 'test-model',
        models: const [ProfileModel(id: 'test-model')],
      );
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      String? passedKey;
      final container = ProviderContainer(
        overrides: [
          modelCatalogProvider.overrideWith((ref) async => ModelCatalog.empty),
          sharedPreferencesProvider.overrideWith((ref) => preferences),
          appDatabaseProvider.overrideWith((ref) => db),
          secureKeyStorageProvider.overrideWith((ref) => keys),
          workspaceRepositoryProvider.overrideWith(
            (ref) => WorkspaceRepository(db, tempDir),
          ),
          attachmentStorageProvider.overrideWith(
            (ref) => AttachmentStorage(
              Directory(p.join(tempDir.path, 'attachments')),
            ),
          ),
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
        // 免 Key 配置不读取、也不发送任何旧凭据。
        expect(passedKey, requiresKey ? _Keys.stored : isEmpty);
        expect(keys.reads, requiresKey ? 1 : 0);
      } finally {
        selectionSubscription.close();
        subscription.close();
        container.dispose();
        await db.close();
      }
    });
  }
}
