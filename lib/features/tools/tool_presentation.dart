import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/tool_call_record.dart';
import '../../../data/models/tool_policy.dart';

/// 工具与状态的展示信息：图标、文案、色调。
///
/// 工具卡片、确认面板与执行记录页共用它，避免各写一份状态文案。
class ToolPresentation {
  const ToolPresentation._();

  static IconData icon(String toolName) => switch (toolName) {
    'system_info' => Symbols.schedule,
    'read_file' => Symbols.description,
    'write_file' => Symbols.save,
    'list_files' => Symbols.folder_open,
    'http_request' => Symbols.language,
    'capture_screen' => Symbols.screenshot,
    'perform_gestures' => Symbols.touch_app,
    _ => Symbols.build,
  };

  static String toolLabel(String toolName) => switch (toolName) {
    'system_info' => '时间与设备信息',
    'read_file' => '读取文件',
    'write_file' => '写入文件',
    'list_files' => '列出文件',
    'http_request' => 'HTTP 请求',
    'inspect_ui' => '观察界面',
    'list_apps' => '获取应用列表',
    'open_app' => '打开应用',
    'click_node' => '点击控件',
    'scroll' => '滚动界面',
    'input_text' => '输入文本',
    'capture_screen' => '截图观察',
    'perform_gestures' => '执行手势组合',
    _ => toolName,
  };

  /// 状态文案区分执行阶段与终态，不用“处理中”混淆成功和失败。
  static String statusLabel(ToolCallStatus status) => switch (status) {
    ToolCallStatus.prepared => '准备中',
    ToolCallStatus.awaitingConfirmation => '等待确认',
    ToolCallStatus.executing => '执行中',
    ToolCallStatus.succeeded => '已完成',
    ToolCallStatus.failed => '已失败',
    ToolCallStatus.rejected => '已拒绝',
    ToolCallStatus.cancelled => '已取消',
  };

  static Color statusColor(BuildContext context, ToolCallStatus status) {
    final colors = Theme.of(context).colorScheme;
    return switch (status) {
      ToolCallStatus.succeeded => colors.tertiary,
      ToolCallStatus.failed => colors.error,
      ToolCallStatus.rejected || ToolCallStatus.cancelled => colors.outline,
      ToolCallStatus.prepared ||
      ToolCallStatus.awaitingConfirmation ||
      ToolCallStatus.executing => colors.primary,
    };
  }

  static IconData statusIcon(ToolCallStatus status) => switch (status) {
    ToolCallStatus.prepared => Symbols.hourglass_top,
    ToolCallStatus.awaitingConfirmation => Symbols.pan_tool_alt,
    ToolCallStatus.executing => Symbols.progress_activity,
    ToolCallStatus.succeeded => Symbols.check_circle,
    ToolCallStatus.failed => Symbols.error,
    ToolCallStatus.rejected => Symbols.block,
    ToolCallStatus.cancelled => Symbols.cancel,
  };

  /// 该状态是否仍在进行（用于显示进度动画）。
  static bool isInFlight(ToolCallStatus status) => switch (status) {
    ToolCallStatus.prepared ||
    ToolCallStatus.awaitingConfirmation ||
    ToolCallStatus.executing => true,
    _ => false,
  };

  /// 策略文案。
  static String policyLabel(ToolPolicy policy) => switch (policy) {
    ToolPolicy.allow => '直接执行',
    ToolPolicy.ask => '需要确认',
    ToolPolicy.deny => '禁止使用',
  };

  /// 执行通道文案：确认面板与执行记录都显示实际通道，不按工具名猜。
  static String channelLabel(ExecutionChannel channel) => switch (channel) {
    ExecutionChannel.app => '应用内',
    ExecutionChannel.accessibility => '无障碍服务',
    ExecutionChannel.shizuku => 'Shizuku',
    ExecutionChannel.termux => 'Termux',
  };

  /// 用户决定文案；未要求确认时为 null。
  static String decisionLabel(ToolDecision? decision) => switch (decision) {
    ToolDecision.approved => '允许一次',
    ToolDecision.rejected => '拒绝',
    ToolDecision.expired => '超时未决定',
    null => '未要求确认',
  };

  /// 确认面板展示的参数：标签 + 真实值。
  ///
  /// 与工具卡片不同，确认面板必须让用户看到这次动作的实际参数
  /// （design 第一部分 §5.3），因此未在下面登记的工具也逐条展示原始参数。
  static List<ToolParameterDetail> parameterDetails(ToolCallRecord record) {
    final arguments = record.arguments;
    if (arguments.isEmpty) return const [];
    final labels = _parameterLabels[record.toolName];
    final details = <ToolParameterDetail>[];
    final seen = <String>{};
    if (labels != null) {
      for (final entry in labels.entries) {
        if (!arguments.containsKey(entry.key)) continue;
        seen.add(entry.key);
        details.add(_detail(entry.key, entry.value, arguments[entry.key]));
      }
    }
    for (final entry in arguments.entries) {
      if (!seen.add(entry.key)) continue;
      details.add(_detail(entry.key, entry.key, entry.value));
    }
    return details;
  }

  /// 关键参数的中文标签；未登记的参数用原始键名。
  static const _parameterLabels = <String, Map<String, String>>{
    'perform_gestures': {
      'packageName': '目标应用',
      'coordinateSpace': '坐标空间（默认屏幕像素）',
      'imageWidth': '参照图片宽度',
      'imageHeight': '参照图片高度',
      'actions': '手势组合（按声明的坐标空间顺序执行）',
    },
    'read_file': {'reference': '引用', 'offset': '起始行', 'limit': '读取行数'},
    'write_file': {'path': '写入路径', 'content': '写入内容'},
    'http_request': {
      'url': '地址',
      'method': '方法',
      'headers': '请求头',
      'body': '请求正文',
    },
  };

  /// 正文类参数按多行展示；其余按单行值展示。
  static const _multilineKeys = {'content', 'body'};

  static ToolParameterDetail _detail(String key, String label, Object? value) {
    if (value == null) {
      return ToolParameterDetail(name: key, label: label, value: '（未提供）');
    }
    if (value is String) {
      final multiline = _multilineKeys.contains(key);
      return ToolParameterDetail(
        name: key,
        label: label,
        value: multiline ? _preview(value) : value,
        multiline: multiline,
      );
    }
    // 结构化参数（请求头等）按缩进 JSON 展示，原样呈现真实取值。
    return ToolParameterDetail(
      name: key,
      label: label,
      value: const JsonEncoder.withIndent('  ').convert(value),
      multiline: true,
    );
  }

  /// 长正文的预览上限：确认面板要能看清开头，但不必渲染整份文件。
  static const _previewChars = 1200;

  static String _preview(String text) {
    if (text.length <= _previewChars) return text;
    return '${text.substring(0, _previewChars)}\n'
        '……（共 ${text.length} 字，以上为前 $_previewChars 字）';
  }

  static const storageFailureMessage = '相月未能保存这次对话，任务已停止。';

  /// 完整展示本次工具返回的内容；没有输出时才使用状态说明。
  static String outputText(ToolCallRecord record) {
    final result = record.result;
    if (result != null && result.trim().isNotEmpty) return result;
    if (record.errorCode == 'storageError') return storageFailureMessage;
    return switch (record.status) {
      ToolCallStatus.prepared => '参数已就绪，等待执行',
      ToolCallStatus.awaitingConfirmation => '等待你确认这次动作',
      ToolCallStatus.executing => '正在执行',
      ToolCallStatus.succeeded => '执行完成',
      ToolCallStatus.failed => '执行失败',
      ToolCallStatus.rejected => '未执行（已拒绝）',
      ToolCallStatus.cancelled => '已取消',
    };
  }
}

/// 确认面板里的一行参数：标签与真实值。
class ToolParameterDetail {
  const ToolParameterDetail({
    required this.name,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  /// 工具参数里的原始键名，用于稳定的界面标识。
  final String name;

  final String label;

  /// 实际参数值（长正文为带总字数的预览）。
  final String value;

  /// 是否按多行文本展示（文件内容、请求正文与结构化参数）。
  final bool multiline;
}
