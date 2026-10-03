import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../tools/tool.dart';
import '../tools/tool_output_limits.dart';

/// Bytes remain separate by stream; ordinary output does not create log attachments.
class CommandOutputCollector {
  CommandOutputCollector(this.context);
  final ToolContext context;
  final previews = [ToolOutputTail(), ToolOutputTail()];
  final sizes = [0, 0];
  final _files = <int, RandomAccessFile>{};
  final artifacts = <String>[];
  final _artifactIds = <int, String>{};
  var _closed = false;
  String _path(int stream) => p.join(
    context.artifactsDirectory,
    '${context.toolCallId}-${stream == 0 ? 'stdout' : 'stderr'}.txt',
  );
  Future<void> add(bool stderr, Uint8List bytes) async {
    if (_closed) return;
    final index = stderr ? 1 : 0;
    final previous =
        _files[index] == null &&
            sizes[index] + bytes.length > ToolOutputLimits.maxBytes
        ? previews[index].bytes
        : null;
    sizes[index] += bytes.length;
    previews[index].add(bytes);
    try {
      if (sizes[index] > ToolOutputLimits.maxBytes) {
        var file = _files[index];
        if (file == null) {
          final output = File(_path(index));
          await output.parent.create(recursive: true);
          file = await output.open(mode: FileMode.write);
          _files[index] = file;
          await file.writeFrom(previous!);
          await file.writeFrom(bytes);
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
      if (sizes[i] == 0 ||
          (!previews[i].preview.truncated && !_combinedTruncated) ||
          _artifactIds.containsKey(i)) {
        continue;
      }
      if (sizes[i] <= ToolOutputLimits.maxBytes) {
        try {
          final output = File(_path(i));
          await output.parent.create(recursive: true);
          await output.writeAsBytes(previews[i].bytes, flush: true);
        } on FileSystemException {
          throw const CommandChannelFailure(
            'outputSaveFailed',
            '命令日志保存失败，请检查可用空间',
          );
        }
      }
      final artifact = await context.storage.registerArtifact(
        conversationId: context.conversationId,
        path: _path(i),
        name: p.basename(_path(i)),
      );
      artifacts.add(artifact.id);
      _artifactIds[i] = artifact.id;
    }
  }

  bool get _combinedTruncated =>
      sizes[0] + sizes[1] > ToolOutputLimits.maxBytes ||
      previews[0].lineCount + previews[1].lineCount > ToolOutputLimits.maxLines;

  Future<void> close() async {
    _closed = true;
    final files = _files.values.toList();
    _files.clear();
    CommandChannelFailure? failure;
    for (final file in files) {
      try {
        await file.close();
      } on FileSystemException {
        failure ??= const CommandChannelFailure('outputSaveFailed', '命令日志保存失败');
      }
    }
    if (failure != null) throw failure;
  }

  Map<String, dynamic> get result => {
    'stdout': previews[0].preview.text,
    'stderr': previews[1].preview.text,
    'stdoutBytes': sizes[0],
    'stderrBytes': sizes[1],
    'previewTruncated':
        _combinedTruncated ||
        previews.any((preview) => preview.preview.truncated),
    'stdoutArtifactId': ?_artifactIds[0],
    'stderrArtifactId': ?_artifactIds[1],
    'artifactIds': artifacts,
  };
}
