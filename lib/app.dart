import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/theme_mode_controller.dart';
import 'features/tools/run_recovery_controller.dart';

/// 应用根组件：装配主题与路由。
class PhaseApp extends ConsumerStatefulWidget {
  const PhaseApp({super.key});

  @override
  ConsumerState<PhaseApp> createState() => _PhaseAppState();
}

class _PhaseAppState extends ConsumerState<PhaseApp> {
  @override
  void initState() {
    super.initState();
    // 错误保存在恢复控制器中，由聊天页提供重试入口。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(runRecoveryControllerProvider.notifier)
            .initialize()
            .catchError((Object _) {}),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    return MaterialApp.router(
      title: '相月',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
