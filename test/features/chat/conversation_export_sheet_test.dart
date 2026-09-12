import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/features/chat/conversation_export.dart';
import 'package:phase/features/chat/conversation_export_sheet.dart';

/// 导出入口的格式面板：Markdown / JSON 两个选项，取消不导出。
void main() {
  Future<ValueNotifier<ConversationExportFormat?>> openSheet(
    WidgetTester tester,
  ) async {
    final picked = ValueNotifier<ConversationExportFormat?>(null);
    addTearDown(picked.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked.value = await showConversationExportSheet(context);
              },
              child: const Text('打开导出面板'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开导出面板'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('导出面板提供 Markdown 与 JSON，选择后返回对应格式', (tester) async {
    final picked = await openSheet(tester);

    expect(find.text('导出会话'), findsOneWidget);
    expect(find.byKey(const ValueKey('export-markdown')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-json')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('export-markdown')));
    await tester.pumpAndSettle();
    expect(picked.value, ConversationExportFormat.markdown);
    expect(find.byKey(const ValueKey('export-json')), findsNothing);
  });

  testWidgets('选择 JSON 返回 JSON 格式', (tester) async {
    final picked = await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('export-json')));
    await tester.pumpAndSettle();
    expect(picked.value, ConversationExportFormat.json);
  });

  testWidgets('关闭面板不产生格式', (tester) async {
    final picked = await openSheet(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(picked.value, isNull);
    expect(tester.takeException(), isNull);
  });
}
