import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:phase/data/datasources/local/app_database.dart';
import 'package:phase/data/models/skill_installation.dart';
import 'package:phase/data/repositories/skill_repository.dart';
import 'package:phase/features/skills/skill_package.dart';
import 'package:phase/features/tools/tool.dart';

const sampleSkill =
    '---\nname: 整理文档\ndescription: 将文档整理为摘要产物\n---\n'
    '读取文档中的实际内容，然后用 write_file 保存摘要。';

class SkillFixture {
  SkillFixture()
    : directory = Directory.systemTemp.createTempSync('phase_skills'),
      database = AppDatabase(NativeDatabase.memory()) {
    repository = SkillRepository(
      database,
      Directory(p.join(directory.path, 'installed')),
    );
  }
  final Directory directory;
  final AppDatabase database;
  late final SkillRepository repository;
  int _sequence = 0;
  Future<Directory> source({
    String text = sampleSkill,
    Map<String, List<int>> files = const {},
  }) async {
    final folder = Directory(p.join(directory.path, 'source-${_sequence++}'));
    await folder.create();
    await File(p.join(folder.path, 'SKILL.md')).writeAsString(text);
    for (final entry in files.entries) {
      final file = File(p.join(folder.path, entry.key));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value);
    }
    return folder;
  }

  Future<File> zip(Archive archive) async {
    final file = File(p.join(directory.path, 'package-${_sequence++}.zip'));
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file;
  }

  Future<PreparedSkill> prepare({
    String text = sampleSkill,
    Map<String, List<int>> files = const {},
  }) async => repository.packages.prepare(
    (await source(text: text, files: files)).path,
    zip: false,
    cancellation: RunCancellation(),
  );
  Future<SkillInstallation> install({
    String text = sampleSkill,
    Map<String, List<int>> files = const {},
    String? replaceId,
  }) async {
    final package = await prepare(text: text, files: files);
    try {
      return await repository.install(
        package,
        RunCancellation(),
        replaceId: replaceId,
      );
    } finally {
      await package.discard();
    }
  }

  Future<void> close() async {
    await database.close();
    await directory.delete(recursive: true);
  }
}
