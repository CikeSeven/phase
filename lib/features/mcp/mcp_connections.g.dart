// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_connections.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mcpConnections)
final mcpConnectionsProvider = McpConnectionsProvider._();

final class McpConnectionsProvider
    extends $FunctionalProvider<McpConnections, McpConnections, McpConnections>
    with $Provider<McpConnections> {
  McpConnectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpConnectionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpConnectionsHash();

  @$internal
  @override
  $ProviderElement<McpConnections> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  McpConnections create(Ref ref) {
    return mcpConnections(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpConnections value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpConnections>(value),
    );
  }
}

String _$mcpConnectionsHash() => r'68ffa7aaeb12376e685698c20c84ea0a75f28add';
