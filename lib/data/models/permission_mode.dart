/// 会话选择的工具授权模式，与助手的扩展启用范围独立。
enum PermissionMode { plan, basic, fullAccess }

extension PermissionModeLabel on PermissionMode {
  String get label => switch (this) {
    PermissionMode.plan => '计划模式',
    PermissionMode.basic => '基础模式',
    PermissionMode.fullAccess => '全权限模式',
  };

  String get description => switch (this) {
    PermissionMode.plan => '仅开放只读工具',
    PermissionMode.basic => '写文件、命令和应用操作需确认',
    PermissionMode.fullAccess => '已开放工具直接执行',
  };
}

/// 当前档位与进入计划前的执行档；新聊天在首次发送前只保存此草稿。
class PermissionSelection {
  const PermissionSelection({
    this.mode = PermissionMode.basic,
    this.lastExecutionMode = PermissionMode.basic,
  }) : assert(lastExecutionMode != PermissionMode.plan);

  final PermissionMode mode;
  final PermissionMode lastExecutionMode;

  PermissionSelection select(PermissionMode next) => PermissionSelection(
    mode: next,
    lastExecutionMode: next == PermissionMode.plan ? lastExecutionMode : next,
  );

  @override
  bool operator ==(Object other) =>
      other is PermissionSelection &&
      mode == other.mode &&
      lastExecutionMode == other.lastExecutionMode;

  @override
  int get hashCode => Object.hash(mode, lastExecutionMode);
}
