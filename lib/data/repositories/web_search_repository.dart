import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/id.dart';
import '../../core/utils/logger.dart';
import '../datasources/local/secure_key_storage.dart';
import '../datasources/local/settings_storage.dart';
import '../datasources/remote/web_fetch_client.dart';
import '../datasources/remote/web_page_text.dart';
import '../datasources/remote/web_request_scope.dart';
import '../datasources/remote/web_search/api_search_providers.dart';
import '../datasources/remote/web_search/deepseek_search_provider.dart';
import '../datasources/remote/web_search/duckduckgo_search_provider.dart';
import '../datasources/remote/web_search/web_http_client.dart';
import '../datasources/remote/web_search/web_search_provider.dart';
import '../models/web_search_result.dart';
import '../models/web_search_settings.dart';
import 'web_result_budget.dart';

part 'web_search_repository.g.dart';

class WebSearchRepository {
  WebSearchRepository(this._settings, this._keys, this._http, this._fetch)
    : _current = _settings.readWebSearch();
  final SettingsStorage _settings;
  final SecureKeyStorage _keys;
  final WebHttpClient _http;
  final WebFetchClient _fetch;
  WebSearchSettings _current;
  bool _writing = false;
  bool _disposed = false;
  final _requests =
      <WebRequestScope, ({String? profileId, bool fetch, bool check})>{};

  WebRequestScope _request(
    Duration timeout,
    Future<void>? cancellation, {
    String? profileId,
    bool fetch = false,
    bool check = false,
  }) {
    if (_disposed) throw const WebFailure('cancelled', '网页服务已停止');
    final scope = WebRequestScope(timeout: timeout, cancellation: cancellation);
    _requests[scope] = (profileId: profileId, fetch: fetch, check: check);
    return scope;
  }

  void _closeRequest(WebRequestScope scope) {
    _requests.remove(scope);
    scope.close();
  }

  void _revoke({String? profileId, bool search = false, bool fetch = false}) {
    for (final entry in _requests.entries) {
      final request = entry.value;
      if (profileId != null && request.profileId == profileId ||
          !request.check &&
              (fetch && request.fetch || search && !request.fetch)) {
        entry.key.abort(const WebFailure('disabled', '网页服务已停用，本次请求已停止'));
      }
    }
  }

  void dispose() {
    _disposed = true;
    for (final scope in _requests.keys) {
      scope.abort(const WebFailure('cancelled', '网页服务已停止'));
    }
  }

  WebSearchSettings read() => _current;

  Future<void> _persist(WebSearchSettings next) async {
    await _settings.writeWebSearch(next);
    // preferences 的内存缓存可能先于平台写入更新；运行只读取已确认提交的值。
    _current = next;
  }

  Future<T> _write<T>(Future<T> Function() action) async {
    if (_writing) throw const OperationFailure('请等待搜索配置保存完成');
    _writing = true;
    try {
      return await action();
    } finally {
      _writing = false;
    }
  }

  Future<void> saveOptions(WebSearchSettings draft) => _write(() async {
    final current = read();
    await _persist(
      draft.copyWith(
        profiles: current.profiles,
        selectedProfileId: current.selectedProfileId,
        clearSelection: current.selectedProfileId == null,
      ),
    );
    _revoke(search: !draft.searchEnabled, fetch: !draft.fetchEnabled);
  });

  Future<void> select(String id) => _write(() async {
    final current = read();
    final selected = current.profiles
        .where((profile) => profile.id == id)
        .firstOrNull;
    if (selected == null || !selected.enabled || selected.deleting) {
      throw const OperationFailure('此搜索服务不可选择');
    }
    await _persist(current.copyWith(selectedProfileId: id));
  });

  Future<WebSearchProfile> saveProfile(
    WebSearchProfile draft, {
    String? apiKey,
    bool clearKey = false,
  }) => _write(() async {
    draft.copyWith(clearCredential: clearKey).validate();
    final current = read();
    final previous = current.profiles
        .where((profile) => profile.id == draft.id)
        .firstOrNull;
    if (previous?.deleting == true) {
      throw const OperationFailure('请先完成此搜索服务的删除');
    }
    if (previous != null &&
        (previous.revision != draft.revision || previous.kind != draft.kind)) {
      throw const OperationFailure('搜索配置已变化，请重新打开编辑页');
    }
    if (apiKey != null &&
        (apiKey.length > 8192 || apiKey.contains(RegExp(r'[\x00-\x1f]')))) {
      throw const OperationFailure('搜索密钥格式无效');
    }
    if (clearKey && apiKey?.trim().isNotEmpty == true) {
      throw const OperationFailure('请只选择保存新密钥或移除已有密钥');
    }
    String? newReference;
    try {
      var reference = previous?.credentialRef;
      final references = {...?previous?.credentialRefs};
      if (apiKey?.trim().isNotEmpty == true) {
        newReference = generateId();
        await _keys.writeWebSearch(newReference, apiKey!.trim());
        reference = newReference;
        references.add(reference);
      }
      if (clearKey) reference = null;
      final saved = draft.copyWith(
        credentialRef: reference,
        clearCredential: reference == null,
        credentialRefs: references.toList(),
        revision: generateId(),
      );
      final profiles = [...current.profiles];
      final index = profiles.indexWhere((profile) => profile.id == saved.id);
      if (index < 0) {
        profiles.add(saved);
      } else {
        profiles[index] = saved;
      }
      await _persist(
        current.copyWith(
          profiles: profiles,
          selectedProfileId:
              current.selectedProfileId ?? (saved.enabled ? saved.id : null),
          clearSelection: current.selectedProfileId == null && !saved.enabled,
        ),
      );
      if (!saved.enabled || clearKey) _revoke(profileId: saved.id);
      return saved;
    } on Object {
      if (newReference != null) {
        try {
          await _keys.deleteWebSearch(newReference);
        } on Failure {
          AppLogger.warning('未提交的搜索凭据未能清理');
        }
      }
      rethrow;
    }
  });

  /// 先标记撤权；清理失败可重试，未完成删除的配置不会再次派发网络请求。
  Future<void> deleteProfile(String id) => _write(() async {
    var current = read();
    final profile = current.profiles
        .where((profile) => profile.id == id)
        .firstOrNull;
    if (profile == null) return;
    if (!profile.deleting) {
      current = current.copyWith(
        profiles: [
          for (final item in current.profiles)
            if (item.id == id)
              item.copyWith(enabled: false, deleting: true)
            else
              item,
        ],
      );
      await _persist(current);
    }
    _revoke(profileId: id);
    for (final reference in profile.credentialRefs) {
      await _keys.deleteWebSearch(reference);
    }
    final remaining = current.profiles.where((item) => item.id != id).toList();
    final next = current.selectedProfileId == id
        ? remaining
              .where((item) => item.enabled && !item.deleting)
              .firstOrNull
              ?.id
        : current.selectedProfileId;
    await _persist(
      current.copyWith(
        profiles: remaining,
        selectedProfileId: next,
        clearSelection: next == null,
      ),
    );
  });

  Future<bool> hasCredential(WebSearchProfile profile) async =>
      profile.credentialRef != null &&
      (await _keys.readWebSearch(profile.credentialRef!))?.isNotEmpty == true;

  bool allowed(WebSearchSettings snapshot, {required bool fetch}) {
    final current = read();
    if (fetch) return current.fetchEnabled && snapshot.fetchEnabled;
    if (!current.searchEnabled || !snapshot.searchEnabled) return false;
    final selected = snapshot.selected;
    if (selected == null) return true; // 未配置时保留工具，并在执行时返回可恢复错误。
    final live = current.profiles
        .where((profile) => profile.id == selected.id)
        .firstOrNull;
    return live != null &&
        live.enabled &&
        !live.deleting &&
        live.kind == selected.kind &&
        (selected.credentialRef == null || live.credentialRef != null);
  }

  static List<String> validateQueries(List<String> queries, int maxQueries) {
    if (queries.isEmpty || queries.length > maxQueries) {
      throw WebFailure('invalidArguments', 'queries 须包含 1 至 $maxQueries 个查询');
    }
    for (final query in queries) {
      if (query.trim().isEmpty ||
          utf8.encode(query).length > 2048 ||
          query.contains(RegExp(r'[\x00-\x1f]'))) {
        throw const WebFailure('invalidArguments', '查询不能为空、超过 2048 字节或包含控制字符');
      }
    }
    return queries.toSet().toList();
  }

  Future<WebSearchResult> search(
    WebSearchSettings snapshot,
    List<String> queries, {
    int? maxResults,
    Future<void>? cancellation,
  }) async {
    final accepted = validateQueries(queries, snapshot.maxQueries);
    if (!allowed(snapshot, fetch: false)) {
      throw const WebFailure('disabled', '网页搜索或当前搜索服务已停用');
    }
    final profile = snapshot.selected;
    if (profile == null) {
      throw const WebFailure('notConfigured', '请在设置中配置并选择搜索服务');
    }
    if (!profile.enabled || profile.deleting) {
      throw const WebFailure('disabled', '当前搜索服务已停用');
    }
    final effectiveMax = (maxResults ?? snapshot.maxResults).clamp(1, 20);
    return _search(
      profile,
      snapshot,
      accepted,
      cancellation,
      maxResultsOverride: effectiveMax,
      enforceAuthorization: true,
    );
  }

  /// 手动检查只使用用户提供的草稿；密钥仅驻留本次请求，不写普通设置。
  Future<WebSearchResult> checkProfile(
    WebSearchProfile profile, {
    String? apiKey,
    Future<void>? cancellation,
  }) {
    profile.validate();
    final settings = read().copyWith(maxResults: 1);
    return _search(
      profile,
      settings,
      ['Flutter documentation'],
      cancellation,
      maxResultsOverride: 1,
      draftKey: apiKey,
    );
  }

  Future<WebSearchResult> _search(
    WebSearchProfile profile,
    WebSearchSettings settings,
    List<String> queries,
    Future<void>? cancellation, {
    int? maxResultsOverride,
    String? draftKey,
    bool enforceAuthorization = false,
  }) async {
    final effectiveMax = maxResultsOverride ?? settings.maxResults;
    final scope = _request(
      Duration(seconds: settings.searchTimeoutSeconds),
      cancellation,
      profileId: profile.id,
      check: !enforceAuthorization,
    );
    try {
      final apiKey = draftKey?.trim().isNotEmpty == true
          ? draftKey!.trim()
          : profile.credentialRef == null
          ? null
          : await scope.guard(_keys.readWebSearch(profile.credentialRef!));
      scope.check();
      if (profile.kind.requiresKey && (apiKey == null || apiKey.isEmpty)) {
        throw const WebFailure('credentialMissing', '搜索密钥未配置，请编辑当前搜索服务');
      }
      if (apiKey != null && apiKey.contains(RegExp(r'[\x00-\x1f]'))) {
        throw const WebFailure('credentialInvalid', '搜索密钥格式无效，请重新设置');
      }
      if (apiKey != null && apiKey.isNotEmpty) {
        if (apiKey.length > 8192) {
          throw const WebFailure('credentialInvalid', '搜索密钥格式无效');
        }
        profile.copyWith(credentialRef: 'validation').validate();
      }
      if (enforceAuthorization && !allowed(settings, fetch: false)) {
        throw const WebFailure('disabled', '网页搜索或当前搜索服务已停用');
      }
      final provider = _provider(profile.kind);
      Object? firstFailure;
      final pages = List<WebSearchPage?>.filled(queries.length, null);
      await Future.wait(
        queries.indexed.map((entry) async {
          try {
            pages[entry.$1] = await provider.search(
              query: entry.$2,
              maxResults: effectiveMax,
              profile: profile,
              apiKey: apiKey,
              scope: scope,
            );
          } on Object catch (error) {
            firstFailure ??= error;
            scope.abort(const WebFailure('batchCancelled', '搜索批次已停止'));
          }
        }),
      );
      if (firstFailure != null) {
        if (firstFailure is Failure) throw firstFailure!;
        throw const WebFailure('invalidResponse', '搜索服务返回的结果无法解析');
      }
      scope.check();
      return _merge(queries, pages.cast<WebSearchPage>(), effectiveMax);
    } finally {
      _closeRequest(scope);
    }
  }

  Future<WebFetchResult> fetch(
    WebSearchSettings snapshot,
    String url, {
    Future<void>? cancellation,
  }) async {
    if (!allowed(snapshot, fetch: true)) {
      throw const WebFailure('disabled', '网页读取已停用');
    }
    final scope = _request(
      Duration(seconds: snapshot.fetchTimeoutSeconds),
      cancellation,
      fetch: true,
    );
    try {
      final result = await _fetch.fetch(
        url,
        scope,
        maxCharacters: snapshot.maxPageCharacters,
      );
      scope.check();
      return boundWebFetchResult(result);
    } finally {
      _closeRequest(scope);
    }
  }

  WebSearchProvider _provider(WebSearchProviderKind kind) => switch (kind) {
    WebSearchProviderKind.duckDuckGo => DuckduckgoSearchProvider(_http),
    WebSearchProviderKind.bing => BingSearchProvider(_http),
    WebSearchProviderKind.deepseek => DeepseekSearchProvider(_http),
    WebSearchProviderKind.exa => ExaSearchProvider(_http),
    WebSearchProviderKind.brave => BraveSearchProvider(_http),
    WebSearchProviderKind.tavily => TavilySearchProvider(_http),
    WebSearchProviderKind.perplexity => PerplexitySearchProvider(_http),
    WebSearchProviderKind.searxng => SearxngSearchProvider(_http),
    WebSearchProviderKind.bocha => BochaSearchProvider(_http),
    WebSearchProviderKind.serper => SerperSearchProvider(_http),
    WebSearchProviderKind.jina => JinaSearchProvider(_http),
  };

  WebSearchResult _merge(
    List<String> queries,
    List<WebSearchPage> pages,
    int maxResults,
  ) {
    final sources = <WebSearchSource>[];
    final seen = <String>{};
    var truncated = pages.any((page) => page.truncated);
    final maxRank = pages
        .map((page) => page.sources.length)
        .fold(0, (a, b) => a > b ? a : b);
    for (var rank = 0; rank < maxRank; rank++) {
      for (final page in pages) {
        if (rank >= page.sources.length) continue;
        final source = page.sources[rank];
        final uri = Uri.tryParse(source.url);
        if (uri == null ||
            !const {'http', 'https'}.contains(uri.scheme) ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            source.url.length > 4096) {
          truncated = true;
          continue;
        }
        if (!seen.add(uri.replace(fragment: '').toString())) continue;
        if (sources.length == maxResults) {
          truncated = true;
          continue;
        }
        truncated |=
            (source.snippet?.length ?? 0) > 2000 ||
            (source.title?.length ?? 0) > 400;
        sources.add(
          WebSearchSource(
            url: source.url,
            title: source.title == null
                ? null
                : clipWebText(source.title!, 400),
            snippet: source.snippet == null
                ? null
                : clipWebText(source.snippet!, 2000),
            publishedAt: source.publishedAt == null
                ? null
                : clipWebText(source.publishedAt!, 100),
          ),
        );
      }
    }
    final answers = <WebSearchAnswer>[];
    for (final (index, page) in pages.indexed) {
      if (page.answer?.isNotEmpty == true) {
        truncated |= page.answer!.length > 10000;
        answers.add(
          WebSearchAnswer(
            query: queries[index],
            text: clipWebText(page.answer!, 10000),
          ),
        );
      }
    }
    return boundWebSearchResult(
      WebSearchResult(
        queries: List.unmodifiable(queries),
        sources: List.unmodifiable(sources),
        answers: List.unmodifiable(answers),
        retrievedAt: DateTime.now().toUtc(),
        truncated: truncated,
      ),
    );
  }
}

@Riverpod(keepAlive: true, dependencies: [settingsStorage])
WebSearchRepository webSearchRepository(Ref ref) {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  final repository = WebSearchRepository(
    ref.watch(settingsStorageProvider),
    ref.watch(secureKeyStorageProvider),
    WebHttpClient(dio),
    const WebFetchClient(),
  );
  ref.onDispose(() {
    repository.dispose();
    dio.close(force: true);
  });
  return repository;
}
