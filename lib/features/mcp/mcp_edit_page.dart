import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/app_bottom_bar.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/models/mcp_server_profile.dart';
import '../../../data/models/tool_policy.dart';
import '../chat/chat_controller.dart';
import '../tools/tool.dart';
import 'mcp_controller.dart';

class McpEditPage extends ConsumerStatefulWidget {
  const McpEditPage({super.key, this.serverId});
  final String? serverId;
  @override
  ConsumerState<McpEditPage> createState() => _McpEditPageState();
}

class _McpEditPageState extends ConsumerState<McpEditPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _endpoint = TextEditingController();
  final _bearer = TextEditingController();
  final _headers = TextEditingController();
  final _connectTimeout = TextEditingController(text: '15');
  final _callTimeout = TextEditingController(text: '60');
  late final String _id;
  McpServerEntry? _entry;
  bool _loading = true;
  bool _enabled = true;
  bool _requiresBearer = false;
  bool _saving = false;
  bool _checking = false;
  bool _dirty = false;
  String? _error;
  String? _notice;
  bool get _busy => _saving || _checking;

  @override
  void initState() {
    super.initState();
    _id = widget.serverId ?? generateId();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _endpoint,
      _bearer,
      _headers,
      _connectTimeout,
      _callTimeout,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (_error != null) ref.invalidate(mcpControllerProvider(_id));
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entry = await ref.read(mcpControllerProvider(_id).future);
      if (!mounted) return;
      if (widget.serverId != null && entry == null) {
        throw const OperationFailure('MCP 服务已不存在');
      }
      setState(() {
        _entry = entry;
        if (entry != null) {
          _name.text = entry.profile.name;
          _endpoint.text = entry.profile.endpoint;
          _enabled = entry.profile.enabled;
          _requiresBearer = entry.profile.requiresBearer;
          _connectTimeout.text = '${entry.profile.connectTimeoutSeconds}';
          _callTimeout.text = '${entry.profile.callTimeoutSeconds}';
        }
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          _loading = false;
        });
      }
    }
  }

  String _message(Object error) => error is ToolCancelled
      ? '连接检查已取消'
      : error is Failure
      ? error.userMessage
      : '操作失败，请重试';

  void _changed(String _) => setState(() {
    _dirty = true;
    _notice = null;
  });

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      Map<String, String>? headers;
      if (_headers.text.trim().isNotEmpty) {
        try {
          headers = Map<String, String>.from(jsonDecode(_headers.text) as Map);
        } on Object {
          throw const OperationFailure('请求头应为名称和值均为文本的 JSON 对象');
        }
      }
      final now = DateTime.now();
      await ref
          .read(mcpControllerProvider(_id).notifier)
          .save(
            McpServerProfile(
              id: _id,
              name: _name.text.trim(),
              endpoint: _endpoint.text.trim(),
              definitionRevision:
                  _entry?.profile.definitionRevision ?? generateId(),
              createdAt: _entry?.profile.createdAt ?? now,
              updatedAt: now,
              enabled: _enabled,
              requiresBearer: _requiresBearer,
              credentialRef: _entry?.profile.credentialRef,
              connectTimeoutSeconds: int.parse(_connectTimeout.text),
              callTimeoutSeconds: int.parse(_callTimeout.text),
            ),
            bearer: _bearer.text,
            headers: headers,
          );
      if (!mounted) return;
      _bearer.clear();
      _headers.clear();
      context.pop();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _check() async {
    if (_busy || _dirty) return;
    setState(() {
      _checking = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(mcpControllerProvider(_id).notifier).check();
      if (!mounted) return;
      setState(() {
        _entry = ref.read(mcpControllerProvider(_id)).value;
        _notice = '已完成连接与工具发现，未执行工具。';
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: '删除 MCP 服务',
        description: '关闭此服务的连接并删除凭据。历史工具记录保留。',
        content: const SizedBox.shrink(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(mcpControllerProvider(_id).notifier).delete();
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _entry = ref.read(mcpControllerProvider(_id)).value ?? _entry;
          _error = '删除未完成，请重试删除。${_message(error)}';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mcpControllerProvider(_id));
    final assistants = ref.watch(assistantsProvider);
    final deleting = _entry?.profile.deleting == true;
    return PopScope(
      canPop: !_saving,
      child: AppScaffold(
        title: widget.serverId == null ? '新增 MCP 服务' : '编辑 MCP 服务',
        bottomBar: _loading || (widget.serverId != null && _entry == null)
            ? null
            : AppBottomBar(
                child: Row(
                  children: [
                    if (_entry != null)
                      IconButton.filledTonal(
                        tooltip: '删除 MCP 服务',
                        onPressed: _busy ? null : _delete,
                        icon: const Icon(Symbols.delete),
                      ),
                    if (_entry != null) const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('mcp-save'),
                        onPressed: _busy || deleting ? null : _save,
                        icon: _saving
                            ? const AppLoadingIndicator.small()
                            : const Icon(Symbols.check),
                        label: Text(_saving ? '保存中…' : '保存'),
                      ),
                    ),
                  ],
                ),
              ),
        body: _loading
            ? const Center(child: AppLoadingIndicator())
            : widget.serverId != null && _entry == null
            ? AppEmptyState(
                icon: Symbols.error,
                title: '无法读取 MCP 服务',
                message: _error ?? '服务不存在',
                action: FilledButton.tonal(
                  onPressed: _load,
                  child: const Text('重试'),
                ),
              )
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  children: [
                    const Text('Streamable HTTP'),
                    const SizedBox(height: AppSpacing.l),
                    TextFormField(
                      key: const ValueKey('mcp-name'),
                      controller: _name,
                      enabled: !_busy && !deleting,
                      onChanged: _changed,
                      decoration: const InputDecoration(labelText: '名称'),
                      validator: (value) =>
                          value == null ||
                              value.trim().isEmpty ||
                              value.length > 100
                          ? '请填写 1–100 个字符的名称'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    TextFormField(
                      key: const ValueKey('mcp-endpoint'),
                      controller: _endpoint,
                      enabled: !_busy && !deleting,
                      onChanged: _changed,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: '服务地址',
                        hintText: 'https://example.com/mcp',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请填写服务地址'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SwitchListTile.adaptive(
                      title: const Text('启用服务'),
                      contentPadding: EdgeInsets.zero,
                      value: _enabled,
                      onChanged: _busy || deleting
                          ? null
                          : (value) => setState(() {
                              _enabled = value;
                              _dirty = true;
                            }),
                    ),
                    SwitchListTile.adaptive(
                      title: const Text('Bearer 鉴权'),
                      contentPadding: EdgeInsets.zero,
                      value: _requiresBearer,
                      onChanged: _busy || deleting
                          ? null
                          : (value) => setState(() {
                              _requiresBearer = value;
                              _dirty = true;
                            }),
                    ),
                    if (_requiresBearer) ...[
                      TextFormField(
                        key: const ValueKey('mcp-bearer'),
                        controller: _bearer,
                        enabled: !_busy && !deleting,
                        onChanged: _changed,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Bearer 凭据',
                          helperText: '留空保留已保存的凭据',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.l),
                    ],
                    TextFormField(
                      key: const ValueKey('mcp-headers'),
                      controller: _headers,
                      enabled: !_busy && !deleting,
                      onChanged: _changed,
                      minLines: 1,
                      maxLines: 4,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: '自定义请求头（JSON，可选）',
                        helperText:
                            '加密保存；留空保留，输入 {} 清除。${_entry?.profile.headerRefs.isNotEmpty == true ? "已保存：${_entry!.profile.headerRefs.keys.join('、')}" : ""}',
                      ),
                    ),
                    for (final field in [
                      (_connectTimeout, '连接超时（秒）', 120),
                      (_callTimeout, '调用超时（秒）', 300),
                    ]) ...[
                      const SizedBox(height: AppSpacing.m),
                      TextFormField(
                        controller: field.$1,
                        enabled: !_busy && !deleting,
                        onChanged: _changed,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: field.$2),
                        validator: (value) {
                          final number = int.tryParse(value ?? '');
                          return number == null ||
                                  number < 1 ||
                                  number > field.$3
                              ? '请输入 1–${field.$3}'
                              : null;
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.l),
                    if (_entry == null || _dirty)
                      const Text('保存配置后，可在服务详情中检查连接和发现工具。'),
                    if (_entry != null)
                      Wrap(
                        spacing: AppSpacing.s,
                        runSpacing: AppSpacing.s,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy || _dirty || deleting
                                ? null
                                : _check,
                            icon: _checking
                                ? const AppLoadingIndicator.small()
                                : const Icon(Symbols.sync),
                            label: Text(_checking ? '正在检查…' : '检查连接与工具'),
                          ),
                          if (_checking)
                            TextButton(
                              onPressed: () => ref
                                  .read(mcpControllerProvider(_id).notifier)
                                  .cancelCheck(),
                              child: const Text('取消检查'),
                            ),
                        ],
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.m,
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_notice != null) Text(_notice!),
                    if (_entry?.protocolVersion case final version?) ...[
                      const SizedBox(height: AppSpacing.l),
                      Text('工具目录 · MCP $version'),
                      const Text('添加服务不会自动向助手开放工具，请在助手编辑页选择。'),
                      for (final tool in _entry!.tools)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(tool.source.originalName),
                          subtitle: Text(
                            assistants.when(
                              data: (items) =>
                                  '已向 ${items.where((a) => (a.toolPolicy.policies[tool.name] ?? ToolPolicy.deny) != ToolPolicy.deny).length} 个助手开放',
                              loading: () => '正在读取助手范围…',
                              error: (_, _) => '助手范围读取失败',
                            ),
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SelectableText(
                                '${tool.description}\n\n${const JsonEncoder.withIndent("  ").convert(tool.inputSchema)}',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
