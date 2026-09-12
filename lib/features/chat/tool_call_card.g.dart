// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_call_card.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 一条工具记录的流：卡片跟随记录状态更新。
///
/// 记录被删除时流不发值，卡片整块不显示，不伪造一次调用。

@ProviderFor(toolCallRecord)
final toolCallRecordProvider = ToolCallRecordFamily._();

/// 一条工具记录的流：卡片跟随记录状态更新。
///
/// 记录被删除时流不发值，卡片整块不显示，不伪造一次调用。

final class ToolCallRecordProvider
    extends
        $FunctionalProvider<
          AsyncValue<ToolCallRecord>,
          ToolCallRecord,
          Stream<ToolCallRecord>
        >
    with $FutureModifier<ToolCallRecord>, $StreamProvider<ToolCallRecord> {
  /// 一条工具记录的流：卡片跟随记录状态更新。
  ///
  /// 记录被删除时流不发值，卡片整块不显示，不伪造一次调用。
  ToolCallRecordProvider._({
    required ToolCallRecordFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'toolCallRecordProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$toolCallRecordHash();

  @override
  String toString() {
    return r'toolCallRecordProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ToolCallRecord> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ToolCallRecord> create(Ref ref) {
    final argument = this.argument as String;
    return toolCallRecord(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ToolCallRecordProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$toolCallRecordHash() => r'334a5ec1bf85223a9b18c79bbcdd4ee6e5ea7d7f';

/// 一条工具记录的流：卡片跟随记录状态更新。
///
/// 记录被删除时流不发值，卡片整块不显示，不伪造一次调用。

final class ToolCallRecordFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ToolCallRecord>, String> {
  ToolCallRecordFamily._()
    : super(
        retry: null,
        name: r'toolCallRecordProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 一条工具记录的流：卡片跟随记录状态更新。
  ///
  /// 记录被删除时流不发值，卡片整块不显示，不伪造一次调用。

  ToolCallRecordProvider call(String toolCallId) =>
      ToolCallRecordProvider._(argument: toolCallId, from: this);

  @override
  String toString() => r'toolCallRecordProvider';
}
