import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' as archive;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../../../data/models/skill_installation.dart';
import '../../../data/models/tool_source.dart';
import '../tools/tool.dart';

/// 导入与原生目录复制共用这些上限；原生值由请求传入。
abstract final class SkillLimits {
  static const archiveBytes = 16 * 1024 * 1024;
  static const totalBytes = 32 * 1024 * 1024;
  static const fileBytes = 4 * 1024 * 1024;
  static const entries = 512;
  static const depth = 16;
  static const pathLength = 240;
}

String skillRelativePath(String path, {bool directory = false}) {
  final value = directory && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  final segments = value.split('/');
  if (value.isEmpty ||
      value.length > SkillLimits.pathLength ||
      value.contains(RegExp(r'[\x00-\x1f\x7f\\:]')) ||
      segments.length > SkillLimits.depth ||
      segments.any((s) => s.isEmpty || s == '.' || s == '..')) {
    throw const SkillFailure('invalidPath', '资源路径无效，不能使用绝对路径、越界引用或过深目录');
  }
  return value;
}

class PreparedSkill {
  PreparedSkill({
    required this.directory,
    required this.name,
    required this.description,
    required this.source,
    required this.resources,
    required this.ignoredFields,
  });
  final Directory directory;
  final String name;
  final String description;
  final String source;
  final Map<String, SkillResource> resources;
  final List<String> ignoredFields;
  String get revision => definitionDigest({
    for (final e in resources.entries) e.key: e.value.toJson(),
  });
  Future<void> discard() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// 只复制与校验，永不执行包内内容。失败目录与安装版本分离。
class SkillPackageReader {
  SkillPackageReader(this.stagingRoot);
  final Directory stagingRoot;

  Future<PreparedSkill> prepare(
    String sourcePath, {
    required bool zip,
    required RunCancellation cancellation,
    String? sourceLabel,
  }) async {
    final staging = Directory(p.join(stagingRoot.path, generateId()));
    try {
      cancellation.throwIfCancelled();
      await staging.create(recursive: true);
      if (zip) {
        await _zip(File(sourcePath), staging, cancellation);
      } else {
        await _directory(Directory(sourcePath), staging, cancellation);
      }
      cancellation.throwIfCancelled();
      // 接受入口在根目录，或 ZIP 中只有一个顶层包装目录。
      var root = staging;
      if (!await File(p.join(root.path, 'SKILL.md')).exists()) {
        final children = await root.list(followLinks: false).toList();
        if (zip && children.length == 1 && children.single is Directory) {
          root = children.single as Directory;
        }
      }
      final entry = File(p.join(root.path, 'SKILL.md'));
      if (!await entry.exists()) {
        throw const SkillFailure('missingEntry', '所选内容缺少 SKILL.md');
      }
      if (await entry.length() > 256 * 1024) {
        throw const SkillFailure('entryTooLarge', 'SKILL.md 超过 256 KiB');
      }
      final text = await entry.readAsString();
      final metadata = _frontmatter(text);
      final resources = <String, SkillResource>{};
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        cancellation.throwIfCancelled();
        if (entity is! File) continue;
        final bytes = await entity.readAsBytes();
        resources[p.relative(entity.path, from: root.path)] = SkillResource(
          size: bytes.length,
          digest: sha256.convert(bytes).toString(),
        );
      }
      // 展平包装目录，安装时目录 rename 仍然是同卷原子操作。
      if (root.path != staging.path) {
        final flattened = await root.rename('${staging.path}-root');
        try {
          await staging.delete(recursive: true);
          await flattened.rename(staging.path);
        } catch (_) {
          if (await flattened.exists()) await flattened.delete(recursive: true);
          rethrow;
        }
      }
      final label = (sourceLabel ?? p.basename(sourcePath)).replaceAll(
        RegExp(r'[\x00-\x1f\x7f]'),
        '',
      );
      return PreparedSkill(
        directory: staging,
        name: metadata.$1,
        description: metadata.$2,
        ignoredFields: metadata.$3,
        source:
            '${zip ? '本地 ZIP' : '本地目录'} · ${label.substring(0, label.length.clamp(0, 100))}',
        resources: resources,
      );
    } catch (error) {
      try {
        if (await staging.exists()) await staging.delete(recursive: true);
      } on FileSystemException {
        throw const SkillFailure('cleanupFailed', '导入未完成，临时文件清理失败，请重试导入');
      }
      if (error is Failure || error is ToolCancelled) rethrow;
      if (error is FileSystemException) {
        throw const SkillFailure(
          'fileAccess',
          '无法复制或读取 Skill 文件，请检查文件访问权限和可用空间',
        );
      }
      throw const SkillFailure('invalidPackage', 'Skill 包损坏或文本格式无效');
    }
  }

  Future<void> _directory(
    Directory source,
    Directory destination,
    RunCancellation cancellation,
  ) async {
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const SkillFailure('invalidDirectory', '请选择真实目录，不能导入目录链接');
    }
    var count = 0;
    var total = 0;
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      cancellation.throwIfCancelled();
      if (++count > SkillLimits.entries) _tooLarge();
      final relative = skillRelativePath(
        p.relative(entity.path, from: source.path),
      );
      if (entity is Link || (entity is! File && entity is! Directory)) {
        throw const SkillFailure('linkUnsupported', 'Skill 包不能包含链接或特殊文件');
      }
      final target = p.join(destination.path, relative);
      if (entity is Directory) {
        await Directory(target).create(recursive: true);
        continue;
      }
      await File(target).parent.create(recursive: true);
      final sink = File(target).openWrite();
      var size = 0;
      try {
        await for (final bytes in File(entity.path).openRead()) {
          cancellation.throwIfCancelled();
          size += bytes.length;
          total += bytes.length;
          if (size > SkillLimits.fileBytes || total > SkillLimits.totalBytes) {
            _tooLarge();
          }
          sink.add(bytes);
          await sink.flush();
        }
      } finally {
        await sink.close();
      }
    }
  }

  Future<void> _zip(
    File source,
    Directory target,
    RunCancellation cancellation,
  ) async {
    if (await source.length() > SkillLimits.archiveBytes) _tooLarge();
    // 流式有界读取，不能仅相信选取时文件大小。
    final input = BytesBuilder(copy: false);
    await for (final chunk in source.openRead()) {
      cancellation.throwIfCancelled();
      if (input.length + chunk.length > SkillLimits.archiveBytes) _tooLarge();
      input.add(chunk);
    }
    final bytes = input.takeBytes();
    _checkZipDirectory(bytes);
    final directory = archive.ZipDirectory()
      ..read(archive.InputMemoryStream(bytes));
    if (directory.filePosition < 0 ||
        directory.numberOfThisDisk != 0 ||
        directory.diskWithTheStartOfTheCentralDirectory != 0 ||
        directory.fileHeaders.length !=
            directory.totalCentralDirectoryEntries) {
      throw const SkillFailure('invalidZip', 'ZIP 目录损坏或使用了不支持的分卷格式');
    }
    if (directory.fileHeaders.length > SkillLimits.entries) _tooLarge();
    var total = 0;
    final paths = <String>{};
    // 先查中央目录：ZipDecoder 会合并重名项并提前解压链接，不能用它进行此校验。
    for (final header in directory.fileHeaders) {
      final file = header.file!;
      final isDirectory = file.filename.endsWith('/');
      skillRelativePath(
        header.filename,
        directory: header.filename.endsWith('/'),
      );
      if (header.filename != file.filename) {
        throw const SkillFailure('invalidZip', 'ZIP 文件目录与条目名称不匹配');
      }
      final path = skillRelativePath(file.filename, directory: isDirectory);
      final type = (header.externalFileAttributes >> 16) & 0xf000;
      if (!paths.add(path) ||
          (type != 0 && type != 0x8000 && type != 0x4000) ||
          file.flags & 1 != 0 ||
          header.generalPurposeBitFlag & 1 != 0 ||
          header.diskNumberStart != 0 ||
          (header.compressionMethod != 0 && header.compressionMethod != 8) ||
          header.uncompressedSize != file.uncompressedSize ||
          header.crc32 != file.crc32 ||
          (file.compressionMethod != archive.CompressionType.none &&
              file.compressionMethod != archive.CompressionType.deflate)) {
        throw const SkillFailure(
          'unsupportedZip',
          'ZIP 包含重名项、链接、特殊文件、加密或不支持的压缩格式',
        );
      }
      if (file.uncompressedSize > SkillLimits.fileBytes) _tooLarge();
      total += file.uncompressedSize;
      if (total > SkillLimits.totalBytes) _tooLarge();
    }
    total = 0;
    for (final header in directory.fileHeaders) {
      cancellation.throwIfCancelled();
      final file = header.file!;
      final isDirectory = file.filename.endsWith('/');
      final relative = skillRelativePath(file.filename, directory: isDirectory);
      final destination = File(p.join(target.path, relative));
      if (isDirectory) {
        await Directory(destination.path).create(recursive: true);
        continue;
      }
      await destination.parent.create(recursive: true);
      Stream<List<int>> stream = Stream.value(
        file.getStream(decompress: false).toUint8List(),
      );
      if (file.compressionMethod == archive.CompressionType.deflate) {
        stream = ZLibDecoder(raw: true).bind(stream);
      }
      final sink = destination.openWrite();
      var size = 0;
      var crc = 0;
      try {
        await for (final bytes in stream) {
          cancellation.throwIfCancelled();
          size += bytes.length;
          total += bytes.length;
          if (size > SkillLimits.fileBytes || total > SkillLimits.totalBytes) {
            _tooLarge();
          }
          crc = archive.getCrc32(bytes, crc);
          sink.add(bytes);
          await sink.flush();
        }
      } finally {
        await sink.close();
      }
      if (size != file.uncompressedSize || crc != file.crc32) {
        throw const SkillFailure('invalidZip', 'ZIP 文件大小或校验值不匹配');
      }
    }
  }

  // 在分配条目对象前限制中央目录。小型 Skill 包无需 ZIP64 或分卷。
  void _checkZipDirectory(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    for (
      var offset = bytes.length - 22;
      offset >= 0 && offset >= bytes.length - 65557;
      offset--
    ) {
      if (data.getUint32(offset, Endian.little) != 0x06054b50) continue;
      if (offset + 22 + data.getUint16(offset + 20, Endian.little) !=
          bytes.length) {
        continue;
      }
      final count = data.getUint16(offset + 10, Endian.little);
      if (count > SkillLimits.entries) _tooLarge();
      final size = data.getUint32(offset + 12, Endian.little);
      final start = data.getUint32(offset + 16, Endian.little);
      if (data.getUint16(offset + 4, Endian.little) != 0 ||
          data.getUint16(offset + 6, Endian.little) != 0 ||
          data.getUint16(offset + 8, Endian.little) != count ||
          size > bytes.length ||
          start + size != offset) {
        throw const SkillFailure('invalidZip', 'ZIP 中央目录无效，不支持 ZIP64 或分卷');
      }
      // 不相信 EOCD 的条目计数；逐个检查边界而不创建解压对象。
      var cursor = start;
      var actual = 0;
      while (cursor < offset) {
        if (++actual > SkillLimits.entries) _tooLarge();
        if (cursor + 46 > offset ||
            data.getUint32(cursor, Endian.little) != 0x02014b50) {
          throw const SkillFailure('invalidZip', 'ZIP 中央目录损坏');
        }
        cursor +=
            46 +
            data.getUint16(cursor + 28, Endian.little) +
            data.getUint16(cursor + 30, Endian.little) +
            data.getUint16(cursor + 32, Endian.little);
      }
      if (actual != count || cursor != offset) {
        throw const SkillFailure('invalidZip', 'ZIP 条目数量或长度不匹配');
      }
      return;
    }
    throw const SkillFailure('invalidZip', 'ZIP 缺少完整中央目录');
  }

  (String, String, List<String>) _frontmatter(String text) {
    final normalized = text.replaceAll('\r\n', '\n');
    if (!normalized.startsWith('---\n')) {
      throw const SkillFailure(
        'frontmatter',
        'SKILL.md 必须以 YAML frontmatter 开头',
      );
    }
    final end = RegExp(r'\n---(?:\n|$)')
        .firstMatch(normalized.substring(4))
        ?.start;
    final boundary = end == null ? -1 : end + 4;
    if (boundary < 0 || boundary > 16 * 1024) {
      throw const SkillFailure('frontmatter', 'frontmatter 未闭合或超过 16 KiB');
    }
    final yaml = loadYaml(normalized.substring(4, boundary));
    if (yaml is! YamlMap || yaml.keys.any((key) => key is! String)) {
      throw const SkillFailure('frontmatter', 'frontmatter 必须是字段映射');
    }
    final name = yaml['name'];
    final description = yaml['description'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.length > 100 ||
        name.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
        description is! String ||
        description.trim().isEmpty ||
        description.length > 1024) {
      throw const SkillFailure(
        'frontmatter',
        'name 必须为 1–100 字符的名称，description 必须为 1–1024 字符的说明',
      );
    }
    return (
      name.trim(),
      description.trim(),
      [
        for (final key in yaml.keys)
          if (key != 'name' && key != 'description') key as String,
      ],
    );
  }

  Never _tooLarge() => throw const SkillFailure(
    'packageTooLarge',
    'Skill 超过导入上限：ZIP 16 MiB、解压后 32 MiB、单文件 4 MiB、512 个条目',
  );
}
