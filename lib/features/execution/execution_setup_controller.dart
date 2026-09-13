import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../data/datasources/local/settings_storage.dart';
import '../../../data/models/execution_scope.dart';
import 'channel_driver.dart';
import 'execution_api.g.dart';
import 'application_policy_bridge.dart';
import 'execution_controller.dart';

part 'execution_setup_controller.g.dart';

@Riverpod(keepAlive: true)
ExecutionSetupApi executionSetupApi(Ref ref) => ExecutionSetupApi();

class ExecutionSetupState {
  const ExecutionSetupState({
    this.scope = const ExecutionScope(),
    this.grants = const [],
    this.applications = const [],
    this.capabilities,
  });
  final ExecutionScope scope;
  final List<FileGrant> grants;
  final List<InstalledApplication> applications;
  final ExecutionCapabilities? capabilities;
}

@Riverpod(keepAlive: true, dependencies: [settingsStorage])
class ExecutionSetupController extends _$ExecutionSetupController {
  bool _busy = false;
  @override
  FutureOr<ExecutionSetupState> build() => ExecutionSetupState(
    scope: ref.read(settingsStorageProvider).readExecutionScope(),
  );

  Future<void> load() async {
    if (_busy) return;
    _busy = true;
    state = const AsyncLoading();
    try {
      final api = ref.read(executionSetupApiProvider);
      final grants = await _boundary(api.fileGrants);
      final apps = await _boundary(api.installedApplications);
      final capabilities = await ref
          .read(channelDriverProvider)
          .queryCapabilities();
      if (ref.mounted) {
        state = AsyncData(
          ExecutionSetupState(
            scope: ref.read(settingsStorageProvider).readExecutionScope(),
            grants: grants,
            applications: apps,
            capabilities: capabilities,
          ),
        );
      }
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
    } finally {
      _busy = false;
    }
  }

  Future<FileGrant?> chooseFile(bool directory) async {
    if (_busy) return null;
    _busy = true;
    try {
      return await _boundary(
        () => ref.read(executionSetupApiProvider).selectFile(directory),
        timeout: const Duration(minutes: 2),
      );
    } finally {
      _busy = false;
      await load();
    }
  }

  Future<void> save(ExecutionScope scope) async {
    if (_busy) throw const OperationFailure('请等待当前操作完成');
    _busy = true;
    try {
      await ref.read(settingsStorageProvider).writeExecutionScope(scope);
      try {
        await _boundary(
          () => ref
              .read(executionSetupApiProvider)
              .updateApplicationPolicy(scope.appPolicy.toBridge()),
        );
      } on Failure {
        // 名单已保存而原生同步未确认时，停止当前任务，保留页面供重试。
        final runId = ref.read(executionControllerProvider).runId;
        if (runId != null) {
          ref.read(executionControllerProvider.notifier).stopRun(runId);
        }
        throw const OperationFailure('执行设置已保存，但权限同步失败；请重试。运行中的任务已停止。');
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> release(String uri) async {
    if (_busy) throw const OperationFailure('请等待当前操作完成');
    _busy = true;
    try {
      await _boundary(
        () => ref.read(executionSetupApiProvider).releaseFileGrant(uri),
      );
      final settings = ref.read(settingsStorageProvider);
      final old = settings.readExecutionScope();
      await settings.writeExecutionScope(
        ExecutionScope(
          appPolicy: old.appPolicy,
          fileUris: old.fileUris.where((value) => value != uri).toList(),
        ),
      );
    } finally {
      _busy = false;
      await load();
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
      if (error.code == 'applicationListUnavailable') {
        throw const OperationFailure('系统未返回应用列表，请检查应用列表访问权限或稍后重试');
      }
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
