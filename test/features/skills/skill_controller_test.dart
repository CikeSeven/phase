import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/data/repositories/skill_repository.dart';
import 'package:phase/features/skills/skill_controller.dart';
import 'package:phase/features/skills/skill_import_source.dart';
import 'package:phase/features/tools/tool.dart';

import 'skill_test_support.dart';

class DelayedSkillSource extends SkillImportSource {
  final ready = Completer<PickedSkill?>();
  int calls = 0;
  @override
  Future<PickedSkill?> pick(bool zip, RunCancellation cancellation) {
    calls++;
    return ready.future;
  }
}

void main() {
  test('导入可以取消、防重复，迟到目录副本被清理且不安装', () async {
    final fixture = SkillFixture();
    addTearDown(fixture.close);
    final source = DelayedSkillSource();
    final container = ProviderContainer(
      overrides: [
        skillRepositoryProvider.overrideWith((ref) => fixture.repository),
        skillImportSourceProvider.overrideWith((ref) => source),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      skillImportControllerProvider(null),
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(
      skillImportControllerProvider(null).notifier,
    );
    final picking = controller.pick(false);
    await Future<void>.delayed(Duration.zero);
    await controller.pick(false);
    controller.cancel();
    final folder = await fixture.source();
    source.ready.complete(
      PickedSkill(folder.path, false, 'source', temporary: true),
    );
    await picking;
    expect(source.calls, 1);
    expect(await fixture.repository.list(), isEmpty);
    expect(await folder.exists(), isFalse);
    expect(container.read(skillImportControllerProvider(null)).package, isNull);
  });

  test('预览退出清理 staging，损坏导入保留上次可安装预览', () async {
    final fixture = SkillFixture();
    addTearDown(fixture.close);
    final directory = await fixture.source();
    final source = DelayedSkillSource()
      ..ready.complete(PickedSkill(directory.path, false, 'source'));
    final container = ProviderContainer(
      overrides: [
        skillRepositoryProvider.overrideWith((ref) => fixture.repository),
        skillImportSourceProvider.overrideWith((ref) => source),
      ],
    );
    final subscription = container.listen(
      skillImportControllerProvider(null),
      (_, _) {},
    );
    final controller = container.read(
      skillImportControllerProvider(null).notifier,
    );
    await controller.pick(false);
    final preview = container
        .read(skillImportControllerProvider(null))
        .package!;
    await File('${directory.path}/SKILL.md').writeAsString('broken');
    await controller.pick(false);
    expect(
      container.read(skillImportControllerProvider(null)).package,
      same(preview),
    );
    expect(
      container.read(skillImportControllerProvider(null)).error,
      isNotNull,
    );
    subscription.close();
    container.dispose();
    for (var i = 0; i < 100 && await preview.directory.exists(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(await preview.directory.exists(), isFalse);
    expect(await fixture.repository.list(), isEmpty);
  });
}
