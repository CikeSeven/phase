import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/data/models/model_catalog.dart';
import 'package:phase/data/models/model_request_record.dart';
import 'package:phase/data/models/token_usage.dart';
import 'package:phase/data/repositories/model_request_repository.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:phase/features/chat/context/context_builder.dart';
import 'package:phase/features/chat/context/context_meter.dart';
import 'package:phase/features/chat/context/context_preview.dart';
import 'package:phase/features/chat/context/context_usage_indicator.dart';

const _capture = bool.fromEnvironment('CAPTURE_CONTEXT');
const _captureKey = ValueKey('context-capture');
final _button = find.byKey(const ValueKey('chat-context-usage'));
final _popup = find.byKey(const ValueKey('context-usage-popover'));

ContextBuild _preview({int used = 32000, int total = 128000}) => ContextBuild(
  const [],
  used,
  ContextBudget(contextWindow: total),
  measurement: ContextMeasurement(
    conversationId: 'c',
    branchHeadId: 'u',
    generation: 'original',
    configurationFingerprint: 'config',
    configurationSnapshot: const {},
    inputFingerprint: 'input',
    messageIds: const ['u'],
    localInputTokens: used,
    estimatedInputTokens: used,
    windowTokens: total,
    outputReserveTokens: 4096,
    marginTokens: 1024,
    windowSource: ContextWindowSource.catalog,
    outputReserveSource: OutputReserveSource.localDefault,
    systemTokens: 0,
    toolTokens: 0,
    messageTokens: used,
    imageTokens: 0,
    measuredAt: DateTime(2026),
    triggerTokens: 90000,
    targetTokens: 50000,
  ),
);

ModelRequestRecord _request(
  String id, {
  TokenUsage? usage,
  bool inherited = false,
}) => ModelRequestRecord(
  id: id,
  conversationId: 'c',
  runId: 'run',
  profileId: 'p',
  protocol: 'openaiCompletions',
  requestedModelId: 'm',
  createdAt: DateTime(2026),
  startedAt: DateTime(2026),
  status: ModelRequestStatus.completed,
  usageComplete: true,
  usage: usage,
  isInherited: inherited,
);

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  double scale = 1,
  bool dark = false,
  String? conversationId = 'c',
  bool submitting = false,
  bool reducedMotion = false,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedMotion,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ContextUsageIndicator(
                      conversationId: conversationId,
                      submitting: submitting,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _UsageChatController extends ChatController {
  void generating(bool value) => state = state.copyWith(
    isGenerating: value,
    runningConversationId: 'c',
    clearContext: true,
  );
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
  });

  for (final (size, scale, dark, keyboard) in [
    (const Size(360, 780), 1.0, false, 0.0),
    (const Size(360, 780), 1.0, true, 240.0),
    (const Size(320, 720), 1.3, false, 260.0),
    (const Size(320, 720), 2.0, true, 260.0),
    (const Size(780, 360), 2.0, true, 100.0),
  ]) {
    testWidgets('百分比、浮层数据、上下定位和返回 $size $scale $dark', (tester) async {
      final previousShadows = debugDisableShadows;
      try {
        if (_capture) debugDisableShadows = false;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(tester.view.reset);
        var subscriptions = 0;
        final container = ProviderContainer(
          overrides: [
            contextPreviewProvider('c').overrideWith((ref) async => _preview()),
            conversationRequestsProvider('c').overrideWith((ref) {
              subscriptions++;
              return Stream.value([
                _request(
                  'a',
                  usage: const TokenUsage(
                    promptTokens: 100,
                    cacheReadTokens: 80,
                  ),
                ),
                _request('b'),
                _request(
                  'inherited',
                  usage: const TokenUsage(
                    promptTokens: 9000,
                    cacheReadTokens: 0,
                  ),
                  inherited: true,
                ),
              ]);
            }),
          ],
        );
        addTearDown(container.dispose);
        await _pump(tester, container, scale: scale, dark: dark);
        expect(subscriptions, 0);
        expect(find.text('25%'), findsOneWidget);
        expect(
          tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator),
              )
              .value,
          .25,
        );
        expect(tester.getSize(_button).shortestSide, greaterThanOrEqualTo(48));
        final ring = find.byType(CircularProgressIndicator);
        expect(tester.widget<CircularProgressIndicator>(ring).strokeWidth, 6);
        expect(
          tester.getSize(ring).width,
          closeTo(ContextUsageIndicator.diameter * scale, .01),
        );
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('上下文占用'), findsOneWidget);
        await tester.tap(_button);
        await tester.pumpAndSettle();
        expect(subscriptions, 1);
        expect(find.text('≈32000 token'), findsOneWidget);
        expect(find.text('128000 token'), findsOneWidget);
        expect(find.text('80.0%'), findsOneWidget);
        expect(find.textContaining('本会话缓存统计'), findsNothing);
        expect(find.textContaining('部分请求'), findsNothing);
        expect(find.textContaining('预计输入，不含'), findsNothing);
        expect(find.text('models.dev 目录窗口'), findsNothing);
        final rect = tester.getRect(_popup);
        expect(rect.width, 240);
        expect(rect.right, closeTo(size.width - 12, .01));
        expect(rect.bottom, lessThan(tester.getTopLeft(_button).dy));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.top, greaterThanOrEqualTo(0));
        if (_capture) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(_captureKey),
          );
          await tester.runAsync(() async {
            final capture = await boundary.toImage(pixelRatio: 2);
            final data = await capture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('build/context-preview');
            await folder.create(recursive: true);
            await File(
              '${folder.path}/${size.width.toInt()}-${size.height.toInt()}-$scale-$dark.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            capture.dispose();
          });
        }
        // 短屏上内容在弹层内滚动，不把面板挤到圆环下方或键盘后。
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(find.text('缓存命中率').hitTestable(), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_popup, findsNothing);
        expect(_button, findsOneWidget);
        for (var i = 0; i < 3; i++) {
          await tester.tap(_button);
          await tester.pump();
          await tester.tapAt(const Offset(4, 4));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(_popup, findsNothing);
        expect(
          ModalRoute.of(tester.element(_button))!.willHandlePopInternally,
          isFalse,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDisableShadows = previousShadows;
      }
    });
  }

  testWidgets('首次未知不伪造零，刷新、空值和失败保留本会话上次占用', (tester) async {
    var pending = Completer<ContextBuild?>();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        contextPreviewProvider('c').overrideWith((ref) => pending.future),
        conversationRequestsProvider('c')
            .overrideWith((ref) => Stream.value([])),
      ],
    );
    addTearDown(container.dispose);
    await _pump(tester, container);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(find.text('待估算'), findsNWidgets(2));
    expect(find.text('未提供'), findsOneWidget);
    pending.complete(_preview());
    await tester.pumpAndSettle();
    expect(find.text('25%'), findsOneWidget);
    pending = Completer<ContextBuild?>();
    container.invalidate(contextPreviewProvider('c'));
    await tester.pump();
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('≈32000 token'), findsOneWidget);
    pending.completeError(StateError('private endpoint must not be displayed'));
    await tester.pumpAndSettle();
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('≈32000 token'), findsOneWidget);
    expect(find.textContaining('private endpoint'), findsNothing);
    pending = Completer<ContextBuild?>()..complete(null);
    container.invalidate(contextPreviewProvider('c'));
    await tester.pumpAndSettle();
    expect(find.text('25%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('发送准备和整轮运行冻结，结束后圆环与数字平滑更新', (tester) async {
    ContextBuild? next = _preview();
    late _UsageChatController controller;
    final container = ProviderContainer(
      overrides: [
        chatControllerProvider.overrideWith(
          () => controller = _UsageChatController(),
        ),
        contextPreviewProvider('c').overrideWith((ref) async => next),
      ],
    );
    addTearDown(container.dispose);
    await _pump(tester, container);
    await _pump(tester, container, submitting: true);
    next = null;
    container.invalidate(contextPreviewProvider('c'));
    controller.generating(true);
    await tester.pumpAndSettle();
    expect(find.text('25%'), findsOneWidget);
    next = _preview(used: 64000);
    container.invalidate(contextPreviewProvider('c'));
    await tester.pumpAndSettle();
    await _pump(tester, container, submitting: false);
    expect(find.text('25%'), findsOneWidget);
    controller.generating(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final value = tester
        .widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .value!;
    expect(value, greaterThan(.25));
    expect(value, lessThan(.5));
    expect(find.text('${(value * 100).round()}%'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('空白会话常驻零，首次发送结束才更新，切换会话不串值', (tester) async {
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        contextPreviewProvider('c').overrideWith((ref) async {
          reads++;
          return _preview();
        }),
      ],
    );
    addTearDown(container.dispose);
    await _pump(tester, container, conversationId: null);
    expect(_button, findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(reads, 0);
    await _pump(tester, container, conversationId: null, submitting: true);
    await _pump(tester, container, submitting: true);
    expect(find.text('0%'), findsOneWidget);
    await _pump(tester, container);
    expect(find.text('25%'), findsOneWidget);
    await _pump(tester, container, conversationId: null);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('25%'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('非零小占用不四舍五入为零，减少动画时直接更新', (tester) async {
    var next = _preview(used: 1);
    final container = ProviderContainer(
      overrides: [
        contextPreviewProvider('c').overrideWith((ref) async => next),
      ],
    );
    addTearDown(container.dispose);
    await _pump(tester, container, reducedMotion: true);
    expect(find.text('<1%'), findsOneWidget);
    next = _preview(used: 64000);
    container.invalidate(contextPreviewProvider('c'));
    await tester.pump();
    await tester.pump();
    expect(find.text('50%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('超窗口圆环封顶但百分比不隐瞒，缓存零分母与失败分开', (tester) async {
    final stream = StreamController<List<ModelRequestRecord>>();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        contextPreviewProvider('c')
            .overrideWith((ref) async => _preview(used: 160000)),
        conversationRequestsProvider('c').overrideWith((ref) => stream.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await stream.close();
    });
    await _pump(tester, container);
    expect(find.text('125%'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      1,
    );
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(find.text('读取中…'), findsOneWidget);
    stream.add([
      _request(
        'a',
        usage: const TokenUsage(promptTokens: 0, cacheReadTokens: 0),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('不适用'), findsOneWidget);
    stream.addError(StateError('raw storage failure'));
    await tester.pumpAndSettle();
    expect(find.text('读取失败'), findsOneWidget);
    expect(find.text('不适用'), findsNothing);
    expect(find.text('≈160000 token'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
