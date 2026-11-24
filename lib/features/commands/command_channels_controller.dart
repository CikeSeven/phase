import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../data/datasources/local/settings_storage.dart';
import '../../../data/models/command_channel.dart';
import '../../../data/models/tool_call_record.dart';
import 'command_api.g.dart';
import 'command_channel_driver.dart';
import 'root_command_driver.dart';

part 'command_channels_controller.g.dart';

class CommandChannelsState {
  const CommandChannelsState({
    required this.settings,
    this.statuses = const [],
    this.busy = false,
    this.error,
  });
  final CommandChannelSettings settings;
  final List<CommandChannelStatus> statuses;
  final bool busy;
  final String? error;
}

@Riverpod(keepAlive: true)
class CommandChannelsController extends _$CommandChannelsController {
  int _revision = 0;
  bool _updating = false;
  bool _refreshing = false;
  @override
  Future<CommandChannelsState> build() async {
    final driver = ref.watch(commandChannelDriverProvider);
    final subscription = driver.changes.listen((_) {
      unawaited(refresh());
    });
    ref.onDispose(subscription.cancel);
    final settings = ref.read(settingsStorageProvider).readCommandChannels();
    await driver.setEnabled(settings.channels);
    return CommandChannelsState(
      settings: settings,
      statuses: await driver.status(),
    );
  }

  Future<void> refresh() async {
    final current = state.value;
    if (_updating || _refreshing || current == null) return;
    _refreshing = true;
    final revision = ++_revision;
    try {
      final statuses = await ref.read(commandChannelDriverProvider).status();
      if (ref.mounted && revision == _revision) {
        state = AsyncData(
          CommandChannelsState(settings: current.settings, statuses: statuses),
        );
      }
    } on Failure catch (error) {
      if (ref.mounted && revision == _revision) {
        state = AsyncData(
          CommandChannelsState(
            settings: current.settings,
            statuses: current.statuses,
            error: error.userMessage,
          ),
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _operate(
    Future<void> Function() action, {
    CommandChannelSettings? settings,
  }) async {
    final current = state.value;
    if (_updating || current == null) return;
    _updating = true;
    ++_revision;
    state = AsyncData(
      CommandChannelsState(
        settings: current.settings,
        statuses: current.statuses,
        busy: true,
      ),
    );
    try {
      await action();
      if (!ref.mounted) return;
      final statuses = await ref.read(commandChannelDriverProvider).status();
      if (ref.mounted) {
        state = AsyncData(
          CommandChannelsState(
            settings: settings ?? current.settings,
            statuses: statuses,
          ),
        );
      }
    } on Failure catch (error) {
      if (ref.mounted) {
        state = AsyncData(
          CommandChannelsState(
            settings: ref.read(settingsStorageProvider).readCommandChannels(),
            statuses: state.value?.statuses ?? current.statuses,
            error: error.userMessage,
          ),
        );
      }
    } finally {
      _updating = false;
    }
  }

  Future<void> setShizukuEnabled(bool value) async {
    final current = state.value;
    if (current == null || current.settings.root) return;
    final next = CommandChannelSettings(
      shizuku: value,
      root: current.settings.root,
    );
    await _operate(() async {
      final driver = ref.read(commandChannelDriverProvider);
      if (value) {
        final statuses = await driver.status();
        if (!ref.mounted) return;
        state = AsyncData(
          CommandChannelsState(
            settings: current.settings,
            statuses: statuses,
            busy: true,
          ),
        );
        if (!hasShizukuDevicePermission(statuses)) {
          throw OperationFailure(
            statuses
                    .where((status) => status.channel == 'shizuku')
                    .firstOrNull
                    ?.message ??
                '无法读取 Shizuku 授权状态',
          );
        }
      }
      await _saveSettings(current.settings, next);
    }, settings: next);
  }

  Future<void> setRootEnabled(bool value) async {
    final current = state.value;
    if (current == null || current.settings.root == value) return;
    final next = CommandChannelSettings(
      shizuku: current.settings.shizuku,
      root: value,
    );
    await _operate(() async {
      const root = RootCommandDriver();
      if (value) {
        await root.authorize();
        if (!ref.mounted) return;
        await _saveSettings(current.settings, next);
      } else {
        await Future.wait([
          _saveSettings(current.settings, next),
          root.cancelDeviceAction(),
        ]);
      }
    }, settings: next);
  }

  Future<void> _saveSettings(
    CommandChannelSettings previous,
    CommandChannelSettings next,
  ) async {
    final storage = ref.read(settingsStorageProvider);
    final driver = ref.read(commandChannelDriverProvider);
    await storage.writeCommandChannels(next);
    try {
      await driver.setEnabled(next.channels);
    } on Failure {
      await storage.writeCommandChannels(previous);
      await driver.setEnabled(previous.channels);
      rethrow;
    }
  }

  Future<void> authorize(String channel) =>
      _operate(() => ref.read(commandChannelDriverProvider).authorize(channel));
  Future<void> initialize(String channel) => _operate(
    () => ref.read(commandChannelDriverProvider).initialize(channel),
  );
  Future<void> open(String channel) => _operate(
    () => ref.read(commandChannelDriverProvider).openSettings(channel),
  );
}

/// Shizuku 按服务状态绑定。Root 在每次实际调用时确认执行身份。
Future<List<CommandChannelSnapshot>> commandSnapshots(Ref ref) async {
  final settings = ref.read(settingsStorageProvider).readCommandChannels();
  final root = [if (settings.root) CommandChannelSnapshot.rootDevice];
  if (settings.channels.isEmpty) return root;
  final driver = ref.read(commandChannelDriverProvider);
  List<CommandChannelStatus> statuses;
  try {
    await driver.setEnabled(settings.channels);
    if (settings.root) return root;
    statuses = await driver.status();
  } on CommandChannelFailure {
    // An unavailable optional channel must not prevent an ordinary chat run.
    return root;
  }
  return [
    ...root,
    for (final status in statuses)
      if (settings.channels.contains(status.channel) &&
          status.state == 'ready' &&
          status.uid != null &&
          status.revision != null)
        CommandChannelSnapshot(
          channel: ExecutionChannel.values.byName(status.channel),
          uid: status.uid!,
          revision: status.revision!,
        ),
  ];
}
