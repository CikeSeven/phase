# 调用级工具权限

## 范围

保留计划／基础／全权限三档和现有 Android、SAF、Ubuntu 执行边界。规则决定一次工具调用是否获准，不是沙箱，不限制已批准 Shell/MCP 程序内部的文件、网络或子进程行为。没有命令前缀永久批准、正则安全判定、目录隔离或模型风险评分。

## 判定

- 先检查运行工具范围、计划白名单、宿主硬拒绝和系统／来源可用性。
- 宿主按实际调用描述效果；HTTP 使用实际方法，虚拟屏使用实际 action。未知工具和 MCP 不因名称或第三方 annotations 而被识别为只读。
- 显式规则精确匹配来源种类、来源 ID、原始工具名和可选动作。多个匹配采用 `deny > ask > allow`；规则不能扩大工具启用范围或绕过计划限制。
- 全权限只改变模式默认值，不覆盖显式“每次确认”或“禁止执行”。MCP 允许规则绑定定义修订，修订变化后不再放行；确认／拒绝规则继续限制同一来源与工具。
- 规则与模式保存到运行快照。后续配置只能收紧活跃运行；放宽用于新运行。规则存储失败不发布新授权，读取失败不默认为允许。

基础档默认询问文件写入、编辑、Skill 复制、命令、安装依赖、记忆写入、通用 HTTP 与 MCP。宿主明确实现的只读工具及网页搜索／读取默认允许。GET 不是通用 HTTP 自动放行的依据。

## 确认与临时授权

- 冻结实际参数，在参数校验和通道准备后展示动作、确认原因与批准范围；保持原来的 60 秒期限、拒绝、停止和关闭未决定语义。
- 普通调用、显式“每次确认”规则只支持一次批准；默认询问的内置应用操作可选择一次或本轮。原生后台面板按其明确展示的范围批准。
- 决定成功落库后签发 `PermissionGrant`。一次授权绑定运行、调用 ID、参数摘要、来源、定义修订和通道；本轮授权只覆盖批准时运行目录中同类别、同来源的工具定义。
- 临时授权只存在于连续运行驱动内存，结束、失败、停止、驱动切换或规则变化后失效；中断恢复不能从审计记录重建授权。
- 每次执行前复检最新规则与来源撤权；MCP 在实际发送前再复检。沿用本轮授权记录批准来源，不伪造后续工具的用户决定。

## 设置与持久化

入口：“设置 → 执行与权限 → 工具规则”。选项为跟随模式、直接允许、每次确认、禁止执行。HTTP 按方法配置，虚拟屏按动作配置；MCP 按已发现工具配置，与按服务启用全部工具的功能独立。暂不可用工具的已有规则仍可删除或调整。

非敏感规则经 `SettingsStorage` 保存。运行快照保存规则；工具记录的 `permissionJson` 保存判定、效果、规则身份、授权范围与批准来源，不借用协议 `providerData`，不保存授权对象本身。数据库 schema 13 为该审计列提供保数据升级；历史记录没有此字段时继续按已有事实展示。复制会话重映射批准来源 ID，不能继承执行授权。

## 实现入口

- `lib/data/models/tool_permission.dart`：请求、规则、判定和临时授权契约。
- `lib/features/tools/tool_permission_policy.dart`：宿主效果识别与调用级规则。
- `lib/features/tools/tool_permission_grants.dart`：本次／本轮授权匹配与失效。
- `lib/features/tools/tool_executor.dart`：确认、复检、派发和审计。
- `lib/features/tools/tool_permission_rules_controller.dart`、`tool_permission_rules_page.dart`：规则状态与设置页。

用户于 2026-10-07 明确允许为本次改动编写和运行测试。覆盖调用规则、授权生命周期、执行器与持久化失败、数据库 12→13 升级、确认范围、规则设置页面及 MCP 最终撤权复检；静态分析、代码生成、构建和安装仍不等同于运行时权限验收。

测试入口：`test/features/tools/tool_permission_*_test.dart`、`test/data/datasources/local/tool_permission_*_test.dart`、`test/features/mcp/mcp_permission_recheck_test.dart`，以及确认面板、确认宿主与原生后台决定的相关用例。更大范围旧测试仍存在消息状态结构、工作区路径与 UI 断言不一致，不能将权限相关测试通过表述为全量回归通过。

2026-10-07 实际结果：定向验证 136 项通过；扩大回归 234 项通过、44 项失败，剩余失败涉及消息/工作区/UI 断言和异步超时，未在本次权限任务中全量整改。日志分别为 `build/permission-targeted-tests.log`、`build/permission-host-tests.log`、`build/permission-overlay-test.log`、`build/permission-memory-tests.log` 与 `build/permission-regression-final.log`。格式检查、静态分析、代码生成和 Profile 构建通过；Profile 包已覆盖安装并启动于 USB 设备 `1b8418ca`。
