import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/app.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/conversation.dart';
import 'package:phase/features/chat/chat_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('冒烟：聊天页空状态可渲染', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => preferences),
          // 避免在测试中打开真实 sqlite 数据库。
          conversationsProvider.overrideWith(
            (ref) => Stream.value(const <Conversation>[]),
          ),
        ],
        child: const PhaseApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 聊天页空状态（DESIGN.md §5.5）。
    expect(find.text('向相月提问，或选择一个助手'), findsOneWidget);
    expect(find.text('选择助手'), findsOneWidget);
    // 输入栏与发送按钮已装配。
    expect(find.byTooltip('发送'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
