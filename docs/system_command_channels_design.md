# E6：系统命令与显式文件传输

更新：2026-09-25。代码已接入；随后按用户要求完成保数据覆盖安装与启动，未获测试授权，不能把编译或安装通过写作实际通道功能验收。

## 选择与参考

本批用户确认：保留 Ubuntu、Shizuku、Termux 并列工具；外部通道全局启用；加入显式文件与目录递归传输。Root、交互 PTY、Termux MCP 双向会话、自动目录同步不在本批。

参考的本地源码版本：Aether `4723e81`、Operit `b2c76100`、Kelivo `25876c21`、RikkaHub `288a034c`。Aether 的 RUN_COMMAND/私有日志/PendingIntent、UserService 绑定与临时字节传输有直接参考价值，但取消脚本仅处理直接子进程并写固定退出码，不能照搬；Operit 使用旧 Shizuku newProcess/反射，Termux 只有未接线回调；后两者是应用内 PRoot，不是外部 Termux。只借鉴事件归属、启动取消竞争和并行排空等机制，不复制这些仓库代码或引入另一套 Agent。

## 对上契约

- `shell` / `install_packages` 仍只作用于 Ubuntu。新增 `shizuku_shell(command, cwd?)`、`termux_shell(command, cwd?)`；每次独立非交互执行，不加载 rc，不保留变量与 cd，不设命令总时限。
- Shizuku 固定 shell UID 2000、`/system/bin/sh -c`、默认 `/`。Termux 使用其真实应用 UID、固定 Bash、默认 HOME；均不是 `/workspace`，也没有路径级强隔离承诺。
- `shizuku_transfer` / `termux_transfer` 接收 `path`、`remotePath`、`direction=to_channel|from_channel`。`path` 是会话工作区相对路径，`remotePath` 是对应身份下的绝对路径；导出源还可显式引用 `attachment:<ID>`，经现有附件复制契约落入会话工作区。
- 全局开关默认关闭，由 SettingsStorage 保存；授权与初始化不自动打开开关。运行 JSON 固定通道集合、UID、runner 摘要和默认目录。新许可不加入旧运行；停用/撤权停止活动调用并阻止后续派发。
- 命令与外部传输共用命令策略：计划 deny、基础 ask、全权限 allow。系统许可仍独立检查；准备任务通知不依赖无障碍，真正启动与写入发生在确认之后。
- 沿用工具记录、结果、产物和资源副本来源表；没有新增 Drift schema 或装机迁移。普通文件工具不改为远程路径路由器。

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

本机已完成 Pigeon/Riverpod 生成、native C++ 编译、Android Kotlin 编译与 Profile APK 构建；`flutter analyze --no-pub lib` 无问题、`git diff --check` 通过。全量 analyze 保留测试文件两项引号 lint；默认格式检查发现已有 `test/support/schema8_fixture.dart` 待格式化，均未修改未获授权的测试，也未运行测试。随后按用户要求在设备 `1b8418ca` 保数据覆盖安装并启动；备份、APK 哈希和启动核对见实施计划第 8 节，未执行 Shizuku/Termux 命令或传输验收。

后续获授权后，先验证两个实际通道的运行门槛，再宣称可用：当前 compileSdk 37/targetSdk 36、ARM64、UserService JNI 可执行性、Termux 发行版/SELinux/私有目录执行、后台 RUN_COMMAND 与回调、租约和真正进程/FD 回收。覆盖启动中取消、双路长输出、非零退出、撤权/宿主死亡/断连、重复迟到回调，以及二进制/空目录/隐藏文件/覆盖冲突/源变化/磁盘满/部分提交。
