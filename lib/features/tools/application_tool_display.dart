import 'dart:convert';

import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_source.dart';

/// 应用工具的阅读投影；记录中的快照、权限信息和协议字段不在卡片展开。
class ApplicationToolDisplay {
  ApplicationToolDisplay(this.record) : result = _result(record.result);

  final ToolCallRecord record;
  final Map<String, dynamic>? result;

  static bool supports(ToolCallRecord record) =>
      record.source?.kind != ToolSourceKind.mcp &&
      const {
        'list_apps',
        'open_app',
        'inspect_ui',
        'click_node',
        'scroll',
        'input_text',
        'capture_screen',
        'perform_gestures',
        'shizuku_display',
      }.contains(record.toolName);

  String? get packageName {
    if (record.arguments['packageName'] case final String package) {
      return package;
    }
    if (result?['screenshot'] case {'packageName': final String package}) {
      return package;
    }
    if (result?['snapshot'] case {'packageName': final String package}) {
      return package;
    }
    return result?['packageName'] is String
        ? result!['packageName'] as String
        : null;
  }

  String? get title => record.toolName == 'shizuku_display'
      ? switch (record.arguments['action']) {
          'launch' => '在虚拟屏打开应用',
          'capture' => '观察虚拟屏',
          'tap' => '点击虚拟屏',
          'swipe' => '滑动虚拟屏',
          'key' => '虚拟屏按键',
          'text' => '虚拟屏输入',
          'close' => '关闭虚拟屏',
          _ => '控制虚拟屏',
        }
      : record.toolName == 'perform_gestures' &&
            record.arguments['actions'] is List
      ? '执行 ${(record.arguments['actions'] as List).length} 步手势'
      : null;

  bool get showScreenshots =>
      record.toolName == 'capture_screen' ||
      record.toolName == 'perform_gestures' ||
      record.toolName == 'shizuku_display';

  String? get call {
    final args = record.arguments;
    final node = args['nodeId'] is String ? '控件 ${args['nodeId']}' : '未指定控件';
    return switch (record.toolName) {
      'click_node' => node,
      'scroll' =>
        '$node · ${switch (args['direction']) {
          'forward' => '向前滚动',
          'backward' => '向后滚动',
          _ => '未指定方向',
        }}',
      'input_text' =>
        '$node\n${args['text'] is String ? args['text'] : '未提供输入文字'}',
      'perform_gestures' => _gestures(args),
      'shizuku_display' => switch (args['action']) {
        'tap' => '图片坐标 (${args['x']}, ${args['y']})',
        'swipe' =>
          '图片坐标 (${args['x']}, ${args['y']}) → (${args['endX']}, ${args['endY']}) · ${args['durationMs'] ?? 400} 毫秒',
        'key' => '${args['key']}',
        'text' => '${args['text']}',
        _ => null,
      },
      'list_apps' => [
        if (args['query'] case final String query when query.isNotEmpty)
          '搜索「$query」',
        if (args['sort'] == 'installedAt') '按安装时间排序',
        if (args['sort'] == 'size') '按应用大小排序',
        if (args['offset'] case final num offset when offset > 0)
          '从第 ${offset + 1} 项开始',
      ].join(' · '),
      _ => null,
    };
  }

  String? output(String fallback) {
    final data = result;
    if (data == null) {
      return record.result?.isNotEmpty == true ||
              record.status == ToolCallStatus.failed ||
              record.status == ToolCallStatus.cancelled ||
              record.status == ToolCallStatus.rejected
          ? fallback
          : null;
    }
    final lines = <String>[
      if (data['actionAccepted'] == true && data['observationChanged'] == false)
        '系统已接受动作，界面未变化',
      if (data['actionAccepted'] == false) '系统未接受动作',
      if (record.toolName == 'shizuku_display' &&
          data['actionDispatched'] == true &&
          data['actionAccepted'] != true)
        '动作已派发，未收到完整执行回执',
      if (record.toolName == 'shizuku_display' &&
          data['dispatchRequested'] == true &&
          data['actionDispatched'] != true)
        '已请求执行，未收到完整回执',
      if (record.toolName == 'perform_gestures') ...[
        if (data['completedCount'] case final num count)
          '已完成 $count/${record.arguments['actions'] is List ? (record.arguments['actions'] as List).length : 0} 步',
        if (data['activeStepDispatched'] == true && data['activeStep'] is num)
          '第 ${(data['activeStep'] as num) + 1} 步已派发',
      ],
      for (final key in ['reason', 'error', 'warning', 'observationError'])
        if (data[key] case final String reason when reason.isNotEmpty) reason,
    ];
    if (data['snapshot'] case final Map snapshot
        when record.toolName == 'inspect_ui') {
      if (snapshot['nodes'] case final List nodes) {
        lines.insertAll(0, [
          if (nodes.isEmpty) '未发现可见控件。本次读取不包含截图。',
          for (final node in nodes.whereType<Map>()) _node(node),
          if (snapshot['truncated'] == true) '控件列表已截断',
        ]);
      }
    }
    if (data['applications'] case final List apps
        when record.toolName == 'list_apps') {
      lines.insertAll(0, [
        if (apps.isEmpty) '没有匹配的应用',
        for (final app in apps.whereType<Map>())
          app['name'] is String ? app['name'] as String : '应用名称不可用',
        if (data['nextOffset'] is num) '还有更多应用',
      ]);
    }
    if (lines.isEmpty && record.status == ToolCallStatus.failed) {
      lines.add('执行失败');
    }
    return lines.isEmpty ? null : lines.join('\n');
  }

  static String _node(Map node) {
    final label = [
      node['text'],
      node['description'],
      node['viewId'],
    ].whereType<String>().where((value) => value.isNotEmpty).firstOrNull;
    return '控件 ${node['id'] ?? '未知'}${label == null ? '' : ' · $label'}';
  }

  static String _gestures(Map<String, dynamic> args) {
    final actions = args['actions'];
    if (actions is! List) return '未提供手势';
    return [
      if (args['coordinateSpace'] == 'image_pixels')
        '图片坐标（${args['imageWidth']} × ${args['imageHeight']}）'
      else
        '屏幕坐标',
      for (final (index, step) in actions.indexed)
        '${index + 1}. ${step is Map ? _gesture(step) : '无效手势'}',
    ].join('\n');
  }

  static String _gesture(Map step) {
    String number(Object? value) =>
        value is num && value == value.roundToDouble()
        ? value.toInt().toString()
        : value?.toString() ?? '?';
    final point = '(${number(step['x'])}, ${number(step['y'])})';
    final duration = step['durationMs'] is num
        ? ' · ${number(step['durationMs'])} 毫秒'
        : '';
    return switch (step['type']) {
      'tap' => '点击 $point',
      'double_tap' => '双击 $point',
      'long_press' => '长按 $point$duration',
      'swipe' =>
        '滑动 $point → (${number(step['endX'])}, ${number(step['endY'])})$duration',
      'wait' => '等待 ${number(step['durationMs'] ?? 400)} 毫秒',
      _ => '未知手势',
    };
  }

  static Map<String, dynamic>? _result(String? text) {
    if (text == null) return null;
    try {
      final value = jsonDecode(text);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }
}
