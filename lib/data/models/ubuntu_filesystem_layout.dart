import 'package:path/path.dart' as p;

/// 宿主 Linux 目录与 Ubuntu guest 路径的唯一映射；目录存在不表示环境就绪。
class UbuntuFilesystemLayout {
  const UbuntuFilesystemLayout(this.linuxRoot);

  final String linuxRoot;
  static const persistentRootNames = {'sessions', 'services'};

  String get rootfs => p.join(linuxRoot, 'environments', 'ubuntu', 'rootfs');
  String get staging => p.join(linuxRoot, 'staging');
  String get sessions => p.join(rootfs, 'sessions');
  String get mcpServices => p.join(rootfs, 'services', 'mcp');
  String sessionDirectory(String id) => p.join(sessions, _id(id));
  String mcpDirectory(String id) => p.join(mcpServices, _id(id));

  static String sessionGuestPath(String id) => '/sessions/${_id(id)}';
  static String mcpGuestPath(String id) => '/services/mcp/${_id(id)}';

  static String _id(String value) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(value)) {
      throw const FormatException('Invalid managed directory ID');
    }
    return value;
  }
}
