import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_dialog.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required TextScaler textScaler,
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (context) => AppDialog(
                  title: '删除工作区',
                  description: '此操作不可撤销。',
                  icon: Icons.delete,
                  content: const Text(
                    '将删除工作区的全部文件与历史记录，'
                    '包括导出的产物、上传的附件和由模型生成的全部内容。'
                    '已删除的文件无法恢复。',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('删除'),
                    ),
                  ],
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  for (final (size, scale) in [
    (const Size(320, 700), 2.0),
    (const Size(360, 400), 1.0),
    (const Size(800, 360), 2.0),
  ]) {
    testWidgets('矮视口或大字号时操作按钮固定在对话框底部 $size/$scale', (tester) async {
      await pumpDialog(
        tester,
        textScaler: TextScaler.linear(scale),
        size: size,
      );

      // Actions 不进滚动流：无需任何滚动即可直接点到。
      final confirm = find.text('删除');
      expect(confirm.hitTestable(), findsOneWidget);
      final confirmRect = tester.getRect(confirm);
      final dialogRect = tester.getRect(find.byType(AppDialog));
      expect(confirmRect.bottom, lessThan(dialogRect.bottom));
      expect(
        confirmRect.bottom,
        greaterThan(dialogRect.top + dialogRect.height * 0.5),
        reason: '按钮应靠近对话框底部而不是跟随内容滚出视口',
      );

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
