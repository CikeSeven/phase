import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import 'execution_setup_controller.dart';

part 'application_names.g.dart';

/// 同一阅读页面共享名称查询；不申请权限，不把名称查询当成工具执行。
@riverpod
Future<Map<String, String>> applicationNames(Ref ref) async {
  try {
    final apps = await ref
        .watch(executionSetupApiProvider)
        .installedApplications()
        .timeout(const Duration(seconds: 15));
    return {
      for (final app in apps)
        if (app.label.isNotEmpty) app.packageName: app.label,
    };
  } on PlatformException {
    throw const OperationFailure('暂时无法读取应用名称');
  } on MissingPluginException {
    throw const OperationFailure('暂时无法读取应用名称');
  } on TimeoutException {
    throw const OperationFailure('读取应用名称超时');
  }
}
