# 相月初版实施计划

版本：初版 v1.0｜日期：2026-09-12

项目尚未发布、暂无用户，现有代码按起步原型处理。本计划从目标产品出发安排建设，原型可以直接改写或替换，不设置保旧接口、双写过渡或开发期数据迁移任务。

产品与技术契约见 [产品与技术设计](./product_and_technical_design.md)，工程规则见 [AGENTS.md](../AGENTS.md)，界面规则见 [DESIGN.md](../DESIGN.md)。以下阶段均为待实现/验收计划。

## 1. 首版交付目标

交付一个可日常使用的 Android 聊天与执行应用：

- 四协议服务商/模型配置，普通聊天与公开思考。
- 多会话、助手、结构化消息、图片/文本/PDF/DOCX 输入。
- 单代理工具循环、确认、停止与执行记录。
- 文件读写和一个跨 App 无障碍场景。
- 主题设置、会话导出与首版发行包。

验收主线：**选择模型与助手 → 输入需求/附件 → 流式回答或工具调用 → 确认 → 执行 → 结果回填 → 展示/保存**。

## 2. 建设顺序

| 阶段 | 交付内容 | 完成标准 |
|---|---|---|
| S1 正式契约与基础设施 | Part、消息、配置、工具与运行模型；schema 1；数据库/密钥/附件存储；Provider 接口 | 数据能直接创建、写入、查询；接口与生成物一致，没有原型格式转换层 |
| S2 聊天与助手 | 四协议文本/公开思考、服务商/模型配置、会话、助手、附件、主题 | 从界面到真实适配器再到显示/保存的聊天链路通过测试 |
| S3 工具闭环 | 结构化工具流、单 Loop、文件/HTTP 工具、工具卡片、确认/停止/记录 | 文档摘要保存任务完整跑通；每个动作有明确决定与结果 |
| S4 Android 执行 | Pigeon、SAF 文件访问、运行宿主/服务、无障碍、任务确认面板和设备队列 | 外部目录文件读写及目标 App 搜索场景可用；Activity 切换和停止不丢失任务控制 |
| S5 首版验收与发行 | 完整场景、布局/性能、导出、权限、签名与 APK | P0 功能真实可用，检查结果与发行包可复现 |

先确定正式契约再组织实现，不需要先把原型修成一个稳定旧版本。

## 3. S1：正式契约与基础设施

### 实现

1. 建立共享模型：ProviderProfile、ModelInfo、Assistant、Conversation、ChatMessage/ContentPart、ToolCallRecord、AgentRun、Attachment。
2. 建立类型化 ChatRequest/ChatChunk 和 AiProvider；原型调用者直接更新到这一套接口。
3. 用 Drift 创建正式 schema 1，设置表关系与查询索引；数据库从创建时加密，密钥交给 SecureKeyStorage。
4. 实现 ConversationRepository、RunRepository、服务商/助手数据访问和 AttachmentStorage。
5. 建立应用初始化、Riverpod 注入和路由装配；初始数据库创建普通助手，未配置模型时显示配置入口。
6. 确定新增依赖：加密 SQLite 构建、PDF 文本抽取、DOCX ZIP/XML 读取和 Pigeon；引入时同步 manifest 与 lockfile。

### 验收

- 内存/临时数据库按 schema 1 创建，验证约束、读写和消息父链。
- Part 只使用正式结构；工具参数/结果只有一处业务事实来源。
- API Key 不进入业务模型与普通数据库。
- 文件内容与附件记录可以建立和删除，产物引用可查询。

**不做**：开发期旧 schema 测试、新旧模型转换、双库切换、接口包装或任意未来字段保存。

## 4. S2：聊天与助手

### 实现

- 四协议各自完成请求构建、SSE 解析和公开思考展示，使用统一的类型化事件。
- 完成服务商、Key/免 Key、模型获取/手动管理、能力与模型参数设置。
- 完成助手创建/编辑/删除、系统提示词、默认模型和工具范围。
- 完成多会话、当前分支、复制和重新生成；重新生成创建新运行。
- 完成图片处理、文本/PDF/DOCX 抽取和附件消息展示。
- 聊天和设置使用 DESIGN 中的材质、布局、滚动与 Android 返回规则。

### 验收

- 四协议分别用脱敏原始 SSE 经过真实适配器到界面/数据库。
- 覆盖正文、公开思考、完成快照、空回复、标准错误与停止。
- 用本地可控 HTTP 连接验证等待响应和空闲流时的真实取消。
- 助手/模型/主题的打开、取消、保存，以及无模型/无 Key 等状态可操作。
- 图片方向/尺寸、文档抽取与附件请求内容对应。

测试按初版行为编写，原型测试随新契约修改，不要求保留原型中的偶然行为。

## 5. S3：单代理工具闭环

### 实现

1. 实现 LoopEngine、ContextBuilder、ToolRegistry 和 ToolExecutor。
2. 为四协议加入工具块组装与结果回填；完整响应收口后才执行工具。
3. 实现本地信息查询、HTTP、文档读取与文件写入工具；本阶段读取已导入附件，产物写入应用私有目录，S4 接通用户选定外部目录的 SAF 路径。
4. 实现 allow/ask/deny、固定参数的确认、60 秒期限和停止。
5. ToolCallRecord 直接记录准备、确认、执行、结果；AgentRun 保存当前位置和计数。
6. UI 展示工具卡片和产物，会话/工具记录可查询；完成 Markdown/JSON 导出。

### 验收

- “读取文档 → 摘要 → 确认保存 → 创建文件 → 最终回答”完整跑通。
- 多个工具调用串行执行，结果按原调用配对回填。
- 拒绝不执行；停止不继续调度；原始参数错误不靠解析普通文本执行。
- 动作已完成但结果未记录时显示结果未确认，不自动重做动作。
- 重新打开应用恢复已知内容与状态，不从日志回放命令。

首版不引入通用事件溯源、补偿事务、断点回放框架或多代理锁。

## 6. S4：Android 执行

### 实现

- 定义 Pigeon 请求/结果/进度，Dart/Kotlin 使用同一应用侧 toolCallId。
- 建立缓存 FlutterEngine 的运行宿主与 ExecutionService，使任务不依赖聊天 Activity 持续处于前台。
- 完成 AppFileDriver 的 SAF 文件/目录访问，与同一套文件工具和附件模型连接。
- 建立无障碍权限引导、目标窗口读取、UiSnapshot 与 nodeId 映射。
- 实现点击、滚动、标准文本输入和操作后的结果观察。
- 建立任务执行条/原生确认面板与停止入口，决定回到同一 ToolExecutor。
- 使用一个设备动作队列；首版不做协议版本协商或多个执行引擎切换。

### 验收

- 固定测试 App 的“搜索预置条目并打开详情”先形成可重复用例，再验证实际目标 App。
- 操作目标改变、权限关闭、锁屏与需人工处理的界面给出明确状态。
- 验证离开相月、返回相月、Activity 重建、服务停止和进程终止。
- 验证取消到底层，原生动作回调与业务目标完成分别记录。
- Pigeon 定义和生成物同步，线程与资源释放在实际设备检查。

## 7. S5：首版验收与发行

- 完成两条主线和全部 P0 页面，不显示未实现的假入口或成功状态。
- 完成浅深主题、320/360dp、横屏、大字号、键盘、长列表与返回手势检查。
- 在 Android Profile 上测量消息阅读、流式更新、侧栏和任务面板的帧数据。
- 验证会话导出范围，密钥不进入 JSON/Markdown；检查系统备份排除规则。
- 配置正式发行签名，核对合并 Manifest 的网络、服务和权限声明。
- 生成发行包并记录实际验证范围，首发使用 GitHub Releases。

不为首版安排历史开发版本的升级工程，也不把“文件生成成功”当作 UI、性能或真实模型验证。

## 8. 后续阶段

| 阶段 | 内容 |
|---|---|
| P1 | Shizuku、Termux、MCP/Skills、plan mode、摘要/记忆、完整分支与加密备份、感知增强、单子代理、多 Key/模型分派 |
| P2 | Root、fork/更多并发、Code Mode、定时事件触发、模板与角色卡生态、远程访问 |

P1/P2 按使用需求逐项实施，不先给初版塞入空实现、镜像存储或复杂调度框架。正式发行后需要演进数据时，再针对实际发行版本设计变更。

## 9. 工程检查

依赖变化时运行 `flutter pub get`，生成输入变化时运行 `dart run build_runner build`。Dart 代码改动执行：

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
```

真机检查先确认授权设备并设置 DEVICE：

```bash
adb devices -l
flutter build apk --profile
adb -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-profile.apk
adb -s "$DEVICE" shell am start -W -n app.xiangyue.phase/.MainActivity
```

设备安装/数据操作遵循 AGENTS，不使用 `flutter install`、卸载或清数据代替正常部署。Debug 不作为性能基准，Profile 不作为正式发行包。

每阶段交付记录实际执行的检查、样本/设备和结果；临时截图、日志与探针放 `build/`。本文是初版建设计划，不表示上述代码、测试或设备操作已执行。

## 10. S1 执行记录

已落地并验证的部分：

- 共享契约：`lib/data/models/` 下的消息 Part 封闭类型集合、`ProviderProfile`/`ProfileModel`、`Assistant`/`ToolPolicyConfig`、`ToolCallRecord`、`AgentRun`/`RunConfiguration`/`TokenUsage`、`ChatRequest`/`ChatChunk` 类型化事件与 `ProviderError` 分类。
- 数据库：Drift schema 1 八表（provider_profiles、models、assistants、conversations、messages、attachments、agent_runs、tool_calls）与查询索引；消息父链、级联删除、Parts/USAGE 往返。
- 加密：pubspec 构建钩子把 `sqlite3` 切到 `sqlite3mc`，`openAppDatabase` 在 `NativeDatabase.createInBackground` 的 setup 阶段执行 `PRAGMA key`，密钥由 `DatabaseKey` 生成并交给 `SecureKeyStorage`；移除已停维护的 `sqlcipher_flutter_libs` 与 `drift_flutter`。
- 仓储：`ConversationRepository`（会话、消息父链、分支指针、附件归属与清理）、`AgentRunRepository`（轮次与尝试计数、确认/结果等待、终态）、`ToolCallRepository`（状态机流转）、`AssistantRepository`、`ProviderProfileRepository`（模型按 id 合并、能力设置优先）。
- 协议适配层：四协议按类型化事件重写（`PartStart`/增量/`PartEnd`/`Usage`/`ResponseEnd`/`ResponseError`），共用分块组装器；协议错误按状态码与明确错误字段分类，界面只显示分类安全文案。
- 界面层：聊天控制器改为按 Part 累积并按模型能力下发推理等级；服务商配置页按新契约（模型独立表、能力设置优先、列表外默认模型可见可保留）；附件保持图片与文本两类。
- 迁移中发现并修正的行为：流内错误事件（`ResponseError`）即本次响应结束，保留已收内容并标记失败，不再把网关错误文案当作正文落库。
- 已执行检查：`dart format --set-exit-if-changed`、`flutter analyze`、`flutter test`（410 通过）、`git diff --check` 全部通过；真机与真网关验证尚未执行。

## 11. S2 执行记录

已落地并验证的部分：

- 助手接入运行链路：会话绑定助手；发送请求带助手系统提示词；模型与推理等级按「会话显式覆盖 → 助手默认 → 最近使用 → 服务商默认」解析；新会话确认的模型选择先保存为草稿，首次发送时写入会话。首次建库写入内置普通助手；新建会话与后续会话都能切换助手（显式选择优先于会话绑定）。
- 助手页与切换：真实列表（名称、系统提示词、默认模型、当前标记）、创建/编辑/删除（删除只解除会话绑定）；默认模型选择面板含推理等级；工具范围按真实状态说明，未落地前不放假开关。聊天顶栏首行助手、次行模型，各自满足 48dp 触区。
- 会话操作：重新生成把分支指针移回最后一条用户消息并生成新回答，旧回答保留为同级分支；复制会话复制全部消息（含其他分支）、附件记录与助手绑定，原始附件和提取文本复制为独立文件，并重映射消息里的附件引用。副本立即切换，删除任一会话不影响另一份文件；复制失败清理本次新文件并回滚数据库写入。
- 文档输入：PDF 用 `syncfusion_flutter_pdf` 抽取，DOCX 用 `archive` 读 `word/document.xml`；抽取在导入时完成并写成独立文本文件；扫描件/损坏文件把原因记入 `attachments.extraction_error`，界面在附件条给出警告，请求里以说明代替内容。
- 模型参数：温度与输出上限按模型配置随请求下发（留空不下发），四协议各自的字段名与映射已有测试覆盖。
- 迁移中发现并修正的行为：助手列表尚未加载时发送会丢掉助手配置（现在先把列表与会话线程等就绪）；`ModelSelection` 的 `dependencies` 声明必须与同名符号同库，否则生成器报「no Element」。
- 已执行检查：`dart format --set-exit-if-changed`、`flutter analyze`、`flutter test`（431 通过）、`git diff --check` 全部通过；真机与真网关验证尚未执行。schema 从 1 升到 3（附件抽取原因、模型温度），迁移随版本号执行。
- S2 审查修复后复验：附件复制/引用映射/双向删除、复制失败清理、模型覆盖保存与重开、面板确认/取消已加入正式回归。格式与静态分析通过，完整测试 445 项通过、4 项跳过；未执行真机或真网关验收。
