import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

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

/// 根据扩展名返回合适的文件图标。
IconData projectFileIcon(String path) {
  final ext = p.extension(path).toLowerCase();
  return switch (ext) {
    '.dart' ||
    '.py' ||
    '.js' ||
    '.ts' ||
    '.jsx' ||
    '.tsx' ||
    '.html' ||
    '.css' ||
    '.scss' ||
    '.json' ||
    '.yaml' ||
    '.yml' ||
    '.sh' ||
    '.bash' ||
    '.sql' ||
    '.kt' ||
    '.java' ||
    '.c' ||
    '.cpp' ||
    '.h' ||
    '.rs' ||
    '.go' ||
    '.php' ||
    '.rb' ||
    '.xml' => LucideIcons.fileCode,
    '.png' ||
    '.jpg' ||
    '.jpeg' ||
    '.gif' ||
    '.webp' ||
    '.svg' ||
    '.bmp' ||
    '.ico' => LucideIcons.fileImage,
    '.zip' ||
    '.tar' ||
    '.gz' ||
    '.7z' ||
    '.bz2' ||
    '.xz' => LucideIcons.fileArchive,
    '.md' ||
    '.txt' ||
    '.log' ||
    '.rst' ||
    '.doc' ||
    '.docx' ||
    '.pdf' => LucideIcons.fileText,
    _ => LucideIcons.file,
  };
}
