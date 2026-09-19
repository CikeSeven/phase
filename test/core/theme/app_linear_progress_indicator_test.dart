import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_progress_indicator/m3e_progress_indicator.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_linear_progress_indicator.dart';

void main() {
  testWidgets('波浪进度实时更新，减少动画仍更新读数，离屏和销毁停止动画', (tester) async {
    var progress = 0.25;
    var reduced = false;
    var visible = true;
    var indeterminate = false;
    late StateSetter update;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: TickerMode(
                enabled: visible,
                child: Scaffold(
                  body: AppLinearProgressIndicator(
                    value: indeterminate ? null : progress,
                    semanticsLabel: '下载中',
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final indicator = find.byType(AppLinearProgressIndicator);
    expect(tester.getSize(indicator).height, 10);
    expect(tester.getSemantics(indicator).value, '25%');
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    update(() => progress = 0.6);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getSemantics(indicator).value, '60%');
    expect(
      tester
          .widget<M3ELinearWavyProgressIndicator>(
            find.byType(M3ELinearWavyProgressIndicator),
          )
          .value,
      0.6,
    );
    update(() => visible = false);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    update(() {
      visible = true;
      reduced = true;
      progress = 0.8;
    });
    await tester.pumpAndSettle();
    expect(tester.getSemantics(indicator).value, '80%');
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.8,
    );
    expect(tester.hasRunningAnimations, isFalse);
    update(() => indeterminate = true);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(indicator).value, '进行中');
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
    expect(tester.hasRunningAnimations, isFalse);
    update(() => reduced = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
