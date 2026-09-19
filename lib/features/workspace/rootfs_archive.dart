import 'dart:io';
import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../tools/tool.dart';

/// Rootfs archives legitimately contain links. Create them last and rewrite guest
/// absolute targets to contained relative targets; never traverse a link to write.
class RootfsArchive {
  static const maxTarBytes = 256 * 1024 * 1024;
  static const maxFileBytes = 64 * 1024 * 1024;
  static const maxEntries = 20000;
  Future<int> extract(
    File compressed,
    Directory destination,
    RunCancellation cancellation, {
    required Future<void> Function(List<String>, List<int>) setModes,
    required void Function(int bytes) progress,
  }) async {
    final tar = File('${destination.path}.tar');
    var inflated = 0;
    final output = await tar.open(mode: FileMode.write);
    try {
      await for (final chunk in compressed.openRead().transform(gzip.decoder)) {
        cancellation.throwIfCancelled();
        inflated += chunk.length;
        if (inflated > maxTarBytes) {
          throw const WorkspaceFailure('archiveLimit', '环境解压体积超过上限');
        }
        await output.writeFrom(chunk);
        progress(inflated);
      }
    } finally {
      await output.close();
    }
    final input = InputFileStream(tar.path);
    final links = <String, (String, bool)>{};
    final seen = <String>{};
    final modes = <String, int>{};
    var total = 0;
    var headers = 0;
    String? nextName;
    String? nextLink;
    try {
      await destination.create(recursive: true);
      while (!input.isEOS) {
        cancellation.throwIfCancelled();
        final header = input.peekBytes(512).toUint8List();
        if (header.length != 512) {
          throw const WorkspaceFailure('archiveInvalid', '环境归档不完整');
        }
        if (header.every((b) => b == 0)) break;
        final checksumText = String.fromCharCodes(header.sublist(148, 156))
            .replaceAll('\u0000', '')
            .trim();
        final expected = int.tryParse(checksumText, radix: 8);
        var actual = 0;
        for (var i = 0; i < 512; i++) {
          actual += i >= 148 && i < 156 ? 32 : header[i];
        }
        if (expected != actual) {
          throw const WorkspaceFailure('archiveInvalid', '环境归档头校验失败');
        }
        final entry = TarFile.read(input);
        if (++headers > maxEntries * 2) {
          throw const WorkspaceFailure('archiveLimit', '环境归档条目超过上限');
        }
        if (entry.typeFlag == TarFile.exHeader ||
            entry.typeFlag == TarFile.gExHeader) {
          if (entry.fileSize > 65536) {
            throw const WorkspaceFailure('archiveLimit', '环境归档元数据超过上限');
          }
          final bytes = entry.rawContent!.toUint8List();
          var offset = 0;
          while (offset < bytes.length) {
            final space = bytes.indexOf(32, offset);
            if (space < offset) {
              throw const WorkspaceFailure('archiveInvalid', '环境归档元数据损坏');
            }
            final length = int.tryParse(
              ascii.decode(bytes.sublist(offset, space)),
            );
            if (length == null ||
                length <= space - offset + 1 ||
                offset + length > bytes.length ||
                bytes[offset + length - 1] != 10) {
              throw const WorkspaceFailure('archiveInvalid', '环境归档元数据损坏');
            }
            final text = utf8.decode(
              bytes.sublist(space + 1, offset + length - 1),
            );
            final separator = text.indexOf('=');
            if (separator < 1) {
              throw const WorkspaceFailure('archiveInvalid', '环境归档元数据损坏');
            }
            final key = text.substring(0, separator);
            final value = text.substring(separator + 1);
            if (key == 'path') nextName = value;
            if (key == 'linkpath') nextLink = value;
            if (key == 'size' || key.startsWith('GNU.sparse')) {
              throw const WorkspaceFailure(
                'archiveType',
                '环境归档包含不支持的大小覆盖或稀疏文件',
              );
            }
            offset += length;
          }
          continue;
        }
        final name = _relative(nextName ?? entry.filename);
        final linkedName = nextLink ?? entry.nameOfLinkedFile;
        nextName = null;
        nextLink = null;
        if (name == '.') continue;
        if (!seen.add(name) ||
            seen.length > maxEntries ||
            entry.fileSize > maxFileBytes ||
            entry.fileSize < 0) {
          throw const WorkspaceFailure('archiveLimit', '环境归档包含重名条目或超出上限');
        }
        final file = File(p.join(destination.path, name));
        if (entry.typeFlag == TarFile.directory) {
          await Directory(file.path).create(recursive: true);
          // Directory.create obeys the process umask (0700 on Android);
          // dpkg and friends need the archive's own modes, e.g. 0755.
          modes[file.path] = entry.mode & 0x1ff;
          if (modes.length == 256) {
            await setModes(modes.keys.toList(), modes.values.toList());
            modes.clear();
          }
        } else if (entry.typeFlag == TarFile.symbolicLink ||
            entry.typeFlag == TarFile.hardLink) {
          final target = linkedName ?? '';
          final hard = entry.typeFlag == TarFile.hardLink;
          final resolved = _relative(
            p.posix.normalize(
              target.startsWith('/')
                  ? target.substring(1)
                  : hard
                  ? target
                  : p.posix.join(p.posix.dirname(name), target),
            ),
          );
          links[name] = (resolved, hard);
        } else if (entry.typeFlag == TarFile.normalFile ||
            entry.typeFlag == '\u0000') {
          total += entry.fileSize;
          if (total > maxTarBytes) {
            throw const WorkspaceFailure('archiveLimit', '环境文件总量超过上限');
          }
          await file.parent.create(recursive: true);
          final handle = await file.open(mode: FileMode.write);
          try {
            final content = entry.rawContent!;
            var copied = 0;
            while (!content.isEOS) {
              cancellation.throwIfCancelled();
              final bytes = content
                  .readBytes(content.length.clamp(0, 65536))
                  .toUint8List();
              copied += bytes.length;
              await handle.writeFrom(bytes);
            }
            if (copied != entry.fileSize) {
              throw const WorkspaceFailure('archiveInvalid', '环境文件内容不完整');
            }
          } finally {
            await handle.close();
          }
          // Drop setuid/setgid/sticky bits; all files belong to the app UID.
          modes[file.path] = entry.mode & 0x1ff;
          if (modes.length == 256) {
            await setModes(modes.keys.toList(), modes.values.toList());
            modes.clear();
          }
        } else {
          throw const WorkspaceFailure('archiveType', '环境归档包含不支持的条目类型');
        }
        if (seen.length % 32 == 0) {
          progress(total);
          await Future<void>.delayed(Duration.zero);
        }
      }
      if (modes.isNotEmpty) {
        await setModes(modes.keys.toList(), modes.values.toList());
      }
      // No archive entry may be written beneath a symbolic link, even if it was
      // not yet created. This also rejects link cycles with children.
      for (final name in seen) {
        var parent = p.posix.dirname(name);
        while (parent != '.') {
          if (links.containsKey(parent)) {
            throw const WorkspaceFailure('archiveLink', '环境归档试图通过链接写入文件');
          }
          parent = p.posix.dirname(parent);
        }
      }
      for (final entry in links.entries.where((e) => e.value.$2)) {
        cancellation.throwIfCancelled();
        if (links.containsKey(entry.value.$1)) {
          throw const WorkspaceFailure('archiveLink', '环境硬链接目标无效');
        }
        final source = File(p.join(destination.path, entry.value.$1));
        if (!await source.exists()) {
          throw const WorkspaceFailure('archiveLink', '环境硬链接目标不存在');
        }
        final target = File(p.join(destination.path, entry.key));
        await target.parent.create(recursive: true);
        await source.copy(target.path);
        total += await source.length();
        if (total > maxTarBytes) {
          throw const WorkspaceFailure('archiveLimit', '环境文件总量超过上限');
        }
        await setModes([target.path], [(await source.stat()).mode & 0x1ff]);
      }
      for (final entry in links.entries.where((e) => !e.value.$2)) {
        cancellation.throwIfCancelled();
        final target = Link(p.join(destination.path, entry.key));
        await target.parent.create(recursive: true);
        await target.create(
          p.posix.relative(entry.value.$1, from: p.posix.dirname(entry.key)),
        );
      }
      return total;
    } finally {
      await input.close();
      if (await tar.exists()) await tar.delete();
    }
  }

  String _relative(String value) {
    final name = p.posix.normalize(value);
    if (value.contains('\u0000') ||
        value.contains('\\') ||
        name.startsWith('/') ||
        name == '..' ||
        name.startsWith('../') ||
        name.length > 4096) {
      throw const WorkspaceFailure('archivePath', '环境归档路径越界');
    }
    return name;
  }
}
