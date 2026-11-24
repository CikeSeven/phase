import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_breathing_dots.dart';
import '../../../core/theme/app_motion.dart';
import '../../../data/models/attachment.dart';

const artifactPageBytes = 256 * 1024;

Future<({String text, int? next})> readArtifactPage(
  File file,
  int offset,
) async {
  final length = await file.length();
  final buffer = BytesBuilder(copy: false);
  await for (final chunk in file.openRead(
    offset,
    (offset + artifactPageBytes + 4).clamp(0, length),
  )) {
    buffer.add(chunk);
  }
  final bytes = buffer.takeBytes();
  var end = bytes.length.clamp(0, artifactPageBytes);
  // Keep the next page on a UTF-8 code point boundary, including split log writes.
  while (end > 0 && end < bytes.length && (bytes[end] & 0xc0) == 0x80) {
    end--;
  }
  return (
    text: utf8.decode(bytes.sublist(0, end), allowMalformed: true),
    next: offset + end < length ? offset + end : null,
  );
}

class ArtifactTextSheet extends StatefulWidget {
  const ArtifactTextSheet({
    super.key,
    required this.attachment,
    required this.initialText,
    required this.nextOffset,
  });
  final Attachment attachment;
  final String initialText;
  final int? nextOffset;
  @override
  State<ArtifactTextSheet> createState() => _ArtifactTextSheetState();
}

class _ArtifactTextSheetState extends State<ArtifactTextSheet> {
  final offsets = [0];
  late final pages = [widget.initialText];
  final scroll = ScrollController();
  int first = 0;
  late int? next = widget.nextOffset;
  var index = 0;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    scroll.addListener(_nearEnd);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void _nearEnd() {
    if (!busy &&
        error == null &&
        next != null &&
        scroll.position.isScrollingNotifier.value &&
        scroll.position.userScrollDirection == ScrollDirection.reverse &&
        scroll.position.extentAfter < 220) {
      _load(index + 1, append: true);
    }
  }

  Future<void> _load(int target, {bool append = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final offset = target < offsets.length ? offsets[target] : next!;
      final page = await readArtifactPage(
        File(widget.attachment.localPath),
        offset,
      );
      if (!mounted) return;
      setState(() {
        if (target == offsets.length) offsets.add(offset);
        index = target;
        if (!append) {
          first = target;
          pages.clear();
        }
        pages.add(page.text);
        next = page.next;
      });
      if (!append && scroll.hasClients) scroll.jumpTo(0);
    } on FileSystemException {
      if (mounted) setState(() => error = '读取产物文件失败，请重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheet(
    title: widget.attachment.name,
    subtitle:
        '${(widget.attachment.size / 1024).toStringAsFixed(1)} KiB${next != null || index > 0 ? ' · 第 ${index + 1} 页，每页最多 256 KiB' : ''}',
    footer: next != null || index > 0
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) Text(error!),
              Wrap(
                spacing: 16,
                children: [
                  TextButton(
                    onPressed: busy || index == 0
                        ? null
                        : () => _load(index - 1),
                    child: const Text('上一页'),
                  ),
                  TextButton(
                    onPressed: busy || next == null
                        ? null
                        : () => _load(index + 1),
                    child: Text(busy ? '读取中…' : '下一页'),
                  ),
                ],
              ),
            ],
          )
        : null,
    child: ListView.builder(
      controller: scroll,
      key: const ValueKey('tool-artifact-content'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      itemCount: pages.length + (next != null ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == pages.length) {
          return const Center(child: AppBreathingDots(label: '还有更多内容'));
        }
        return TweenAnimationBuilder<double>(
          key: ValueKey(first + i),
          tween: Tween(begin: i == 0 ? 1 : 0, end: 1),
          duration: AppMotion.reduce(context)
              ? Duration.zero
              : AppMotion.effects,
          curve: Curves.easeOutCubic,
          builder: (_, t, child) => Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: Opacity(opacity: t, child: child),
          ),
          child: SelectableText(
            pages[i],
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      },
    ),
  );
}
