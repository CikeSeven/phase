import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../data/models/web_search_result.dart';
import '../../data/models/web_search_settings.dart';
import '../../data/repositories/web_search_repository.dart';

part 'web_search_controller.g.dart';

class WebSearchState {
  const WebSearchState(this.settings, {this.busy = false});
  final WebSearchSettings settings;
  final bool busy;
}

@Riverpod(keepAlive: true, dependencies: [webSearchRepository])
class WebSearchController extends _$WebSearchController {
  bool _working = false;

  @override
  FutureOr<WebSearchState> build() =>
      WebSearchState(ref.watch(webSearchRepositoryProvider).read());

  Future<T> _operate<T>(
    Future<T> Function(WebSearchRepository repository) action,
  ) async {
    if (_working) throw const OperationFailure('请等待搜索配置保存完成');
    final current = state.value;
    if (current == null) throw const OperationFailure('搜索配置尚未就绪');
    _working = true;
    state = AsyncData(WebSearchState(current.settings, busy: true));
    final repository = ref.read(webSearchRepositoryProvider);
    try {
      return await action(repository);
    } finally {
      _working = false;
      if (ref.mounted) {
        try {
          state = AsyncData(WebSearchState(repository.read()));
        } on Failure catch (error, stack) {
          state = AsyncError(error, stack);
        }
      }
    }
  }

  Future<void> saveOptions(WebSearchSettings draft) =>
      _operate((repository) => repository.saveOptions(draft));
  Future<void> select(String id) =>
      _operate((repository) => repository.select(id));
  Future<WebSearchProfile> saveProfile(
    WebSearchProfile draft, {
    String? apiKey,
    bool clearKey = false,
  }) => _operate(
    (repository) =>
        repository.saveProfile(draft, apiKey: apiKey, clearKey: clearKey),
  );
  Future<void> deleteProfile(String id) =>
      _operate((repository) => repository.deleteProfile(id));

  Future<bool> credentialStatus(WebSearchProfile profile) =>
      ref.read(webSearchRepositoryProvider).hasCredential(profile);
  Future<WebSearchResult> checkProfile(
    WebSearchProfile draft, {
    String? apiKey,
    Future<void>? cancellation,
  }) => ref
      .read(webSearchRepositoryProvider)
      .checkProfile(draft, apiKey: apiKey, cancellation: cancellation);
}
