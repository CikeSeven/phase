import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import 'command_api.g.dart';

part 'command_channel_driver.g.dart';

/// Shizuku 的 ready 同时要求服务运行、系统授权及可读取的实际执行身份。
bool hasShizukuDevicePermission(Iterable<CommandChannelStatus> statuses) =>
    statuses.any(
      (status) => status.channel == 'shizuku' && status.state == 'ready',
    );

class CommandChannelDriver implements CommandChannelFlutterApi {
  CommandChannelDriver() {
    CommandChannelFlutterApi.setUp(this);
  }
  final _host = CommandChannelHostApi();
  final _changes = StreamController<void>.broadcast();
  bool _disposed = false;
  Stream<void> get changes => _changes.stream;

  Future<T> _boundary<T>(
    Future<T> Function() call, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (_disposed) {
      throw const CommandChannelFailure('unavailable', '系统能力通道已关闭');
    }
    try {
      return await call().timeout(timeout);
    } on PlatformException catch (error) {
      throw CommandChannelFailure(error.code, commandErrorText(error.code));
    } on MissingPluginException {
      throw const CommandChannelFailure('unsupported', '此设备不支持 Shizuku 虚拟屏');
    } on TimeoutException {
      throw const CommandChannelFailure('channelTimeout', '系统能力通道未及时响应');
    }
  }

  Future<List<CommandChannelStatus>> status() => _boundary(_host.status);
  Future<void> setEnabled(List<String> channels) =>
      _boundary(() => _host.setEnabled(channels));
  Future<void> authorize(String channel) =>
      _boundary(() => _host.authorize(channel));
  Future<void> initialize(String channel) => _boundary(
    () => _host.initialize(channel),
    timeout: const Duration(minutes: 3),
  );
  Future<void> openSettings(String channel) =>
      _boundary(() => _host.openSettings(channel));

  @override
  void statusChanged() {
    if (!_disposed) _changes.add(null);
  }

  Future<void> dispose() async {
    _disposed = true;
    CommandChannelFlutterApi.setUp(null);
    await _changes.close();
  }
}

String commandErrorText(String code) => switch (code) {
  'permissionRequired' || 'channelDisabled' => 'Shizuku 虚拟屏未启用或授权已撤销',
  'notInstalled' => '未安装 Shizuku',
  'notRunning' => 'Shizuku 未运行',
  'identityChanged' => 'Shizuku 执行身份或设备组件已改变，请开始新运行',
  'deviceInitializationFailed' => 'Shizuku 设备服务连接失败，请检查服务及授权',
  'invalidChannel' => '系统能力通道无效',
  _ => 'Shizuku 虚拟屏暂不可用，请检查授权、服务和设备支持情况',
};

@Riverpod(keepAlive: true)
CommandChannelDriver commandChannelDriver(Ref ref) {
  final driver = CommandChannelDriver();
  ref.onDispose(() {
    unawaited(driver.dispose());
  });
  return driver;
}
