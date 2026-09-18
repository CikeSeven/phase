// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(McpController)
final mcpControllerProvider = McpControllerFamily._();

final class McpControllerProvider
    extends $AsyncNotifierProvider<McpController, McpServerEntry?> {
  McpControllerProvider._({
    required McpControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mcpControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mcpControllerHash();

  @override
  String toString() {
    return r'mcpControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  McpController create() => McpController();

  @override
  bool operator ==(Object other) {
    return other is McpControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mcpControllerHash() => r'edd298811c20cec5742a0740295e95c6f30386dd';

final class McpControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          McpController,
          AsyncValue<McpServerEntry?>,
          McpServerEntry?,
          FutureOr<McpServerEntry?>,
          String
        > {
  McpControllerFamily._()
    : super(
        retry: null,
        name: r'mcpControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  McpControllerProvider call(String id) =>
      McpControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'mcpControllerProvider';
}

abstract class _$McpController extends $AsyncNotifier<McpServerEntry?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<McpServerEntry?> build(String id);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<McpServerEntry?>, McpServerEntry?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<McpServerEntry?>, McpServerEntry?>,
              AsyncValue<McpServerEntry?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
