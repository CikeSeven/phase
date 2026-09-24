import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/permission_mode.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/chat_input_bar.dart';
import 'package:phase/features/tools/tool.dart';

import '../tools/tool_loop_harness.dart';

const _capture = bool.fromEnvironment('CAPTURE_PERMISSIONS');
const _captureKey = ValueKey('permission-menu-capture');
final _button = find.byKey(const ValueKey('chat-agent-mode'));
Finder _option(PermissionMode mode) =>
    find.byKey(ValueKey('permission-mode-${mode.name}'));

Future<void> _settleIo(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  ToolLoopHarness h, {
  double scale = 1,
  bool dark = false,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatInputBar(),
            ),
          ),
        ),
      ),
    ),
  );
  await _settleIo(tester);
}

// 此处只验证运行状态驱动菜单；真实发送、快照与停止由 flow 测试覆盖。
class _ModeTestController extends ChatController {
  void setGenerating(bool value) => state = state.copyWith(isGenerating: value);
}

void main() {
  setUpAll(() async {
    if (!_capture) return;
    final bytes = await File('build/ui-preview/NotoSansCJKsc-Regular.otf')
        .readAsBytes();
    for (final family in ['Roboto', 'Ahem', 'sans-serif']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final family = entry['family'] as String;
      if (!family.toLowerCase().contains('material')) continue;
      final loader = FontLoader(family);
      for (final font
          in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  for (final (size, scale, dark, keyboard) in [
    (const Size(360, 800), 1.0, false, 0.0),
    (const Size(360, 800), 1.0, true, 240.0),
    (const Size(320, 700), 2.0, false, 0.0),
    (const Size(800, 360), 2.0, true, 0.0),
  ]) {
    testWidgets('三档菜单向上展开、逐项选择与取消 $size $scale $dark $keyboard', (
      tester,
    ) async {
      final previousShadows = debugDisableShadows;
      try {
        if (_capture) debugDisableShadows = false;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(tester.view.reset);
        late ToolLoopHarness h;
        await tester.runAsync(() async {
          h = await ToolLoopHarness.create(registry: ToolRegistry([]));
        });
        await _pump(tester, h, scale: scale, dark: dark);
        await tester.enterText(
          find.byKey(const ValueKey('chat-message-input')),
          '保留输入草稿',
        );
        await tester.tap(_button);
        await tester.pumpAndSettle();
        final menu = tester.widget<MenuAnchor>(
          find.ancestor(of: _button, matching: find.byType(MenuAnchor)),
        );
        expect(
          menu.style!.maximumSize!.resolve({})!.width,
          closeTo(304 * 2 / 3, .01),
        );
        for (final mode in PermissionMode.values) {
          expect(find.text(mode.description), findsNothing);
        }
        expect(
          h.container.read(conversationPermissionsProvider).value!.mode,
          PermissionMode.basic,
        );
        if (scale == 1) {
          expect(
            tester.getBottomLeft(_option(PermissionMode.fullAccess)).dy,
            lessThanOrEqualTo(tester.getTopLeft(_button).dy),
          );
        }
        if (_capture) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(_captureKey),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final folder = Directory('build/permission-preview');
            await folder.create(recursive: true);
            await File(
              '${folder.path}/${size.width.toInt()}-${size.height.toInt()}-$dark.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        for (final mode in [
          PermissionMode.fullAccess,
          PermissionMode.plan,
          PermissionMode.basic,
        ]) {
          if (_option(mode).evaluate().isEmpty) {
            await tester.tap(_button);
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(_option(mode));
          await tester.pumpAndSettle();
          await tester.tap(_option(mode));
          await tester.pumpAndSettle();
          expect(
            h.container.read(conversationPermissionsProvider).value!.mode,
            mode,
          );
          expect(_option(mode), findsNothing);
        }
        expect(find.text('保留输入草稿'), findsOneWidget);
        await tester.tap(_button);
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_option(PermissionMode.plan), findsNothing);
        expect(find.byType(ChatInputBar), findsOneWidget);
        await tester.tap(_button);
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        expect(_option(PermissionMode.plan), findsNothing);
        expect(
          h.container.read(conversationPermissionsProvider).value!.mode,
          PermissionMode.basic,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDisableShadows = previousShadows;
      }
    });
  }

  testWidgets('换会话和运行开始关闭菜单；快速开关不遗留返回层级', (tester) async {
    late ToolLoopHarness h;
    late _ModeTestController controller;
    late String id;
    await tester.runAsync(() async {
      h = await ToolLoopHarness.create(
        registry: ToolRegistry([]),
        controllerFactory: () => controller = _ModeTestController(),
      );
      id = (await (await h.conversations()).createConversation()).id;
    });
    await _pump(tester, h);
    for (var i = 0; i < 3; i++) {
      await tester.tap(_button);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(_button);
      await tester.pumpAndSettle();
    }
    expect(_option(PermissionMode.plan), findsNothing);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    await tester.runAsync(() => h.controller().openConversation(id));
    await _settleIo(tester);
    expect(_option(PermissionMode.plan), findsNothing);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    controller.setGenerating(true);
    await tester.pump();
    for (
      var i = 0;
      i < 30 && _option(PermissionMode.plan).evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_option(PermissionMode.plan), findsNothing);
    expect(tester.widget<TextButton>(_button).onPressed, isNull);
    controller.setGenerating(false);
    await _settleIo(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    // 上下文预览可能仍在读库，FakeAsync 中先显式排空关闭流程。
    await tester.runAsync(() async {
      h.container.dispose();
      await h.database.close();
    });
  });
}
