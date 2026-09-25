// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command_channels_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CommandChannelsController)
final commandChannelsControllerProvider = CommandChannelsControllerProvider._();

final class CommandChannelsControllerProvider
    extends
        $AsyncNotifierProvider<
          CommandChannelsController,
          CommandChannelsState
        > {
  CommandChannelsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commandChannelsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commandChannelsControllerHash();

  @$internal
  @override
  CommandChannelsController create() => CommandChannelsController();
}

String _$commandChannelsControllerHash() =>
    r'546b7d010bde8d8eb87b7858528257da2bfb0ec8';

abstract class _$CommandChannelsController
    extends $AsyncNotifier<CommandChannelsState> {
  FutureOr<CommandChannelsState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<CommandChannelsState>, CommandChannelsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<CommandChannelsState>,
                CommandChannelsState
              >,
              AsyncValue<CommandChannelsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
