# 相月（Phase）产品与技术设计

更新：2026-09-19｜阶段：未发布的初版建设｜平台：Android

相月是 Android 多模型聊天与设备执行应用，工程名 `phase`，应用 ID `app.xiangyue.phase`。用户自带模型服务；Flutter/Dart 负责界面、模型请求与 Agent 循环，Kotlin 负责 Android 能力。

本文保留产品边界、当前实现入口和必须延续的契约，已实现功能不再逐项重写建设步骤。新增功能详见 [Agent 与扩展设计](./agent_extensions_design.md)，任务顺序和验收缺口见 [实施计划](./implementation_plan.md)。工程规则见 [AGENTS.md](../AGENTS.md)，视觉与交互见 [DESIGN.md](../DESIGN.md)。

“已有实现”指当前代码中存在对应链路，并列出可检查的测试入口；不表示本次执行了测试，也不表示已完成真实网关、真机或发行验收。项目仍不维护开发期接口与数据库的向后兼容，调整数据契约不授权清理设备数据。

# 第一部分 产品设计

## 1. 产品方向与架构决策

| 事项 | 决策 |
|---|---|
| 主循环 | 延续 Dart `AgentLoop`：模型响应 → 结构化工具 → 结果回填 → 下一轮 |
| 模型接入 | 四协议 `AiProvider`，协议选择显式、运行配置固定 |
| 工具入口 | 内置、MCP、命令及后续插件统一进入 `ToolRegistry` / `ToolExecutor` |
| 插件基础 | MCP 远程 Streamable HTTP、本地 stdio、按需加载 Skills |
| 本地命令 | 建设按需安装的 Ubuntu 24.04 PRoot 环境；Node/Python 按需要安装 |
| 系统通道 | 无障碍、Shizuku、Termux 各自声明能力与授权，不自动互换 |
| 扩展内核 | 不引入第二套常驻 Agent 循环；Pi 扩展、Operit ToolPkg 不列为直接兼容格式 |
| 平台与发行 | 仅 Android；首次发行使用 GitHub Releases，发行验收独立排期 |

内置 Linux、插件接口和 Agent 循环分别演进。普通聊天、远程 MCP 和纯文本 Skill 不以 Linux 安装成功为前置条件。PRoot 提供用户态 Linux 兼容环境，不提供 Android Root 权限或强安全隔离。

## 2. 当前实现概况

路径均相对于仓库根目录。下面是截至更新日期的源码核对结果。

| 已接入能力 | 主要代码入口 | 回归入口 |
|---|---|---|
| 四协议、模型管理、推理参数、Key/免 Key | [providers](../lib/providers/)、[providers_config](../lib/features/providers_config/) | [协议测试](../test/providers/)、[推理链路](../test/ui/reasoning_response_flow_test.dart) |
| 会话、助手、复制、重新生成、主题 | [chat](../lib/features/chat/)、[assistants](../lib/features/assistants/)、[settings](../lib/features/settings/) | [聊天链路](../test/ui/chat_flow_test.dart)、[会话复制](../test/data/repositories/conversation_copy_test.dart) |
| 图片、文本、PDF/DOCX 本地抽取 | [attachment_picker.dart](../lib/features/chat/attachment_picker.dart)、[document_extractor.dart](../lib/features/chat/document_extractor.dart) | [附件链路](../test/features/chat/attachment_flow_test.dart) |
| 单代理、工具策略、确认、停止、重试、中断恢复 | [tools](../lib/features/tools/)、[chat_controller.dart](../lib/features/chat/chat_controller.dart) | [工具回归](../test/features/tools/)、[真实连接取消](../test/features/chat/model_retry_transport_test.dart) |
| 文件、HTTP、工具记录、Markdown/JSON 导出 | [tool_registry.dart](../lib/features/tools/tool_registry.dart)、[conversation_export.dart](../lib/features/chat/conversation_export.dart) | [文件链路](../test/features/tools/file_tools_flow_test.dart)、[导出](../test/features/chat/conversation_export_test.dart) |
| 远程 MCP、来源/修订快照、扩展管理与助手范围 | [mcp](../lib/features/mcp/)、[MCP 仓储](../lib/data/repositories/mcp_server_repository.dart) | [MCP 测试](../test/features/mcp/)；本机真实 HTTP/SSE 与四协议闭环通过；设备范围见实施计划 |
| Skills 本地目录/ZIP、版本固定、助手范围与按需读取 | [skills](../lib/features/skills/)、[安装仓储](../lib/data/repositories/skill_repository.dart) | [Skills 测试](../test/features/skills/)；本机四协议文件产物闭环通过，真机范围见实施计划 |
| Ubuntu 安装、会话独立工作区、shell 与 Skill 工作副本 | [workspace](../lib/features/workspace/)、[原生宿主](../android/app/src/main/kotlin/app/xiangyue/phase/workspace/) | 本机四协议首轮工作区闭环通过；此前环境/原始进程桥已装机验证，本次会话归属调整已覆盖安装、数据保留与启动验证，完整 UI/生命周期待验收 |
| SAF、应用名单、无障碍、原生任务控制、设备队列 | [execution](../lib/features/execution/)、[Android 执行](../android/app/src/main/kotlin/app/xiangyue/phase/) | [Dart 执行测试](../test/features/execution/)、[JVM 测试](../android/app/src/test/kotlin/app/xiangyue/phase/) |
| Android 14+ 窗口截图、图片回填、坐标手势组合 | [visual_tools.dart](../lib/features/execution/visual_tools.dart)、[vision](../android/app/src/main/kotlin/app/xiangyue/phase/vision/) | [四协议视觉链路](../test/features/execution/visual_protocol_flow_test.dart) |
| 结构化消息、加密 Drift、附件与产物归属 | [models](../lib/data/models/)、[local](../lib/data/datasources/local/)、[repositories](../lib/data/repositories/) | [数据测试](../test/data/) |

## 3. 尚待建设的能力

| 类别 | 缺口 | 详细设计 |
|---|---|---|
| 工具生态 | 远程 MCP 外部服务验收、本地 MCP stdio、Skill 脚本真机验收/网络导入、插件包及受限扩展钩子 | [MCP](./agent_extensions_design.md#extensions-mcp)、[Skills](./agent_extensions_design.md#extensions-skills)、[插件包](./agent_extensions_design.md#extensions-plugins) |
| 命令环境 | PRoot 安装/文件 UI、通知停止和生命周期真机验收、本地 MCP stdio、依赖安装、PTY、Termux、Shizuku | [扩展设计 §5–§7](./agent_extensions_design.md#extensions-runtime) |
| Agent 能力 | Plan Mode、上下文预算与摘要、长期记忆、单子代理 | [扩展设计 §8、§10](./agent_extensions_design.md#extensions-planning) |
| 聊天与数据 | 完整分支导航、加密备份恢复、原生文档上传 | [扩展设计 §11](./agent_extensions_design.md#extensions-product) |
| 配置与感知 | 多 Key、按任务选模型、成本统计、通知监听与回复 | [扩展设计 §11](./agent_extensions_design.md#extensions-product) |
| 后续研究 | Root、更多代理并发/fork、Code Mode、定时事件、模板/角色卡生态、远程访问 | [扩展设计 §12](./agent_extensions_design.md#extensions-later) |

消息树与重新生成已有实现，完整分支导航尚无界面；数据库加密与会话导出已有实现，完整备份恢复尚未实现。截图和前台目标识别已接入，不再作为整个“感知通道尚未开始”的依据。

## 4. 用户主线

- 聊天：选择助手/模型 → 输入文本或附件 → 流式回答 → 阅读、复制或导出。
- 设备执行：提出需求 → 观察目标 → 固定参数确认 → 执行动作 → 返回实际观察。
- 扩展任务：配置 MCP 或安装 Skill → 开放给助手 → 必要时安装环境/依赖 → 同一工具循环完成任务。

基础验收仍保留“文档摘要保存”和“固定测试 App 搜索并打开详情”两条闭环，再验证实际目标 App；不承诺适用于任意 App。

## 5. 权限与确认

### 5.1 授权来源

应用私有目录/SAF、无障碍、Shizuku、Termux 与 Linux 工作区是不同的数据和执行范围。通道可用、助手开放工具、用户批准具体动作是三个条件；获取授权不代表工具或模型已通过验收。

### 5.2 工具策略

`allow / ask / deny` 分别表示在范围内执行、等待确认、不向模型开放且拒绝调用。新助手写入内置工具默认策略；shell 默认 ask，环境就绪且模型支持工具时自动注入，显式 deny 仍阻止开放。其他未列出的工具均为 deny。第三方工具被用户加入助手范围后默认 ask；服务器声明只读不能自动提高权限。

应用工具统一使用 `app_operations`：`list_apps`、`open_app`、`inspect_ui`、`click_node`、`scroll`、`input_text`、`capture_screen`、`perform_gestures`。不能以单工具配置绕过该组。

应用名单保持以下规则：

- 黑名单默认为空，允许第三方应用；系统应用需显式放行，显式禁止优先。白名单模式只允许选中的包名，两种模式分别保存。
- 相月自身与其他第三方应用同权，无截图或交互特例。
- 原生边界在应用分页前过滤；总数不包含禁止项。操作时同时检查实际目标、运行名单快照和最新保存名单。
- 名单收紧立即生效；新增允许不扩大正在运行的快照。恢复运行也与最新名单取交集。

### 5.3 确认流程

确认绑定 runId、应用侧 toolCallId、固定参数、目标和执行通道，默认 60 秒。展示本次实际内容与主要影响，提供允许一次、拒绝、停止；关闭或返回不视为批准，也不重置期限。变更参数需新调用。等待期间不占设备动作队列。

支付、密码、验证码由用户手动处理，自动动作不猜目标。拒绝一个动作后不能通过换工具重复同一效果；停止任务则结束循环。

## 6. 页面组织

现有聊天、助手、服务商、任务恢复、工具记录与执行权限页面延续 DESIGN。“设置 → 扩展”已接入 MCP 服务和 Skills；“环境设置”独立管理 Ubuntu，工作区文件从所属会话进入，不在设置中列出；插件入口随对应实现加入，不堆入现有无障碍权限页。页面内容见扩展设计，布局、返回与草稿规则统一遵循 DESIGN。

## 7. 数据与质量边界

API Key、MCP 凭据和环境密钥只通过安全存储引用，不进入业务序列化、诊断或导出。用户主动提交的文件、命令和工具输出作为业务内容管理，不能把诊断日志当作它们的副本。声明“导出不含密钥”指应用管理的凭据不会被加入，不能保证用户文本从未包含敏感内容。

构建成功、存在测试、生成截图与通过真机/真实网关验收分别记录。未完成的发行项不得以扩展功能完成代替，详见实施计划的发行清单。

# 第二部分 聊天与 Agent Loop

## 1. 职责

`AgentLoop` 只推进轮次；当前 `ChatController` 提供流式请求、上下文装配、工具执行与持久化宿主。后续按实际新增职责提取上下文构建，不为迁移到框架重写现有聊天路径。Provider 不调工具，原生进程不调用模型，插件不拥有另一份会话事实来源。

## 2. 运行快照

一次发送创建 `AgentRun`，固定连接、模型、参数、助手提示词、工具范围和执行范围；新编辑影响新运行。凭据按配置 ID 在必要时读取，快照不保存密钥。查看其他会话不改变根任务；现阶段同一时间一个根运行。

## 3. 一轮执行

装配当前分支 → 发起模型请求 → 合并正文/公开思考/工具块 → 响应完整收口 → 依次执行工具 → 保存结果与结果消息 → 下一轮。模型无工具调用时结束。未正常收口或参数无效的调用不派发，不从普通文本或 XML 猜测命令。

`turnCount` 在逻辑模型轮开始时增加；实际请求及其重试各增加 `modelAttemptCount`。结果回填不重复计算轮次。

## 4. 流式和结果

按 Part ID 合并增量与完成快照，避免重复追加。正文与思考分开计时、累积、显示；思考仅取公开文本，不解读签名/加密字段。流式写库节流且串行收尾，终态不被迟到写入覆盖。

工具响应、错误和已有外部效果直接回填 AI；是否再次观察或提出新调用由 AI 决定。图片/文件使用受控附件引用；工具输出只在构建模型上下文时限长，用户查看的已保存结果不替换为摘要。

## 5. 工具状态

`prepared → executing`，或 `prepared → awaitingConfirmation → executing / rejected / cancelled`；执行后收口为 `succeeded / failed / cancelled`。派发前保存 executing，结果与结果消息同事务提交。`ToolCallRecord` 是参数、决定、结果的唯一事实来源。

没有执行后人工核验状态。外部动作与数据库不能原子提交，保存失败必须如实报告并结束运行，不重发动作、不声称撤销。

## 6. 停止与恢复

### 6.1 等待与确认

等待确认、重试退避和执行均可停止。决定只作用于当前尚有效的调用，拒绝/过期回填为本次工具结果；用户停止结束根任务。

### 6.2 停止

取消传递到 HTTP、原生动作及后续进程入口，停止新调度并丢弃迟到增量。保留已收正文、公开思考和已知工具结果；下一次请求保留中断轮的正文与已执行工具历史，半截思考不回传。取消请求不等于外部效果被撤销。

### 6.3 恢复

重开应用读取运行与工具记录：已有结果仅恢复显示；executing 且无结果的调用按中断失败收口；未决确认保留原期限。用户从中断任务页继续时，只处理未派发调用或补结果消息，不重放已派发动作；不要求用户填写执行结果。

## 7. 结束与错误

默认最多 30 个逻辑模型轮。正常、空回复、停止、轮次耗尽、模型错误与应用记录存储失败有明确终态。

临时模型错误每轮最多重试两次，默认退避 2/4 秒，尊重有效 Retry-After，超过 60 秒则结束本轮。每次失败尝试独立保存；新尝试使用原请求上下文，不拼接失败输出、不继承失败协议状态、不重放工具。永久错误、额度耗尽或未分类错误不盲目重试。

工具文件、临时副本、产物读取失败是工具错误；会话/运行/工具记录写入失败才按 `StorageFailure` 结束。没有通用工具自动重试器，也不靠切协议、改推理参数或换执行环境消化错误。

## 8. 上下文与扩展

当前分支、工具调用与结果成组构建请求；缺失结果补如实的错误信息。跨配置/模型的签名和加密状态不回放。已有工具结果限长不代表完整的上下文预算、自动摘要和长期记忆已完成；这些按 [扩展设计 §8](./agent_extensions_design.md#extensions-planning) 建设。

# 第三部分 Android 执行通道

## 1. 运行宿主

`PhaseApplication` 持有缓存 FlutterEngine，`ExecutionService` 提供执行期间的前台通知与停止入口，Activity 只负责挂接。普通聊天不依赖设备服务。服务不粘性重启、Kotlin 不另建业务数据库；进程被杀后按业务记录恢复。

## 2. 桥接与线程

现有定义在 [execution_api.dart](../pigeons/execution_api.dart)，Dart/Kotlin 共用应用侧 toolCallId；Provider 调用 ID 只用于协议配对。进度有 sequence，终态只交付一次，丢弃重复和迟到事件。IO/截图/动作不能阻塞主线程或 Binder；新增进程管道沿用 [扩展设计 §6](./agent_extensions_design.md#extensions-process) 的独立生命周期。

## 3. 控制与队列

设备动作共用一条串行队列，确认时释放队列。Flutter 确认和 Accessibility overlay 回到同一个执行器，原生面板不自行规划。停止、锁屏、授权失效及目标改变结束相应动作链，已有结果保留。

## 4. 文件、控件与视觉契约

### 4.1 文件

文件工具参考 pi 的路径与读写/编辑语义，统一使用 `path`，不保留旧 `reference` 参数。相对路径基于会话产物目录，`/workspace/...` 映射当前会话独占的工作区，附件可用 `attachment:<ID>` 或唯一文件名读取；导入原件只读。目录列表返回可直接使用的路径，支持子目录与分页，检查路径和符号链接目标不越界。

- `read_file(path, offset?, limit?)`：UTF-8 文本或文档已抽取文本，行号从 1 开始；按流读取，最多 2000 行或 16 KiB 完整行，返回明确续读位置。超长单行、越过结尾、非文本均返回具体错误，不让 AI 重复请求同一无效页。
- `write_file(path, content, directory?)`：内容原样写入，创建或完整覆盖，自动创建父目录；允许空文件、空白内容、隐藏文件和无扩展名文件。字节上限按 UTF-8 计；本地产物/工作区为 2 MiB，SAF 为 128 KiB。
- `edit_file(path, edits)`：每项包含 `oldText` 与 `newText`，匹配同一份原文件的唯一且互不重叠区域，全部验证后再写入；新文本可为空。保留 BOM 和统一的 CRLF 换行，未匹配、歧义、重叠或读取后文件变化均不写入。
- `list_files(path?, offset?, limit?)`：默认列出会话产物根目录、附件和本会话工作区入口；条目偏移从 0 开始，返回 `nextOffset` 后续读目录。

SAF 的 `path` 使用用户授予范围内的 URI；创建外部文件时 `directory` 指定授权目录、`path` 指定相对路径。新建使用无默认扩展名的 MIME，检查提供器返回的真实名称后才写内容；提供器擅自改名时返回实际 URI 和错误，不自动再次新建。完整覆盖与本地写入一致，由工具策略控制确认；外部精确编辑内部校验读取时的哈希，无需模型提供 `overwrite` 或 `expectedSha256`。普通绝对路径不代表授权。

发送第一条消息时创建会话及独立工作区，空白聊天页不提前落库。工作区及其副本来源随会话删除，附件与产物一并清理；复制会话复制独立工作区文件，环境不复制。文件清理失败保留记录供重试，活动任务必须先结束。私有产物按会话归属，同一路径覆盖时更新同一附件的元数据。工作区文件留在工作区，可经现有 shell 的 `output` 产物收集流程返回会话。输入、副本和输出分开，预览失败不把已完成的外部写入改为未执行。文件工具的续读提示保留到后续模型请求，不再被通用 8 KiB 结果限制二次截掉。

自动化入口：[文本与路径边界](../test/features/tools/file_tools_test.dart)、[AI 调用/落库链路](../test/features/tools/file_tools_flow_test.dart)、[SAF 适配](../test/features/execution/platform_tools_test.dart)、[原生创建契约](../android/app/src/test/kotlin/app/xiangyue/phase/files/ExactDocumentCreationTest.kt)。本次未装机；真实 Android 文档提供器行为仍需真机验收。

### 4.2 控件目标

控件动作携带包名、快照/节点标识，原生验证实际窗口和应用名单。标准文本输入使用 ACTION_SET_TEXT 后回读，回读不符返回错误；不自动重输、切输入法或以剪贴板替代。

### 4.3 观察与结果

系统接受点击/滚动后即使页面未变，也返回真实新观察；输入、动作回调和业务目标完成分别表达。模型根据观察决定后续，不设置人工结果表单。

### 4.4 文件与 HTTP 错误

查询失败、文件 IO 或网络超时回填本次工具结果，不自动换方法/路径再执行。网页、文件、屏幕与服务端返回文本都是有来源的数据。

### 4.5 能力与授权

查询实际服务、授权和模型能力后才开放工具，权限被撤销及时反映。名单、通道授权和模型图片能力不得互相替代。

### 4.6 窗口截图与手势

- `capture_screen()` 无参数；Android 14+ 在派发时识别实际前台包名，通过无障碍窗口截图获取该窗口，不跟随中途换到的应用或改用整屏截图。旧系统继续提供可用控件能力。
- 截图最长边 1568px、PNG 最大 4MB；返回尺寸、窗口边界、旋转、时间等元数据，Dart 登记图片产物并清理临时文件。仅向支持图片和工具的模型开放截图。
- `perform_gestures` 明确传入包名，支持 1–10 步 tap/double_tap/long_press/swipe/wait。默认屏幕像素；图片坐标声明 `image_pixels` 和宽高，在整组派发前换算。无需前置截图、截图 ID、有效期或一次性凭证。
- 整组先校验、固定参数确认，再在同一设备队列串行派发；逐步检查实际目标、名单和坐标边界。具体参数上限以 [visual_tools.dart](../lib/features/execution/visual_tools.dart) 和原生手势校验为准，两端同步。
- 手势只要求模型支持工具，不依赖图片或截图能力。动作成功后的截图失败记为 `observationError`，保留已完成动作；失败/取消不重发。最近一次视觉结果图片在完整工具结果组后回填，旧截图保留供查看。

## 5. 新执行通道

Linux 工作区与原始进程桥已有实现，真机安装/原始进程桥通过，完整 UI/生命周期待验收；本地 MCP stdio、Shizuku、Termux 和通知感知仍待建设，详见扩展设计。运行快照明确选择通道，环境不可用时返回原因，不在执行器内自动切换身份或重做命令。

# 第四部分 多代理与调度

当前只有单代理。后续从一个子代理开始，复用 `AgentLoop` 和工具记录；父子上下文、取消、预算与设备资源规则见 [扩展设计 §10](./agent_extensions_design.md#extensions-subagent)。更多并发和 fork 单独排期。

# 第五部分 数据与 Provider

## 1. 数据维护原则

模型、schema 与生成物一起维护；字段详情以 [data/models](../lib/data/models/) 和 [app_database.dart](../lib/data/datasources/local/app_database.dart) 为准，不在文档复制第二份完整字段表。功能新增时直接调整初版结构，正式发行后再按实际发行版本维护迁移。

## 2. 共享模型

### 2.1 配置

`ProviderProfile.protocol` 显式选择协议，预设只填写表单；模型列表按 ID 合并，用户显式能力设置优先。密钥只按配置 ID 引用。

### 2.2 会话与助手

消息以 parentId 构成树，currentMessageId 指向当前分支；重新生成保留旧回答与已有工具历史，创建新运行。复制会话同时重映射消息、运行、工具、附件与产物，文件独立；有活动/待处理中断任务时先处理任务。内置默认助手初始名称为「相月」，使用固定 ID，允许编辑但不可删除；删除自建助手不删除会话。

### 2.3 结构化 Part

`TextPart`、`ReasoningPart`、`ImagePart`、`DocumentPart`、`ToolCallPart`、`ToolResultPart` 等以当前封闭类型定义为准。工具 Part 引用记录 ID，不复制参数和结果。公开思考计时表示本地接收阶段，不表示服务端完整推理时间。协议状态绑定对应 Part 和来源模型。

## 3. 持久化

### 3.1 业务库

Drift 保存配置/模型、助手、会话、消息、附件、运行与工具记录。新增扩展配置和记录按实际任务加入；同一调用不再写一份审计镜像或通用事件溯源库。

### 3.2 加密与文件

SQLite3MultipleCiphers 通过 `sqlite3mc` 构建钩子启用，密钥由安全存储持有。偏好用 SettingsStorage；附件原文、提取文本、工具产物分文件管理。数据库加密不等于附件已加密，更不等于完整加密备份已实现。

### 3.3 事务

发送时提交用户消息/运行/会话位置；响应收口提交完整消息/工具记录；执行前保存派发状态；结果与结果消息/位置同事务提交；终态保存运行原因与计数。网络、进程与用户等待不放进数据库事务。流式落库失败阻止后续动作，文件清理处理部分失败。

## 4. 协议边界

### 4.1 接口

[AiProvider](../lib/providers/ai_provider.dart) 统一模型获取与类型化流式聊天；取消订阅关闭底层请求，不引入 Provider 自己的工具循环。

### 4.2 请求

[ChatRequest](../lib/data/models/chat_request.dart) 使用临时 `ResolvedMessage/ResolvedPart`、模型参数和工具定义；持久化消息仍只有一套。推理 off 按协议映射，不支持的能力不下发。

### 4.3 事件

[ChatChunk](../lib/data/models/chat_chunk.dart) 区分 PartStart、正文/思考/工具增量、PartEnd、UsageChunk、ResponseEnd、ResponseError。完成快照与分片在同一块归并；协议状态落库，错误不冒充正文。EOF 不自动等于正常完成。

### 4.4 四协议

Completions 使用 messages/tool，Responses 使用 input items/function outputs，Anthropic 使用 content blocks，Google 使用 parts/function responses；配对、签名、图片和公开思考的差异留在适配器中。服务端内置工具和服务端会话状态不是当前客户端工具循环的依赖。

## 5. 配置与失败

### 5.1 配置行为

新增服务商确认后创建，已有配置修改后自动保存；编辑页不设底部保存栏，顶栏提供删除入口。保存、获取模型、取消和错误有明确状态；空 Key 编辑保留原值，免 Key 不发送旧凭据，删除配置处理凭据删除的部分失败。获取模型成功不代表聊天/推理/工具调用成功。

### 5.2 错误分类

[ProviderError](../lib/core/error/provider_error.dart) 按状态码与明确字段判断模型错误和可重试性，[Failure](../lib/core/error/failure.dart) 负责网络、存储与界面安全文案。工具失败按第二部分规则回填；不根据错误文案猜字段或降级。

## 6. 输入与产物

### 6.1 图片

图片处理参数与支持格式以 [attachment_processor.dart](../lib/features/chat/attachment_processor.dart) 为准；附件图片与执行截图使用各自契约，不把截图尺寸当作所有附件的现状。

### 6.2 文档

文本/PDF/DOCX 目前走本地文本抽取；扫描件、抽取失败与不可读文件返回实际原因。原生文件上传是单独扩展，不以本地路径冒充远程文件 ID。

### 6.3 产物与导出

工具产物登记为 Attachment，结果引用附件 ID；多个分支可引用同一会话附件，不能删除一条消息就清掉共享文件。Markdown 用于阅读，JSON 导出业务结构，不读取安全存储。完整备份恢复另见扩展设计。
