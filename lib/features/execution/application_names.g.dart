// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_names.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 同一阅读页面共享名称查询；不申请权限，不把名称查询当成工具执行。

@ProviderFor(applicationNames)
final applicationNamesProvider = ApplicationNamesProvider._();

/// 同一阅读页面共享名称查询；不申请权限，不把名称查询当成工具执行。

final class ApplicationNamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// 同一阅读页面共享名称查询；不申请权限，不把名称查询当成工具执行。
  ApplicationNamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'applicationNamesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$applicationNamesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    return applicationNames(ref);
  }
}

String _$applicationNamesHash() => r'6782e5c2692d00ebe6611111ef1af84480ad8798';
