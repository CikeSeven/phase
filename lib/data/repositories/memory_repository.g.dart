// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(memoryRepository)
final memoryRepositoryProvider = MemoryRepositoryProvider._();

final class MemoryRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<MemoryRepository>,
          MemoryRepository,
          FutureOr<MemoryRepository>
        >
    with $FutureModifier<MemoryRepository>, $FutureProvider<MemoryRepository> {
  MemoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<MemoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MemoryRepository> create(Ref ref) {
    return memoryRepository(ref);
  }
}

String _$memoryRepositoryHash() => r'd34b7c4c1a601f132cd4feac70008b193fe9dd93';

@ProviderFor(memories)
final memoriesProvider = MemoriesProvider._();

final class MemoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MemoryEntry>>,
          List<MemoryEntry>,
          Stream<List<MemoryEntry>>
        >
    with
        $FutureModifier<List<MemoryEntry>>,
        $StreamProvider<List<MemoryEntry>> {
  MemoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoriesHash();

  @$internal
  @override
  $StreamProviderElement<List<MemoryEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MemoryEntry>> create(Ref ref) {
    return memories(ref);
  }
}

String _$memoriesHash() => r'8e3980ddec075d822b90277bd34dfdd15cfe2e96';
