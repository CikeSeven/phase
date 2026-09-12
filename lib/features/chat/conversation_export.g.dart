// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_export.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 导出目录：应用私有目录下的 `exports/`。
///
/// 首版不接系统分享（S5 再做）；导出后由界面提示这里的路径。

@ProviderFor(exportDirectory)
final exportDirectoryProvider = ExportDirectoryProvider._();

/// 导出目录：应用私有目录下的 `exports/`。
///
/// 首版不接系统分享（S5 再做）；导出后由界面提示这里的路径。

final class ExportDirectoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<Directory>,
          Directory,
          FutureOr<Directory>
        >
    with $FutureModifier<Directory>, $FutureProvider<Directory> {
  /// 导出目录：应用私有目录下的 `exports/`。
  ///
  /// 首版不接系统分享（S5 再做）；导出后由界面提示这里的路径。
  ExportDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exportDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exportDirectoryHash();

  @$internal
  @override
  $FutureProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Directory> create(Ref ref) {
    return exportDirectory(ref);
  }
}

String _$exportDirectoryHash() => r'91e10a650334009e3aa6562d61e5fda8146de7d6';

/// 会话导出器：会话仓储 + 导出目录。

@ProviderFor(conversationExporter)
final conversationExporterProvider = ConversationExporterProvider._();

/// 会话导出器：会话仓储 + 导出目录。

final class ConversationExporterProvider
    extends
        $FunctionalProvider<
          AsyncValue<ConversationExporter>,
          ConversationExporter,
          FutureOr<ConversationExporter>
        >
    with
        $FutureModifier<ConversationExporter>,
        $FutureProvider<ConversationExporter> {
  /// 会话导出器：会话仓储 + 导出目录。
  ConversationExporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationExporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationExporterHash();

  @$internal
  @override
  $FutureProviderElement<ConversationExporter> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ConversationExporter> create(Ref ref) {
    return conversationExporter(ref);
  }
}

String _$conversationExporterHash() =>
    r'f43eb7229fa64520969daf37dc543cfecea9cf04';
