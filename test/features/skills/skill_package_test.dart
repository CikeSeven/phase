import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/features/skills/skill_package.dart';
import 'package:phase/features/tools/tool.dart';

import 'skill_test_support.dart';

void main() {
  late SkillFixture fixture;
  setUp(() {
    fixture = SkillFixture();
  });
  tearDown(() => fixture.close());

  test('本地目录校验 YAML 多行说明、未知字段和脚本，不执行脚本', () async {
    final marker = File('${fixture.directory.path}/executed');
    final package = await fixture.prepare(
      text: '---\nname: 整理文档\ndescription: |\n  第一行\n  第二行\nallowed-tools: [shell]\n---\n指导',
      files: {'scripts/run.sh': utf8.encode('touch ${marker.path}')},
    );
    expect(package.description, '第一行\n第二行');
    expect(package.ignoredFields, ['allowed-tools']);
    expect(package.resources.keys, contains('scripts/run.sh'));
    expect(await marker.exists(), isFalse);
    expect(package.revision, hasLength(64));
  });

  for (final wrapped in [false, true]) {
    test('ZIP 导入与目录的摘要一致，包装目录 $wrapped', () async {
      final source = await fixture.prepare(
        files: {'resources/sample.txt': utf8.encode('月相')},
      );
      final prefix = wrapped ? 'document/' : '';
      final zip = await fixture.zip(
        Archive()
          ..add(ArchiveFile.string('${prefix}SKILL.md', sampleSkill))
          ..add(ArchiveFile.string('${prefix}resources/sample.txt', '月相')),
      );
      final prepared = await fixture.repository.packages.prepare(
        zip.path,
        zip: true,
        cancellation: RunCancellation(),
      );
      expect(prepared.revision, source.revision);
      expect(
        await File('${prepared.directory.path}/SKILL.md').readAsString(),
        sampleSkill,
      );
    });
  }

  for (final path in [
    '../escape',
    '/absolute',
    'a/../../escape',
    'a\\escape',
    'C:/escape',
    'a//b',
    'a/./b',
  ]) {
    test('ZIP 拒绝路径 $path，清理 staging', () async {
      final zip = await fixture.zip(
        Archive()
          ..add(ArchiveFile.string('SKILL.md', sampleSkill))
          ..add(ArchiveFile.string(path, 'bad')),
      );
      if (path.contains('\\')) {
        // 编码器规范化反斜杠；还原真实不安全文件名再验证导入器。
        final bytes = await zip.readAsBytes();
        final normalized = utf8.encode(path.replaceAll('\\', '/'));
        for (var i = 0; i <= bytes.length - normalized.length; i++) {
          if (List.generate(normalized.length, (j) => bytes[i + j]).join(',') ==
              normalized.join(',')) {
            bytes.setRange(i, i + normalized.length, utf8.encode(path));
          }
        }
        await zip.writeAsBytes(bytes);
      }
      await expectLater(
        fixture.repository.packages.prepare(
          zip.path,
          zip: true,
          cancellation: RunCancellation(),
        ),
        throwsA(isA<SkillFailure>()),
      );
      expect(
        await fixture.repository.packages.stagingRoot.list().toList(),
        isEmpty,
      );
    });
  }

  test('不跟随目录内链接', () async {
    final source = await fixture.source();
    await Link('${source.path}/external').create(fixture.directory.path);
    await expectLater(
      fixture.repository.packages.prepare(
        source.path,
        zip: false,
        cancellation: RunCancellation(),
      ),
      throwsA(
        isA<SkillFailure>().having((e) => e.code, 'code', 'linkUnsupported'),
      ),
    );
  });

  test('ZIP 链接在解压前拒绝', () async {
    final file = ArchiveFile.string('link', '../outside')..mode = 0xa1ff;
    final zip = await fixture.zip(
      Archive()
        ..add(ArchiveFile.string('SKILL.md', sampleSkill))
        ..add(file),
    );
    await expectLater(
      fixture.repository.packages.prepare(
        zip.path,
        zip: true,
        cancellation: RunCancellation(),
      ),
      throwsA(isA<SkillFailure>()),
    );
  });

  test('ZIP 重名项不能由解码器静默覆盖', () async {
    final zip = await fixture.zip(
      Archive()
        ..add(ArchiveFile.string('SKILL.md', sampleSkill))
        ..add(ArchiveFile.string('aaaa.txt', 'one'))
        ..add(ArchiveFile.string('bbbb.txt', 'two')),
    );
    final bytes = await zip.readAsBytes();
    final old = utf8.encode('bbbb.txt');
    for (var i = 0; i <= bytes.length - old.length; i++) {
      if (List.generate(old.length, (j) => bytes[i + j]).join(',') ==
          old.join(',')) {
        bytes.setRange(i, i + old.length, utf8.encode('aaaa.txt'));
      }
    }
    await zip.writeAsBytes(bytes);
    await expectLater(
      fixture.repository.packages.prepare(
        zip.path,
        zip: true,
        cancellation: RunCancellation(),
      ),
      throwsA(
        isA<SkillFailure>().having((e) => e.code, 'code', 'unsupportedZip'),
      ),
    );
  });

  test('ZIP 损坏内容的 CRC 不会被当作成功', () async {
    final zip = await fixture.zip(
      Archive()
        ..add(ArchiveFile.noCompress('SKILL.md', 1, utf8.encode(sampleSkill))),
    );
    final bytes = await zip.readAsBytes();
    final index = bytes.indexOf(45, 30);
    bytes[index] = 42;
    await zip.writeAsBytes(bytes);
    await expectLater(
      fixture.repository.packages.prepare(
        zip.path,
        zip: true,
        cancellation: RunCancellation(),
      ),
      throwsA(isA<SkillFailure>()),
    );
  });

  test('单文件超限与损坏 ZIP 都失败并清理', () async {
    final zip = await fixture.zip(
      Archive()
        ..add(ArchiveFile.string('SKILL.md', sampleSkill))
        ..add(
          ArchiveFile.bytes('large', List.filled(SkillLimits.fileBytes + 1, 0)),
        ),
    );
    await expectLater(
      fixture.repository.packages.prepare(
        zip.path,
        zip: true,
        cancellation: RunCancellation(),
      ),
      throwsA(
        isA<SkillFailure>().having((e) => e.code, 'code', 'packageTooLarge'),
      ),
    );
    await zip.writeAsString('broken');
    await expectLater(
      fixture.repository.packages.prepare(
        zip.path,
        zip: true,
        cancellation: RunCancellation(),
      ),
      throwsA(isA<SkillFailure>()),
    );
    expect(
      await fixture.repository.packages.stagingRoot.list().toList(),
      isEmpty,
    );
  });

  for (final text in [
    '无 frontmatter',
    '---\nname: a\n---\n缺少说明',
    '---\nname: [a]\ndescription: b\n---\n错误类型',
    '---\nname: a\nname: b\ndescription: c\n---\n重复键',
  ]) {
    test('无效 frontmatter：$text', () async {
      await expectLater(
        fixture.prepare(text: text),
        throwsA(isA<SkillFailure>()),
      );
    });
  }

  test('已经取消的导入不落半成品', () async {
    final source = await fixture.source();
    await expectLater(
      fixture.repository.packages.prepare(
        source.path,
        zip: false,
        cancellation: RunCancellation()..cancel(),
      ),
      throwsA(isA<ToolCancelled>()),
    );
    expect(await fixture.repository.list(), isEmpty);
  });
}
