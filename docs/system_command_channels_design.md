# 系统命令、Termux 传输与 Shizuku 虚拟屏

更新：2026-09-27。Ubuntu/Termux 负责通用命令与会话文件；Shizuku 只提供独立虚拟屏控制，不再提供通用命令、文件传输。用户明确选择无需开启应用无障碍服务独立运行；本次补充虚拟屏 Unicode 文字输入。schema 仍为 10，不增加数据库迁移。代码、构建与真实设备验收分别记录。

## 范围与参考

Ubuntu / Termux 在环境设置中全局单选；新会话首次发送绑定已保存的环境，之后不可切换。shell、文件与 Skill 使用相同后端，两侧目录独立，显式复制不自动同步。Shizuku 不是主环境，不参与普通 shell、文件工具或工作区传输。

本地参考版本：Aether `4723e81`、Operit `b2c76100`、Kelivo `25876c21`、RikkaHub `288a034c`。本次参考 Aether 的 VirtualDisplay、定向输入与 ImageReader 观察链路，不复制 GPL 源码、不引入 Pi/Node Agent、不降低 targetSdk。Aether 的应用级共享显示屏、任意命令、按键模拟文字和无权限沙箱插件契约不作为相月契约。

独立 su Root 通道、交互 PTY、Termux MCP 双向会话、自动目录同步、Shizuku 主屏后端、跨运行保留虚拟屏、实时视频预览与虚拟屏人工触控接管不在本批。

## 通用命令与文件

- `shell(command, cwd?)` 仅派发至会话固定的 Ubuntu/Termux；不提供后端参数，也不并列注入 `termux_shell`。`install_packages` 仅在 Ubuntu 就绪时开放。每次独立非交互执行，不加载 rc，不保留变量与 cd，不设命令总时限。
- Termux 使用真实应用 UID、固定 Bash、默认 `HOME/.phase/workspaces/<workspaceId>`；不是 Ubuntu `/workspace`，没有路径级强隔离承诺。环境未就绪不自动切换、不阻塞普通聊天。
- `termux_transfer(path, remotePath, direction)` 显式导入/导出文件或目录。`path` 是当前会话工作区相对路径，`remotePath` 是 Termux 身份下的绝对路径；导出附件可使用 `attachment:<ID>`，先按已有契约落入工作区。
- 不注册 `shizuku_shell` / `shizuku_transfer`，原生命令及传输入口同样拒绝 Shizuku；旧命令 UserService 与 AIDL 已移除，不留下可通过原生桥调用的通用入口。
- 命令与外部传输共用命令策略：计划 deny、基础 ask、全权限 allow。系统许可独立检查；准备通知不依赖无障碍，实际执行和写入在确认之后。

## 授权与快照

- 设置仅保存 Shizuku 独立开关，默认关闭，当前语义是“虚拟屏控制”。服务运行、系统授权、实际 UID 可读后才可开启，保存前重新核对；失去授权仍可关闭。授权或连接不自动打开开关，不代表真实虚拟屏已验收。
- 使用 Shizuku 实际授权 UID，包括 shell / root；不主动提权，不自动切换身份。运行快照保留通道、UID 和设备定义修订，UserService 复核调用者应用 UID 与实际执行 UID。
- 现有 `commandChannels` 运行 JSON 同时记录 Termux 命令绑定和 Shizuku 设备绑定；后者 revision 为设备契约版本，home 为空，不表示可用文件根目录。工具快照只有 `shizuku_display`，不兼容或重放旧运行中的 Shizuku 命令工具。
- Termux 无额外应用内使用开关。未安装、未授权或状态未知时禁选；保存前复核系统授权。`initializationRequired` 与 `ready` 都表示系统命令权限已授予，实际执行仍需运行组件和外部调用配置就绪。切回 Ubuntu 不停用已有 Termux 会话。
- 新许可不加入旧运行；Shizuku 停用、系统撤权、身份改变或服务死亡会停止对应活动运行。应用名单取运行快照与当前保存名单的交集，收紧立即生效。

## Shizuku 虚拟屏视觉闭环

入口：`pigeons/execution_api.dart` 的 `controlDisplay`、`lib/features/execution/shizuku_display_tool.dart`、Android `shizuku/`。保持 Dart AgentLoop / ToolExecutor，不另建执行循环或会话事实库。

- 仅在 Shizuku 已启用、已授权且模型支持工具与图片时开放 `shizuku_display`。它属于 `app_operations`：计划 deny、基础 ask、全权限 allow；定义可见不授予执行权。计划档不会因调用而绑定 UserService 或创建显示屏。
- 动作固定为 `launch/capture/tap/swipe/key/text/close`。继续复用宿主的 `list_apps`。不接受任意命令、文件路径或 Android displayId；主屏无障碍工具保持独立，不在失败时切换后端重发。
- 首次 `launch` 创建本次运行专属的 720×1280、320 dpi VirtualDisplay，应用使用指定 displayId 启动。系统必须具备独立焦点和禁止抢占主屏顶层焦点的相应标志，缺失则失败，不默默忽略。不申请安全显示能力，不绕过 Android 受保护内容限制。
- 启动使用显示屏 Context 创建一次性、不可变 `PendingIntent`，发送时指定 `launchDisplayId`，结束后清理令牌。与 Aether 使用相同的系统启动入口，不从未向 ActivityManager 注册为应用进程的 UserService 直接调用 `Context.startActivity`；不回退主屏或自动重发。UserService 绑定版本为 3，避免重用旧启动/按键文字输入实现。系统 API 的 `SecurityException` 不等同于 Shizuku 撤权；启动被拒绝/请求取消分别回填，已明确收到拒绝时不再提示“未收到完整执行回执”。真正的开关、系统授权和 UID 检查仍由宿主执行。
- 原生宿主先校验应用名单，UserService 在输入前及截图前后按该显示屏实际前台任务核对包名；无法读取或目标不符时拒绝，不把最后启动的包名当现场。它是任务级身份检查，不声称能识别全部系统覆盖窗口、密码框、支付或验证码。虚拟屏不隔离账号/数据，Android 应用仍可能复用或迁移任务。
- 输入动作必须引用本运行最近成功返回的 `screenshotId`；输入派发后令牌失效，取得新的真实截图后才签发下一令牌。坐标是返回图片像素，不引入 0–1000 归一化坐标。该令牌不证明同一应用画面此后没有自行变化，仍须按实际观察选择动作。
- 点击/滑动逐步核对目标并响应取消；按键仅支持 back/enter/tab/delete/escape/方向键。`text` 不再把字符映射为硬件按键，使用下述 Unicode 编辑链；不切输入法、不用剪贴板、不降级重输。支付、密码和验证码仍由用户手动处理；首版没有虚拟屏人工接管能力，不绕过主屏工具的人工协作前置。
- 操作后尽可能取真实截图。ImageReader → 限长 PNG → 宿主提供的 PFD；仅传这一次截图，不提供通用文件传输。Dart 复用 4 MiB 上限、PNG 尺寸检查、附件登记和图片回填。原生超时不生成黑图冒充观察；动作已派发但观察失败时保留动作信息，不自动重试。
- 图片与动作在聊天工具卡片呈现，图片可打开查看；首版不是实时 Texture 预览。异常、取消、观察失败明确显示，不暴露包名/显示屏 ID 等实现字段作为卡片常驻说明。
- 与既有设备操作共用串行队列，但虚拟屏不依赖应用无障碍服务连接，不受主屏前台窗口切换驱动。任务通知及停止复用 ExecutionService，准备不创建显示屏，真正派发在确认后。锁屏、撤权、服务死亡、用户停止和运行收尾释放本运行显示屏、ImageReader 与 FD；宿主 Binder 死亡由 UserService 收尾。资源释放不等于外部效果回滚，重启不恢复或重放动作。

### Unicode 文字输入

入口：Android `shizuku/DisplayTextConnection.kt`、`DisplayTextInput.kt`。Android 14+ 在已授权的 Shizuku UserService 内按调用临时建立 UiAutomation 节点连接；无需用户开启相月无障碍服务，也不改系统输入法设置。仅注册节点访问并保留其他无障碍服务，不使用带主屏旋转恢复副作用的系统 `UiAutomationConnection`，不开放额外命令/权限接口；连接或 ROM 接口不可用时如实失败，不抢占已有自动化连接。

- 仅从运行专属 displayId 中查找目标应用的已聚焦应用窗口和输入节点，不调用全局活动窗口/焦点，不猜测第一个可编辑框。每次写入前重新检查显示屏、包名、焦点、可编辑状态、内容与选区，仍受原应用名单、截图令牌和取消检查约束。
- 通过 `ACTION_SET_TEXT` 写入 Unicode，中文与 Emoji 不经过按键映射；保留选区外的原文，按光标插入/替换选中内容，必要时用 `ACTION_SET_SELECTION` 调整光标。输入上限仍为 500 个 UTF-16 单元，参与编辑的完整字段上限 16384 个单元；未知选区、选区超出可读内容、过长字段及不支持的自绘控件均不猜测或清空原文。依赖目标应用如实提供标准编辑节点，不承诺任意自定义控件均可编辑。
- 仅在本次调用内有界回读预期内容，不向模型或日志额外输出节点原文。系统接受写入与实际回读一致分别判断；回读不符、焦点改变或光标调整失败保留已派发/接受信息，不自动再次输入。已标记密码或提示为密码/验证码的输入框拒绝自动写入，这不是完整密码、支付或系统覆盖窗口识别能力。
- 成功、失败、取消均释放临时节点、窗口和连接；连接创建等待上限 3 秒，失败清理不重发文字。清理异常作为本次观察警告返回，UserService 死亡仍由注册 Binder 的死亡回收兜底。不增加无障碍开关、常驻输入服务或安装新输入法。

## 工作区文件后端

`WorkspaceFileAccess` 统一本地与 Termux 文件访问，普通文件工具、文件页、Skill 副本和 shell 使用同一绑定。附件原件、抽取文本、Skill 安装库及历史产物由相月保存，预览按需生成临时副本；MCP stdio 固定 Ubuntu 服务专属目录，不随主环境变化。

- `WorkspaceFileRequest` 只接受宿主定义操作、工作区 ID 和相对路径；runner 直接 exec 类型化 helper，不依赖模型 shell 文本或 Python/Node。大文件走有鉴权短命字节通道，不能用 Intent 承载完整内容。
- 保持完整行分页（2000 行 / 16 KiB）、2 MiB 写入与编辑、空内容覆盖和原文唯一匹配。编辑由宿主计算替换，提交前比较摘要再原子替换；不把摘要变成 AI 参数。Termux helper 拒绝链接路径，但不隔离同 UID 任意脚本。
- 计划档只执行类型化读取和列目录，不能初始化 helper、准备 Skill 或安装依赖。首次写入前记录目录归属，每次核对授权与身份。
- `workspace_transfer(path, direction=to_other|from_other)` 与文件菜单仅在两个托管目录的同一相对路径显式复制：同名覆盖、目录合并、保留目标额外文件。部分失败回填已收到的提交项，不自动重试或回滚已提交文件。
- 复制会话复制两侧已创建目录；删除清理两侧托管文件，Termux 不可达或清理失败保留重试。任意外部导出目标不随会话删除。

## Termux 生命周期与传输

入口仍为 `pigeons/command_api.dart`，生成使用 `tool/generate_execution_bridge.sh`。按 owner/run/toolCall 归属，复用 ExecutionRuntime/ExecutionService；原 LinuxProcessHostApi 与 MCP 管道保持不变。

Termux 使用显式 RUN_COMMAND、non-exported receiver 和 one-shot mutable PendingIntent。用户自行安装、授权与开启 allow-external-apps；初始化只部署并校验版本化原生 runner，不安装 Python/Node、不修改 rc。回调校验注册 ID、result bundle 与截断长度；大输出保存于 Termux 私有目录，16 KiB 以内分块读取。

`tool/native/command_runner.cpp` 保留独立会话/进程组、subreaper、父死亡信号和真实 wait 状态。30 秒本地租约由活跃控制轮询续租；失联期限不是无输出超时。TERM 后 800 ms 转 KILL，回收受管理后代与 FD；不按旧 PID 盲杀，不保证清理任意逃逸进程。stdout/stderr 各预览 64 KiB、合计 8 MiB 达限停止；仅超出预览时登记完整日志。没有终止回执不宣称已停止，重启不恢复句柄或重放命令。

递归传输仅监听 `127.0.0.1` 的短命 socket，随机 256-bit 令牌只准入本次操作，不进入模型、记录或日志。端点不接受请求方选择相月任意路径。wire format 保持网络字节序：项数 u32；逐项 type u8、UTF-8 路径长度 u32/字节、大小 u64，随后文件字节和 32-byte SHA-256，ready/commit/成功回执。

- 清单最多 64 KiB，单文件 64 MiB、单次 256 MiB、1000 项；保留名称、层级、隐藏文件和空目录，不跟随链接或特殊文件，不复制所有者与特殊权限。
- 同名文件完整覆盖、目录合并、目标额外文件保留；文件/目录冲突预检失败。暂存、摘要校验后逐项提交，目录不是整体事务；失败记录已提交项、清理未提交临时文件，不回滚已提交文件。
- 文件/传输/产物 IO 失败属于工具错误；业务状态读写失败才是 StorageFailure。

## 数据与验证边界

schema 10 仅保留已授权的 9 → 10 保数据升级：已有会话绑定 Ubuntu、Termux 身份为空，旧来源标记 Ubuntu；其他数据与文件保留，事务失败回滚，不扩展历史链。本次不改 schema、不转换历史工具记录。

此前 E6 安装记录见实施计划第 8 节：曾完成 Profile 覆盖安装及启动，但未验证真实 Shizuku/Termux 命令与传输。2026-09-26 的 UID 放开安装也不构成虚拟屏验收；旧 Shizuku 命令路径已在本次移除。

本次已执行 Pigeon 生成、`flutter analyze --no-pub lib`、改动 Dart 格式检查、`git diff --check`、Android Kotlin 编译与 `flutter build apk --profile --no-pub`，均通过。全量 analyze 仍有既有 2 处测试替身接口不匹配和 2 项引号 lint；全量格式检查仍报告既有 `test/support/schema8_fixture.dart`，未改动这些测试。检查期间一度无 Android 设备；随后检测到已授权设备 `1b8418ca`，以 `adb install -r` 覆盖安装 Profile 包（`Success`），冷启动 `Status: ok`、`TotalTime: 2394 ms`，进程存活；未卸载或清数据。未新增、修改或运行测试，未进行虚拟屏、ROM 或 shell/root 实机验收。真实验收需分别覆盖 shell/root UID、当前 targetSdk 与 ROM 的显示创建、实际目标/名单、坐标/PNG、受保护画面、非 ASCII 输入、主屏任务复用影响，以及手势中停止、截图等待、撤权、身份切换、宿主/服务死亡和资源释放。Termux 仍需独立验证启动取消、双路输出、进程回收、外部调用与递归传输；不能把虚拟屏构建当作这些路径的验收。

随后排查“动作已派发 / 授权已撤销”报告：设备 API 36，相月的 Shizuku 权限为 granted，Shizuku 服务 UID 为 0。代码中的这组文案指向启动派发后的系统拒绝分支，而非前置开关检查；现存日志未保留该次原始异常，未宣称复现具体 ROM 拒绝原因。对照 Aether 后改用上述 PendingIntent 启动并修正错误分类。改动 Dart 格式、`flutter analyze --no-pub lib`、`git diff --check` 和 Profile 构建通过；全量检查仍为上述既有问题。已在同一设备保数据覆盖安装（`Success`），冷启动 `Status: ok`、`TotalTime: 1865 ms`，权限仍为 granted。未新增、修改或运行测试，修复后的实际虚拟屏启动、截图与输入仍待复验。

2026-09-27 中文输入：已核对原实现及 Aether 都将文本交给 `KeyCharacterMap.getEvents`，无法映射中文；新增上述 Unicode 节点编辑链，隐藏接口按 AOSP Android 14/16 的注册、连接和回收实现核对，不把源码核对当 ROM 验收。改动 Dart 格式、`flutter analyze --no-pub lib`、`git diff --check` 与 Profile 构建通过；全量格式/分析仍有上述既有测试文件问题，未修改测试。已在设备 `1b8418ca` 保数据覆盖安装（`Success`），冷启动 `Status: ok`、`TotalTime: 2954 ms`，进程存活且 Shizuku 权限仍为 granted。未新增、修改或运行测试；普通输入框的中文/Emoji、选区替换、主屏不受影响、其他自动化占用、取消与连接回收，以及 WebView/Compose/自绘控件差异均未作本轮真机验收。
