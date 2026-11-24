import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_motion.dart';
import '../tools/run_recovery_controller.dart';
import '../execution/execution_controller.dart';
import 'chat_controller.dart';
import 'tool_confirmation_host.dart';

/// 切换查看位置后仍能回到根任务；启动失败与中断任务都有可达入口。
class ChatRunBanner extends ConsumerWidget {
  const ChatRunBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summarizing = ref.watch(
      chatControllerProvider.select((state) => state.summarizing),
    );
    final recovery = ref.watch(runRecoveryControllerProvider);
    final count = recovery.value?.length ?? 0;
    final execution = ref.watch(
      executionControllerProvider.select(
        (state) =>
            (confirmation: state.confirmation, userAction: state.userAction),
      ),
    );
    final pending = execution.confirmation;
    final userAction = execution.userAction;
    final reopen = ToolConfirmationHost.reopenOf(context);
    final canConfirm = pending != null && reopen != null;
    if (count == 0 &&
        !recovery.hasError &&
        !canConfirm &&
        userAction == null &&
        !summarizing) {
      return const _BannerReveal();
    }
    return _BannerReveal(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.xs,
              children: [
                if (summarizing) const Text('正在整理上下文摘要 · 可停止'),
                if (userAction != null)
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const ValueKey('waiting-for-user'),
                      padding: const EdgeInsets.all(AppSpacing.s),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('等待你操作 · AI 已暂停'),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 96),
                            child: SingleChildScrollView(
                              child: Text(userAction.prompt),
                            ),
                          ),
                          TextButton.icon(
                            key: const ValueKey('continue-user-action'),
                            icon: const Icon(LucideIcons.play),
                            label: const Text('继续，让 AI 接管'),
                            onPressed: () => ref
                                .read(executionControllerProvider.notifier)
                                .continueRun(
                                  userAction.runId,
                                  userAction.toolCallId,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (canConfirm)
                  TextButton(
                    key: const ValueKey('reopen-tool-confirmation'),
                    onPressed: reopen,
                    child: const Text('查看待确认动作'),
                  ),
                if (recovery.hasError)
                  TextButton(
                    onPressed: () => context.push('/tasks'),
                    child: const Text('中断任务读取失败 · 重试'),
                  )
                else if (count > 0)
                  TextButton(
                    key: const ValueKey('open-recovered-runs'),
                    onPressed: () => context.push('/tasks'),
                    child: Text('查看中断任务（$count）'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerReveal extends StatefulWidget {
  const _BannerReveal({this.child});
  final Widget? child;
  @override
  State<_BannerReveal> createState() => _BannerRevealState();
}

class _BannerRevealState extends State<_BannerReveal>
    with SingleTickerProviderStateMixin {
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: .78,
  );
  late final _progress = AnimationController.unbounded(vsync: this);
  Widget? _content;
  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = AppMotion.reduce(context);
    if (_reduced != reduced) {
      _reduced = reduced;
      _transition();
    }
  }

  @override
  void didUpdateWidget(_BannerReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.child == null) != (widget.child == null)) _transition();
  }

  Future<void> _transition() async {
    final target = widget.child == null ? 0.0 : 1.0;
    if (_reduced == true ||
        _progress.value == target && !_progress.isAnimating) {
      _progress.value = target;
      _content = widget.child;
      return;
    }
    try {
      await _progress
          .animateWith(
            SpringSimulation(
              _spring,
              _progress.value,
              target,
              _progress.velocity,
              snapToEnd: true,
            ),
          )
          .orCancel;
      if (mounted && widget.child == null) setState(() => _content = null);
    } on TickerCanceled {
      // 状态再次变化时沿用当前速度。
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child != null) _content = widget.child;
    if (_content == null) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: widget.child == null,
      child: ExcludeSemantics(
        excluding: widget.child == null,
        child: AnimatedBuilder(
          animation: _progress,
          builder: (_, child) => Transform.scale(
            alignment: Alignment.topCenter,
            scale: 1 + (_progress.value - 1).clamp(0.0, .05),
            child: child,
          ),
          child: ClipRRect(
            clipper: _BannerClip(_progress),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: _content!,
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerClip extends CustomClipper<RRect> {
  _BannerClip(this.progress) : super(reclip: progress);
  final Animation<double> progress;
  @override
  RRect getClip(Size size) {
    final t = progress.value.clamp(0.0, 1.0);
    final w = 48 + (size.width - 48) * t;
    return RRect.fromRectAndRadius(
      Rect.fromLTWH((size.width - w) / 2, 0, w, 10 + (size.height - 10) * t),
      Radius.circular(12 * (1 - t)),
    );
  }

  @override
  bool shouldReclip(_BannerClip oldClipper) => oldClipper.progress != progress;
}
