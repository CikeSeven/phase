# AGENTS.md — 工程规范

本文件规定项目边界与开发流程；视觉、交互和 UI 验收统一见 [DESIGN.md](./DESIGN.md)。规范是改动要求，不代表所有场景已经验证。

## 1. 项目范围

- 产品「相月」，取自《尔雅》中农历七月的雅称；工程名 `phase`，仅支持 Android，应用 ID 为 `app.xiangyue.phase`。
- 当前为尚未发布、0 用户的初版建设阶段；已有聊天、工具和 Android 执行基线，按目标设计继续建设，不维护开发期接口、模型或数据库的向后兼容，不建设旧格式转换与双写过渡。
- 产品现状与有效契约见 [产品设计](./docs/product_and_technical_design.md)，新增能力见 [Agent 与扩展设计](./docs/agent_extensions_design.md)，建设顺序见 [实施计划](./docs/implementation_plan.md)。已有实现、自动化验证、真机验收和发行状态分别记录，不把规划描述为完成。
- 应用身份与平台范围按产品设计确定；修改聚焦当前任务，不顺带重构无关模块。设备安装与数据操作仍遵循第 6 节，不因项目处于初版阶段自动执行破坏性操作。

## 2. 技术与依赖

- 使用 Flutter stable；SDK 约束与依赖声明见 `pubspec.yaml`，解析版本见 `pubspec.lock`，实际工具链用 `flutter --version` 确认，不维护第二份版本表。
- UI 采用 Material 3 Expressive 设计体系，以 Flutter Material 组件和项目共享样式/交互适配实现，保留月色玻璃主题；图标与 Markdown 使用 `material_symbols_icons`、`gpt_markdown`，具体组件与动效边界见 DESIGN。业务状态用 Riverpod 3 注解生成，路由用 go_router，网络用 Dio，存储用 Drift / shared_preferences / flutter_secure_storage。
- 优先复用 SDK、标准库和已有依赖；新增或升级依赖先说明必要性与影响，同步 manifest 和 lockfile。分析器规则以 `analysis_options.yaml` 为准，不为通过检查关闭 lint。

## 3. 结构与依赖边界

- `lib/features/` 按业务组织页面、局部组件和状态；仅真正跨业务复用的能力进入 `lib/core/`。
- `lib/data/models/` 定义初版共享数据契约，不机械增加 entity 层。消息采用结构化 Part，角色按 `ChatRole.user/assistant/system/tool` 定义；原型字段、旧序列化格式不作为兼容约束。
- `lib/data/repositories/` 封装业务数据访问；`lib/data/datasources/` 封装数据库、偏好、密钥与网络设施。
- `lib/providers/` 是 AI 协议适配层，不是 Riverpod 状态目录；Riverpod 定义随所属职责放置。
- feature 通过注入的 notifier、repository、设置/密钥封装和 AI 工厂组织业务，不在页面直接操作 Dio、Drift 或存储插件；数据与协议层不反向依赖页面。
- `lib/main.dart`、`lib/app.dart`、`lib/core/router/app_router.dart` 是初始化与装配点；路由引用页面是装配职责，不推广为共享组件依赖 feature 的理由。

## 4. AI 协议、流式与错误

- 对上使用初版 `AiProvider`、`ChatRequest`、类型化 `ChatChunk`；实现时直接同步调用者与测试，不为原型签名保留兼容包装。四种模型协议的差异留在协议适配层。
- `ProviderProfile.protocol` 明确选择协议，预设用于填写创建表单；不根据域名、模型名或异常自动切换协议。模型获取与手动管理按 ID 合并，显式能力设置优先。
- 请求尊重模型能力与用户推理等级；不支持推理时不下发推理字段，`off` 按各协议的关闭语义映射。补响应解析不能暗改请求参数。
- 正文与思考分通道累积；思考只取实际公开文本/摘要，不由模型名、token 数、签名或加密字段伪造。SSE 须处理分片、多行事件、完成快照及带内错误，避免重复追加。
- 流式更新合并、节流写库；正常完成、停止、空回复和错误必须有明确结果。停止保留已收内容，丢弃迟到增量；取消应传递到底层请求，修改此路径须验证等待响应、空闲流和最终落库。
- 临时模型错误在当前逻辑轮内有限自动重试，允许正文、公开思考或工具参数已部分输出。每次失败尝试独立落库；新尝试使用原请求上下文，不拼接失败输出、不继承其协议状态，也不重放此前已派发的工具。退避等待可停止，实际请求逐次计数；不修改模型参数或切换协议来消化错误。
- 网络与存储边界将异常映射为 `lib/core/error/failure.dart` 中的 `Failure`；界面展示安全文案，不吞异常伪装成功。异步写入失败和资源销毁也要收尾。
- 不设置执行后的“结果未确认”或人工核验流程。工具响应、错误、超时与已有动作信息直接回填给 AI，由 AI 读取现场并决定后续步骤；点击已被系统接受但画面不变时如实返回观察，不让用户填写结果。失败/取消不代表外部效果已撤销，框架不自动重发已派发动作；停止与存储故障仍须正确收尾。
- 文件读取、临时副本与产物文件处理失败属于本次工具结果，不因使用了文件系统就升级为全局 `StorageFailure`；应用状态记录读写失败才按存储故障收尾。给 AI 的恢复规则不直接作为用户错误提示，界面说明具体文件/操作与实际失败原因。
- 协议问题依据脱敏请求/响应定位并编写测试，不为未出现的网关变体添加字段猜测、正则链或自动降级。获取模型成功不等于聊天、推理或工具调用已验证。

## 5. 编码、状态与数据安全

- 文件 `snake_case`，类型 `PascalCase`，成员/常量 `camelCase`；按主职责拆文件。注释只解释必要原因与契约，修改行为时清理过期注释。
- 共享业务状态使用 Riverpod 3 注解 API；可变业务状态用 `Notifier` / `AsyncNotifier`，禁止 legacy API。草稿、搜索、焦点、展开和动画可用局部 widget 状态，确认前不提前覆盖持久化选择。
- `build()` 无网络/存储副作用；优先 `async/await`。异步操作处理防重复、过期结果、`mounted` 与异常；释放 controller、监听器、订阅等资源。
- `*.g.dart` 等生成文件不手改；修改注解、模型、表结构后重新生成并随源码维护。
- 会话、结构化消息、工具记录与运行状态使用初版 Drift schema，偏好用 `SettingsStorage`；数据模型、schema 与生成物同步。初版直接建表并测试正式数据契约，不补开发期旧 schema/JSON 迁移；正式发行后再针对实际发行版本维护数据变更。
- 2026-09-19 用户明确允许一次安装例外：现有测试包的 schema 3 → 4 仅新增 MCP 表和工具来源可空列，保留设备数据，并验证覆盖升级；不据此扩展其他开发期兼容链。
- API Key 只经 `SecureKeyStorage` 按配置 ID 存取，不进入模型序列化或普通存储；空 Key 编辑保留原值，免 Key 调用不使用旧凭据，也不因隐藏字段删除它。删除配置需处理对应凭据及部分失败的重试。
- 日志使用 `AppLogger`，禁止直接 `print`；不得记录密钥、鉴权头、用户对话或原始请求/响应正文。URL 查询参数、userinfo 和异常对象也可能泄密，不假设日志设施会自动脱敏。
- UI 行为遵循 DESIGN，不能为解决布局问题改动协议、存储或用户选择。

## 6. 工程命令与 Android

Dart 变更检查；仅依赖变化时运行 `flutter pub get`，生成输入变化时运行 `dart run build_runner build`：

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
```

Android 桥接当前定义位于 `pigeons/execution_api.dart`；新增进程 API 时同步扩展 `pigeons/` 与生成脚本。定义修改后执行 `bash tool/generate_execution_bridge.sh`（Pigeon 生成、Dart 格式化、Kotlin 行尾空白归一化），随定义维护 Dart/Kotlin 生成物。原生执行代码变更另运行 `cd android && ./gradlew :app:testDebugUnitTest`；JVM 测试不替代真机服务、权限、Activity 与线程验收。

真机 UI/性能验收使用 Profile；先用 `adb devices -l` 确认授权设备，将 `DEVICE` 设为其 ID：

```bash
flutter build apk --profile
adb -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-profile.apk
adb -s "$DEVICE" shell am start -W -n app.xiangyue.phase/.MainActivity
```

- **更新已有安装只用 `adb install -r`；禁止 `flutter install`、卸载重装和清数据。** 不改应用 ID、签名或用破坏性操作绕过安装错误；设备操作须在任务授权范围内。
- 调试可用 `flutter build apk --debug`；Debug 不作帧率基准。Release 当前仍使用 debug 签名，发布前单独验证签名、合并 Manifest 权限、联网与升级路径，不能将 Profile 当生产包。
- 保留 `android/app/build.gradle.kts` 显式的 `compileSdk = 37`（安全存储依赖要求）；SDK/依赖升级需检查兼容性，不无依据改回默认值。
- 本机 SDK 使用 `~/android-sdk` 覆盖目录，系统 `/opt/android-sdk` 只读；环境故障先用 `flutter doctor -v` 核对，不擅自提权或改写系统 SDK。

## 7. Git 与改动范围

- 保留已有未提交修改；不顺带格式化或修改任务外文件。新增分支用 `feat/…`、`fix/…`，`main` 保持可验证状态。
- Commit 遵循 Conventional Commits；仅在用户要求时提交、推送，不把一次授权视为后续自动授权。
- 改动涉及规范时同步本文件或 DESIGN；临时日志、截图和探针放在忽略的 `build/`，不提交凭据与测试产物。

## 8. 测试与交付

- 使用现有 `test/` 体系，优先回归用户的真实操作和边界，而非平凡 getter；测试用内存数据库、假凭据、可控网络，不读取手机配置或调用付费 API。
- 协议修复用脱敏原始 SSE 经真实适配器到显示/落库验证，参考 `test/ui/reasoning_response_flow_test.dart`；发送与停止参考 `test/ui/chat_flow_test.dart`，不能用假流证明空闲连接即时取消。
- 配置测试覆盖保存、模型管理、免 Key、失败与取消；数据测试覆盖初版模型读写、关系和事务，不建设历史开发格式的升级用例。
- UI 验收按 DESIGN 第 9 节；保留显式 `MaterialPage` 与 Android 预测返回，验证打开、取消、提交及页面状态恢复。
- 交付只陈述实际执行的检查和未验证范围；构建、截图生成、模拟响应分别不是视觉、性能或真实网关验收。纯文档改动核对事实、引用、命令及 diff，无需为此装机。

## 9. Agent、命令与插件扩展

- 保留 Dart `AgentLoop` 为统一循环；MCP、Skills、命令与插件工具复用 `ToolRegistry` / `ToolExecutor`、运行快照、确认、取消和结果记录。原生或 Node 进程不另建 Agent 循环与会话事实库。
- 动态工具按稳定来源 ID 和定义修订注册；未加入助手范围的工具默认 deny，用户启用的第三方工具默认 ask。服务器说明、Skill 指导和插件清单不授予权限；运行中收紧权限立即生效，新增许可不扩大旧快照。
- 本地命令按需使用 Ubuntu PRoot 工作区，MCP stdio 使用独立 stdin/stdout/stderr 管道，PTY 只用于交互终端。进程按运行/调用归属，取消和超时回收受管理子进程与 FD，重启不重放命令。Termux/Shizuku 是显式选择的独立通道。
- PRoot 执行文件通过 ABI 对应的 JNI 库目录交付，验证当前 targetSdk，不降低 SDK 绕过运行问题。PRoot 与同 UID 插件进程不是强隔离沙箱，不宣称工作区路径检查可以限制任意脚本访问。
- MCP 凭据、敏感头和环境机密按用途与 ID 存入 `SecureKeyStorage`，业务模型只保存引用；不传给模型、诊断或备份。插件不得直接读取通用密钥存储。
- 新增模型/接口随对应功能建立，不预建插件市场、兼容 Pi/ToolPkg 的包装层或多代理调度框架。文档更新压缩已有步骤，保留有效契约、源码入口和实际验收范围。
