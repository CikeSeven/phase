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
    updating => '下载软件包索引，尚未安装 Python、Node.js 等依赖',
    installing => '下载、解包并配置 Python、Node.js、Git 与 ripgrep',
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
  static const all = [python, node, gitTools];

  /// 完整安装时一次装入的全部软件包，用于确认文案与模型侧描述。
  static String get completePackages =>
      all.expand((profile) => profile.packages).join('、');
  static DependencyProfile? byId(String id) {
    for (final profile in all) {
      if (profile.id == id) return profile;
    }
    return null;
  }
}
