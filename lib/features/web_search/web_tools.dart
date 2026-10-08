import 'dart:convert';

import '../../core/error/failure.dart';
import '../../data/datasources/remote/web_fetch_client.dart';
import '../../data/models/tool_policy.dart';
import '../../data/models/tool_source.dart';
import '../../data/models/web_search_settings.dart';
import '../../data/repositories/web_search_repository.dart';
import '../tools/tool.dart';

List<Tool> buildWebTools(
  WebSearchRepository repository,
  WebSearchSettings settings,
) => [
  if (settings.searchEnabled) WebSearchTool(repository, settings),
  if (settings.fetchEnabled) WebFetchTool(repository, settings),
];

class WebSearchTool extends Tool {
  const WebSearchTool(this.repository, this.settings);
  final WebSearchRepository repository;
  final WebSearchSettings settings;

  @override
  String get name => 'web_search';
  @override
  String get description =>
      '搜索网页中的最新或需要核实的信息，支持一次并行搜索多个关键词。'
      '返回标题、URL、可选摘录、提供方日期和可选答案。';
  @override
  String get promptSnippet => '搜索网页中的最新信息与来源';
  @override
  List<String> get promptGuidelines => [
    '基于搜索来源回答时在相应句子后以 Markdown 链接引用原始 URL。',
    if (settings.fetchEnabled) '摘录不足或需要核实时，使用 web_fetch 阅读原文。',
  ];
  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'queries': {
        'type': 'array',
        'minItems': 1,
        'maxItems': settings.maxQueries,
        'items': {'type': 'string', 'minLength': 1, 'maxLength': 2048},
        'description': '1 至 ${settings.maxQueries} 个聚焦的搜索查询；完全相同的查询只执行一次。',
      },
      'max_results': {
        'type': 'integer',
        'minimum': 1,
        'maximum': 20,
        'description':
            '期望返回的最大来源数 (1–20)。可选，不填写默认使用用户配置的 ${settings.maxResults} 条。',
      },
    },
    'required': ['queries'],
    'additionalProperties': false,
  };
  @override
  ToolSource get source => ToolSource(
    kind: ToolSourceKind.builtIn,
    id: 'builtIn',
    originalName: name,
    effectClass: ToolEffectClass.readOnly,
    definitionRevision: definitionDigest([name, description, inputSchema]),
  );
  @override
  Set<String> get requiredCapabilities => const {'network'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;
  @override
  String describeAction(Map<String, dynamic> arguments) {
    final queries = (arguments['queries'] as List? ?? const []).join('；');
    final max = arguments['max_results'] ?? arguments['maxResults'];
    return max != null ? '搜索网页（最多 $max 条）：$queries' : '搜索网页：$queries';
  }

  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final queries = arguments['queries'];
    if (queries is! List || queries.any((query) => query is! String)) {
      return 'queries 须为字符串数组';
    }
    final rawMax = arguments['max_results'] ?? arguments['maxResults'];
    if (rawMax != null) {
      final max = rawMax is num ? rawMax.toInt() : null;
      if (max == null || max < 1 || max > 20) {
        return 'max_results 须为 1 至 20 的整数';
      }
    }
    try {
      WebSearchRepository.validateQueries(
        queries.cast<String>(),
        settings.maxQueries,
      );
    } on WebFailure catch (failure) {
      return failure.userMessage;
    }
    return null;
  }

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    cancellation.throwIfCancelled();
    final validation = validateArguments(arguments);
    if (validation != null) {
      return ToolOutcome.failure(validation, errorCode: 'invalidArguments');
    }
    onProgress?.call('正在搜索网页');
    final rawMax = arguments['max_results'] ?? arguments['maxResults'];
    final requestedMax = rawMax is num ? rawMax.toInt() : null;
    final effectiveMax = requestedMax?.clamp(1, 20) ?? settings.maxResults;
    try {
      final result = await repository.search(
        settings,
        (arguments['queries'] as List).cast<String>(),
        maxResults: effectiveMax,
        cancellation: cancellation.whenCancelled,
      );
      cancellation.throwIfCancelled();
      return ToolOutcome.success(jsonEncode(result.toJson()));
    } on WebFailure catch (failure) {
      return failure.code == 'cancelled'
          ? ToolOutcome.cancelled(failure.userMessage)
          : ToolOutcome.failure(failure.userMessage, errorCode: failure.code);
    }
  }
}

class WebFetchTool extends Tool {
  const WebFetchTool(this.repository, this.settings);
  final WebSearchRepository repository;
  final WebSearchSettings settings;
  @override
  String get name => 'web_fetch';
  @override
  String get description =>
      '读取公网 HTTP(S) URL 的 HTML、文本、JSON 或 PDF 正文。'
      '返回最终 URL、HTTP 状态、可读正文与截断标记。';
  @override
  String get promptSnippet => '读取网页原文并核实搜索来源';
  @override
  List<String> get promptGuidelines => const ['引用网页内容时以 Markdown 链接标注 URL 来源。'];
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'url': {
        'type': 'string',
        'minLength': 1,
        'maxLength': 4096,
        'description': '要读取的完整公网 HTTP(S) URL',
      },
    },
    'required': ['url'],
    'additionalProperties': false,
  };
  @override
  ToolSource get source => ToolSource(
    kind: ToolSourceKind.builtIn,
    id: 'builtIn',
    originalName: name,
    effectClass: ToolEffectClass.readOnly,
    definitionRevision: definitionDigest([name, description, inputSchema]),
  );
  @override
  Set<String> get requiredCapabilities => const {'network'};
  @override
  ToolPolicy get defaultPolicy => ToolPolicy.allow;
  @override
  String describeAction(Map<String, dynamic> arguments) =>
      '读取网页：${arguments['url'] ?? ''}';
  @override
  String? validateArguments(Map<String, dynamic> arguments) {
    final url = arguments['url'];
    if (url is! String) return 'url 须为完整网页地址';
    try {
      WebFetchClient.validateUrl(url);
    } on WebFailure catch (failure) {
      return failure.userMessage;
    }
    return null;
  }

  @override
  Future<ToolOutcome> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
    RunCancellation cancellation, {
    ToolProgress? onProgress,
  }) async {
    cancellation.throwIfCancelled();
    final validation = validateArguments(arguments);
    if (validation != null) {
      return ToolOutcome.failure(validation, errorCode: 'invalidArguments');
    }
    onProgress?.call('正在读取网页正文');
    try {
      final result = await repository.fetch(
        settings,
        arguments['url'] as String,
        cancellation: cancellation.whenCancelled,
      );
      cancellation.throwIfCancelled();
      final content = jsonEncode(result.toJson());
      return result.statusCode >= 200 && result.statusCode < 300
          ? ToolOutcome.success(content)
          : ToolOutcome.failure(content, errorCode: 'http${result.statusCode}');
    } on WebFailure catch (failure) {
      return failure.code == 'cancelled'
          ? ToolOutcome.cancelled(failure.userMessage)
          : ToolOutcome.failure(failure.userMessage, errorCode: failure.code);
    }
  }
}
