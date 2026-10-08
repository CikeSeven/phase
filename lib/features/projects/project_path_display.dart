import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../../core/widgets/app_icon_badge.dart';

/// 格式化用于界面展示的项目路径，严格保证 `/projects/<id>` 及绝对路径在 UI 不可见。
String formatProjectPath(String path, {String? projectId}) {
  var cleaned = path.trim();
  if (projectId != null && cleaned.startsWith('/projects/$projectId')) {
    cleaned = cleaned.substring('/projects/$projectId'.length);
  } else if (cleaned.startsWith('/projects/')) {
    final match = RegExp(r'^/projects/[^/]+').firstMatch(cleaned);
    if (match != null) {
      cleaned = cleaned.substring(match.end);
    }
  } else if (cleaned.startsWith('/sessions/')) {
    final match = RegExp(r'^/sessions/[^/]+').firstMatch(cleaned);
    if (match != null) {
      cleaned = cleaned.substring(match.end);
    }
  }

  while (cleaned.startsWith('/') || cleaned.startsWith(r'\')) {
    cleaned = cleaned.substring(1);
  }

  if (cleaned.isEmpty || cleaned == '.') {
    return '项目根目录';
  }
  return cleaned;
}

/// 分解相对路径为面包屑组件列表。
List<String> splitProjectPath(String path, {String? projectId}) {
  final display = formatProjectPath(path, projectId: projectId);
  if (display == '项目根目录') return const [];
  return p.posix.split(display).where((s) => s.isNotEmpty && s != '.').toList();
}

/// 格式化文件字节大小。
String formatFileSize(int bytes) {
  if (bytes < 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
}

/// 根据扩展名或目录属性返回合适的文件图标。
IconData projectFileIcon(String path, {bool isDirectory = false}) {
  if (isDirectory) return LucideIcons.folder;
  final ext = p.extension(path).toLowerCase();
  return switch (ext) {
    '.dart' ||
    '.py' ||
    '.js' ||
    '.mjs' ||
    '.cjs' ||
    '.ts' ||
    '.mts' ||
    '.cts' ||
    '.jsx' ||
    '.tsx' ||
    '.html' ||
    '.htm' ||
    '.css' ||
    '.scss' ||
    '.sass' ||
    '.less' ||
    '.json' ||
    '.yaml' ||
    '.yml' ||
    '.sql' ||
    '.kt' ||
    '.kts' ||
    '.java' ||
    '.c' ||
    '.cpp' ||
    '.cc' ||
    '.cxx' ||
    '.h' ||
    '.hpp' ||
    '.rs' ||
    '.go' ||
    '.php' ||
    '.rb' ||
    '.xml' ||
    '.gradle' ||
    '.lock' => LucideIcons.fileCode,
    '.sh' || '.bash' || '.zsh' => LucideIcons.fileTerminal,
    '.toml' || '.ini' || '.conf' || '.config' => LucideIcons.fileSliders,
    '.csv' || '.tsv' || '.xls' || '.xlsx' => LucideIcons.fileSpreadsheet,
    '.png' ||
    '.jpg' ||
    '.jpeg' ||
    '.gif' ||
    '.webp' ||
    '.svg' ||
    '.bmp' ||
    '.ico' => LucideIcons.fileImage,
    '.mp4' || '.mov' || '.webm' || '.mkv' => LucideIcons.fileVideo,
    '.mp3' || '.wav' || '.ogg' || '.m4a' => LucideIcons.fileAudio,
    '.zip' ||
    '.tar' ||
    '.gz' ||
    '.tgz' ||
    '.7z' ||
    '.bz2' ||
    '.xz' ||
    '.rar' => LucideIcons.fileArchive,
    '.md' ||
    '.markdown' ||
    '.txt' ||
    '.log' ||
    '.rst' ||
    '.doc' ||
    '.docx' ||
    '.pdf' => LucideIcons.fileText,
    _ => LucideIcons.file,
  };
}

/// 根据文件路径或目录属性返回语义色调。
AppTone projectFileTone(String path, {bool isDirectory = false}) {
  if (isDirectory) return AppTone.primary;
  final ext = p.extension(path).toLowerCase();
  return switch (ext) {
    '.dart' ||
    '.py' ||
    '.js' ||
    '.mjs' ||
    '.cjs' ||
    '.ts' ||
    '.mts' ||
    '.cts' ||
    '.jsx' ||
    '.tsx' ||
    '.html' ||
    '.htm' ||
    '.css' ||
    '.scss' ||
    '.sass' ||
    '.less' ||
    '.json' ||
    '.yaml' ||
    '.yml' ||
    '.toml' ||
    '.ini' ||
    '.conf' ||
    '.config' ||
    '.sh' ||
    '.bash' ||
    '.zsh' ||
    '.sql' ||
    '.kt' ||
    '.kts' ||
    '.java' ||
    '.c' ||
    '.cpp' ||
    '.cc' ||
    '.cxx' ||
    '.h' ||
    '.hpp' ||
    '.rs' ||
    '.go' ||
    '.php' ||
    '.rb' ||
    '.xml' ||
    '.gradle' ||
    '.lock' => AppTone.teal,
    '.png' ||
    '.jpg' ||
    '.jpeg' ||
    '.gif' ||
    '.webp' ||
    '.svg' ||
    '.bmp' ||
    '.ico' ||
    '.mp4' ||
    '.mov' ||
    '.webm' ||
    '.mkv' ||
    '.mp3' ||
    '.wav' ||
    '.ogg' ||
    '.m4a' => AppTone.lavender,
    '.zip' ||
    '.tar' ||
    '.gz' ||
    '.tgz' ||
    '.7z' ||
    '.bz2' ||
    '.xz' ||
    '.rar' => AppTone.gold,
    '.md' ||
    '.markdown' ||
    '.txt' ||
    '.log' ||
    '.rst' ||
    '.doc' ||
    '.docx' ||
    '.pdf' ||
    '.csv' ||
    '.tsv' ||
    '.xls' ||
    '.xlsx' => AppTone.primary,
    _ => AppTone.primary,
  };
}

/// 返回人类可读的文件或目录类型说明。
String projectFileTypeLabel(String path, {bool isDirectory = false}) {
  if (isDirectory) return '文件夹';
  final ext = p.extension(path).toLowerCase();
  return switch (ext) {
    '.dart' => 'Dart 源码',
    '.py' => 'Python 脚本',
    '.js' || '.mjs' || '.cjs' => 'JavaScript 脚本',
    '.ts' || '.mts' || '.cts' => 'TypeScript 源码',
    '.jsx' || '.tsx' => 'React 组件',
    '.html' || '.htm' => 'HTML 页面',
    '.css' || '.scss' || '.sass' || '.less' => '样式表',
    '.json' => 'JSON 数据',
    '.yaml' || '.yml' => 'YAML 配置',
    '.toml' || '.ini' || '.conf' || '.config' => '配置文件',
    '.sh' || '.bash' || '.zsh' => 'Shell 脚本',
    '.sql' => 'SQL 脚本',
    '.kt' || '.kts' => 'Kotlin 源码',
    '.java' => 'Java 源码',
    '.c' || '.h' => 'C 源码',
    '.cpp' || '.cc' || '.cxx' || '.hpp' => 'C++ 源码',
    '.rs' => 'Rust 源码',
    '.go' => 'Go 源码',
    '.php' => 'PHP 脚本',
    '.rb' => 'Ruby 脚本',
    '.xml' => 'XML 文档',
    '.gradle' => 'Gradle 脚本',
    '.lock' => '锁定文件',
    '.md' || '.markdown' => 'Markdown 文档',
    '.txt' => '文本文档',
    '.pdf' => 'PDF 文档',
    '.doc' || '.docx' => 'Word 文档',
    '.log' => '日志文件',
    '.csv' || '.tsv' => '表格数据',
    '.xls' || '.xlsx' => 'Excel 表格',
    '.png' => 'PNG 图像',
    '.jpg' || '.jpeg' => 'JPEG 图像',
    '.svg' => 'SVG 矢量图',
    '.gif' => 'GIF 动图',
    '.webp' => 'WebP 图像',
    '.ico' || '.bmp' => '位图图像',
    '.mp4' || '.mov' || '.webm' || '.mkv' => '视频文件',
    '.mp3' || '.wav' || '.ogg' || '.m4a' => '音频文件',
    '.zip' ||
    '.tar' ||
    '.gz' ||
    '.tgz' ||
    '.7z' ||
    '.rar' ||
    '.bz2' ||
    '.xz' => '压缩文件',
    _ =>
      ext.isNotEmpty && ext.length <= 6
          ? '${ext.substring(1).toUpperCase()} 文件'
          : '文件',
  };
}
