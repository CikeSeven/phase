import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:phase/core/error/failure.dart';
import 'package:phase/core/theme/app_spacing.dart';
import 'package:phase/core/theme/app_theme.dart';
import 'package:phase/core/theme/frosted_surface.dart';
import 'package:phase/core/widgets/app_card.dart';
import 'package:phase/core/widgets/app_sheet.dart';
import 'package:phase/data/datasources/local/settings_storage.dart';
import 'package:phase/data/models/api_protocol.dart';
import 'package:phase/data/models/profile_model.dart';
import 'package:phase/data/models/provider_profile.dart';
import 'package:phase/data/models/reasoning_effort.dart';
import 'package:phase/data/repositories/provider_profile_repository.dart';
import 'package:phase/features/chat/model_picker_sheet.dart';
import 'package:phase/features/chat/model_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _profiles = [
  ProviderProfile(
    id: 'daily',
    name: '日常',
    protocol: ApiProtocol.openaiCompletions,
    baseUrl: 'https://example.com/v1',
    models: const [
      ProfileModel(id: 'chat-basic'),
      ProfileModel(id: 'think-model', supportsReasoning: true),
    ],
    createdAt: DateTime(2026),
  ),
  ProviderProfile(
    id: 'workspace',
    name: '工作空间',
    protocol: ApiProtocol.openaiCompletions,
    baseUrl: 'https://example.com/v1',
    models: const [ProfileModel(id: 'think-model', supportsReasoning: true)],
    createdAt: DateTime(2026),
  ),
];

const _initialValues = <String, Object>{
  'last_profile_id': 'daily',
  'last_model': 'chat-basic',
  'last_reasoning_effort': 'low',
};

void main() {
  testWidgets('模型面板无常驻教学，保留当前选择和确认推理交互', (tester) async {
    final host = await _pumpHost(tester);
    await _openPicker(tester);
    expect(tester.widget<AppSheet>(find.byType(AppSheet)).subtitle, isNull);
    expect(find.byType(AppCard), findsNothing);
    expect(find.byIcon(Symbols.radio_button_unchecked), findsNothing);
    expect(
      find.byKey(const ValueKey(('provider-tab', 'daily'))),
      findsOneWidget,
    );
    final selectedSurface = tester.widget<Material>(
      find.descendant(
        of: _option('daily', 'chat-basic'),
        matching: find.byType(Material),
      ),
    );
    final colors = Theme.of(tester.element(_option('daily', 'chat-basic')))
        .colorScheme;
    expect(
      selectedSurface.color,
      colors.primaryContainer.withValues(alpha: 0.72),
    );
    for (final phrase in ['确认后用于对话', '确认前不会更改', '先选择一个模型']) {
      expect(find.textContaining(phrase), findsNothing);
    }
    final summary = find.byKey(const ValueKey('model-draft-summary'));
    expect(
      find.descendant(of: summary, matching: find.text('chat-basic')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('当前')),
      findsOneWidget,
    );
    final optionHeight = tester.getSize(_option('daily', 'think-model')).height;
    await _chooseModel(tester, 'daily', 'think-model');
    expect(
      tester.getSize(_option('daily', 'think-model')).height,
      optionHeight,
    );
    await _setEffort(tester, ReasoningEffort.high);
    await _tapVisible(tester, _confirm);
    expect(host.preferences.getString('last_model'), 'think-model');
    expect(host.preferences.getString('last_reasoning_effort'), 'high');
  });

  testWidgets('模型与推理仅修改草稿，取消及关闭都不改变原选择', (tester) async {
    final host = await _pumpHost(tester);
    await _openPicker(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('model-draft-summary')),
        matching: find.text('当前'),
      ),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);

    await _chooseModel(tester, 'daily', 'think-model');
    expect(find.byType(ModelPickerSheet), findsOneWidget);
    expect(_sliderValue(tester), ReasoningEffort.low.index.toDouble());
    await _setEffort(tester, ReasoningEffort.high);
    expect(host.preferences.getString('last_model'), 'chat-basic');
    expect(host.preferences.getString('last_reasoning_effort'), 'low');
    expect(
      host.container.read(modelSelectionProvider).value!.model,
      'chat-basic',
    );

    await _tapVisible(tester, find.text('取消'));
    expect(find.byType(ModelPickerSheet), findsNothing);
    expect(host.preferences.getString('last_model'), 'chat-basic');
    expect(host.preferences.getString('last_reasoning_effort'), 'low');

    await _openPicker(tester);
    await _chooseModel(tester, 'workspace', 'think-model');
    await _tapVisible(tester, find.byTooltip('关闭'));
    expect(find.byType(ModelPickerSheet), findsNothing);
    expect(host.preferences.getString('last_profile_id'), 'daily');
    expect(host.preferences.getString('last_model'), 'chat-basic');
    expect(tester.takeException(), isNull);
  });

  testWidgets('推理等级统一为全部五个，不按模型收窄', (tester) async {
    final host = await _pumpHost(
      tester,
      profiles: [
        ProviderProfile(
          protocol: ApiProtocol.openaiCompletions,
          createdAt: DateTime(2026),
          id: 'daily',
          name: '日常',
          baseUrl: 'https://example.com/v1',
          models: [ProfileModel(id: 'thinker', supportsReasoning: true)],
        ),
      ],
      values: const {
        'last_profile_id': 'daily',
        'last_model': 'thinker',
        'last_reasoning_effort': 'high',
      },
    );

    // 持久化等级原样保留，不再按模型降级。
    expect(
      host.container.read(modelSelectionProvider).value!.effort,
      ReasoningEffort.high,
    );

    await _openPicker(tester);
    // 滑杆统一提供 关+五个等级：最左关、最右最高。
    expect(_sliderValue(tester), ReasoningEffort.high.index.toDouble());
    expect(tester.widget<Text>(_effortLabel).data, ReasoningEffort.high.label);
    final slider = tester.widget<Slider>(_effortSlider);
    expect(slider.min, 0);
    expect(slider.max, (ReasoningEffort.values.length - 1).toDouble());
    expect(slider.divisions, ReasoningEffort.values.length - 1);

    await _setEffort(tester, ReasoningEffort.max);
    expect(_sliderValue(tester), ReasoningEffort.max.index.toDouble());
    expect(tester.widget<Text>(_effortLabel).data, ReasoningEffort.max.label);
    await _tapVisible(tester, _confirm);
    expect(host.preferences.getString('last_reasoning_effort'), 'max');
  });

  testWidgets('标题右侧的当前模型名在空间足够时不提前截断', (tester) async {
    await _pumpHost(
      tester,
      profiles: [
        ProviderProfile(
          protocol: ApiProtocol.openaiCompletions,
          createdAt: DateTime(2026),
          id: 'daily',
          name: '日常',
          baseUrl: 'https://example.com/v1',
          models: [ProfileModel(id: 'gpt-5-mini')],
        ),
      ],
      values: const {'last_profile_id': 'daily', 'last_model': 'gpt-5-mini'},
    );
    await _openPicker(tester);
    final summary = find.byKey(const ValueKey('model-draft-summary'));
    final idText = find.descendant(
      of: summary,
      matching: find.text('gpt-5-mini'),
    );
    expect(idText, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(idText);
    expect(paragraph.didExceedMaxLines, isFalse);
    // 摘要占满标题与关闭按钮之间的全部剩余宽度，不再对半分。
    expect(
      tester.getRect(summary).right,
      closeTo(tester.getRect(find.byTooltip('关闭')).left - AppSpacing.s, 0.1),
    );
  });

  testWidgets('未勾选启用的模型不出现在选择列表，标签计数同步', (tester) async {
    await _pumpHost(
      tester,
      profiles: [
        ProviderProfile(
          protocol: ApiProtocol.openaiCompletions,
          createdAt: DateTime(2026),
          id: 'daily',
          name: '日常',
          baseUrl: 'https://example.com/v1',
          models: [
            ProfileModel(id: 'enabled-model'),
            ProfileModel(id: 'disabled-model', enabled: false),
          ],
        ),
      ],
      values: const {'last_profile_id': 'daily', 'last_model': 'enabled-model'},
    );

    await _openPicker(tester);
    expect(_option('daily', 'enabled-model'), findsOneWidget);
    expect(_option('daily', 'disabled-model'), findsNothing);
    expect(
      find.descendant(of: _providerTab('daily'), matching: find.text('1')),
      findsOneWidget,
    );

    // 搜索也搜不到未启用的模型。
    await tester.enterText(_search, 'disabled');
    await tester.pumpAndSettle();
    expect(find.text('没有找到模型'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('默认模型被停用时，派生选择回退到第一个启用的模型', (tester) async {
    final host = await _pumpHost(
      tester,
      profiles: [
        ProviderProfile(
          protocol: ApiProtocol.openaiCompletions,
          createdAt: DateTime(2026),
          id: 'daily',
          name: '日常',
          baseUrl: 'https://example.com/v1',
          defaultModel: 'disabled-default',
          models: [
            ProfileModel(id: 'enabled-model'),
            ProfileModel(id: 'disabled-default', enabled: false),
          ],
        ),
      ],
      values: const {},
    );
    expect(
      host.container.read(modelSelectionProvider).value!.model,
      'enabled-model',
    );
  });

  testWidgets('点击服务商标签滚动定位到对应分组，不改变草稿', (tester) async {
    final host = await _pumpHost(
      tester,
      profiles: [
        ProviderProfile(
          protocol: ApiProtocol.openaiCompletions,
          createdAt: DateTime(2026),
          id: 'daily',
          name: '日常',
          baseUrl: 'https://example.com/v1',
          defaultModel: 'daily-000',
          models: [
            for (var i = 0; i < 40; i++)
              ProfileModel(id: 'daily-${i.toString().padLeft(3, '0')}'),
          ],
        ),
        ProviderProfile(
          protocol: ApiProtocol.openaiCompletions,
          createdAt: DateTime(2026),
          id: 'workspace',
          name: '工作空间',
          baseUrl: 'https://example.com/v1',
          models: [ProfileModel(id: 'work-pro')],
        ),
      ],
      values: const {'last_profile_id': 'daily', 'last_model': 'daily-000'},
    );
    await _openPicker(tester);
    // 所有模型在同一个列表里，分组标题隔开；工作空间的模型默认在屏幕外。
    expect(_option('daily', 'daily-000'), findsOneWidget);
    expect(_option('workspace', 'work-pro').hitTestable(), findsNothing);

    await _tapVisible(tester, _providerTab('workspace'));
    await tester.pumpAndSettle();
    // 列表滚动到工作空间分组，草稿仍是原模型。
    expect(_option('workspace', 'work-pro').hitTestable(), findsOneWidget);
    final summary = find.byKey(const ValueKey('model-draft-summary'));
    expect(
      find.descendant(of: summary, matching: find.text('daily-000')),
      findsOneWidget,
    );
    expect(host.preferences.getString('last_model'), 'daily-000');

    // 直接点模型才改草稿。
    await _chooseModel(tester, 'workspace', 'work-pro');
    await _tapVisible(tester, _confirm);
    expect(host.preferences.getString('last_profile_id'), 'workspace');
    expect(host.preferences.getString('last_model'), 'work-pro');
    expect(tester.takeException(), isNull);
  });

  testWidgets('同名服务商与模型以 ID 区分，同面板确认推理并持久化', (tester) async {
    final host = await _pumpHost(
      tester,
      profiles: _profiles
          .map((profile) => profile.copyWith(name: '同名服务商'))
          .toList(),
    );
    await _openPicker(tester);
    await _chooseModel(tester, 'workspace', 'think-model');
    final selected = tester.widget<Semantics>(
      _option('workspace', 'think-model'),
    );
    expect(selected.properties.selected, isTrue);
    await _setEffort(tester, ReasoningEffort.high);
    expect(find.byType(ModelPickerSheet), findsOneWidget);
    expect(host.preferences.getString('last_profile_id'), 'daily');

    await _tapVisible(tester, _confirm);
    expect(find.byType(ModelPickerSheet), findsNothing);
    expect(host.preferences.getString('last_profile_id'), 'workspace');
    expect(host.preferences.getString('last_model'), 'think-model');
    expect(host.preferences.getString('last_reasoning_effort'), 'high');
    final selection = await host.container.read(modelSelectionProvider.future);
    expect(selection!.profile.id, 'workspace');
    expect(selection.model, 'think-model');
    expect(selection.effort, ReasoningEffort.high);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未设置推理时保留关的默认值，不支持推理的模型不显示控件', (tester) async {
    final host = await _pumpHost(
      tester,
      values: const {'last_profile_id': 'daily', 'last_model': 'chat-basic'},
    );
    await _openPicker(tester);
    await _chooseModel(tester, 'daily', 'think-model');
    expect(_sliderValue(tester), ReasoningEffort.off.index.toDouble());
    await _setEffort(tester, ReasoningEffort.medium);
    await _chooseModel(tester, 'daily', 'chat-basic');
    expect(find.byType(Slider), findsNothing);
    await _tapVisible(tester, _confirm);
    expect(host.preferences.getString('last_model'), 'chat-basic');
    expect(host.preferences.getString('last_reasoning_effort'), 'medium');
    expect(tester.takeException(), isNull);
  });

  testWidgets('候选为空时保留有效手动模型，推理设置仍可确认', (tester) async {
    const manualId = 'manual-reasoner-not-in-remote-list';
    final host = await _pumpHost(
      tester,
      profiles: [
        ProviderProfile(
          protocol: ApiProtocol.openaiCompletions,
          createdAt: DateTime(2026),
          id: 'manual',
          name: '手动配置',
          baseUrl: 'https://example.com/v1',
        ),
      ],
      values: const {
        'last_profile_id': 'manual',
        'last_model': manualId,
        'last_reasoning_effort': 'off',
      },
    );
    await _openPicker(tester);
    await _chooseModel(tester, 'manual', manualId);
    expect(find.textContaining('当前手动模型'), findsOneWidget);
    expect(find.text('暂无模型'), findsNothing);
    expect(_sliderValue(tester), ReasoningEffort.off.index.toDouble());
    await _setEffort(tester, ReasoningEffort.medium);
    await _tapVisible(tester, _confirm);
    expect(host.preferences.getString('last_model'), manualId);
    expect(host.preferences.getString('last_reasoning_effort'), 'medium');
    expect(tester.takeException(), isNull);
  });

  testWidgets('数百候选惰性构建，支持模型 ID、服务商名称和服务商 ID 搜索', (tester) async {
    final host = await _pumpHost(
      tester,
      profiles: [
        ProviderProfile(
          protocol: ApiProtocol.openaiCompletions,
          createdAt: DateTime(2026),
          id: 'many',
          name: '模型仓库',
          baseUrl: 'https://example.com/v1',
          models: List.generate(
            600,
            (index) =>
                ProfileModel(id: 'model-${index.toString().padLeft(3, '0')}'),
          ),
        ),
        ProviderProfile(
          protocol: ApiProtocol.openaiCompletions,
          createdAt: DateTime(2026),
          id: 'provider-research',
          name: '研究空间',
          baseUrl: 'https://example.com/v1',
          models: [ProfileModel(id: 'research-only')],
        ),
      ],
      values: const {},
    );
    await _openPicker(tester);
    expect(_option('many', 'model-599'), findsNothing);
    expect(_modelOptions.evaluate().length, inInclusiveRange(1, 19));

    await tester.enterText(_search, 'MODEL-599');
    await tester.pumpAndSettle();
    await _chooseModel(tester, 'many', 'model-599');
    expect(_option('many', 'model-001'), findsNothing);
    expect(host.preferences.getString('last_model'), isNull);

    await tester.enterText(_search, '研究空间');
    await tester.pumpAndSettle();
    expect(_option('provider-research', 'research-only'), findsOneWidget);
    expect(_option('many', 'model-599'), findsNothing);
    await tester.enterText(_search, 'provider-research');
    await tester.pumpAndSettle();
    expect(_option('provider-research', 'research-only'), findsOneWidget);

    await tester.enterText(_search, 'no-matching-model');
    await tester.pumpAndSettle();
    expect(find.text('没有找到模型'), findsOneWidget);
    await _tapVisible(tester, find.byTooltip('清除搜索'));
    await tester.scrollUntilVisible(
      _option('many', 'model-040'),
      400,
      scrollable: _modelScrollable,
      maxScrolls: 30,
    );
    await tester.pumpAndSettle();
    expect(_option('many', 'model-040'), findsOneWidget);
    expect(_modelOptions.evaluate().length, inInclusiveRange(1, 19));
    expect(_confirm.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('键盘拉起触发面板紧凑分支切换时搜索框保持焦点可继续输入', (tester) async {
    await _pumpHost(tester);
    await _openPicker(tester);
    await tester.tap(_search);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: _search, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );

    // 模拟英文键盘拉起：可用高度骤减，面板从固定列表切到紧凑滚动分支。
    tester.view.viewInsets = const FakeViewPadding(bottom: 480);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: _search, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.enterText(_search, 'think');
    await tester.pumpAndSettle();
    expect(find.text('think'), findsOneWidget);
    expect(_option('daily', 'think-model'), findsOneWidget);

    // 键盘收回后面板切回固定分支，焦点与已输入内容仍保留。
    tester.view.viewInsets = const FakeViewPadding(bottom: 24);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: _search, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(find.text('think'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无服务商时引导至真实配置路径', (tester) async {
    final host = await _pumpHost(tester, profiles: const [], values: const {});
    await _openPicker(tester);
    expect(find.text('暂无服务商'), findsOneWidget);
    expect(_confirm, findsNothing);
    await _tapVisible(tester, find.text('去配置服务商'));
    expect(find.text('服务商配置目的页'), findsOneWidget);
    expect(
      GoRouterState.of(tester.element(find.text('服务商配置目的页'))).uri.path,
      '/settings/providers',
    );
    expect(host.router.canPop(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单个服务商无模型时直接进入该服务商编辑页', (tester) async {
    final host = await _pumpHost(
      tester,
      profiles: [
        ProviderProfile(
          protocol: ApiProtocol.openaiCompletions,
          createdAt: DateTime(2026),
          id: 'empty-profile',
          name: '等待配置模型的服务商',
          baseUrl: 'https://example.com/v1',
        ),
      ],
      values: const {},
    );
    await _openPicker(tester);
    expect(tester.widget<FilledButton>(_confirm).onPressed, isNull);
    await _tapVisible(tester, find.text('配置模型'));
    expect(find.text('编辑服务商 empty-profile'), findsOneWidget);
    expect(
      GoRouterState.of(tester.element(find.text('编辑服务商 empty-profile')))
          .uri
          .path,
      '/settings/providers/empty-profile',
    );
    expect(host.router.canPop(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载错误展示用户文案，点击重试重新读取本地列表', (tester) async {
    var attempts = 0;
    await _pumpHost(
      tester,
      profileStream: () {
        attempts++;
        return attempts == 1
            ? Stream.error(const NetworkFailure('internal diagnostic'))
            : Stream.value(_profiles);
      },
    );
    await _openPicker(tester);
    expect(find.text('无法加载模型'), findsOneWidget);
    expect(find.text('网络连接失败，请检查网络后重试'), findsOneWidget);
    expect(find.textContaining('internal diagnostic'), findsNothing);
    await _tapVisible(tester, find.text('重试'));
    expect(attempts, greaterThanOrEqualTo(2));
    expect(_option('daily', 'chat-basic'), findsOneWidget);
    expect(find.text('无法加载模型'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final failingPart in ['model', 'effort']) {
    testWidgets('$failingPart 持久化失败不关闭面板，重试完成两项保存', (tester) async {
      late _ControlledSettings storage;
      final host = await _pumpHost(
        tester,
        settings: (preferences) => storage = _ControlledSettings(preferences)
          ..failModel = failingPart == 'model'
          ..failEffort = failingPart == 'effort',
      );
      await _openPicker(tester);
      await _chooseModel(tester, 'workspace', 'think-model');
      await _setEffort(tester, ReasoningEffort.high);
      await _tapVisible(tester, _confirm);
      expect(find.byType(ModelPickerSheet), findsOneWidget);
      expect(find.text('未能完整保存选择，请重试。'), findsOneWidget);
      expect(find.textContaining('private diagnostic'), findsNothing);
      expect(host.preferences.getString('last_reasoning_effort'), 'low');
      if (failingPart == 'model') {
        expect(host.preferences.getString('last_model'), 'chat-basic');
      }
      storage
        ..failModel = false
        ..failEffort = false;
      await _tapVisible(tester, _confirm);
      expect(find.byType(ModelPickerSheet), findsNothing);
      expect(host.preferences.getString('last_profile_id'), 'workspace');
      expect(host.preferences.getString('last_model'), 'think-model');
      expect(host.preferences.getString('last_reasoning_effort'), 'high');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('异步保存期间销毁面板，不使用失效的 WidgetRef 或导航上下文', (tester) async {
    final gate = Completer<void>();
    late _ControlledSettings storage;
    await _pumpHost(
      tester,
      settings: (preferences) =>
          storage = _ControlledSettings(preferences)..modelGate = gate,
    );
    await _openPicker(tester);
    await _chooseModel(tester, 'daily', 'think-model');
    await tester.ensureVisible(_confirm);
    await tester.tap(_confirm);
    await tester.pump();
    expect(find.text('保存中…'), findsOneWidget);
    expect(tester.widget<FilledButton>(_confirm).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete();
    await tester.pumpAndSettle();
    expect(storage.effortWrites, 0);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(320, 760), scale: 1.3, keyboard: 0.0, dark: false),
    (size: const Size(360, 800), scale: 1.3, keyboard: 0.0, dark: true),
    (size: const Size(320, 760), scale: 2.0, keyboard: 0.0, dark: true),
    (size: const Size(360, 800), scale: 2.0, keyboard: 0.0, dark: false),
    (size: const Size(800, 360), scale: 2.0, keyboard: 160.0, dark: true),
  ]) {
    testWidgets('长 ID 窄屏/键盘可搜索并确认：$scenario', (tester) async {
      final longId = 'custom-thinker-${'very-long-model-id-' * 8}';
      final host = await _pumpHost(
        tester,
        size: scenario.size,
        scale: scenario.scale,
        keyboard: scenario.keyboard,
        dark: scenario.dark,
        profiles: [
          ProviderProfile(
            protocol: ApiProtocol.openaiCompletions,
            createdAt: DateTime(2026),
            id: 'long-provider-id-${'identifier-' * 8}',
            name: '需要完整区分的超长服务商名称与工作空间名称',
            baseUrl: 'https://example.com/v1',
            models: [
              const ProfileModel(id: 'chat-basic'),
              ProfileModel(id: longId, supportsReasoning: true),
            ],
          ),
        ],
        values: const {},
      );
      await _openPicker(tester);
      expect(tester.takeException(), isNull);
      final surface = find
          .descendant(
            of: find.byType(AppSheet),
            matching: find.byType(FrostedSurface),
          )
          .first;
      expect(
        tester.getRect(surface).bottom,
        lessThanOrEqualTo(scenario.size.height - scenario.keyboard + 0.01),
      );
      await tester.ensureVisible(_search);
      await tester.enterText(_search, 'custom-thinker');
      await tester.pumpAndSettle();
      final profileId = 'long-provider-id-${'identifier-' * 8}';
      await _chooseModel(tester, profileId, longId);
      final modelText = tester.widget<Text>(
        find.descendant(
          of: _option(profileId, longId),
          matching: find.text(longId),
        ),
      );
      expect(modelText.maxLines, 2);
      expect(modelText.overflow, TextOverflow.ellipsis);
      await _setEffort(tester, ReasoningEffort.high);
      await _tapVisible(tester, _confirm);
      expect(find.byType(ModelPickerSheet), findsNothing);
      expect(host.preferences.getString('last_model'), longId);
      expect(host.preferences.getString('last_reasoning_effort'), 'high');
      expect(tester.takeException(), isNull);
    });
  }
}

Finder get _search => find.byKey(const ValueKey('model-search'));
Finder get _modelOptions => find.descendant(
  of: find.byKey(const ValueKey('model-list')),
  matching: find.byType(InkWell),
);
Finder get _confirm => find.byKey(const ValueKey('confirm-model-selection'));
Finder get _modelScrollable => find
    .descendant(
      of: find.byKey(const ValueKey('model-list')),
      matching: find.byType(Scrollable),
    )
    .first;
Finder _option(String profileId, String modelId) =>
    find.byKey(ValueKey(('model-option', profileId, modelId)));
Finder _providerTab(String profileId) =>
    find.byKey(ValueKey(('provider-tab', profileId)));
Finder get _effortSlider =>
    find.byKey(const ValueKey('reasoning-effort-slider'));
Finder get _effortLabel => find.byKey(const ValueKey('reasoning-effort-label'));

double _sliderValue(WidgetTester tester) =>
    tester.widget<Slider>(_effortSlider).value;

/// 点滑杆轨道对应档位（档位 0..5，两端留出圆角余量）。
Future<void> _setEffort(WidgetTester tester, ReasoningEffort effort) async {
  await tester.ensureVisible(_effortSlider);
  await tester.pumpAndSettle();
  final rect = tester.getRect(_effortSlider);
  final last = ReasoningEffort.values.length - 1;
  final fraction = effort.index / last;
  final dx = (rect.left + fraction * rect.width).clamp(
    rect.left + 12,
    rect.right - 12,
  );
  await tester.tapAt(Offset(dx, rect.center.dy));
  await tester.pumpAndSettle();
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text('打开模型'));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _chooseModel(
  WidgetTester tester,
  String profileId,
  String modelId,
) async {
  final option = _option(profileId, modelId);
  await tester.scrollUntilVisible(
    option,
    160,
    scrollable: _modelScrollable,
    maxScrolls: 30,
  );
  await tester.pumpAndSettle();
  await _tapVisible(
    tester,
    find.descendant(of: option, matching: find.text(modelId)),
  );
}

Future<
  ({
    SharedPreferences preferences,
    ProviderContainer container,
    GoRouter router,
  })
>
_pumpHost(
  WidgetTester tester, {
  List<ProviderProfile>? profiles,
  Map<String, Object> values = _initialValues,
  Stream<List<ProviderProfile>> Function()? profileStream,
  SettingsStorage Function(SharedPreferences)? settings,
  Size size = const Size(390, 844),
  double scale = 1,
  double keyboard = 0,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.padding = FakeViewPadding(
    top: 24,
    bottom: keyboard == 0 ? 24 : 0,
  );
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(values);
  final preferences = await SharedPreferences.getInstance();
  final storage = settings?.call(preferences);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _PickerHost()),
      GoRoute(
        path: '/settings/providers',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('服务商配置目的页'))),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => Scaffold(
              body: Center(child: Text('编辑服务商 ${state.pathParameters['id']}')),
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => preferences),
        providerProfilesProvider.overrideWith(
          (ref) => profileStream?.call() ?? Stream.value(profiles ?? _profiles),
        ),
        if (storage != null)
          settingsStorageProvider.overrideWith((ref) => storage),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    preferences: preferences,
    container: ProviderScope.containerOf(
      tester.element(find.byType(_PickerHost)),
    ),
    router: router,
  );
}

class _PickerHost extends ConsumerWidget {
  const _PickerHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(modelSelectionProvider);
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => showModelPickerSheet(context),
          child: const Text('打开模型'),
        ),
      ),
    );
  }
}

class _ControlledSettings extends SettingsStorage {
  _ControlledSettings(super.preferences);

  bool failModel = false;
  bool failEffort = false;
  int effortWrites = 0;
  Completer<void>? modelGate;

  @override
  Future<void> writeLastModelSelection({
    required String profileId,
    required String model,
  }) async {
    await modelGate?.future;
    if (failModel) throw StateError('private diagnostic');
    await super.writeLastModelSelection(profileId: profileId, model: model);
  }

  @override
  Future<void> writeLastReasoningEffort(String effortName) async {
    effortWrites++;
    if (failEffort) throw StateError('private diagnostic');
    await super.writeLastReasoningEffort(effortName);
  }
}
