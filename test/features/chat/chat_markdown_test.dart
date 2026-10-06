import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:phase/features/chat/chat_code_block.dart';
import 'package:phase/features/chat/chat_markdown.dart';
import 'package:phase/features/chat/chat_markdown_alert.dart';
import 'package:phase/features/chat/chat_markdown_table.dart';

void main() {
  Widget buildApp(Widget child, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: brightness,
        ),
      ),
      home: Scaffold(body: child),
    );
  }

  Iterable<RichText> findRichTexts(WidgetTester tester, [Finder? within]) {
    final finder = find.byWidgetPredicate((w) => w is RichText);
    return tester.widgetList<RichText>(
      within != null ? find.descendant(of: within, matching: finder) : finder,
    );
  }

  group('Inline Code Rendering', () {
    testWidgets('renders inline code with CodeTextSpan and correct style', (
      tester,
    ) async {
      const text = '这是普通的 `inlineCode` 测试';
      await tester.pumpWidget(
        buildApp(const ChatMarkdown(text: text, streaming: false)),
      );
      await tester.pumpAndSettle();

      // Ensure no raw backticks are displayed in plain text
      final textFinder = find.byWidgetPredicate(
        (w) => w is Text && (w.data?.contains('`') ?? false),
      );
      expect(textFinder, findsNothing);

      bool foundCodeSpan = false;
      for (final rich in findRichTexts(tester)) {
        void checkSpan(InlineSpan span) {
          if (span is CodeTextSpan) {
            expect(span.text, 'inlineCode');
            expect(span.codeStyle.padding?.horizontal, 0);
            expect(span.codeStyle.borderWidth, 0);
            foundCodeSpan = true;
          }
          if (span is TextSpan && span.children != null) {
            for (final c in span.children!) {
              checkSpan(c);
            }
          }
        }

        checkSpan(rich.text);
      }
      expect(foundCodeSpan, isTrue);
    });

    testWidgets(
      'renders Chinese characters tightly adjacent to inline code without raw backticks',
      (tester) async {
        const text = '请务必使用`apiKey`参数进行鉴权。';
        await tester.pumpWidget(
          buildApp(const ChatMarkdown(text: text, streaming: false)),
        );
        await tester.pumpAndSettle();

        final rawBacktickFinder = find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('`') ?? false),
        );
        expect(rawBacktickFinder, findsNothing);

        bool foundCode = false;
        for (final rich in findRichTexts(tester)) {
          void checkSpan(InlineSpan span) {
            if (span is CodeTextSpan) {
              expect(span.text, 'apiKey');
              foundCode = true;
            }
            if (span is TextSpan && span.children != null) {
              for (final c in span.children!) {
                checkSpan(c);
              }
            }
          }

          checkSpan(rich.text);
        }
        expect(foundCode, isTrue);
      },
    );

    testWidgets('renders inline code inside GitHub-style Callout body', (
      tester,
    ) async {
      const text = '> [!NOTE]\n> 请务必提供 `apiKey` 参数。';
      await tester.pumpWidget(
        buildApp(const ChatMarkdown(text: text, streaming: false)),
      );
      await tester.pumpAndSettle();

      final alertFinder = find.byType(ChatMarkdownAlert);
      expect(alertFinder, findsOneWidget);

      final alert = tester.widget<ChatMarkdownAlert>(alertFinder);
      expect(alert.type, ChatAlertType.note);

      // Verify that the body contains the CodeTextSpan and no raw backticks
      bool foundCodeInAlert = false;
      for (final rich in findRichTexts(tester, alertFinder)) {
        void checkSpan(InlineSpan span) {
          if (span is CodeTextSpan) {
            expect(span.text, 'apiKey');
            foundCodeInAlert = true;
          }
          if (span is TextSpan && span.children != null) {
            for (final c in span.children!) {
              checkSpan(c);
            }
          }
        }

        checkSpan(rich.text);
      }
      expect(foundCodeInAlert, isTrue);
    });

    testWidgets('renders inline code inside GitHub-style Callout title', (
      tester,
    ) async {
      const text = '> [!TIP] 配置 `baseUrl` 说明\n> 正文中的 `test` 代码';
      await tester.pumpWidget(
        buildApp(const ChatMarkdown(text: text, streaming: false)),
      );
      await tester.pumpAndSettle();

      final alertFinder = find.byType(ChatMarkdownAlert);
      expect(alertFinder, findsOneWidget);

      final alert = tester.widget<ChatMarkdownAlert>(alertFinder);
      expect(alert.type, ChatAlertType.tip);
      expect(alert.title, '配置 `baseUrl` 说明');
      expect(alert.titleWidget, isNotNull);

      // Verify CodeTextSpan in title and body
      bool foundBaseUrl = false;
      bool foundTest = false;
      for (final rich in findRichTexts(tester, alertFinder)) {
        void checkSpan(InlineSpan span) {
          if (span is CodeTextSpan) {
            if (span.text == 'baseUrl') foundBaseUrl = true;
            if (span.text == 'test') foundTest = true;
          }
          if (span is TextSpan && span.children != null) {
            for (final c in span.children!) {
              checkSpan(c);
            }
          }
        }

        checkSpan(rich.text);
      }
      expect(foundBaseUrl, isTrue);
      expect(foundTest, isTrue);
    });

    testWidgets('renders inline code inside standard BlockQuote', (
      tester,
    ) async {
      const text = '> 这是普通引用，包含 `inlineQuote` 代码。';
      await tester.pumpWidget(
        buildApp(const ChatMarkdown(text: text, streaming: false)),
      );
      await tester.pumpAndSettle();

      final quoteFinder = find.byType(ChatMarkdownQuote);
      expect(quoteFinder, findsOneWidget);

      bool foundCode = false;
      for (final rich in findRichTexts(tester, quoteFinder)) {
        void checkSpan(InlineSpan span) {
          if (span is CodeTextSpan) {
            expect(span.text, 'inlineQuote');
            foundCode = true;
          }
          if (span is TextSpan && span.children != null) {
            for (final c in span.children!) {
              checkSpan(c);
            }
          }
        }

        checkSpan(rich.text);
      }
      expect(foundCode, isTrue);
    });

    testWidgets('renders inline code inside table cells', (tester) async {
      const text = '''
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `name` | `String` | 姓名 |
| `count` | `int` | 数量 |
''';
      await tester.pumpWidget(
        buildApp(const ChatMarkdown(text: text, streaming: false)),
      );
      await tester.pumpAndSettle();

      final tableFinder = find.byType(ChatMarkdownTable);
      expect(tableFinder, findsOneWidget);

      final codeTexts = <String>{};
      for (final rich in findRichTexts(tester, tableFinder)) {
        void checkSpan(InlineSpan span) {
          if (span is CodeTextSpan && span.text != null) {
            codeTexts.add(span.text!);
          }
          if (span is TextSpan && span.children != null) {
            for (final c in span.children!) {
              checkSpan(c);
            }
          }
        }

        checkSpan(rich.text);
      }

      expect(codeTexts, containsAll(['name', 'String', 'count', 'int']));
    });

    testWidgets('renders inline code inside task lists and regular lists', (
      tester,
    ) async {
      const text = '''
- [x] 完成 `setup()` 函数
- [ ] 检查 `config.json` 文件
1. 执行 `flutter run` 命令
''';
      await tester.pumpWidget(
        buildApp(const ChatMarkdown(text: text, streaming: false)),
      );
      await tester.pumpAndSettle();

      final codeTexts = <String>{};
      for (final rich in findRichTexts(tester)) {
        void checkSpan(InlineSpan span) {
          if (span is CodeTextSpan && span.text != null) {
            codeTexts.add(span.text!);
          }
          if (span is TextSpan && span.children != null) {
            for (final c in span.children!) {
              checkSpan(c);
            }
          }
        }

        checkSpan(rich.text);
      }

      expect(codeTexts, containsAll(['setup()', 'config.json', 'flutter run']));
    });

    testWidgets(
      'coexists with LaTeX math formula and inline code without corruption',
      (tester) async {
        const text = r'质能方程为 $E = mc^2$，而在代码中使用 `calculateEnergy(m, c)` 计算。';
        await tester.pumpWidget(
          buildApp(const ChatMarkdown(text: text, streaming: false)),
        );
        await tester.pumpAndSettle();

        bool foundCode = false;
        for (final rich in findRichTexts(tester)) {
          void checkSpan(InlineSpan span) {
            if (span is CodeTextSpan) {
              expect(span.text, 'calculateEnergy(m, c)');
              foundCode = true;
            }
            if (span is TextSpan && span.children != null) {
              for (final c in span.children!) {
                checkSpan(c);
              }
            }
          }

          checkSpan(rich.text);
        }
        expect(foundCode, isTrue);
      },
    );

    testWidgets(
      'renders inline code containing markdown symbols and angle brackets literally',
      (tester) async {
        const text =
            '查看 `List<Map<String, dynamic>>` 和 `*not_bold*` 以及 `a || b` 表达式。';
        await tester.pumpWidget(
          buildApp(const ChatMarkdown(text: text, streaming: false)),
        );
        await tester.pumpAndSettle();

        final codeTexts = <String>{};
        for (final rich in findRichTexts(tester)) {
          void checkSpan(InlineSpan span) {
            if (span is CodeTextSpan && span.text != null) {
              codeTexts.add(span.text!);
            }
            if (span is TextSpan && span.children != null) {
              for (final c in span.children!) {
                checkSpan(c);
              }
            }
          }

          checkSpan(rich.text);
        }

        expect(
          codeTexts,
          containsAll(['List<Map<String, dynamic>>', '*not_bold*', 'a || b']),
        );
      },
    );

    testWidgets('handles streaming mode without crashes or state leaks', (
      tester,
    ) async {
      const text = '流式输出中包含 `partialCode`...';
      await tester.pumpWidget(
        buildApp(const ChatMarkdown(text: text, streaming: true)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      bool foundCode = false;
      for (final rich in findRichTexts(tester)) {
        void checkSpan(InlineSpan span) {
          if (span is CodeTextSpan && span.text == 'partialCode') {
            foundCode = true;
          }
          if (span is TextSpan && span.children != null) {
            for (final c in span.children!) {
              checkSpan(c);
            }
          }
        }

        checkSpan(rich.text);
      }
      expect(foundCode, isTrue);
    });

    testWidgets('handles unclosed inline code gracefully during streaming', (
      tester,
    ) async {
      const text = '流式输出中尚未闭合的 `unclosedCode';
      await tester.pumpWidget(
        buildApp(const ChatMarkdown(text: text, streaming: true)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      // Should render without throwing exceptions
      expect(tester.takeException(), isNull);
    });
  });

  group('Code Block Rendering', () {
    testWidgets('normalizes trailing newline to report accurate line count', (
      tester,
    ) async {
      const code = '```dart\nvoid main() {\n  print("hello");\n}\n```';
      await tester.pumpWidget(
        buildApp(const ChatMarkdown(text: code, streaming: false)),
      );
      await tester.pumpAndSettle();

      final codeFinder = find.byType(ChatCodeBlock);
      expect(codeFinder, findsOneWidget);

      // Should show '· 3 行', not '· 4 行'
      expect(find.text('· 3 行'), findsOneWidget);

      // Line numbers should only show 1, 2, 3
      expect(
        find.descendant(of: codeFinder, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: codeFinder, matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: codeFinder, matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: codeFinder, matching: find.text('4')),
        findsNothing,
      );
    });
  });
}
