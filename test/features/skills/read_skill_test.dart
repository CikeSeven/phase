import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/datasources/local/artifact_storage.dart';
import 'package:phase/data/models/tool_policy.dart';
import 'package:phase/data/models/assistant.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/features/skills/read_skill_tool.dart';
import 'package:phase/features/tools/tool.dart';

import 'skill_test_support.dart';

void main() {
  late SkillFixture fixture;
  setUp(() {
    fixture = SkillFixture();
  });
  tearDown(() => fixture.close());

  test('分页可无损重组 Unicode 和转义文本，包内资源按明确路径读取', () async {
    final content = '月🌙"\\\n' * 5000;
    final skill = await fixture.install(
      files: {'resources/long.txt': utf8.encode(content)},
    );
    var offset = 0;
    final result = StringBuffer();
    do {
      final page = await readSkillResource(
        skill.snapshot,
        'resources/long.txt',
        offset: offset,
        cancellation: RunCancellation(),
      );
      expect(utf8.encode(jsonEncode(page)).length, lessThanOrEqualTo(6 * 1024));
      result.write(page['content']);
      if (page['nextOffset'] == null) break;
      expect(page['nextOffset'] as int, greaterThan(offset));
      offset = page['nextOffset'] as int;
    } while (true);
    expect(result.toString(), content);
  });

  test('资源缺失、越界、二进制、修改和链接返回具体文件错误', () async {
    final skill = await fixture.install(
      files: {
        'resources/blob': [0, 255],
        'resources/file.txt': utf8.encode('原文'),
      },
    );
    for (final path in [
      '../SKILL.md',
      '/SKILL.md',
      'missing',
      'resources/blob',
    ]) {
      await expectLater(
        readSkillResource(
          skill.snapshot,
          path,
          cancellation: RunCancellation(),
        ),
        throwsA(isA<SkillFailure>()),
      );
    }
    final file = File('${skill.snapshot.installedPath}/resources/file.txt');
    await file.writeAsString('修改');
    await expectLater(
      readSkillResource(
        skill.snapshot,
        'resources/file.txt',
        cancellation: RunCancellation(),
      ),
      throwsA(
        isA<SkillFailure>().having((e) => e.code, 'code', 'resourceChanged'),
      ),
    );
    await file.delete();
    await expectLater(
      readSkillResource(
        skill.snapshot,
        'resources/file.txt',
        cancellation: RunCancellation(),
      ),
      throwsA(
        isA<SkillFailure>().having(
          (e) => e.userMessage,
          'message',
          contains('文件已不存在'),
        ),
      ),
    );
    await Link(file.path).create('${skill.snapshot.installedPath}/SKILL.md');
    await expectLater(
      readSkillResource(
        skill.snapshot,
        'resources/file.txt',
        cancellation: RunCancellation(),
      ),
      throwsA(isA<SkillFailure>().having((e) => e.code, 'code', 'invalidPath')),
    );
  });

  test('Skill 范围独立于读取工具权限，新增许可不扩大旧快照', () async {
    final first = await fixture.install(
      files: {'scripts/run.sh': utf8.encode('echo ready')},
    );
    final second = await fixture.install(
      text: sampleSkill.replaceAll('整理文档', '另一个 Skill'),
    );
    final assistants = AssistantRepository(fixture.database);
    var assistant = (await assistants.ensureDefault()).copyWith(
      skillIds: {first.id},
      toolPolicy: const ToolPolicyConfig(
        policies: {'read_skill': ToolPolicy.allow},
      ),
    );
    await assistants.save(assistant);
    final tool = ReadSkillTool(
      skills: [first.snapshot],
      repository: fixture.repository,
      assistants: assistants,
      assistantId: assistant.id,
    );
    final storage = ArtifactStorage(
      root: fixture.directory,
      loadAttachments: (_) async => [],
      saveAttachment: (_) async {},
    );
    final context = ToolContext(
      conversationId: 'c',
      runId: 'r',
      toolCallId: 't',
      storage: storage,
      attachments: [],
    );
    Future<ToolOutcome> read(String id, {String? path}) => tool.execute(
      {'skillId': id, 'relativePath': ?path},
      context,
      RunCancellation(),
    );
    expect((await read(first.id)).ok, isTrue);
    expect(
      (await read(first.id, path: 'scripts/run.sh')).content,
      contains('当前没有脚本执行环境'),
    );
    assistant = assistant.copyWith(skillIds: {first.id, second.id});
    await assistants.save(assistant);
    expect((await read(second.id)).errorCode, 'skillDenied');
    await assistants.save(assistant.copyWith(skillIds: {second.id}));
    expect((await read(first.id)).errorCode, 'skillDenied');
    await assistants.save(assistant);
    await fixture.repository.setEnabled(first.id, false);
    expect((await read(first.id)).errorCode, 'skillDisabled');
  });
}
