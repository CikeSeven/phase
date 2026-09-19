/// 依赖安装的固定白名单；设置页与后续模型工具共用同一来源。
enum DependencyStep { repairing, updating, installing, verifying }

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
    description: 'python3、pip 与 venv，用于运行脚本与 uvx 服务',
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
