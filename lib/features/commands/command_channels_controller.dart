import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../data/datasources/local/settings_storage.dart';
import '../../../data/models/command_channel.dart';
import '../../../data/models/tool_call_record.dart';
import 'command_api.g.dart';
import 'command_channel_driver.dart';

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
            statuses: current.statuses,
            error: error.userMessage,
          ),
        );
      }
    } finally {
      _updating = false;
    }
  }

  Future<void> enable(ExecutionChannel channel, bool value) async {
    final current = state.value;
    if (current == null) return;
    final next = current.settings.select(channel, value);
    await _operate(() async {
      final storage = ref.read(settingsStorageProvider);
      final driver = ref.read(commandChannelDriverProvider);
      await storage.writeCommandChannels(next);
      try {
        await driver.setEnabled(next.channels);
      } on Failure {
        await storage.writeCommandChannels(current.settings);
        await driver.setEnabled(current.settings.channels);
        rethrow;
      }
    }, settings: next);
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

/// Only setup for explicitly enabled channels participates in run creation.
Future<List<CommandChannelSnapshot>> commandSnapshots(Ref ref) async {
  final settings = ref.read(settingsStorageProvider).readCommandChannels();
  if (settings.channels.isEmpty) return const [];
  final driver = ref.read(commandChannelDriverProvider);
  List<CommandChannelStatus> statuses;
  try {
    await driver.setEnabled(settings.channels);
    statuses = await driver.status();
  } on CommandChannelFailure {
    // An unavailable optional channel must not prevent an ordinary chat run.
    return const [];
  }
  return [
    for (final status in statuses)
      if (settings.channels.contains(status.channel) &&
          status.state == 'ready' &&
          status.uid != null &&
          status.revision != null &&
          status.home != null)
        CommandChannelSnapshot(
          channel: ExecutionChannel.values.byName(status.channel),
          uid: status.uid!,
          revision: status.revision!,
          home: status.home!,
        ),
  ];
}
