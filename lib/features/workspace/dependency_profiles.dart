import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 依赖安装的固定白名单；设置页与后续模型工具共用同一来源。
enum DependencyStep {
  repairing,
  updating,
  installing,
  verifying;

  String get label => switch (this) {
    repairing => '修复包状态',
    updating => '更新软件源',
    installing => '安装依赖',
    verifying => '验证版本',
  };

  String get description => switch (this) {
    repairing => '检查并配置上次未完成的软件包',
    updating => '下载 Ubuntu 软件包索引',
    installing => '下载、解包并配置所选软件包',
    verifying => '逐组检查命令可用性并记录版本',
  };
}

class DependencyProfile {
  const DependencyProfile({
    required this.id,
    required this.label,
    required this.description,
    required this.packages,
    required this.verifyCommand,
  });
  final String id;
  final String label;
  final String description;
  final List<String> packages;
  final String verifyCommand;

  static const python = DependencyProfile(
    id: 'python',
    label: 'Python',
    description: 'python3、pip 与 venv，用于运行脚本；不包含 uv/uvx',
    packages: ['python3', 'python3-pip', 'python3-venv'],
    verifyCommand: 'python3 --version && pip3 --version',
  );
  static const node = DependencyProfile(
    id: 'node',
    label: 'Node.js',
    description: 'Ubuntu 源内的 nodejs 与 npm，用于 MCP stdio 服务',
    packages: ['nodejs', 'npm'],
    verifyCommand: 'node --version && npm --version',
  );
  static const gitTools = DependencyProfile(
    id: 'git-tools',
    label: 'Git 与搜索工具',
    description: 'git 与 ripgrep，供版本操作与文件检索',
    packages: ['git', 'ripgrep'],
    verifyCommand: 'git --version && rg --version',
  );
  static const base = [python, node, gitTools];

  static const officeDocuments = DependencyProfile(
    id: 'office-documents',
    label: '文档与格式转换',
    description: '无界面 Office 文档处理、格式转换与中英文字体',
    packages: [
      'libreoffice-writer',
      'libreoffice-calc',
      'libreoffice-impress',
      'libreoffice-draw',
      'pandoc',
      'fonts-noto-cjk',
      'fontconfig',
      'fonts-liberation',
      'fonts-crosextra-carlito',
      'fonts-crosextra-caladea',
    ],
    verifyCommand: 'libreoffice --headless --version && pandoc --version && fc-match :lang=zh-cn',
  );
  static const officeData = DependencyProfile(
    id: 'office-data',
    label: '表格与 Office 脚本',
    description: 'DOCX、XLS/XLSX、ODF、PDF、CSV 读写、分析与绘图',
    packages: [
      'python3-docx',
      'python3-openpyxl',
      'python3-xlsxwriter',
      'python3-xlrd',
      'python3-xlwt',
      'python3-odf',
      'python3-pandas',
      'python3-pypdf',
      'python3-matplotlib',
      'python3-pil',
      'csvkit',
    ],
    verifyCommand: 'python3 -c "import importlib.util; names=[\'docx\',\'openpyxl\',\'xlsxwriter\',\'xlrd\',\'xlwt\',\'odf\',\'pandas\',\'pypdf\',\'matplotlib\',\'PIL\']; missing=[name for name in names if importlib.util.find_spec(name) is None]; assert not missing, missing; print(\'Python office libraries available\')" && command -v csvstat >/dev/null',
  );
  static const officePdf = DependencyProfile(
    id: 'office-pdf',
    label: 'PDF 与文件元数据',
    description: 'PDF 文本提取、页面渲染、合并拆分、修复与元数据读取',
    packages: [
      'poppler-utils',
      'qpdf',
      'ghostscript',
      'libimage-exiftool-perl',
    ],
    verifyCommand: 'command -v pdftotext >/dev/null && qpdf --version && gs --version && exiftool -ver',
  );
  static const officeOcr = DependencyProfile(
    id: 'office-ocr',
    label: '扫描件与图像',
    description: '英文、简体/繁體中文 OCR、可搜索 PDF 与图像处理',
    packages: [
      'ocrmypdf',
      'tesseract-ocr',
      'tesseract-ocr-eng',
      'tesseract-ocr-chi-sim',
      'tesseract-ocr-chi-tra',
      'tesseract-ocr-osd',
      'imagemagick',
    ],
    verifyCommand: 'ocrmypdf --version && tesseract --version && for language in eng chi_sim chi_tra; do tesseract --list-langs | grep -qx "\$language" || exit 1; done && convert -version',
  );
  static const officeLegacyAndArchives = DependencyProfile(
    id: 'office-legacy-archives',
    label: '旧版格式与归档',
    description: '旧版 Word/RTF/ODF 文本提取与 ZIP、7z 归档',
    packages: [
      'antiword',
      'catdoc',
      'unrtf',
      'odt2txt',
      'zip',
      'unzip',
      '7zip',
    ],
    verifyCommand: 'for command in antiword catdoc unrtf odt2txt zip unzip 7zz; do command -v "\$command" >/dev/null || exit 1; done; printf \'Legacy office formats and archives available\\n\'',
  );
  static const office = [
    officeDocuments,
    officeData,
    officePdf,
    officeOcr,
    officeLegacyAndArchives,
  ];

  /// Kept for callers that use the original complete development profile set.
  static const all = base;
  static const managed = [...base, ...office];

  /// Complete package lists used in install confirmations and dependency details.
  static String get completePackages =>
      base.expand((profile) => profile.packages).join('、');
  static String get officeCompletePackages =>
      office.expand((profile) => profile.packages).join('、');

  static DependencyProfile? byId(String id) {
    for (final profile in managed) {
      if (profile.id == id) return profile;
    }
    return null;
  }
}

/// 组织可选依赖包组；支持页面渲染、状态统计与后续扩展。
class DependencyBundle {
  const DependencyBundle({
    required this.id,
    required this.label,
    required this.description,
    required this.profiles,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final List<DependencyProfile> profiles;
  final IconData icon;

  static const office = DependencyBundle(
    id: 'office',
    label: '办公与文档处理',
    description: '无界面 Office 文档转换、表格数据脚本、PDF 处理与 OCR 识别',
    profiles: DependencyProfile.office,
    icon: LucideIcons.fileText,
  );

  static const optionalBundles = [office];

  int installedCount(Map<String, dynamic> records) =>
      profiles.where((profile) => records.containsKey(profile.id)).length;

  bool isInstalled(Map<String, dynamic> records) =>
      profiles.every((profile) => records.containsKey(profile.id));

  bool isPartiallyInstalled(Map<String, dynamic> records) {
    final count = installedCount(records);
    return count > 0 && count < profiles.length;
  }

  String statusText(Map<String, dynamic> records) {
    final count = installedCount(records);
    if (count == 0) return '未安装';
    if (count == profiles.length) return '已安装';
    return '部分安装 · $count/${profiles.length} 组';
  }

  String get completePackages =>
      profiles.expand((profile) => profile.packages).join('、');
}
