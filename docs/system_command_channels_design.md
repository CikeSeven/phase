# E6：系统命令与显式文件传输

更新：2026-09-26。主环境仅在环境设置中全局选择，新会话绑定后不可切换；已授权本次 9 → 10 保数据覆盖升级。初始安装记录见实施计划，环境设置交互调整与未验收范围见本文末节；未运行测试，不将安装启动视为通道功能验收。

## 选择与参考

用户确认：Ubuntu / Termux 在环境设置中全局单选，命令、文件与 Skill 使用会话创建时绑定的环境，已有会话不允许切换；两侧文件独立保留，AI 工具与文件页提供显式复制。Shizuku 独立全局启用；Termux 取消应用内使用开关，以系统命令授权为选择门槛，依赖自行管理。Root、交互 PTY、Termux MCP 双向会话、自动目录同步不在本批。

参考的本地源码版本：Aether `4723e81`、Operit `b2c76100`、Kelivo `25876c21`、RikkaHub `288a034c`。Aether 的 RUN_COMMAND/私有日志/PendingIntent、UserService 绑定与临时字节传输有直接参考价值，但取消脚本仅处理直接子进程并写固定退出码，不能照搬；Operit 使用旧 Shizuku newProcess/反射，Termux 只有未接线回调；后两者是应用内 PRoot，不是外部 Termux。只借鉴事件归属、启动取消竞争和并行排空等机制，不复制这些仓库代码或引入另一套 Agent。

## 对上契约

- `shell(command, cwd?)` 统一派发至本会话主环境，不提供后端参数，也不并列注入 `termux_shell`。`install_packages` 仅在 Ubuntu 主环境就绪时开放；Shizuku 仍使用独立 `shizuku_shell`。每次独立非交互执行，不加载 rc，不保留变量与 cd，不设命令总时限。
- Shizuku 固定 shell UID 2000、`/system/bin/sh -c`、默认 `/`。Termux 使用真实应用 UID、固定 Bash、默认 `HOME/.phase/workspaces/<workspaceId>`；不是 Ubuntu `/workspace`，没有路径级强隔离承诺。
- 全局默认 Ubuntu，仅影响之后首次发送的新会话；会话创建后主环境不可修改，聊天页无环境入口或草稿。全局保存尚未完成时，新会话创建等待保存结果；运行仍固定身份，批准计划核对来源。未就绪不自动切换、不阻塞普通聊天。
- `shizuku_transfer` / `termux_transfer` 接收 `path`、`remotePath`、`direction=to_channel|from_channel`。`path` 是会话工作区相对路径，`remotePath` 是对应身份下的绝对路径；导出源还可显式引用 `attachment:<ID>`，经现有附件复制契约落入会话工作区。
- SettingsStorage 的通道设置仅保存 Shizuku 开关，默认关闭；界面与保存路径均只在原生返回已授权、运行中且 shell 身份受支持时允许开启，禁止用旧状态保存开启值，关闭不要求授权。Termux 不再有第二层应用内许可，不能因旧偏好中的关闭值阻止已授权使用。上方 Termux 选项在系统命令权限未授予或状态尚未取得时禁用，保存前再向原生核对；`initializationRequired` 与 `ready` 都表明系统权限已授予，但实际执行仍要求运行组件就绪和外部调用配置。授权或初始化不自动改变主环境，也不打开 Shizuku 开关。切回 Ubuntu 仅改变新会话默认值，不停用已有 Termux 会话。运行 JSON 固定通道集合、UID、runner 摘要和默认目录，新许可不加入旧运行；Shizuku 停用与系统撤权仍停止对应活动调用并阻止后续派发。
- 命令与外部传输共用命令策略：计划 deny、基础 ask、全权限 allow。系统许可仍独立检查；准备任务通知不依赖无障碍，真正启动与写入发生在确认之后。
- 使用 schema 10 初版契约：会话主环境、工作区 Termux 身份及分环境资源来源。仅本次获授权 9 → 10 升级：已有会话绑定 Ubuntu、Termux 身份为空，旧文件来源标记 Ubuntu，保留其他数据与文件；事务校验失败回滚，不扩展历史链。

## 工作区文件后端

`WorkspaceFileAccess` 统一本地与 Termux 文件访问，普通文件工具、文件页、Skill 副本和 shell 使用同一运行绑定；宿主路径不冒充 Termux 路径。附件原件、抽取文本、Skill 安装库及历史产物仍由相月保存，预览按需生成临时副本；MCP stdio 仍在 Ubuntu 服务专属目录，不自动共享会话文件。

- `WorkspaceFileRequest` 只接受宿主定义的操作、工作区 ID 和相对路径。runner 直接 exec 类型化文件 helper，不使用模型 shell 文本或 Python/Node；控制与读取共用监督进程、归属、取消和输出限制。大文件走有鉴权的短命字节传输，不能经 Intent 传完整内容。
- 保持完整行分页（2000 行 / 16 KiB）、2 MiB 编辑与写入、空内容覆盖及原文唯一匹配。编辑在宿主计算替换，提交前比较摘要，再原子替换；不把摘要暴露为 AI 参数。Termux helper 拒绝链接路径；这些检查不隔离同 UID 的任意脚本。
- 计划档只允许执行类型化读取和列目录；命令/传输定义可保持可见，但调用在派发前拒绝，不因模型调用而初始化 helper、准备 Skill 或安装依赖。首次写入前记录 Termux 目录归属；系统撤权和身份改变均检查当前状态。
- `workspace_transfer(path, direction=to_other|from_other)` 在两个托管目录的同一相对路径显式复制。文件页提供“复制到另一环境”；同名覆盖、目录合并，保留目标额外文件。失败回填已收到的提交项，不重试不回滚已提交文件。
- 外部传输的 `path` 同样指当前主环境；Termux 与 Shizuku 之间通过宿主受控暂存转运，不建立镜像。`prepare_skill` 返回 `executionPath`，缺解释器不自动安装。
- 复制会话复制两侧已创建目录；删除清理两侧托管文件，Termux 不可达时保留删除重试状态。未完成副本清理失败时保留可删除的归属记录。用户导出到任意外部位置的文件不随会话删除。

## 原生执行与生命周期

入口是 `pigeons/command_api.dart`，生成入口仍为 `tool/generate_execution_bridge.sh`。新命令宿主复用 ExecutionRuntime/ExecutionService，按 owner/run/toolCall 归属；原 LinuxProcessHostApi 与 MCP 管道保持不变。

Shizuku 使用 API/provider 13.1.5 和独立 UserService。Binder 只派发控制，IO 在工作线程，输出使用独立 PFD；服务按客户端 Binder 死亡收尾。命令由 APK JNI 目录中的 runner 执行，日志/控制记录只放 shell 可达的受管理目录，不把相月私有路径当成 shell 可读路径。

Termux 通过显式 RUN_COMMAND 与 non-exported receiver 的 one-shot mutable PendingIntent 收发。用户自行安装、授权、打开 allow-external-apps；初始化只分块部署、校验并启用版本化原生 runner，不安装 Python/Node，不修改用户 rc。回调只接受注册 ID 和规定 result bundle，校验截断长度；大输出在 Termux 私有目录保存，16 KiB 原始字节以内分块读取。

`tool/native/command_runner.cpp` 负责单次执行：唯一 started 标记、独立会话/进程组、subreaper、父死亡信号、真实 wait 状态。保持 leader 未回收，避免拿已复用 PGID 终止其他任务；取消请求由仍拥有后代的 supervisor 处理，不按磁盘旧 PID 盲杀，不伪造 143。

- 本地租约 30 秒，活跃控制轮询续租；Shizuku 服务每 5 秒续租，Termux 空闲时约每秒轮询。正常长命令没有总时限，失联期限不是“无输出超时”。
- TERM 后 800 ms 转 KILL，并回收受管理后代；实际命令仍可能产生不可逆外部效果。同 UID 恶意命令能干扰宿主，不宣称强隔离或保证清理任意逃逸进程。
- stdout/stderr 各预览 64 KiB，合计 8 MiB 达限停止。普通输出不附加日志文件；超出预览才登记完整日志。结果区分取消请求与终止回执，失联不显示已终止。
- 重启不恢复旧进程句柄、不重放命令；失联日志和未确认终态如实回填，不设置人工核验流程。

## 递归传输

Shizuku 使用 PFD 双向字节通道；Termux 使用只监听 `127.0.0.1` 的短命 socket，随机 256-bit 令牌只准入本次操作，令牌不进入模型、记录或日志。端点不接受请求方选择相月任意路径，不是共享目录服务器。控制仍使用 RUN_COMMAND，传输不经 Intent 承载整个文件，也不失败后自动换通道重发。

内部 wire format：网络字节序，清单项数 u32；逐项 type u8（文件 1、目录 2）、UTF-8 路径长度 u32/字节、大小 u64。根项路径为空，父目录必须先出现；清单后按顺序发送每个文件的内容及 32-byte SHA-256。接收方返回 ready，发送方明确 commit，再返回成功标志与已提交项数。清单总字节不超过 64 KiB；超出直接失败，避免 Pigeon/Binder 大消息。

- 单文件 64 MiB、单次 256 MiB、最多 1000 项。保留名称、层级、隐藏文件与空目录，不复制所有者或特殊权限，不跟随符号链接和特殊文件。
- 同名文件完整覆盖，目录合并，目标额外文件保留；文件/目录冲突在预检阶段失败。不把同一字符串路径视为三个 UID 的共享文件。
- 目标同目录暂存、流式摘要校验后逐项提交；目录不是整体事务。部分失败记录已经收到的完成项，清理未提交临时文件，不回滚已提交文件。
- 导入后登记工作区来源和产物；外部导出目标不随会话删除。业务记录失败是 StorageFailure，文件/传输/产物 IO 失败是工具错误。

## 验证边界

初始 E6 的 Profile 构建、覆盖安装及数据保留记录见实施计划第 8 节。主环境初次实现时完成 Pigeon/Riverpod/Drift 生成，`flutter analyze --no-pub lib`、native C++ 与 Android Kotlin 编译、`git diff --check` 通过。全量 analyze 另有 3 处测试替身接口未同步（`createConversation`、`setPrimaryEnvironment`、`WorkspaceFiles.outputs`）及 2 项既有引号 lint；默认格式检查仍报告既有 `test/support/schema8_fixture.dart`。当时未修改或运行测试，未装机；后续环境设置交互的安装记录不代表真实通道功能验收。

2026-09-26 环境设置交互调整：使用 SDK SegmentedButton 与紧凑通道卡片，取消 Termux 独立使用开关，补齐 Termux 选择和 Shizuku 开启的授权复核。已同步生成物，应用代码静态检查、改动格式及 diff 检查、Profile 构建通过，并以 `adb install -r` 覆盖安装后确认启动，未卸载或清数据。全量检查仍有 2 处既有测试替身接口不匹配、2 项引号 lint 和 `schema8_fixture.dart` 格式问题；未修改或运行测试，未完成真机布局、动画和真实授权流程验收。

后续获授权后，先验证两个实际通道的运行门槛，再宣称可用：当前 compileSdk 37/targetSdk 36、ARM64、UserService JNI 可执行性、Termux 发行版/SELinux/私有目录执行、后台 RUN_COMMAND 与回调、租约和真正进程/FD 回收。覆盖启动中取消、双路长输出、非零退出、撤权/宿主死亡/断连、重复迟到回调，以及二进制/空目录/隐藏文件/覆盖冲突/源变化/磁盘满/部分提交。
