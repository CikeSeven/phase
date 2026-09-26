import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/tool_call_record.dart';
import '../execution/execution_controller.dart';
import '../tools/tool_executor.dart';
import 'tool_confirmation_sheet.dart';

/// 应用级展示端：路由与生命周期变化只移交展示权，不决定/重置待确认动作。
class ToolConfirmationHost extends ConsumerStatefulWidget {
  const ToolConfirmationHost({
    required this.navigatorKey,
    required this.child,
    super.key,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  static VoidCallback? reopenOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ConfirmationPresentation>()
      ?.reopen;

  @override
  ConsumerState<ToolConfirmationHost> createState() =>
      _ToolConfirmationHostState();
}

class _ToolConfirmationHostState extends ConsumerState<ToolConfirmationHost>
    with WidgetsBindingObserver {
  ModalBottomSheetRoute<ToolConfirmationOutcome>? _route;
  ToolConfirmationRequest? _shown;
  String? _dismissedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        didChangeAppLifecycleState(
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground) _dismissedId = null;
    ref.read(executionControllerProvider.notifier).setForeground(foreground);
    _scheduleSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final route = _route;
    _route = null;
    // 不在祖先销毁过程中修改 Navigator；仍挂接时在下一帧移除这一条路由。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.navigator != null && route!.isActive) {
        route.navigator!.removeRoute(route);
      }
    });
    super.dispose();
  }

  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _sync() {
    final state = ref.read(executionControllerProvider);
    final request = state.foreground ? state.confirmation : null;
    if (_route != null && (!identical(_shown, request) || request == null)) {
      final old = _route!;
      _route = null;
      _shown = null;
      if (old.isActive) old.navigator?.removeRoute(old);
    }
    if (request == null ||
        _route != null ||
        request.record.id == _dismissedId) {
      return;
    }
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final route = ModalBottomSheetRoute<ToolConfirmationOutcome>(
      builder: (_) => ToolConfirmationSheet(request: request),
      isScrollControlled: true,
      useSafeArea: true,
      barrierLabel: MaterialLocalizations.of(navigator.context)
          .modalBarrierDismissLabel,
    );
    _route = route;
    _shown = request;
    unawaited(
      navigator.push(route).then((outcome) {
        if (!mounted || !identical(_route, route)) return;
        _route = null;
        _shown = null;
        _dismissedId = request.record.id;
        final controller = ref.read(executionControllerProvider.notifier);
        if (!ref.read(executionControllerProvider).foreground) return;
        switch (outcome) {
          case ToolConfirmationOutcome.allowOnce:
          case ToolConfirmationOutcome.allowApplicationOperationsForRun:
            controller.decide(
              request.record.runId,
              request.record.id,
              ToolDecision.approved,
            );
          case ToolConfirmationOutcome.reject:
            controller.decide(
              request.record.runId,
              request.record.id,
              ToolDecision.rejected,
            );
          case ToolConfirmationOutcome.stopTask:
            controller.stopRun(request.record.runId);
          case ToolConfirmationOutcome.expired:
          case null:
            // 关闭只是未决定。到期/停止由应用级控制器收口。
            break;
        }
        _scheduleSync();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(executionControllerProvider, (previous, next) {
      _scheduleSync();
      if (next.failure != null && !identical(previous?.failure, next.failure)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final context = widget.navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              buildAppSnackBar(content: Text(next.failure!.userMessage)),
            );
          }
        });
      }
    });
    return _ConfirmationPresentation(
      reopen: () {
        _dismissedId = null;
        _scheduleSync();
      },
      child: widget.child,
    );
  }
}

class _ConfirmationPresentation extends InheritedWidget {
  const _ConfirmationPresentation({required this.reopen, required super.child});
  final VoidCallback reopen;

  @override
  bool updateShouldNotify(_ConfirmationPresentation oldWidget) => false;
}
