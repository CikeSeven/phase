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

  McpServerProfile stdioProfile({McpStdioCommand? command}) => McpServerProfile(
    id: 'stdio-1',
    name: '本地样本',
    endpoint: '',
    transport: McpTransport.stdio,
    command:
        command ??
        const McpStdioCommand(
          executable: '/usr/bin/node',
          args: ['/workspace/server.js'],
          environment: {'DEBUG': '1'},
        ),
    definitionRevision: 'r1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('stdio 命令与敏感环境变量：JSON 只存引用，空映射清除', () async {
    final saved = await repository.save(
      stdioProfile(),
      environmentSecrets: {'API_TOKEN': 'stdio-secret'},
    );
    final row = await db.select(db.mcpServers).getSingle();
    expect(row.profileJson, isNot(contains('stdio-secret')));
    expect(saved.command?.environmentSecretRefs.keys, ['API_TOKEN']);
    expect(await repository.readEnvironmentSecrets(saved), {
      'API_TOKEN': 'stdio-secret',
    });
    final roundtrip = McpServerProfile.fromJson(
      jsonDecode(jsonEncode(saved.toJson())),
    );
    expect(roundtrip.transport, McpTransport.stdio);
    expect(roundtrip.command?.executable, '/usr/bin/node');
    expect(roundtrip.command?.cwd, '/workspace');
    final cleared = await repository.save(saved, environmentSecrets: const {});
    expect(cleared.command?.environmentSecretRefs, isEmpty);
    // 旧引用与请求头轮换语义一致：保留到服务删除时统一清理。
    await repository.delete(saved.id);
    expect(keys.values, isEmpty);
  });

  test('stdio 命令变化生成新修订并清空目录；切回 HTTP 丢弃命令', () async {
    final first = await repository.save(stdioProfile());
    final tool = mcpToolSnapshot(first, McpMemoryTransport().tool());
    await repository.saveCatalog(first, [tool], '2025-06-18');
    final edited = await repository.save(
      first.copyWith(
        command: first.command?.copyWith(args: ['/workspace/other.js']),
      ),
    );
    expect(edited.definitionRevision, isNot(first.definitionRevision));
    expect((await repository.get(edited.id))!.tools, isEmpty);
    final http = McpServerProfile(
      id: first.id,
      name: first.name,
      endpoint: 'https://mcp.test/mcp',
      definitionRevision: edited.definitionRevision,
      createdAt: first.createdAt,
      updatedAt: first.updatedAt,
    );
    final switched = await repository.save(http);
    expect(switched.transport, McpTransport.streamableHttp);
    expect(switched.command, isNull);
    final stored = (await repository.get(http.id))!.profile;
    expect(stored.command, isNull);
  });

  test('stdio 校验拒绝相对路径、非法环境名与同名双份变量', () async {
    await expectLater(
      repository.save(
        stdioProfile(command: const McpStdioCommand(executable: 'node')),
      ),
      throwsA(isA<OperationFailure>()),
    );
    await expectLater(
      repository.save(
        stdioProfile(
          command: const McpStdioCommand(
            executable: '/usr/bin/node',
            environment: {'1BAD': 'x'},
          ),
        ),
      ),
      throwsA(isA<OperationFailure>()),
    );
    await expectLater(
      repository.save(
        stdioProfile(),
        environmentSecrets: {'DEBUG': 'duplicate'},
      ),
      throwsA(isA<OperationFailure>()),
    );
    expect(keys.values, isEmpty);
    expect(await repository.list(), isEmpty);
  });
}
