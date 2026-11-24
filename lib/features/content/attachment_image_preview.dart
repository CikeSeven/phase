import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'attachment_image_frame.dart';

import 'package:flutter/physics.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_motion.dart';
import '../../data/models/attachment.dart';

/// 同一个附件可能出现在多个位置，每个缩略图持有独立的 Hero 标签。
class AttachmentImagePreview extends StatefulWidget {
  const AttachmentImagePreview({
    required this.attachment,
    required this.child,
    required this.onOpen,
    super.key,
  });
  final Attachment attachment;
  final Widget child;
  final ValueChanged<Object>? onOpen;

  @override
  State<AttachmentImagePreview> createState() => _AttachmentImagePreviewState();
}

class _AttachmentImagePreviewState extends State<AttachmentImagePreview>
    with SingleTickerProviderStateMixin {
  final _tag = Object();
  final _portal = OverlayPortalController();
  late final _progress = AnimationController.unbounded(vsync: this);
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 430,
    ratio: .72,
  );
  Rect _source = Rect.zero;

  void _peek() {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    _source = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    _portal.show();
    if (AppMotion.reduce(context)) {
      _progress.value = 1;
    } else {
      _progress.animateWith(
        SpringSimulation(
          _spring,
          _progress.value,
          1,
          _progress.velocity,
          snapToEnd: true,
        ),
      );
    }
  }

  Future<void> _dismiss() async {
    if (!_portal.isShowing) return;
    if (!AppMotion.reduce(context)) {
      try {
        await _progress
            .animateTo(
              0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
            )
            .orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (mounted) {
      _progress.value = 0;
      _portal.hide();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: (context) => LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final bounds = media.padding
            .deflateRect(
              media.viewInsets.deflateRect(Offset.zero & constraints.biggest),
            )
            .deflate(12);
        final width = math.max(0.0, math.min(320.0, bounds.width));
        final height = math.max(0.0, math.min(240.0, bounds.height));
        final left = (_source.center.dx - width / 2).clamp(
          bounds.left,
          math.max(bounds.left, bounds.right - width),
        );
        final above = _source.top - height - 8;
        final top = (above >= bounds.top ? above : _source.bottom + 8).clamp(
          bounds.top,
          math.max(bounds.top, bounds.bottom - height),
        );
        return Stack(
          children: [
            Positioned(
              left: left.toDouble(),
              top: top.toDouble(),
              width: width,
              height: height,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (_, child) => Opacity(
                      opacity: _progress.value.clamp(0, 1),
                      child: Transform.scale(
                        scale: .86 + .14 * _progress.value,
                        child: child,
                      ),
                    ),
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: Image.file(
                        File(widget.attachment.localPath),
                        frameBuilder: attachmentImageFrame,
                        fit: BoxFit.contain,
                        cacheWidth: 900,
                        errorBuilder: (_, _, _) =>
                            const Icon(LucideIcons.imageOff),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
    child: GestureDetector(
      onTap: widget.onOpen == null ? null : () => widget.onOpen!(_tag),
      onLongPressStart: widget.onOpen == null ? null : (_) => _peek(),
      onLongPressEnd: (_) => _dismiss(),
      onLongPressCancel: _dismiss,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (_, child) => Transform.scale(
          scale: 1 - .035 * _progress.value,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              color: Colors.black.withValues(
                alpha: .15 * _progress.value.clamp(0, 1),
              ),
            ),
            child: child,
          ),
        ),
        child: Hero(tag: _tag, child: widget.child),
      ),
    ),
  );
}
