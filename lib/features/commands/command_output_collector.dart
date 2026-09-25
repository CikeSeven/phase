import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../tools/tool.dart';
import '../workspace/shell_tool.dart';

/// Bytes remain separate by stream; ordinary output does not create log attachments.
class CommandOutputCollector {
  CommandOutputCollector(this.context);
  final ToolContext context;
  final previews = [BytesBuilder(copy: false), BytesBuilder(copy: false)];
  final sizes = [0, 0];
  final _files = <int, RandomAccessFile>{};
  final artifacts = <String>[];
  String _path(int stream) => p.join(
    context.artifactsDirectory,
    '${context.toolCallId}-${stream == 0 ? 'stdout' : 'stderr'}.txt',
  );
  Future<void> add(bool stderr, Uint8List bytes) async {
    final index = stderr ? 1 : 0;
    final remaining = (ShellLimits.previewBytes - previews[index].length).clamp(
      0,
      bytes.length,
    );
    sizes[index] += bytes.length;
    if (remaining > 0) previews[index].add(bytes.sublist(0, remaining));
    try {
      if (sizes[index] > ShellLimits.previewBytes) {
        var file = _files[index];
        if (file == null) {
          final output = File(_path(index));
          await output.parent.create(recursive: true);
          file = await output.open(mode: FileMode.write);
          _files[index] = file;
          await file.writeFrom(previews[index].toBytes());
          if (remaining < bytes.length) {
            await file.writeFrom(bytes.sublist(remaining));
          }
        } else {
          await file.writeFrom(bytes);
        }
      }
    } on FileSystemException {
      throw const CommandChannelFailure('outputSaveFailed', '命令日志保存失败，请检查可用空间');
    }
  }

  Future<void> finish() async {
    await close();
    for (var i = 0; i < sizes.length; i++) {
      if (sizes[i] <= ShellLimits.previewBytes) continue;
      final artifact = await context.storage.registerArtifact(
        conversationId: context.conversationId,
        path: _path(i),
        name: p.basename(_path(i)),
      );
      artifacts.add(artifact.id);
    }
  }

  Future<void> close() async {
    final files = _files.values.toList();
    _files.clear();
    for (final file in files) {
      try {
        await file.close();
      } on FileSystemException {
        throw const CommandChannelFailure('outputSaveFailed', '命令日志保存失败');
      }
    }
  }

  Map<String, dynamic> get result => {
    'stdout': utf8.decode(previews[0].toBytes(), allowMalformed: true),
    'stderr': utf8.decode(previews[1].toBytes(), allowMalformed: true),
    'stdoutBytes': sizes[0],
    'stderrBytes': sizes[1],
    'previewTruncated': sizes.any((size) => size > ShellLimits.previewBytes),
    'artifactIds': artifacts,
  };
}
