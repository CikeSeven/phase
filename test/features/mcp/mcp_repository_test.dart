import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/datasources/local/secure_key_storage.dart';
import 'package:phase/data/models/mcp_server_profile.dart';
import 'package:phase/data/repositories/mcp_server_repository.dart';

import '../../support/fake_secure_storage.dart';
import '../../support/test_database.dart';
import 'mcp_memory_transport.dart';

class _Keys extends FakeSecureStorage {
  bool failDelete = false;
  int reads = 0;
  @override
  Future<String?> read(String key) {
    reads++;
    return super.read(key);
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('delete failed');
    await super.delete(key);
  }
}

void main() {
  late AppDatabase db;
  late _Keys keys;
  late McpServerRepository repository;
  late McpServerProfile profile;
  setUp(() {
    final fixture = createTestDatabase(name: 'mcp');
    db = fixture.database;
    keys = _Keys();
    repository = McpServerRepository(db, SecureKeyStorage(keys));
    profile = McpMemoryTransport().profile(bearer: true);
    addTearDown(() async {
      await db.close();
      fixture.directory.deleteSync(recursive: true);
    });
  });

  test('凭据与敏感头只存安全引用，空值保留，免 Key 不读取旧值', () async {
    final saved = await repository.save(
      profile,
      bearer: 'old-secret',
      headers: {'X-Api-Key': 'header-secret'},
    );
    expect(await repository.readBearer(saved), 'old-secret');
    expect(await repository.readHeaders(saved), {'X-Api-Key': 'header-secret'});
    final row = await db.select(db.mcpServers).getSingle();
    expect(row.profileJson, isNot(contains('old-secret')));
    expect(row.profileJson, isNot(contains('header-secret')));
    final blank = await repository.save(saved.copyWith(name: '改名'), bearer: '');
    expect(blank.definitionRevision, saved.definitionRevision);
    expect(await repository.readBearer(blank), 'old-secret');
    final noKey = await repository.save(blank.copyWith(requiresBearer: false));
    final reads = keys.reads;
    expect(await repository.readBearer(noKey), isNull);
    expect(keys.reads, reads);
    expect(keys.values.values, contains('old-secret'));
  });

  test('编辑连接和轮换凭据不修改旧快照；新目录需要重新发现', () async {
    final first = await repository.save(profile, bearer: 'old-secret');
    final tool = mcpToolSnapshot(first, McpMemoryTransport().tool());
    await repository.saveCatalog(first, [tool], '2025-06-18');
    final saved = await repository.save(
      first.copyWith(endpoint: 'https://other.test/mcp'),
      bearer: 'new-secret',
    );
    expect(saved.definitionRevision, isNot(first.definitionRevision));
    expect(saved.credentialRef, isNot(first.credentialRef));
    expect(await repository.readBearer(first), 'old-secret');
    expect(await repository.readBearer(saved), 'new-secret');
    expect((await repository.get(saved.id))!.tools, isEmpty);
    await expectLater(
      repository.saveCatalog(first, [tool], '2025-06-18'),
      throwsA(isA<OperationFailure>()),
    );
    final roundtrip = McpServerProfile.fromJson(
      jsonDecode(jsonEncode(saved.toJson())),
    );
    expect(roundtrip.credentialRefs, hasLength(2));
  });

  test('删除凭据失败时保留禁用条目，可重试清理全部凭据版本', () async {
    final first = await repository.save(profile, bearer: 'first');
    await repository.save(
      first,
      bearer: 'second',
      headers: {'X-Token': 'header'},
    );
    keys.failDelete = true;
    await expectLater(
      repository.delete(profile.id),
      throwsA(isA<StorageFailure>()),
    );
    final pending = (await repository.get(profile.id))!.profile;
    expect(pending.enabled, isFalse);
    expect(pending.deleting, isTrue);
    keys.failDelete = false;
    await repository.delete(profile.id);
    expect(await repository.get(profile.id), isNull);
    expect(keys.values, isEmpty);
  });

  test('拒绝在 URL 和普通配置中写入鉴权，以及覆盖协议头', () async {
    for (final endpoint in [
      'https://user:secret@mcp.test',
      'https://mcp.test/?token=secret',
    ]) {
      await expectLater(
        repository.save(profile.copyWith(endpoint: endpoint)),
        throwsA(isA<OperationFailure>()),
      );
    }
    await expectLater(
      repository.save(profile, headers: {'Authorization': 'secret'}),
      throwsA(isA<OperationFailure>()),
    );
    expect(keys.values, isEmpty);
    expect(await repository.list(), isEmpty);
  });
}
