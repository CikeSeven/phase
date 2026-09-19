import 'dart:io';

import 'package:phase/data/repositories/workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/data/models/agent_run.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/skill_installation.dart';
import 'package:phase/data/repositories/agent_run_repository.dart';
import 'package:phase/data/repositories/assistant_repository.dart';
import 'package:phase/data/repositories/conversation_repository.dart';
import 'package:phase/features/tools/tool.dart';

import 'skill_test_support.dart';

void main() {
  late SkillFixture fixture;
  setUp(() {
    fixture = SkillFixture();
  });
  tearDown(() => fixture.close());

  test('初版记录持久化，安装不自动加入助手，同名不能覆盖', () async {
    final assistants = AssistantRepository(fixture.database);
    final assistant = await assistants.ensureDefault();
    final skill = await fixture.install();
    expect((await assistants.getById(assistant.id))!.skillIds, isEmpty);
    expect(
      (await fixture.repository.get(skill.id))!.snapshot.revision,
      skill.snapshot.revision,
    );
    await expectLater(
      fixture.install(),
      throwsA(
        isA<SkillFailure>().having((e) => e.code, 'code', 'duplicateName'),
      ),
    );
    await assistants.save(assistant.copyWith(skillIds: {skill.id}));
    expect((await assistants.getById(assistant.id))!.skillIds, {skill.id});
  });

  test('更新固定运行版本，活跃引用释放后清理旧文件', () async {
    final first = await fixture.install();
    final lease = await fixture.repository.acquire({first.id});
    final second = await fixture.install(
      text: '$sampleSkill\n新版',
      replaceId: first.id,
    );
    await fixture.repository.collectGarbage();
    expect(lease.skills.single.revision, first.snapshot.revision);
    expect(second.snapshot.revision, isNot(first.snapshot.revision));
    expect(await Directory(first.snapshot.installedPath).exists(), isTrue);
    await lease.close();
    expect(await Directory(first.snapshot.installedPath).exists(), isFalse);
    expect(await Directory(second.snapshot.installedPath).exists(), isTrue);
  });

  test('持久化运行也保留旧版本，重建仓储不会丢失引用', () async {
    final first = await fixture.install();
    final conversation = await ConversationRepository(
      fixture.database,
      workspaces: WorkspaceRepository(fixture.database, fixture.directory),
    ).createConversation(title: '版本固定');
    final runs = AgentRunRepository(fixture.database);
    await runs.create(
      AgentRun(
        id: 'active',
        conversationId: conversation.id,
        inputMessageId: 'input',
        createdAt: DateTime.now(),
        configuration: RunConfiguration(
          connection: const RunConnection(
            profileId: 'p',
            protocol: 'openaiCompletions',
            baseUrl: 'https://example.test',
            requiresKey: false,
          ),
          modelSelection: const ModelSelection(profileId: 'p', modelId: 'm'),
          systemPrompt: '',
          skills: [first.snapshot],
        ),
      ),
    );
    await fixture.install(text: '$sampleSkill\n更新', replaceId: first.id);
    await fixture.repository.collectGarbage();
    expect(await Directory(first.snapshot.installedPath).exists(), isTrue);
    expect(
      (await runs.getById('active'))!.configuration.skills.single.revision,
      first.snapshot.revision,
    );
    await runs.finish(
      'active',
      status: RunStatus.stopped,
      finishReason: RunFinishReason.cancelled,
    );
    await fixture.repository.collectGarbage();
    expect(await Directory(first.snapshot.installedPath).exists(), isFalse);
  });

  test('取消更新保留旧安装与助手选择', () async {
    final first = await fixture.install();
    final assistants = AssistantRepository(fixture.database);
    final assistant = (await assistants.ensureDefault()).copyWith(
      skillIds: {first.id},
    );
    await assistants.save(assistant);
    final prepared = await fixture.prepare(text: '$sampleSkill\n新版本');
    await expectLater(
      fixture.repository.install(
        prepared,
        RunCancellation()..cancel(),
        replaceId: first.id,
      ),
      throwsA(isA<ToolCancelled>()),
    );
    await prepared.discard();
    expect(
      (await fixture.repository.get(first.id))!.snapshot.revision,
      first.snapshot.revision,
    );
    expect((await assistants.getById(assistant.id))!.skillIds, {first.id});
  });

  test('删除立即撤销选择，引用版本延迟清理；释放重复调用安全', () async {
    final first = await fixture.install();
    final assistants = AssistantRepository(fixture.database);
    final assistant = await assistants.ensureDefault();
    await assistants.save(assistant.copyWith(skillIds: {first.id}));
    final lease = await fixture.repository.acquire({first.id});
    await fixture.repository.delete(first.id);
    expect((await fixture.repository.get(first.id))!.deleting, isTrue);
    expect((await assistants.getById(assistant.id))!.skillIds, isEmpty);
    final disabled = await fixture.repository.acquire({first.id});
    expect(disabled.skills, isEmpty);
    await disabled.close();
    expect(await Directory(first.snapshot.installedPath).exists(), isTrue);
    await lease.close();
    await lease.close();
    expect(await fixture.repository.get(first.id), isNull);
    expect(await Directory(first.snapshot.installedPath).exists(), isFalse);
  });

  test('停用不改变助手选择，但不能加入新运行', () async {
    final skill = await fixture.install();
    await fixture.repository.setEnabled(skill.id, false);
    final lease = await fixture.repository.acquire({skill.id});
    expect(lease.skills, isEmpty);
    await lease.close();
    final view = await fixture.repository.acquire({
      skill.id,
    }, enabledOnly: false);
    expect(view.skills.single, isA<SkillSnapshot>());
    await view.close();
  });
  test('记录提交失败还原 staging，可重试且不破坏旧版本', () async {
    final first = await fixture.install();
    final package = await fixture.prepare(text: '$sampleSkill\n新版本');
    await fixture.database.customStatement(
      "CREATE TRIGGER reject_skill BEFORE INSERT ON skill_installations BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      fixture.repository.install(
        package,
        RunCancellation(),
        replaceId: first.id,
      ),
      throwsA(isA<StorageFailure>()),
    );
    expect(await package.directory.exists(), isTrue);
    expect(
      (await fixture.repository.get(first.id))!.snapshot.revision,
      first.snapshot.revision,
    );
    await fixture.database.customStatement('DROP TRIGGER reject_skill');
    final updated = await fixture.repository.install(
      package,
      RunCancellation(),
      replaceId: first.id,
    );
    expect(updated.snapshot.revision, package.revision);
  });

  test('重新导入相同内容修复损坏原件，启动清理中断副本', () async {
    final first = await fixture.install();
    await File('${first.snapshot.installedPath}/SKILL.md').writeAsString('损坏');
    final repaired = await fixture.install(replaceId: first.id);
    expect(repaired.snapshot.revision, first.snapshot.revision);
    expect(
      repaired.snapshot.installedPath,
      isNot(first.snapshot.installedPath),
    );
    expect(
      await File('${repaired.snapshot.installedPath}/SKILL.md').readAsString(),
      sampleSkill,
    );
    final partial = Directory(
      '${fixture.repository.packages.stagingRoot.path}/interrupted',
    );
    await partial.create(recursive: true);
    await fixture.repository.initialize();
    expect(await partial.exists(), isFalse);
    expect(await Directory(first.snapshot.installedPath).exists(), isFalse);
    expect(await Directory(repaired.snapshot.installedPath).exists(), isTrue);
  });
}
