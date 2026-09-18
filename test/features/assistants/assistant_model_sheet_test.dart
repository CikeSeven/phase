import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/widgets/app_choice_chip.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/model_selection.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/assistants/assistant_model_sheet.dart';

void main() {
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    for (final (size, keyboard) in [
      (const Size(320, 760), 0.0),
      (const Size(640, 360), 0.0),
      (const Size(320, 760), 300.0),
    ]) {
      testWidgets('${theme.brightness} $size 键盘 $keyboard 大字推理选择可达且取消不提交', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(tester.view.reset);
        const current = ModelSelection(
          profileId: 'profile',
          modelId: 'reasoner',
          temperature: 0.7,
          maxOutputTokens: 2048,
        );
        ModelSelection? result;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              providerProfilesProvider.overrideWith(
                (ref) => Stream.value([
                  ProviderProfile(
                    id: 'profile',
                    name: '测试服务商',
                    protocol: ApiProtocol.openaiResponses,
                    baseUrl: 'https://example.invalid',
                    models: const [
                      ProfileModel(id: 'reasoner', supportsReasoning: true),
                    ],
                    createdAt: DateTime(2026),
                  ),
                ]),
              ),
            ],
            child: MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async =>
                        result = await showAssistantModelSheet(
                          context,
                          current: current,
                        ),
                    child: const Text('选择默认模型'),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> chooseEffort() async {
          await tester.tap(find.text('选择默认模型'));
          await tester.pumpAndSettle();
          final high = find.byKey(const ValueKey('assistant-effort-high'));
          await tester.ensureVisible(high);
          await tester.pumpAndSettle();
          await tester.tap(high);
          await tester.pumpAndSettle();
          expect(tester.widget<AppChoiceChip>(high).selected, isTrue);
          expect(tester.takeException(), isNull);
        }

        await chooseEffort();
        await tester.ensureVisible(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(current.reasoningEffort, ReasoningEffort.off);
        await chooseEffort();
        final model = find.byKey(
          const ValueKey('assistant-model-profile-reasoner'),
        );
        await tester.ensureVisible(model);
        await tester.pumpAndSettle();
        await tester.tap(model);
        await tester.pumpAndSettle();
        expect(result!.modelId, current.modelId);
        expect(result!.reasoningEffort, ReasoningEffort.high);
        expect(result!.temperature, current.temperature);
        expect(result!.maxOutputTokens, current.maxOutputTokens);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
