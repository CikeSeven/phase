# Ubuntu 共享文件系统与会话目录开发方案

更新：2026-10-04｜状态：代码已实现，Profile 已安装；完整行为验收未完成｜范围：Android 内置 Ubuntu

本文记录已实现的共享 Ubuntu 文件系统契约：会话文件实际位于固定 rootfs 的 `/sessions/<session_id>`，不再依赖会话目录 bind。代码实现、构建安装与行为验收分开记录，当前交付结果见 §11.3。

相关文档：[产品设计](./product_and_technical_design.md)、[扩展设计](./agent_extensions_design.md)、[系统命令通道](./system_command_channels_design.md)、[实施计划](./implementation_plan.md)。代码规范与界面规范分别遵循 [AGENTS.md](../AGENTS.md)、[DESIGN.md](../DESIGN.md)。

## 1. 已确认的方向

| 事项 | 本次契约 |
|---|---|
| Ubuntu 环境 | 所有 Ubuntu 会话共用一套 rootfs、系统目录和已安装软件 |
| 会话文件 | 实际保存在 rootfs 内的 `/sessions/<session_id>`，不再存到 rootfs 外后绑定成 `/workspace` |
| 默认 cwd | 每次 shell 调用默认使用所属会话的 `/sessions/<session_id>` |
| 全局访问 | shell 可访问 Ubuntu 内其他目录，包括其他会话目录；不隐藏、不增加会话间访问阻断 |
| shell 状态 | 每次调用是独立非交互进程；`cd`、变量、函数和 alias 不跨调用保留 |
| 执行权限 | 延续会话计划／基础／全权限三档，命令与依赖安装共用 `command_execution` |
| 沙箱 | 不新增 Bubblewrap、Landlock、Docker、虚拟机或独立沙箱系统，不新增沙箱档位 |
| 目录契约 | 采用固定 rootfs 与真实会话目录，不建设旧目录兼容层 |

这里的“会话目录”是默认位置和文件归属，不是 shell 的访问边界。电脑 coding agent 的常见命令体验不要求持久终端；本批不新增跨调用 cwd 跟随、持久 shell 或 PTY。

PRoot 仍只承担 Ubuntu 用户态兼容环境。guest root 身份不等于 Android Root；命令的实际权限仍来自应用 UID 和 Android 系统授权，不宣称获得整台手机的任意访问权。

## 2. 实施前基线与改动入口

| 实施前基线 | 入口 | 本批改动 |
|---|---|---|
| 会话与工作区分别生成 ID，工作区位于 `linux/workspaces/<workspaceId>` | [会话仓储](../lib/data/repositories/conversation_repository.dart)、[工作区仓储](../lib/data/repositories/workspace_repository.dart) | 创建顺序与目录归属改为持久会话 ID，目录进入固定 rootfs |
| `WorkspaceSnapshot.executionRoot` 返回 `/workspace` | [workspace.dart](../lib/data/models/workspace.dart) | Ubuntu 返回 `/sessions/<session_id>` |
| shell 启动、确认摘要和结果中存在固定 `/workspace` | [shell_tool.dart](../lib/features/workspace/shell_tool.dart) | 默认目录统一取运行快照，不重复写死路径 |
| `LinuxProcessSpec.workspace` 是宿主目录，原生将其绑定到 `/workspace` | [process_api.dart](../pigeons/process_api.dart)、[LinuxProcessHost.kt](../android/app/src/main/kotlin/app/xiangyue/phase/workspace/LinuxProcessHost.kt) | 移除 workspace 绑定参数，直接使用 rootfs 内的 guest cwd |
| 文件工具和文件页直接访问宿主工作区 | [file_tools.dart](../lib/features/tools/file_tools.dart)、[文件访问适配](../lib/features/workspace/workspace_file_access.dart)、[workspace_actions.dart](../lib/features/workspace/workspace_actions.dart) | 实际目录改为 rootfs 内的会话目录 |
| 安装完成后启用带修订与随机 ID 的 rootfs 路径 | [linux_installer.dart](../lib/features/workspace/linux_installer.dart) | 使用稳定 rootfs 路径，安装与卸载不得连带删除会话子树 |
| 安装探针、依赖安装和 MCP stdio 同样依赖 `/workspace` 绑定 | [dependency_installer.dart](../lib/features/workspace/dependency_installer.dart)、[mcp_connections.dart](../lib/features/mcp/mcp_connections.dart)、[mcp_stdio_client.dart](../lib/features/mcp/mcp_stdio_client.dart) | 同步切换到 rootfs 内实际目录，不保留第二套旧启动接口 |

只调整相关文件与调用者，不重写 `AgentLoop`、模型协议或设备执行。

## 3. 文件系统布局

### 3.1 宿主路径与 Ubuntu 路径

固定布局如下；`<app noBackupFilesDir>` 由 Android 平台返回，业务代码不得写死设备上的 `/data/user/...` 路径。

```text
<app noBackupFilesDir>/linux/
├── environments/ubuntu/rootfs/
│   ├── bin/、usr/、etc/、var/、root/、tmp/……
│   ├── sessions/
│   │   ├── <session A>/
│   │   │   ├── imports/<attachment_id>/<原文件名>
│   │   │   ├── .skills/<skill_id>/<资源副本版本>/
│   │   │   └── 用户／Agent 生成的文件
│   │   └── <session B>/
│   └── services/mcp/<server_id>/
├── staging/                         # 下载、解包和宿主文件临时副本
└── processes/                       # 原生进程回执与 PRoot 临时数据
```

| 用途 | Ubuntu guest 路径 | 实际宿主目录 |
|---|---|---|
| 共享 Ubuntu 根目录 | `/` | `linux/environments/ubuntu/rootfs` |
| 当前会话目录 | `/sessions/<session_id>` | `<rootfs>/sessions/<session_id>` |
| 本地 MCP 默认目录 | `/services/mcp/<server_id>` | `<rootfs>/services/mcp/<server_id>` |

文件在命令启动前就已经位于 rootfs 内。启动 PRoot 只是建立执行环境，不再复制会话文件或添加会话目录 bind。Ubuntu rootfs 物理上仍是应用私有目录中的文件树，不是独立磁盘、常驻虚拟机或系统级挂载。

`staging`、进程控制数据、聊天数据库、附件原件和历史产物继续由宿主管理，不因为共享 Ubuntu 就把应用凭据或数据库放进 guest 文件树。

### 3.2 身份与模型字段

- `session_id` 使用持久化的 `Conversation.id`，不是一次运行的 `AgentRun.id`。重新发送、重新生成和切换消息分支不换目录。
- 新会话先生成会话 ID，再以同一个 ID 创建现有 `Workspace` 记录；`Workspace.id` 与所属会话 ID 一致。继续复用工作区仓储、文件页和来源记录，不再额外生成目录身份，也不顺带删除整层工作区管理代码。
- `Workspace.rootPath` 是实际宿主会话目录；Ubuntu 的 `WorkspaceSnapshot.executionRoot` 是 `/sessions/<id>`；`environmentRoot` 是本次可执行 Ubuntu 的宿主 rootfs。
- 路径拼接由同一个布局入口提供。会话目录、MCP 服务目录、安装器和删除入口不得各自维护不同的 rootfs 路径规则。
- rootfs 目录存在不等于 Ubuntu 可执行。运行目录注入仍取决于环境 `ready` 和模型工具能力，不能只检查 `Directory.exists()`。
- 原有表和模型按需要直接同步新契约；路径调整本身不要求新建数据表。不为旧 `workspaceId`、旧 `/workspace` 或旧运行 JSON 增加转换分支。

## 4. shell 执行契约

### 4.1 参数与行为

保留显式绝对 cwd，命令工具为 `shell(command, cwd?, timeout?)`；timeout 为可选秒数，默认没有总时限：

- `command` 按原文交给 `/bin/sh -c`，不新增命令白名单、前缀批准或正则改写。
- `cwd` 省略时使用运行快照的 `/sessions/<session_id>`；显式指定时使用 Ubuntu guest 绝对路径。
- `cwd` 可以是 `/root`、`/tmp`、`/usr` 或 `/sessions/<其他会话>` 等实际可用目录，不强制位于当前会话子树。
- 无效、不存在或非目录的 cwd 返回实际失败，不回退当前会话目录重做命令。路径不做模型驱动的宿主目录授权或自动 bind。
- 启动不加载 rc；保留固定基础环境变量与 `HOME=/root`，不另建隐式会话 HOME。工具定义不暴露应用管理的凭据。
- `cd` 只在同一次调用中有效；文件、软件包及 Ubuntu 全局配置的修改仍持久保留。
- 保留当前无命令总时限、stdin 关闭、双路输出、输出上限、取消和进程归属规则。

下表是目标验收示例，假设会话 A 的 ID 为 `a`；不是本次已执行的命令：

| 调用 | 预期 |
|---|---|
| `shell(command: "pwd")` | 输出 `/sessions/a` |
| `shell(command: "cd /tmp && pwd")` | 本次输出 `/tmp` |
| 随后的 `shell(command: "pwd")` | 仍输出 `/sessions/a` |
| `shell(command: "pwd", cwd: "/root")` | 输出 `/root` |
| `shell(command: "cat /sessions/b/shared.txt")` | 文件存在且系统权限允许时可读取，不因属于 B 而拒绝 |
| `shell(command: "printf shared > /root/shared.txt")` | 根据当前命令权限确认或直接执行，写入共享 Ubuntu 文件 |

修改其他会话或全局文件也是本次命令的真实外部效果。失败、非零退出和停止不代表撤销；框架不自动重发已派发命令。

### 4.2 端到端链路

```text
首次发送
  → 保存会话与工作区 ID
  → 创建 <rootfs>/sessions/<session_id>
  → 获取工作区／环境租约及固定运行快照
  → 注入 shell 与运行环境上下文
  → ToolExecutor 核对范围、策略、参数与用户确认
  → ProcessDriver / LinuxProcessHostApi
  → 原生监督进程 → PRoot -r <rootfs> -w <guest cwd>
  → /bin/sh -c <command>
  → 保存输出、调用结果和当前会话产物
  → 回填 AgentLoop，完整收尾后释放租约
```

确认摘要和结果中的 `cwd` 统一表示本次**启动目录**；若命令内部 `cd`，不把它反写成下一次调用的默认目录，也不把启动目录冒充退出时的实际 cwd。

## 5. 文件工具、附件与产物

文件工具在共享文件系统基础上向 pi 对齐路径与输出语义：

- `read_file`、`write_file`、`edit_file`、`list_files` 以当前会话目录为相对路径根，也支持所选环境的绝对路径和 `~`。例如 `report.txt` 对应 `/sessions/<id>/report.txt`，`/etc/os-release` 指向 Ubuntu rootfs 内文件。
- 不保留 `/workspace` 别名。Ubuntu 链接的绝对目标按 guest 路径解析，最多跟随 40 层，不把模型路径解释为任意 Android 宿主文件；`/dev`、`/proc` 对应现有 shell 挂载。
- 文件页与会话生命周期仍使用工作区相对路径校验，不因模型文件工具开放绝对路径而放宽删除或复制范围。新增 grep/find 使用已有 rg，按宿主只读工具授权。
- 附件原件继续只读保存在原附件存储，执行副本放进 `/sessions/<id>/imports/<attachment_id>/<原文件名>`；复制不能追加或改变文件名。
- Skill 工作副本进入当前会话 `.skills/`；读取指导和准备副本不执行脚本，执行仍经 shell 或现有工具。
- 文件页继续从所属会话进入，显示当前目录中的相对路径；导入、导出与预览访问同一实际目录，不生成第二份会话文件树。

产物收集只扫描当前 `/sessions/<id>`，保留当前 100 个文件／64 MiB 上限，排除根目录的 `imports/` 和 `.skills/`，不扫描整个 rootfs 或其他会话。全局文件不会因为这次命令访问过就自动归到当前会话；需要作为产物时，Agent 可以显式复制到当前会话目录。

stdout／stderr 在记录中保留有界尾部；命令模型预览合计最多 2000 行 / 50 KiB，超过预览时保存已收完整日志附件。合计 8 MiB 的底层输出停止保护仍保留，不等同于模型预览预算。结果投影保留状态与来源，可经 `read_history` 读取原始记录；文件读取使用 2000 行 / 50 KiB 完整行分页。

## 6. 权限：确认不是文件系统沙箱

| 工具类别 | 计划 | 基础 | 全权限 |
|---|---|---|---|
| 宿主文件读取／列表 | allow | allow | allow |
| 文件写入／编辑、Skill 复制 | deny | ask | allow |
| shell、install_packages、现有命令类传输 | deny | ask | allow |

- 三档由会话保存并固定到运行；不新增 Ubuntu 目录权限、独立沙箱档位或“当前目录内自动批准”规则。
- 基础档默认每次命令只批准一次，不继承应用操作的本轮批准，不凭命令名或 `cd` 判定效果。显式工具规则可以改变是否需要审批，但不授予目录权限、不分析命令安全性、不支持命令前缀永久批准。
- 计划档连 `pwd` 这类通用 shell 调用也在派发前拒绝，继续使用宿主只读工具；不为本次目录调整扩大计划执行权限。
- 同一命令在 `/sessions/a`、`/sessions/b` 或 `/root` 启动都使用同一个命令策略。目录归属不另行触发确认，也不替代已有确认。
- 环境就绪、模型能力、运行工具范围、系统授权和实际执行身份检查保持有效。deny 在准备执行通道和派发前生效。
- 全权限仍不是 Android 提权或凭据开放；应用管理的密钥不放入文件树、提示词、确认摘要或日志。

不新增 `sandbox_permissions`、沙箱拒绝后的自动重跑或外部动作“结果未确认”流程。

## 7. 新布局的生命周期

以下是本次新契约的正常文件生命周期，不是旧数据迁移。没有旧工作区复制、旧 rootfs 导入或旧 JSON 转换步骤。

### 7.1 Ubuntu 尚未安装

保留“普通聊天和会话文件不依赖 Ubuntu 已安装”的现有能力：首次发送可以直接建立稳定 rootfs 下的 `sessions/<id>` 目录骨架。目录只存会话文件，不执行 Ubuntu 二进制、不自动安装镜像，环境状态仍是未安装。

这不需要 rootfs 外的过渡工作区；后续安装 Ubuntu 时，会话文件已经在目标位置，无需搬入或重新 bind。

### 7.2 首次安装与失败重试

- 沿用固定镜像、摘要校验、解包限制、配置和 PRoot 实际检查；不新增依赖或改变当前 ABI 支持范围。
- 镜像仍先在 `staging` 解包和验证；探针直接写 staged rootfs 内的 `/tmp` 并从宿主核对，不再依赖绑定的 `/workspace/check`。
- 固定 rootfs 的 `sessions/` 和 `services/` 是宿主管理的持久子树。提交前拒绝镜像覆盖这些保留路径；安装提交只处理镜像系统内容，不递归删除整个 rootfs。
- 环境级独占覆盖系统文件提交，提交期间不允许启动命令／MCP 或创建、删除、复制会话目录。仓储侧须覆盖检查到落盘的整个异步操作，不能只在入口做一次 busy 检查。
- 系统内容按安装清单从 staged rootfs 提交到固定 rootfs；验证并完成提交后才保存 ready。失败／取消保存明确状态并清理本次暂存，不碰会话和服务子树；未完成系统提交的环境不开放 shell，下次显式安装可重新完成系统内容。
- 已 ready 的环境不提供本批隐式 rootfs 替换；依赖缺失仍走“修复环境”的同一 apt 流程。发行版升级、在线系统替换另行设计，不作为本批前置。

安装成功后自动安装完整开发依赖的现有流程不变；依赖失败或取消保留 Ubuntu 和已安装内容，不重新下载 rootfs。

### 7.3 卸载与依赖安装

- 卸载须显式触发，保留任务／环境互斥。它移除 Ubuntu 系统内容和依赖，但保留 `sessions/`、`services/` 与所属记录；目录骨架可以继续承载会话文件。
- 卸载确认如实说明：会话文件保留，其他 Ubuntu 内容及已安装软件会移除。存放在 `/root` 等系统区的全局文件不承诺随卸载保留，不能把“共享可访问”描述成自动备份。
- 原生进程回执和 PRoot 临时文件仍按所属进程清理，不与会话文件混在一起。
- `install_packages` 使用 rootfs 内本次调用的 `/tmp/phase-deps-<id>` 作为临时 cwd，结束只清理该目录。继续使用 apt 锁、受管依赖安装互斥和 `DEBIAN_FRONTEND=noninteractive`。
- 无论卸载还是失败重试，都不得执行 `delete(rootfs, recursive: true)` 连带删掉持久子树，也不借环境损坏自动清理用户文件。

### 7.4 创建、复制、删除和恢复

- 创建：空白页不落库；首次有效发送建立会话及真实目录，记录失败清理本次创建的目录，不留下无所属的新目录。
- 复制：生成新的会话 ID 和 `/sessions/<新 ID>`，复制所属目录、来源及附件／产物，不复制 rootfs、全局目录或其他会话。原有复制和链接检查继续有效，不跟随链接把外部文件树整批复制进来。
- 删除：先结束所属活动运行，再清理当前 `sessions/<id>`、来源、附件与产物。清理失败保留删除标记供重试；不追踪并删除 Agent 曾写入的全局文件或其他会话文件。
- 分支／重新生成：目录沿用同一会话，不对文件树做历史版本回滚。旧消息中的文件路径是历史事实，不保证文件仍是当时内容。
- 恢复：继续校验工作区／环境快照、进程归属和运行状态；不恢复旧 PID、不重放已派发命令。完整收尾后释放租约，环境变化后不能用旧运行偷偷切到新环境。
- 共享访问意味着一个会话的命令可能修改另一个目录；当前会话租约不代表能锁住任意 shell 的所有读写，本批不新增全局文件锁或多根运行调度。

## 8. 原始进程桥与所有调用者同步

### 8.1 Pigeon 与 Kotlin

`LinuxProcessSpec` 保留 `ownerId`、`processId`、`rootfs`、`executable`、`argv`、`cwd`、`environment` 和输出／超时参数，移除用于 `/workspace` 绑定的 `workspace` 字段。

`LinuxProcessHost.start()`：

1. 核对 owner、process ID、平台能力、宿主受管理 rootfs 与参数大小。
2. 仅接受正式固定 rootfs 或本次安装用的受管理 staging rootfs；不由模型选择任意宿主目录作为 guest root。
3. 保留必要的 `/dev`、`/proc` 绑定，以及既有 supervisor、PRoot loader、环境清理与进程终止机制。
4. 删除 `${workspace.path}:/workspace`，把 guest cwd 直接交给 PRoot `-w`。
5. 不因 cwd 位于其他会话或系统目录而增加拒绝，也不自动替命令创建不存在的任意目录。

桥接定义修改后使用 `bash tool/generate_execution_bridge.sh` 重新生成 Dart／Kotlin，生成文件不手改。本批不因取消目录绑定而删除进程 owner、通知停止、双路管道、序列校验或回收机制。

### 8.2 本地 MCP stdio

它也使用原始进程桥，不能遗漏：

- 服务专属目录改为 rootfs 内 `/services/mcp/<server_id>`，默认 cwd 使用该路径，不随当前会话切换。
- `McpStdioCommand.cwd` 以未指定表示服务默认目录，显式值仍是 guest 绝对路径；同步模型序列化、验证、编辑表单默认值和 launcher，移除 `/workspace` 默认值，不兼容旧配置。
- 服务创建、删除和启动使用同一布局入口；取消、stderr 详情、stdin／stdout 分离及环境租约继续沿现有链路收尾。
- 服务目录是默认位置，不是隐藏其他会话的隔离措施。MCP 不自动附加会话文件，也不自动扩展工具授权。
- 临时解密的凭据仍通过该进程的环境变量传递，不写到服务目录、会话快照或模型上下文。

## 9. 上下文与界面

- `workspacePrompt`、运行环境 `RuntimeContextPart`、shell 工具描述、确认摘要和结果统一使用 `/sessions/<id>`，不将 Android 宿主路径发送给模型。
- 面向模型的环境上下文保留 Ubuntu 环境、默认 cwd、绝对/相对文件路径、附件副本路径和可用状态；工具自身提供用途摘要与使用指导，说明输出预算、续读和 shell 可选超时。不注入进程实现机制或自动安装／修复软件的指导。
- 状态更新仍按现有分区追加，不把动态会话目录硬编码进固定助手提示词，也不改写旧消息。
- 会话文件入口、文件页、环境设置和三档权限交互不新增面板；保留必要的实际目录／执行内容和失败提示，不为实现机制增加常驻说明文案。
- MCP 表单只同步实际默认目录语义；不增加宿主挂载配置、沙箱安装入口、沙箱开关或目录白名单 UI。

## 10. 实施顺序

| 阶段 | 实施内容 | 完成标准 |
|---|---|---|
| UFS1：布局与身份 | 固定 rootfs 布局、首次发送创建顺序、会话／工作区 ID、快照和文件路径 | 无命令运行时，文件工具已在真实 `rootfs/sessions/<id>` 读写 |
| UFS2：执行闭环 | Pigeon 定义／生成物、Kotlin、shell、安装探针、依赖安装、MCP 全部调用者 | 无会话／服务 `/workspace` bind；默认 cwd、显式 cwd 与管道闭环正确 |
| UFS3：生命周期 | 初装提交、卸载保留子树、复制删除、失败重试 | 不误删会话数据，失败保留回滚或重试 |
| UFS4：投影与验收 | 提示词、确认、结果、文件页、MCP 表单和文档同步 | 目录语义统一，权限与实际运行验证单独记录 |

阶段划分是开发顺序，不能先交付只改 `/sessions` 字符串而原生仍绑定 `/workspace` 的半成品；正式安装前必须贯通全部原始进程调用者。

没有新增依赖需求。若实际实现证明需要新增依赖，先说明原因与影响，不把独立沙箱系统作为隐含依赖。

## 11. 验证与交付边界

以下是完整行为验收清单，不代表全部通过；当前已执行结果与未验收边界见 §11.3。

### 11.1 核心场景

- [ ] Ubuntu 未安装时，发送后直接创建会话文件；文件真实位于稳定 rootfs 的会话目录，shell 不开放。
- [ ] 首次安装 Ubuntu 后，原本属于新布局的文件无需复制即可从 `/sessions/<id>` 读取；重开应用保持目录和内容。
- [ ] 会话 A、B 的默认 pwd 不同；B 可经 shell 读取 A 明确创建的文件，不出现会话范围拒绝。
- [ ] `/root` 等 Ubuntu 全局文件在下一次命令和另一个 Ubuntu 会话中可用。
- [ ] `cd /tmp && pwd` 仅影响本次；下一次默认 cwd 返回所属会话目录；显式 cwd 正确，不存在时失败且不回退。
- [ ] 文件工具、附件副本、Skill、文件页及自动产物收集使用同一文件树；全局文件不被误归属或整库扫描。
- [ ] 计划档拒绝 shell 且不派发；基础档逐次询问；全权限直接执行；修改 cwd 不改变批准范围。
- [ ] 等待启动、空闲无输出、持续输出、非零退出、通知停止及子进程回收沿真实桥验证，已发生文件效果保留。
- [ ] 安装取消、提交失败、依赖修复和卸载均不误删 `sessions/`、`services/`；未完成安装不标 ready。
- [ ] 复制会话获得独立目录；删除只清理所属托管目录，跨会话／全局写入不被追踪删除。
- [ ] 本地 MCP 使用服务默认 cwd，显式 cwd 正常，JSON-RPC 双向管道和取消／释放不回归。

现有回归入口包括 [工作区测试](../test/features/workspace/)、[文件工具测试](../test/features/tools/file_tools_test.dart)、[权限模式测试](../test/features/tools/permission_mode_policy_test.dart)、[MCP stdio 测试](../test/features/mcp/mcp_stdio_test.dart)；同步 fake 与夹具到新契约，不新增旧目录或旧 schema 升级用例。

### 11.2 工程检查和设备

实际 Dart／生成输入修改后，按工程规范执行对应生成、格式、分析和 diff 检查；原生编译、测试、Profile 构建与真实设备行为分别记录。

设备安装按当前 AGENTS 的 USB 设备确认、`adb install -r` 和启动规则执行。**不做旧数据迁移并不授权卸载、清数据、删库或更换应用身份**；现有测试安装不满足新契约时报告具体不兼容，不靠破坏性操作制造通过结果。

### 11.3 本次交付记录（2026-10-04）

- 已实现固定 rootfs、会话／工作区统一 ID、真实会话与服务目录、无 `/workspace` bind 的进程桥，以及安装／卸载保留持久子树；同步 shell、依赖安装、MCP、文件工具和原生导出路径。
- Pigeon 与 Riverpod 生成物已同步，`flutter analyze --no-pub` 通过；未新增依赖或数据迁移。
- 停止前的回归结果为 111 项通过、20 项失败，包含未完成的测试夹具／测试环境修复。按用户要求停止回归测试，不将这次运行算作完整验收通过；原生专项测试和完整 UI／生命周期验收未执行。
- `flutter build apk --profile` 成功；在授权 USB 设备 `1b8418ca` 上以 `adb install -r` 覆盖安装返回 `Success`，启动 `app.xiangyue.phase/.MainActivity` 返回 `Status: ok`。
- 未卸载应用、清数据、修改应用身份或签名；未迁移设备上的旧布局。构建、安装和启动成功不代表全部 Ubuntu／MCP 运行行为已验收。
