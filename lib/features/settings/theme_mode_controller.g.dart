// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 主题模式：默认跟随系统，修改后持久化到 shared_preferences。

@ProviderFor(ThemeModeController)
final themeModeControllerProvider = ThemeModeControllerProvider._();

/// 主题模式：默认跟随系统，修改后持久化到 shared_preferences。
final class ThemeModeControllerProvider
    extends $NotifierProvider<ThemeModeController, ThemeMode> {
  /// 主题模式：默认跟随系统，修改后持久化到 shared_preferences。
  ThemeModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeControllerProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[settingsStorageProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ThemeModeControllerProvider.$allTransitiveDependencies0,
          ThemeModeControllerProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = settingsStorageProvider;
  static final $allTransitiveDependencies1 =
      SettingsStorageProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$themeModeControllerHash();

  @$internal
  @override
  ThemeModeController create() => ThemeModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeControllerHash() =>
    r'dbda74f70f8891fb394162c2e94d5b2e00ce8a4a';

/// 主题模式：默认跟随系统，修改后持久化到 shared_preferences。

abstract class _$ThemeModeController extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
