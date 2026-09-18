// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_server_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mcpServerRepository)
final mcpServerRepositoryProvider = McpServerRepositoryProvider._();

final class McpServerRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<McpServerRepository>,
          McpServerRepository,
          FutureOr<McpServerRepository>
        >
    with
        $FutureModifier<McpServerRepository>,
        $FutureProvider<McpServerRepository> {
  McpServerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpServerRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpServerRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<McpServerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<McpServerRepository> create(Ref ref) {
    return mcpServerRepository(ref);
  }
}

String _$mcpServerRepositoryHash() =>
    r'6a23100ee5196ead22fd1e7f2bd55a0783c2bfe1';

@ProviderFor(mcpServers)
final mcpServersProvider = McpServersProvider._();

final class McpServersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<McpServerEntry>>,
          List<McpServerEntry>,
          Stream<List<McpServerEntry>>
        >
    with
        $FutureModifier<List<McpServerEntry>>,
        $StreamProvider<List<McpServerEntry>> {
  McpServersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpServersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpServersHash();

  @$internal
  @override
  $StreamProviderElement<List<McpServerEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<McpServerEntry>> create(Ref ref) {
    return mcpServers(ref);
  }
}

String _$mcpServersHash() => r'd311dd36d8e27f3beaa141268ace1b74fabaef14';
