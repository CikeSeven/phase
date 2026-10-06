import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/tool_permission.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/tool_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rule = ToolPermissionRule(
  sourceKind: ToolSourceKind.builtIn,
  sourceId: 'builtIn',
  toolName: 'shell',
  policy: ToolPolicy.ask,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('规则序列化后真实偏好重开可读取，列表不可变', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = SettingsStorage(prefs);
    expect(storage.readToolPermissionRules(), isEmpty);
    await storage.writeToolPermissionRules([_rule]);
    final reopened = SettingsStorage(prefs).readToolPermissionRules();
    expect(reopened.single.toJson(), _rule.toJson());
    expect(() => reopened.clear(), throwsUnsupportedError);
    expect(
      prefs.getString('tool_permission_rules_v1'),
      jsonEncode([_rule.toJson()]),
    );
    await storage.writeToolPermissionRules([]);
    expect(SettingsStorage(prefs).readToolPermissionRules(), isEmpty);
  });

  for (final payload in [
    '{broken',
    '{}',
    '[null]',
    jsonEncode([
      {..._rule.toJson(), 'policy': 'invalid'},
    ]),
    jsonEncode([_rule.toJson(), _rule.toJson()]),
  ]) {
    test('非法或重复规则 fail closed: $payload', () async {
      SharedPreferences.setMockInitialValues({
        'tool_permission_rules_v1': payload,
      });
      final storage = SettingsStorage(await SharedPreferences.getInstance());
      expect(storage.readToolPermissionRules, throwsA(isA<StorageFailure>()));
      expect(storage.readToolPermissionRules, throwsA(isA<StorageFailure>()));
    });
  }

  test('偏好提前修改缓存时，执行器仍只读取已提交规则，失败可重试', () async {
    final prefs = _ControlledPreferences();
    final storage = SettingsStorage(prefs);
    await storage.writeToolPermissionRules([_rule]);
    final gate = Completer<bool>();
    prefs.pending = gate;
    final writing = storage.writeToolPermissionRules([
      _rule.withPolicy(ToolPolicy.allow),
    ]);
    expect(prefs.getString('tool_permission_rules_v1'), contains('allow'));
    expect(storage.readToolPermissionRules().single.policy, ToolPolicy.ask);
    await expectLater(
      storage.writeToolPermissionRules([]),
      throwsA(isA<OperationFailure>()),
    );
    gate.complete(false);
    await expectLater(writing, throwsA(isA<StorageFailure>()));
    expect(storage.readToolPermissionRules().single.policy, ToolPolicy.ask);
    prefs.pending = null;
    await storage.writeToolPermissionRules([_rule.withPolicy(ToolPolicy.deny)]);
    expect(storage.readToolPermissionRules().single.policy, ToolPolicy.deny);
  });

  test('偏好提交抛异常不发布新授权，并且不泄露异常内容', () async {
    final prefs = _ControlledPreferences();
    final storage = SettingsStorage(prefs);
    await storage.writeToolPermissionRules([_rule]);
    prefs.failure = StateError('private response');
    await expectLater(
      storage.writeToolPermissionRules([_rule.withPolicy(ToolPolicy.allow)]),
      throwsA(
        isA<StorageFailure>().having(
          (error) => error.userMessage,
          'message',
          isNot(contains('private response')),
        ),
      ),
    );
    expect(storage.readToolPermissionRules().single.policy, ToolPolicy.ask);
  });

  test('非法和重复写入不改变已提交规则', () async {
    final storage = SettingsStorage(_ControlledPreferences());
    await storage.writeToolPermissionRules([_rule]);
    await expectLater(
      storage.writeToolPermissionRules([_rule, _rule]),
      throwsA(isA<StorageFailure>()),
    );
    const invalid = ToolPermissionRule(
      sourceKind: ToolSourceKind.builtIn,
      sourceId: '',
      toolName: 'shell',
      policy: ToolPolicy.allow,
    );
    await expectLater(
      storage.writeToolPermissionRules([invalid]),
      throwsA(isA<StorageFailure>()),
    );
    expect(storage.readToolPermissionRules().single.policy, ToolPolicy.ask);
  });
}

class _ControlledPreferences implements SharedPreferences {
  final values = <String, String>{};
  Completer<bool>? pending;
  Object? failure;
  @override
  String? getString(String key) => values[key];
  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    if (failure case final error?) throw error;
    return pending == null ? true : await pending!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
