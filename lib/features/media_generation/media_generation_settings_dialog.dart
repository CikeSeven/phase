import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/failure.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../data/models/media_generation.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/provider_profile.dart';
import '../../data/models/video_generation.dart';
import '../../data/repositories/media_generation_repository.dart';
import '../../data/repositories/provider_profile_repository.dart';
import '../../data/repositories/video_generation_repository.dart';

class MediaGenerationSettingsDialog extends ConsumerStatefulWidget {
  const MediaGenerationSettingsDialog({required this.repository, super.key});

  final MediaGenerationRepository repository;

  @override
  ConsumerState<MediaGenerationSettingsDialog> createState() =>
      _MediaGenerationSettingsDialogState();
}

class _MediaGenerationSettingsDialogState
    extends ConsumerState<MediaGenerationSettingsDialog> {
  final _custom = TextEditingController();
  Completer<void>? _catalogRequest;
  List<VideoCatalogModel> _catalog = const [];
  String? _catalogError;
  bool _editingCustom = false;
  late final MediaGenerationSettings? _initial;
  VideoGenerationProtocol _protocol = VideoGenerationProtocol.seedance;
  String _profileId = '';
  String _modelId = '';
  bool _saving = false;
  String? _error;

  bool get _video => widget.repository.kind == MediaGenerationKind.video;

  @override
  void initState() {
    super.initState();
    _initial = widget.repository.read();
    if (_initial case final settings?) {
      _profileId = settings.target.profileId;
      _modelId = settings.target.modelId;
      if (settings.video case final options?) {
        _protocol = options.protocol;
        if (options.custom.isNotEmpty) {
          _custom.text = const JsonEncoder.withIndent('  ').convert({
            for (final MapEntry(:key, :value) in options.custom.entries)
              key: value.toJson(),
          });
        }
      }
    }
    if (_video && _profileId.isNotEmpty) unawaited(_loadVideoModels());
  }

  @override
  void dispose() {
    _catalogRequest?.complete();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _save(
    MediaGenerationTarget? target, [
    VideoCatalogModel? model,
  ]) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final options = target != null && _video
          ? VideoGenerationOptions(
              _protocol,
              preset: model?.preset,
              custom: VideoGenerationOptions.parseCustomText(_custom.text),
            )
          : null;
      await widget.repository.save(
        target == null ? null : MediaGenerationSettings(target, video: options),
      );
      if (mounted) Navigator.of(context).pop();
    } on Failure catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.userMessage;
      });
    }
  }

  Future<void> _loadVideoModels() async {
    final repository = widget.repository;
    if (repository is! VideoGenerationRepository) return;
    _catalogRequest?.complete();
    final request = Completer<void>();
    setState(() {
      _catalogRequest = _profileId.isEmpty ? null : request;
      _catalog = const [];
      _catalogError = null;
    });
    if (_profileId.isEmpty) return;
    var models = const <VideoCatalogModel>[];
    String? failure;
    try {
      models = await repository.listModels(
        _profileId,
        _protocol,
        request.future,
      );
    } on Failure catch (error) {
      failure = error.userMessage;
    } finally {
      if (mounted && identical(request, _catalogRequest)) {
        setState(() {
          _catalog = models;
          _catalogError = failure;
          _catalogRequest = null;
        });
      }
    }
  }

  List<VideoCatalogModel> _videoModels(ProviderProfile? profile) {
    if (profile == null) return const [];
    final choices = {for (final model in _catalog) model.id: model};
    if (choices.isEmpty) {
      final known = profile.models
          .where((model) => VideoCatalogModel.advertisesVideo(model.id))
          .toList();
      for (final model
          in known.isEmpty && _protocol == VideoGenerationProtocol.compatible
              ? profile.models
              : known) {
        choices[model.id] = VideoCatalogModel(
          model.id,
          model.label,
          preset: _protocol == VideoGenerationProtocol.seedance
              ? _protocol.parameters
              : null,
        );
      }
    }
    final initial = _initial;
    if (initial != null &&
        initial.target.profileId == profile.id &&
        initial.video?.protocol == _protocol) {
      final id = initial.target.modelId;
      choices.putIfAbsent(
        id,
        () => VideoCatalogModel(id, id, preset: initial.video?.preset),
      );
    }
    return choices.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.repository.kind;
    final state = ref.watch(providerProfilesProvider);
    final profiles = (state.value ?? const <ProviderProfile>[]).where(
      (profile) =>
          supportsMediaGeneration(profile.protocol) &&
          (_video || profile.models.isNotEmpty),
    );
    final profile = profiles
        .where((profile) => profile.id == _profileId)
        .firstOrNull;
    final models = profile?.models ?? const <ProfileModel>[];
    final videoModels = _video
        ? _videoModels(profile)
        : const <VideoCatalogModel>[];
    final selectedVideo = videoModels
        .where((model) => model.id == _modelId)
        .firstOrNull;
    final modelId = _video
        ? selectedVideo?.id ?? ''
        : models.where((model) => model.id == _modelId).firstOrNull?.id ?? '';
    final error = _error;
    return PopScope(
      canPop: !_saving,
      child: AppDialog(
        title: kind.label,
        description: _video
            ? '从服务商列表选择聊天时使用的视频模型。'
            : '选择聊天时使用的图像模型。相月会使用该服务商的图像生成接口。',
        icon: _video ? LucideIcons.video : LucideIcons.image,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.m,
          children: [
            if (state.isLoading && !state.hasValue)
              const Center(
                child: AppLoadingIndicator(semanticsLabel: '正在读取服务商'),
              )
            else if (state.hasError)
              TextButton(
                onPressed: () => ref.invalidate(providerProfilesProvider),
                child: const Text('读取服务商失败，重试'),
              )
            else if (profiles.isEmpty)
              Text(
                _video
                    ? '请先在服务商设置中添加服务商和 API 地址。'
                    : '请先在服务商设置中添加 OpenAI 兼容服务商和图像模型。',
              )
            else ...[
              AppDropdown<String>(
                label: '服务商',
                value: profile?.id ?? '',
                options: {
                  '': '选择服务商',
                  for (final item in profiles) item.id: item.name,
                },
                onChanged: _saving
                    ? null
                    : (id) {
                        setState(() {
                          _profileId = id;
                          _modelId = '';
                          if (_video) {
                            final selected = profiles
                                .where((profile) => profile.id == id)
                                .firstOrNull;
                            _protocol = VideoGenerationProtocol.forBaseUrl(
                              selected?.baseUrl ?? '',
                            );
                            _custom.clear();
                            _editingCustom = false;
                          }
                          _error = null;
                        });
                        if (_video) unawaited(_loadVideoModels());
                      },
              ),
              if (_video)
                ..._videoFields(profile != null, videoModels, selectedVideo)
              else
                AppDropdown<String>(
                  label: '图像模型',
                  value: modelId,
                  options: {
                    '': '选择图像模型',
                    for (final item in models) item.id: item.label,
                  },
                  onChanged: _saving || profile == null
                      ? null
                      : (id) {
                          setState(() {
                            _modelId = id;
                            _error = null;
                          });
                        },
                ),
            ],
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
        actions: [
          if (_initial != null)
            TextButton(
              onPressed: _saving ? null : () => _save(null),
              child: Text('关闭${kind.label}'),
            ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed:
                _saving || profile == null || modelId.isEmpty || state.hasError
                ? null
                : () => _save((
                    profileId: profile.id,
                    modelId: modelId,
                  ), selectedVideo),
            child: Text(_saving ? '正在保存…' : '保存'),
          ),
        ],
      ),
    );
  }

  List<Widget> _videoFields(
    bool hasProfile,
    List<VideoCatalogModel> models,
    VideoCatalogModel? selected,
  ) => [
    AppDropdown<String>(
      label: '视频模型',
      value: selected?.id ?? '',
      options: {
        '': '选择视频模型',
        for (final model in models) model.id: model.label,
      },
      onChanged: _saving || models.isEmpty
          ? null
          : (id) => setState(() {
              _modelId = id;
              _error = null;
              _editingCustom = false;
              final saved = _initial;
              final custom =
                  saved?.target == (profileId: _profileId, modelId: id) &&
                      saved?.video?.protocol == _protocol
                  ? saved?.video?.custom
                  : null;
              _custom.text = custom == null || custom.isEmpty
                  ? ''
                  : const JsonEncoder.withIndent('  ').convert({
                      for (final entry in custom.entries)
                        entry.key: entry.value.toJson(),
                    });
            }),
    ),
    if (_catalogRequest != null)
      const Center(child: AppLoadingIndicator(semanticsLabel: '正在获取视频模型'))
    else if (hasProfile && (_catalogError != null || models.isEmpty)) ...[
      Text(_catalogError ?? '服务商暂无可选视频模型'),
      TextButton(
        onPressed: _saving ? null : _loadVideoModels,
        child: const Text('重新获取模型'),
      ),
    ],
    AppDropdown<VideoGenerationProtocol>(
      label: '视频接口',
      value: _protocol,
      options: {
        for (final item in VideoGenerationProtocol.values) item: item.label,
      },
      onChanged: _saving || !hasProfile
          ? null
          : (value) {
              if (value == _protocol) return;
              setState(() {
                _protocol = value;
                _modelId = '';
                _custom.clear();
                _editingCustom = false;
                _error = null;
              });
              unawaited(_loadVideoModels());
            },
    ),
    if (selected != null && selected.preset == null)
      const Text('该模型没有专用参数预设。可添加自定义字段。'),
    if (selected != null &&
        selected.preset != null &&
        !_editingCustom &&
        _custom.text.isEmpty)
      TextButton(
        onPressed: _saving ? null : () => setState(() => _editingCustom = true),
        child: const Text('添加自定义字段'),
      ),
    if (selected != null &&
        (selected.preset == null || _editingCustom || _custom.text.isNotEmpty))
      TextField(
        controller: _custom,
        enabled: hasProfile && !_saving,
        minLines: 2,
        maxLines: 6,
        autocorrect: false,
        enableSuggestions: false,
        smartQuotesType: SmartQuotesType.disabled,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: const InputDecoration(
          labelText: '自定义字段（JSON，可选）',
          hintText: '{"watermark":{"type":"boolean","description":"是否添加水印"}}',
          alignLabelWithHint: true,
        ),
      ),
  ];
}
