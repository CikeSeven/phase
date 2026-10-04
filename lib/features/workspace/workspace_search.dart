import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/error/failure.dart';
import '../../../data/models/workspace.dart';
import '../tools/tool.dart';
import '../tools/tool_output_limits.dart';
import 'process_api.g.dart';
import 'process_driver.dart';
import 'workspace_file_access.dart';

class WorkspaceSearchRequest {
  const WorkspaceSearchRequest({
    required this.findFiles,
    required this.pattern,
    this.path = '.',
    this.glob,
    this.ignoreCase = false,
    this.literal = false,
    this.contextLines = 0,
    required this.limit,
  });
  final bool findFiles;
  final String pattern;
  final String path;
  final String? glob;
  final bool ignoreCase;
  final bool literal;
  final int contextLines;
  final int limit;
}

/// Fixed ripgrep flags and quoted values; no model-supplied command is dispatched.
class WorkspaceSearch {
  const WorkspaceSearch(this.binding, this.processes);
  final WorkspaceSnapshot binding;
  final ProcessDriver? processes;

  Future<String> run(
    WorkspaceSearchRequest request,
    ToolContext context,
    RunCancellation cancellation,
  ) async {
    cancellation.throwIfCancelled();
    if (!binding.executable || processes == null) {
      throw const WorkspaceFailure('environmentMissing', '当前搜索环境未就绪');
    }
    final path = resolveToolExecutionPath(binding, request.path);
    final output = _SearchOutput(request, path);
    final error = BytesBuilder(copy: false);
    final input = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(_SearchTextSink(output.addText, output.finish));
    Future<void> receive(bool stderr, Uint8List bytes) async {
      if (stderr) {
        final remaining = (ToolOutputLimits.maxBytes - error.length).clamp(
          0,
          bytes.length,
        );
        if (remaining > 0) error.add(bytes.sublist(0, remaining));
      } else if (!output.stopped.isCompleted) {
        input.add(bytes);
      }
    }

    final command = _command(request, path);
    if (utf8.encode(command).length > 120 * 1024) {
      throw const WorkspaceFailure(
        'invalidArguments',
        '搜索参数过长，请缩短 pattern 或 glob',
      );
    }
    LinuxProcess? process;
    int? exitCode;
    String? processError;
    var outputLimitExceeded = false;
    var interrupted = false;
    var settled = false;
    try {
      process = await processes!.start(
        LinuxProcessSpec(
          ownerId: context.runId,
          processId: context.toolCallId,
          rootfs: binding.environmentRoot!,
          executable: '/bin/sh',
          argv: ['-c', command],
          cwd: binding.executionRoot,
          environment: {},
          outputLimitBytes: 8 * 1024 * 1024,
        ),
        receive,
      );
      await process.closeInput();
      final done = process.exited;
      final completed = await Future.any<bool>([
        done.then((_) => true),
        cancellation.whenCancelled.then((_) => false),
        output.stopped.future.then((_) => false),
      ]);
      if (!completed) await process.cancel();
      final result = await done;
      settled = true;
      exitCode = result.exitCode;
      processError = result.error;
      interrupted = result.cancelled || result.signal != null;
      outputLimitExceeded = result.outputLimitExceeded;
    } finally {
      try {
        if (!settled) {
          if (process != null) await process.cancel();
        }
      } finally {
        input.close();
      }
    }
    cancellation.throwIfCancelled();
    if (output.failure != null) {
      throw WorkspaceFailure('searchResultInvalid', output.failure!);
    }
    if ((processError != null &&
            !(output.stopped.isCompleted && processError == 'outputStopped')) ||
        (interrupted && !output.stopped.isCompleted)) {
      throw const WorkspaceFailure('searchInterrupted', '搜索未收到完整退出回执，请缩小范围后重试');
    }
    if (!output.stopped.isCompleted &&
        (outputLimitExceeded || (exitCode != 0 && exitCode != 1))) {
      final message = utf8
          .decode(error.takeBytes(), allowMalformed: true)
          .trim();
      throw WorkspaceFailure(
        exitCode == 127 ? 'searchDependencyMissing' : 'searchFailed',
        exitCode == 127
            ? '当前环境没有 ripgrep（rg）；请先安装依赖后再搜索，不会自动安装或切换环境'
            : message.isEmpty
            ? '搜索失败或底层输出超过上限，请缩小范围'
            : message,
      );
    }
    return output.render();
  }

  String _command(WorkspaceSearchRequest request, String path) {
    String quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
    final flags = [
      'rg',
      '--hidden',
      '--color=never',
      if (request.findFiles) ...[
        '--files',
        '--null',
        '--glob',
        request.pattern,
      ] else ...[
        '--json',
        if (request.ignoreCase) '--ignore-case',
        if (request.literal) '--fixed-strings',
        if (request.glob != null) ...['--glob', request.glob!],
        if (request.contextLines > 0) ...[
          '--context',
          '${request.contextLines}',
        ],
      ],
      '--glob',
      '!.git',
    ];
    final prefix = flags.map(quote).join(' ');
    String search(String target) =>
        '$prefix -- ${request.findFiles ? '' : '${quote(request.pattern)} '}${quote(target)}';
    final quotedPath = quote(path);
    return 'command -v rg >/dev/null 2>&1 || exit 127\n'
        'if [ -d $quotedPath ]; then\n'
        '  cd -- $quotedPath || exit 2\n'
        '  ${search('.')}\n'
        '${request.findFiles ? '' : 'elif [ -f $quotedPath ]; then\n  ${search(path)}\n'}'
        'else\n  printf "%s\\n" "搜索路径不存在或类型无效" >&2\n  exit 2\nfi';
  }
}

class _SearchOutput {
  _SearchOutput(this.request, this.searchPath);
  final WorkspaceSearchRequest request;
  final String searchPath;
  final stopped = Completer<void>();
  final _rows = <String>[];
  final _pending = StringBuffer();
  var _bytes = 0;
  var _count = 0;
  var _limitReached = false;
  var _bytesReached = false;
  var _linesTruncated = false;
  String? _lastFile;
  int? _lastMatchLine;
  String? failure;

  void _stop() {
    if (!stopped.isCompleted) stopped.complete();
  }

  void addText(String text) {
    final delimiter = request.findFiles ? '\u0000' : '\n';
    var start = 0;
    while (!stopped.isCompleted) {
      final index = text.indexOf(delimiter, start);
      if (index < 0) {
        _pending.write(text.substring(start));
        break;
      }
      _pending.write(text.substring(start, index));
      final line = _pending.toString();
      _pending.clear();
      start = index + 1;
      if (request.findFiles) {
        _count++;
        _addRow(p.posix.normalize(line));
        if (_count >= request.limit) {
          _limitReached = true;
          _stop();
        }
      } else {
        _event(line);
      }
    }
    if (stopped.isCompleted) _pending.clear();
  }

  void finish() {
    if (stopped.isCompleted || _pending.isEmpty) return;
    if (request.findFiles) {
      failure = '搜索未返回完整文件路径';
    } else {
      _event(_pending.toString());
    }
    _pending.clear();
  }

  void _event(String line) {
    if (line.trim().isEmpty) return;
    try {
      final event = jsonDecode(line);
      if (event is! Map<String, dynamic>) throw const FormatException();
      final type = event['type'];
      if (!const {
        'begin',
        'end',
        'summary',
        'match',
        'context',
      }.contains(type)) {
        throw const FormatException();
      }
      if (type == 'end' && _limitReached) {
        _stop();
        return;
      }
      if (type != 'match' && type != 'context') return;
      final data = event['data'];
      if (data is! Map<String, dynamic> || data['line_number'] is! int) {
        throw const FormatException();
      }
      final file = _text(data['path']);
      final lineNumber = data['line_number'] as int;
      final isMatch = type == 'match' && !_limitReached;
      if (_limitReached &&
          (file != _lastFile ||
              lineNumber > _lastMatchLine! + request.contextLines)) {
        _stop();
        return;
      }
      if (isMatch) {
        _count++;
        _lastFile = file;
        _lastMatchLine = lineNumber;
      }
      var text = _text(data['lines']).replaceAll('\r', '');
      if (text.endsWith('\n')) text = text.substring(0, text.length - 1);
      if (text.runes.length > ToolOutputLimits.grepLineCharacters) {
        text =
            '${String.fromCharCodes(text.runes.take(ToolOutputLimits.grepLineCharacters))}…';
        _linesTruncated = true;
      }
      final path = p.posix.isAbsolute(file)
          ? file == searchPath
                ? p.posix.basename(file)
                : p.posix.relative(file, from: searchPath)
          : p.posix.normalize(file);
      final label = path.replaceAll('\r', r'\r').replaceAll('\n', r'\n');
      _addRow(
        isMatch ? '$label:$lineNumber: $text' : '$label-$lineNumber- $text',
      );
      if (_count >= request.limit) {
        _limitReached = true;
        if (request.contextLines == 0 ||
            lineNumber >= _lastMatchLine! + request.contextLines) {
          _stop();
        }
      }
    } on FormatException {
      failure = '搜索程序返回了无法解析的结果';
      _stop();
    }
  }

  String _text(Object? value) {
    if (value is Map<String, dynamic>) {
      if (value['text'] case final String text) return text;
      if (value['bytes'] case final String bytes) {
        return utf8.decode(base64Decode(bytes), allowMalformed: true);
      }
    }
    throw const FormatException();
  }

  void _addRow(String row) {
    final bytes = utf8.encode(row).length + (_rows.isEmpty ? 0 : 1);
    if (_bytes + bytes > ToolOutputLimits.maxBytes) {
      _bytesReached = true;
      _stop();
      return;
    }
    _rows.add(row);
    _bytes += bytes;
  }

  String render() {
    final notices = [
      if (_limitReached)
        '已达到 ${request.limit} ${request.findFiles ? '项结果' : '处匹配'}；增大 limit 或缩小搜索范围',
      if (_bytesReached) '已达到 50 KiB 输出上限；请缩小 path、pattern 或 glob',
      if (_linesTruncated) '长行已截断到 500 字符；使用 read_file 读取原文',
    ];
    return [
      if (_rows.isEmpty) request.findFiles ? '没有匹配的文件' : '没有匹配内容',
      ..._rows,
      if (notices.isNotEmpty) '\n[${notices.join('；')}]',
    ].join('\n');
  }
}

class _SearchTextSink implements Sink<String> {
  const _SearchTextSink(this.onText, this.onClose);
  final void Function(String) onText;
  final void Function() onClose;
  @override
  void add(String data) => onText(data);
  @override
  void close() => onClose();
}
