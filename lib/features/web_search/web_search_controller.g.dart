// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_search_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WebSearchController)
final webSearchControllerProvider = WebSearchControllerProvider._();

final class WebSearchControllerProvider
    extends $AsyncNotifierProvider<WebSearchController, WebSearchState> {
  WebSearchControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webSearchControllerProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[webSearchRepositoryProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          WebSearchControllerProvider.$allTransitiveDependencies0,
          WebSearchControllerProvider.$allTransitiveDependencies1,
          WebSearchControllerProvider.$allTransitiveDependencies2,
        ],
      );

  static final $allTransitiveDependencies0 = webSearchRepositoryProvider;
  static final $allTransitiveDependencies1 =
      WebSearchRepositoryProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 =
      WebSearchRepositoryProvider.$allTransitiveDependencies1;

  @override
  String debugGetCreateSourceHash() => _$webSearchControllerHash();

  @$internal
  @override
  WebSearchController create() => WebSearchController();
}

String _$webSearchControllerHash() =>
    r'f5bf8bd7506f99f42ce3e0e137c30d5d980b6077';

abstract class _$WebSearchController extends $AsyncNotifier<WebSearchState> {
  FutureOr<WebSearchState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<WebSearchState>, WebSearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<WebSearchState>, WebSearchState>,
              AsyncValue<WebSearchState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
