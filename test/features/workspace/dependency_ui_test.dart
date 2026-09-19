import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_linear_progress_indicator.dart';
import 'package:phase/data/models/workspace.dart';
import 'package:phase/features/workspace/dependency_controller.dart';
import 'package:phase/features/workspace/dependency_profiles.dart';
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
    testWidgets('依赖安装列表、确认、进度与取消 $size/$scale/$dark', (tester) async {
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

      // Ready environment shows the dependency section with profiles.
      // The section starts outside the build cache, so scroll to it first.
      await tester.scrollUntilVisible(
        find.text('环境依赖'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();
      expect(find.text('环境依赖'), findsOneWidget);
      expect(find.text('Python'), findsOneWidget);
      expect(find.text('Node.js'), findsOneWidget);
      expect(find.text('Git 与搜索工具', skipOffstage: false), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('git version 2.43.0 · 2024-05-01'),
        150,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();
      expect(find.text('git version 2.43.0 · 2024-05-01'), findsOneWidget);
      expect(find.text(DependencyProfile.python.description), findsOneWidget);
      expect(find.byType(AppLinearProgressIndicator), findsNothing);

      // Tapping a profile asks for confirmation with its packages.
      await _dragUntilTappable(tester, find.text('Python'));
      await tester.tap(find.text('Python'));
      await tester.pumpAndSettle();
      expect(find.text('安装Python？'), findsOneWidget);
      expect(
        find.textContaining('python3、python3-pip、python3-venv'),
        findsOneWidget,
      );
      // Actions stay fixed at the dialog bottom even at large text scales.
      await tester.tap(find.text('安装'));
      await tester.pumpAndSettle();
      expect(operation.installed, ['python']);
      expect(operation.cancelled, isFalse);

      // Busy install shows an indeterminate bar and step log lines.
      operation.update(
        const DependencyOperation(
          busy: true,
          profileId: 'python',
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
      expect(find.text('正在安装 Python'), findsOneWidget);
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

      operation.update(const DependencyOperation(error: '软件源更新失败，请检查网络后重试'));
      await tester.pump();
      expect(
        find.text('软件源更新失败，请检查网络后重试', skipOffstage: false),
        findsOneWidget,
      );

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
      await tester.pump();
    }
    for (var i = 0; i < 60; i++) {
      if (target.hitTestable().evaluate().isNotEmpty) return;
      if (position.pixels <= 0) break;
      position.jumpTo((position.pixels - step).clamp(0.0, double.infinity));
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
  final installed = <String>[];
  @override
  Future<void> install(String profileId) async {
    installed.add(profileId);
  }
}

class _ControlledEnvironment extends EnvironmentController {
  @override
  EnvironmentOperation build() => const EnvironmentOperation();
  void update(EnvironmentOperation value) => state = value;
}
