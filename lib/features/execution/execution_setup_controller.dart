import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../data/datasources/local/settings_storage.dart';
import '../../../data/models/execution_scope.dart';
import 'channel_driver.dart';
import 'execution_api.g.dart';

part 'execution_setup_controller.g.dart';

@Riverpod(keepAlive: true)
ExecutionSetupApi executionSetupApi(Ref ref) => ExecutionSetupApi();

class ExecutionSetupState {
  const ExecutionSetupState({
    this.scope = const ExecutionScope(),
    this.grants = const AsyncLoading(),
    this.capabilities = const AsyncLoading(),
  });
  final ExecutionScope scope;
  final AsyncValue<List<FileGrant>> grants;
  final AsyncValue<ExecutionCapabilities> capabilities;

  ExecutionSetupState copyWith({
    ExecutionScope? scope,
    AsyncValue<List<FileGrant>>? grants,
    AsyncValue<ExecutionCapabilities>? capabilities,
  }) => ExecutionSetupState(
    scope: scope ?? this.scope,
    grants: grants ?? this.grants,
    capabilities: capabilities ?? this.capabilities,
  );
}

@Riverpod(keepAlive: true, dependencies: [settingsStorage])
class ExecutionSetupController extends _$ExecutionSetupController {
  bool _busy = false;
  Future<void>? _grantsLoading;
  Future<void>? _capabilitiesLoading;
  @override
  FutureOr<ExecutionSetupState> build() => ExecutionSetupState(
    scope: ref.read(settingsStorageProvider).readExecutionScope(),
  );

  Future<void> load() async {
    if (_busy) return;
    try {
      final scope = ref.read(settingsStorageProvider).readExecutionScope();
      state = AsyncData(
        (state.value ?? const ExecutionSetupState()).copyWith(scope: scope),
      );
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      return;
    }
    await loadCapabilities();
  }

  Future<void> loadGrants() => _grantsLoading ??= _loadGrants().whenComplete(
    () => _grantsLoading = null,
  );

  Future<void> _loadGrants() async {
    final value = state.value;
    if (value == null) return;
    state = AsyncData(value.copyWith(grants: const AsyncLoading()));
    final grants = await AsyncValue.guard(
      () => _boundary(ref.read(executionSetupApiProvider).fileGrants),
    );
    if (ref.mounted && state.value != null) {
      state = AsyncData(state.requireValue.copyWith(grants: grants));
    }
  }

  Future<void> loadCapabilities() => _capabilitiesLoading ??=
      _loadCapabilities().whenComplete(() => _capabilitiesLoading = null);

  Future<void> _loadCapabilities() async {
    final value = state.value;
    if (value == null) return;
    state = AsyncData(value.copyWith(capabilities: const AsyncLoading()));
    final capabilities = await AsyncValue.guard(
      () => ref.read(channelDriverProvider).queryCapabilities(),
    );
    if (ref.mounted && state.value != null) {
      state = AsyncData(
        state.requireValue.copyWith(capabilities: capabilities),
      );
    }
  }

  Future<FileGrant?> chooseFile(bool directory) async {
    if (_busy) throw const OperationFailure('请等待当前操作完成');
    if (_grantsLoading != null) {
      throw const OperationFailure('请等待文件授权读取完成');
    }
    _busy = true;
    try {
      return await _boundary(
        () => ref.read(executionSetupApiProvider).selectFile(directory),
        timeout: const Duration(minutes: 2),
      );
    } finally {
      _busy = false;
      if (ref.mounted) unawaited(loadGrants());
    }
  }

  Future<void> save(ExecutionScope scope) async {
    if (_busy) throw const OperationFailure('请等待当前操作完成');
    _busy = true;
    try {
      await ref.read(settingsStorageProvider).writeExecutionScope(scope);
    } finally {
      _busy = false;
    }
  }

  Future<void> release(String uri) async {
    if (_busy) throw const OperationFailure('请等待当前操作完成');
    if (_grantsLoading != null) {
      throw const OperationFailure('请等待文件授权读取完成');
    }
    _busy = true;
    try {
      await _boundary(
        () => ref.read(executionSetupApiProvider).releaseFileGrant(uri),
      );
      final settings = ref.read(settingsStorageProvider);
      final old = settings.readExecutionScope();
      await settings.writeExecutionScope(
        ExecutionScope(
          fileUris: old.fileUris.where((value) => value != uri).toList(),
        ),
      );
    } finally {
      _busy = false;
      if (ref.mounted) unawaited(loadGrants());
    }
  }

  Future<void> openPermission(PermissionScreen screen) => _boundary(
    () => ref.read(executionSetupApiProvider).openPermissionSettings(screen),
  );

  Future<T> _boundary<T>(
    Future<T> Function() action, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      return await action().timeout(timeout);
    } on PlatformException catch (error) {
      throw ExecutionFailure(
        ExecutionFailureCode.values
                .where((code) => code.name == error.code)
                .firstOrNull ??
            ExecutionFailureCode.unavailable,
      );
    } on MissingPluginException {
      throw const ExecutionFailure(ExecutionFailureCode.unavailable);
    } on TimeoutException {
      throw const ExecutionFailure(ExecutionFailureCode.timeout);
    }
  }
}
