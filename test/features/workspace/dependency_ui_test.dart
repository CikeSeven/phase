import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_dialog.dart';
import 'package:phase/core/widgets/app_icon_badge.dart';
import 'package:phase/core/widgets/app_linear_progress_indicator.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/features/workspace/dependency_controller.dart';
import 'package:phase/features/workspace/dependency_profiles.dart';
import 'package:phase/features/workspace/installation_progress.dart';
import 'package:phase/features/workspace/process_api.g.dart';
import 'package:phase/features/workspace/workspace_controller.dart';
import 'package:phase/features/workspace/workspaces_page.dart';

void main() {
  for (final (size, scale, dark) in [
    (const Size(360, 800), 1.0, false),
    (const Size(360, 800), 1.0, true),
    (const Size(320, 700), 2.0, false),
    (const Size(800, 360), 2.0, true),
  ]) {
    testWidgets('依赖安装条目、确认、进度与取消 $size/$scale/$dark', (tester) async {
      final operation = _ControlledDependency();
      final environment = _ControlledEnvironment();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> pump() => tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentControllerProvider.overrideWith(() => environment),
            dependencyControllerProvider.overrideWith(() => operation),
            runtimeEnvironmentProvider.overrideWith(
              (_) => Stream.value(
                RuntimeEnvironment(
                  phase: EnvironmentPhase.ready,
                  rootPath: '/fixture/root',
                  revision: 'fixture',
                  installedDependencies: {
                    'git-tools': InstalledDependency(
                      installedAt: DateTime.utc(2024, 5, 1),
                      version: 'git version 2.43.0',
                    ),
                  },
                ),
              ),
            ),
            linuxPlatformInfoProvider.overrideWith(
              (_) async => LinuxPlatformInfo(
                rootDirectory: '/test',
                abi: 'arm64-v8a',
                available: true,
                freeBytes: 1024 * 1024 * 1024,
              ),
            ),
          ],
          child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const WorkspacesPage(),
          ),
        ),
      );
      await pump();

      // Ready environment shows the merged dependency tile; a partially
      // installed environment names what is already present.
      await tester.scrollUntilVisible(
        find.text('环境依赖'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();
      expect(find.text('环境依赖'), findsOneWidget);
      expect(find.text('开发依赖'), findsOneWidget);
      expect(find.text('已安装 Git 与搜索工具，重新安装可补齐其余依赖'), findsOneWidget);
      expect(find.byType(AppLinearProgressIndicator), findsNothing);

      // Tapping the tile asks for confirmation with every package.
      await _dragUntilTappable(tester, find.text('开发依赖'));
      await tester.tap(find.text('开发依赖'));
      await tester.pumpAndSettle();
      expect(find.text('安装环境依赖？'), findsOneWidget);
      expect(
        find.textContaining('python3、python3-pip、python3-venv'),
        findsOneWidget,
      );
      expect(find.textContaining('nodejs、npm'), findsOneWidget);
      // Actions stay fixed at the dialog bottom even at large text scales.
      await tester.tap(find.text('安装'));
      await tester.pumpAndSettle();
      expect(operation.installed, 1);
      expect(operation.cancelled, isFalse);

      // Busy install shows an indeterminate bar and step log lines.
      operation.update(
        const DependencyOperation(
          busy: true,
          step: DependencyStep.installing,
          logTail: ['读取包列表', '解压 python3'],
        ),
      );
      await tester.pump();
      final indicator = find.byType(AppLinearProgressIndicator);
      expect(indicator, findsOneWidget);
      expect(
        tester.widget<AppLinearProgressIndicator>(indicator).value,
        isNull,
      );
      expect(find.text('安装依赖'), findsOneWidget);
      expect(find.text('开发依赖 · 第 3 / 4 步'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('解压 python3'),
        150,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();
      expect(find.text('解压 python3'), findsOneWidget);
      await _dragUntilTappable(tester, find.text('取消安装'));
      await tester.tap(find.text('取消安装'));
      await tester.pump();
      expect(operation.cancelled, isTrue);

      operation.update(
        const DependencyOperation(error: '软件源更新失败，请检查网络后重试', failed: true),
      );
      await tester.pumpAndSettle();

      // Failures keep the retry button resubmitting the same full install;
      // scroll first because the row may sit outside the build cache.
      await _dragUntilTappable(tester, find.text('重试'));
      expect(find.text('软件源更新失败，请检查网络后重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(operation.installed, 2);

      // Environment-level operations hide the dependency section.
      operation.update(const DependencyOperation());
      environment.update(
        const EnvironmentOperation(
          busy: true,
          phase: EnvironmentPhase.downloading,
        ),
      );
      await tester.pump();
      expect(find.text('环境依赖', skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('全部安装后展示成功标记与概览，重装走独立确认', (tester) async {
    final operation = _ControlledDependency();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dependencyControllerProvider.overrideWith(() => operation),
          runtimeEnvironmentProvider.overrideWith(
            (_) => Stream.value(
              RuntimeEnvironment(
                phase: EnvironmentPhase.ready,
                rootPath: '/fixture/root',
                revision: 'fixture',
                installedDependencies: {
                  for (final profile in DependencyProfile.all)
                    profile.id: InstalledDependency(
                      installedAt: DateTime.utc(2024, 5, 1),
                      version: '${profile.label} 1.0',
                    ),
                },
              ),
            ),
          ),
          linuxPlatformInfoProvider.overrideWith(
            (_) async => LinuxPlatformInfo(
              rootDirectory: '/test',
              abi: 'arm64-v8a',
              available: true,
              freeBytes: 1024 * 1024 * 1024,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const WorkspacesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('环境依赖'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    // A fully installed tile carries the success badge, a reinstall button
    // and no download icon.
    final installedBadge = find.descendant(
      of: find.byType(AppIconBadge),
      matching: find.byIcon(Symbols.check_circle),
    );
    expect(installedBadge, findsOneWidget);
    expect(find.byIcon(Symbols.refresh), findsOneWidget);
    expect(find.byIcon(Symbols.download), findsNothing);
    expect(find.text('全部已安装 · 2024-05-01'), findsOneWidget);

    // Tapping the installed tile opens the info overview, not install consent.
    await _dragUntilTappable(tester, find.text('开发依赖'));
    await tester.tap(find.text('开发依赖'));
    await tester.pumpAndSettle();
    expect(find.text('Python：Python 1.0'), findsOneWidget);
    expect(find.text('Node.js：Node.js 1.0'), findsOneWidget);
    expect(find.text('Git 与搜索工具：Git 与搜索工具 1.0'), findsOneWidget);
    expect(find.text('安装环境依赖？'), findsNothing);

    // The tile's reinstall IconButton also exposes a tooltip with the same
    // text, so target the action button inside the open dialog only.
    final confirmReinstall = find.descendant(
      of: find.byType(AppDialog),
      matching: find.widgetWithText(FilledButton, '重新安装'),
    );
    await tester.tap(confirmReinstall);
    await tester.pumpAndSettle();
    expect(find.text('重新安装环境依赖？'), findsOneWidget);
    // Confirming the reinstall dialog dispatches the full install again.
    await tester.tap(confirmReinstall);
    await tester.pumpAndSettle();
    expect(operation.installed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未安装环境时不显示依赖区', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dependencyControllerProvider.overrideWith(_ControlledDependency.new),
          runtimeEnvironmentProvider.overrideWith(
            (_) => Stream.value(const RuntimeEnvironment()),
          ),
          linuxPlatformInfoProvider.overrideWith(
            (_) async => LinuxPlatformInfo(
              rootDirectory: '/test',
              abi: 'arm64-v8a',
              available: true,
              freeBytes: 1024 * 1024 * 1024,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const WorkspacesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('环境依赖', skipOffstage: false), findsNothing);
  });

  testWidgets('软件源阶段展示整体位置、等待时间与新输出，不将静默判断为网络故障', (tester) async {
    final started = DateTime.now();
    Future<void> show(DateTime updated, List<String> lines) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: InstallationProgress(
                title: '开发依赖',
                steps: [for (final step in DependencyStep.values) step.label],
                current: DependencyStep.updating.index,
                description: DependencyStep.updating.description,
                startedAt: started,
                updatedAt: updated,
                lines: lines,
              ),
            ),
          ),
        );
    await show(started, ['Get: 1 http://fixture/ubuntu noble InRelease']);
    expect(find.text('开发依赖 · 第 2 / 4 步'), findsOneWidget);
    expect(find.textContaining('尚未安装 Python'), findsOneWidget);
    // Test time is passed explicitly because DateTime.now is not fake_async's clock.
    await show(started.subtract(const Duration(seconds: 25)), [
      'Get: 1 http://fixture/ubuntu noble InRelease',
    ]);
    expect(find.textContaining('可能在等待网络或处理文件'), findsOneWidget);
    await show(DateTime.now(), [
      '42% [3 Packages 420 kB/1000 kB 42%] 100 kB/s 6s',
    ]);
    expect(find.textContaining('可能在等待网络或处理文件'), findsNothing);
    expect(find.textContaining('420 kB/1000 kB'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

/// Cached offscreen list items still build, so scrollUntilVisible can stop
/// without making the target tappable; step the scroll position (no fling
/// inertia) until the hit test succeeds.
Future<void> _dragUntilTappable(WidgetTester tester, Finder target) async {
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable))
      .position;
  for (var step = 120.0; step > 10; step /= 2) {
    for (var i = 0; i < 60; i++) {
      if (target.hitTestable().evaluate().isNotEmpty) return;
      if (position.pixels >= position.maxScrollExtent) break;
      position.jumpTo(
        (position.pixels + step).clamp(0.0, position.maxScrollExtent),
      );
      // Two frames: tall lists may need a second pass to finish relayout.
      await tester.pump();
      await tester.pump();
    }
    for (var i = 0; i < 60; i++) {
      if (target.hitTestable().evaluate().isNotEmpty) return;
      if (position.pixels <= 0) break;
      position.jumpTo((position.pixels - step).clamp(0.0, double.infinity));
      await tester.pump();
      await tester.pump();
    }
  }
  fail('target never became tappable: $target');
}

class _ControlledDependency extends DependencyController {
  @override
  DependencyOperation build() => const DependencyOperation();
  void update(DependencyOperation value) => state = value;
  @override
  void cancel() => cancelled = true;
  bool cancelled = false;
  int installed = 0;
  @override
  Future<void> install() async {
    installed++;
  }
}

class _ControlledEnvironment extends EnvironmentController {
  @override
  EnvironmentOperation build() => const EnvironmentOperation();
  void update(EnvironmentOperation value) => state = value;
}
