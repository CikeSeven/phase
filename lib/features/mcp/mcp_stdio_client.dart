import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/error/failure.dart';
import '../../../core/utils/id.dart';
import '../tools/tool.dart';
import '../workspace/process_api.g.dart';
import '../workspace/process_driver.dart';
import 'mcp_client.dart';

/// 本地 stdio 传输：直接读写 E3 原始进程管道，stdout 专用于 JSON-RPC 帧，
/// stderr 只留有界尾部作为业务详情，不写入 AppLogger。进程随连接创建，
/// 关闭/取消/异常终止进程并回收管道；不自动重跑已派发的调用。
class McpStdioClient extends McpClient {
  McpStdioClient(
    super.profile, {
    required this.driver,
    required this.rootfs,
    required this.workspace,
    this.environment = const {},
  });

  static const stderrTailBytes = 4096;
  static const writeChunkBytes = 60 * 1024;

  final ProcessDriver driver;

  /// 宿主侧 rootfs 路径；来自当前就绪的 Ubuntu 环境记录。
  final String rootfs;

  /// 服务专属工作目录（宿主路径，绑定到 guest /workspace）。
  final String workspace;

  /// 明文与解密后敏感环境变量的合并结果；基础 PATH/HOME 由宿主提供。
  final Map<String, String> environment;

  final _pending = <int, Completer<Map<String, dynamic>>>{};
  List<int> _stdoutBuffer = [];
  final List<int> _stderrTail = [];
  LinuxProcess? _process;
  StreamSubscription<String>? _stops;
  String? _owner;
  Future<void>? _started;
  LinuxProcessEvent? _exit;

  @override
  Future<Map<String, dynamic>> exchange(
    int id,
    String method,
    Map<String, dynamic> params,
    RunCancellation cancellation, {
    Duration? timeout,
  }) async {
    await _ensureStarted();
    if (_exit != null) throw _exitFailure();
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    Timer? timer;
    Future<void>? cancelled;
    try {
      timer = Timer(
        timeout ?? Duration(seconds: profile.callTimeoutSeconds),
        () {
          _pending.remove(id);
          if (method != 'initialize') {
            notifyCancelled(id, 'Timeout').ignore();
          }
          if (!completer.isCompleted) {
            completer.completeError(
              const McpFailure('timeout', 'MCP 请求超时；已派发的操作不会自动重发'),
            );
          }
        },
      );
      cancelled = cancellation.whenCancelled.then((_) {
        _pending.remove(id);
        if (method != 'initialize') {
          notifyCancelled(id, 'Cancelled').ignore();
        }
        if (!completer.isCompleted) {
          completer.completeError(const ToolCancelled());
        }
      });
      await _writeLine({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      });
      return await completer.future;
    } finally {
      timer?.cancel();
      cancelled?.ignore();
      _pending.remove(id);
    }
  }

  @override
  Future<void> write(
    Map<String, dynamic> message,
    RunCancellation cancellation,
  ) => _writeLine(message);

  /// 首次请求前启动服务进程；后续复用同一进程与管道。
  Future<void> _ensureStarted() => _started ??= _start();

  Future<void> _start() async {
    final command = profile.command;
    if (command == null) {
      throw const McpFailure('invalidCommand', 'stdio 服务缺少启动命令');
    }
    if (_exit != null) {
      throw _exitFailure();
    }
    final owner = 'mcp-${profile.id}-${generateId()}';
    try {
      await driver.beginTask(owner, 'MCP 服务 ${profile.name}');
      _owner = owner;
      _stops = driver.stops.listen((id) {
        if (id == owner) {
          // 通知面板的停止等同用户停止：终止进程，等待中的请求按取消收口。
          unawaited(_terminate());
        }
      });
      final process = await driver.start(
        LinuxProcessSpec(
          ownerId: owner,
          processId: generateId(),
          rootfs: rootfs,
          workspace: workspace,
          executable: command.executable,
          argv: command.args,
          cwd: command.cwd,
          environment: environment,
          // 长连接不设累计时限与总输出上限；帧级限制由本客户端执行。
        ),
        (stderr, bytes) async {
          if (stderr) {
            _feedStderr(bytes);
          } else {
            _feedStdout(bytes);
          }
        },
      );
      _process = process;
      unawaited(process.exited.then(_onExit));
    } on Failure catch (error) {
      await _releaseOwner();
      throw McpFailure('processStart', error.userMessage);
    } on Object {
      await _releaseOwner();
      throw const McpFailure('processStart', 'MCP 服务进程启动失败');
    }
  }

  void _onExit(LinuxProcessEvent event) {
    _exit = event;
    if (state != McpConnectionState.closing) {
      state = McpConnectionState.failed;
    }
    final failure = _exitFailure();
    for (final completer in _pending.values.toList()) {
      if (!completer.isCompleted) completer.completeError(failure);
    }
    _pending.clear();
  }

  McpFailure _exitFailure() {
    final event = _exit;
    final detail = switch (event) {
      null => 'MCP 服务进程尚未启动',
      _ =>
        'MCP 服务进程已退出'
            '${event.exitCode != null
                ? "（exit ${event.exitCode}）"
                : event.signal != null
                ? "（signal ${event.signal}）"
                : ""}',
    };
    final tail = utf8.decode(_stderrTail, allowMalformed: true).trim();
    return McpFailure('processExit', tail.isEmpty ? detail : '$detail\n$tail');
  }

  /// stdout 只承载 JSON-RPC 帧：按行切分、严格解码并分发。
  void _feedStdout(List<int> bytes) {
    _stdoutBuffer.addAll(bytes);
    if (_stdoutBuffer.length > McpLimits.responseBytes) {
      _stdoutBuffer = _stdoutBuffer.sublist(
        _stdoutBuffer.length - McpLimits.responseBytes,
      );
      unawaited(
        _failConnection(
          const McpFailure('responseLimit', 'MCP stdio 消息超过 8 MiB 上限，读取已停止'),
        ),
      );
      return;
    }
    while (true) {
      final index = _stdoutBuffer.indexOf(10);
      if (index < 0) return;
      var line = _stdoutBuffer.sublist(0, index);
      _stdoutBuffer = _stdoutBuffer.sublist(index + 1);
      // 兼容 \r\n 结尾；空行跳过。
      if (line.isNotEmpty && line.last == 13) {
        line = line.sublist(0, line.length - 1);
      }
      if (line.isEmpty) continue;
      final Map<String, dynamic> frame;
      try {
        frame = parseFrame(utf8.decode(line));
      } on FormatException {
        unawaited(
          _failConnection(
            const McpFailure('invalidResponse', 'MCP stdio 输出了非 JSON-RPC 内容'),
          ),
        );
        return;
      } on McpFailure {
        unawaited(
          _failConnection(
            const McpFailure('invalidResponse', 'MCP stdio 输出了无效的 JSON-RPC 消息'),
          ),
        );
        return;
      }
      _onFrame(frame);
    }
  }

  void _onFrame(Map<String, dynamic> frame) {
    if (frame['method'] case final String method) {
      if (frame.containsKey('id')) {
        // 服务器请求：ping 应答空结果，其余按未实现拒绝。
        write({
          'jsonrpc': '2.0',
          'id': frame['id'],
          if (method == 'ping')
            'result': <String, dynamic>{}
          else
            'error': {'code': -32601, 'message': 'Method not supported'},
        }, RunCancellation()).ignore();
      } else if (method == 'notifications/tools/list_changed') {
        catalogGeneration++;
      }
      return;
    }
    // 已放弃的请求（超时/停止后）可能仍收到迟到响应：没有对应的等待就忽略。
    // 响应帧原样交给基类校验；这里只负责把帧交回等待者。
    final completer = _pending.remove(frame['id']);
    if (completer != null && !completer.isCompleted) {
      completer.complete(frame);
    }
  }

  void _feedStderr(List<int> bytes) {
    _stderrTail.addAll(bytes);
    if (_stderrTail.length > stderrTailBytes) {
      _stderrTail.removeRange(0, _stderrTail.length - stderrTailBytes);
    }
  }

  Future<void> _writeLine(Map<String, dynamic> message) async {
    final process = _process;
    if (process == null || _exit != null) {
      throw const McpFailure(
        'connectionLost',
        'MCP 服务进程不可用，消息未能发送；已派发的操作不会自动重发',
      );
    }
    final bytes = utf8.encode('${jsonEncode(message)}\n');
    try {
      for (var offset = 0; offset < bytes.length; offset += writeChunkBytes) {
        await process.write(
          Uint8List.fromList(
            bytes.sublist(
              offset,
              (offset + writeChunkBytes).clamp(0, bytes.length),
            ),
          ),
        );
      }
    } on Failure {
      throw const McpFailure(
        'connectionLost',
        'MCP 服务进程写入失败，消息未能发送；已派发的操作不会自动重发',
      );
    }
  }

  /// 协议级错误不猜测进程状态：终止进程，等待中的请求以该错误收口。
  Future<void> _failConnection(McpFailure failure) async {
    if (state != McpConnectionState.closing) {
      state = McpConnectionState.failed;
    }
    for (final completer in _pending.values.toList()) {
      if (!completer.isCompleted) completer.completeError(failure);
    }
    _pending.clear();
    await _terminate();
  }

  Future<void> _terminate() async {
    final process = _process;
    if (process == null) return;
    try {
      await process.cancel();
    } on Object {
      /* 退出回执缺失时依赖 exited 兜底，不再阻塞收口。 */
    }
  }

  Future<void> _releaseOwner() async {
    await _stops?.cancel();
    _stops = null;
    final owner = _owner;
    if (owner == null) return;
    _owner = null;
    try {
      await driver.endTask(owner);
    } on Failure {
      /* 任务宿主未确认结束时进程已被终止，残留通知由系统回收。 */
    }
  }

  @override
  Future<void> cancelActiveRequests() async {
    for (final completer in _pending.values.toList()) {
      if (!completer.isCompleted) {
        completer.completeError(
          const McpFailure('disconnected', 'MCP 连接已断开，本次调用没有完整响应'),
        );
      }
    }
    _pending.clear();
  }

  @override
  Future<void> shutdown() async {
    await _terminate();
    await _releaseOwner();
  }
}
