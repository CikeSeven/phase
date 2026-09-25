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
    r'3f056fd5aab3f15248026d4ac322f6040dd636d7';

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
