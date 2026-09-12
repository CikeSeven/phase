# 相月（Phase）产品与技术设计

版本：初版 v1.0｜日期：2026-09-12｜平台：Android

## 项目阶段

相月处于从零建设阶段，尚未发布、暂无用户。现有代码是起步原型，可以按本设计直接调整或替换；接口、消息模型和数据库按目标能力一次设计，不建立面向开发期旧实现的转换层、双写方案或迁移链。

本文描述要建设的产品，而不是现有功能清单。开发顺序见 [初版实施计划](./implementation_plan.md)，工程约定见 [AGENTS.md](../AGENTS.md)，视觉与交互见 [DESIGN.md](../DESIGN.md)。

## 总体决策

| 事项 | 设计 |
|---|---|
| 产品身份 | 产品名「相月」，工程名 `phase`，应用 ID `app.xiangyue.phase` |
| 产品方向 | Android 多模型聊天与设备执行 Agent，用户自带模型服务 |
| 技术栈 | Flutter/Dart 负责 UI、业务状态、模型网络与 Agent Loop；Kotlin 负责 Android 系统能力 |
| 业务基础设施 | Riverpod、go_router、Dio、Drift；偏好与密钥由专用存储封装管理 |
| 消息 | 从首版使用结构化 Part，不以纯 content 字符串承载全部信息 |
| 模型协议 | Completions、Responses、Anthropic Messages、Google Generative AI 各自实现，向上使用统一契约 |
| 执行方式 | 一条 ReAct 循环，首版串行执行工具；模型提出动作，客户端决定是否执行 |
| 数据 | 首版统一 schema；消息保存内容，运行表保存进度，工具记录保存调用与结果 |
| 运行恢复 | 读取已保存的运行与工具状态，不建设通用事件溯源或日志回放系统 |
| 权限 | 通道授权、工具策略、动作确认分开；允许、询问、禁止三档 |
| 发布范围 | P0 为首版；P1 扩展系统通道与 Agent 能力；P2 为生态与研究 |

## 阅读导航

| 部分 | 回答的问题 |
|---|---|
| 第一部分：产品设计 | 做什么、首版包含什么、用户如何使用 |
| 第二部分：聊天与 Agent Loop | 一次请求怎样变成回答和工具执行 |
| 第三部分：Android 执行通道 | Dart 如何调用无障碍、Shizuku、Termux 与感知能力 |
| 第四部分：多代理与调度 | 后续如何委派任务、共享设备和停止子任务 |
| 第五部分：数据与 Provider | 正式模型、数据库、协议事件和输入处理如何实现 |

# 第一部分 产品设计

## 1. 产品定位

相月是 Android 端的多模型聊天与执行应用：既能进行日常对话，也能在用户授予的范围内读取文件、查询信息和操作设备。

核心价值不是把所有权限堆在一起，而是把“提出需求 → 获取必要信息 → 确认动作 → 执行 → 展示结果”做成连贯体验。普通聊天不需要开启设备权限；执行功能在任务需要时引导授权。

产品仅面向 Android。首版不做端侧模型推理，也不以 iOS、桌面端或远程服务器为设计前提。

## 2. 用户与参照产品

### 2.1 目标用户

| 用户 | 主要需求 | 产品重点 |
|---|---|---|
| 日常聊天用户 | 使用自己的服务商和模型，长时间阅读和整理对话 | 配置简单、流式阅读、多会话、附件与助手 |
| 效率用户 | 用一句话完成文件处理、信息查询和跨 App 操作 | 按需授权、可见进度、动作确认和明确结果 |
| 进阶用户 | 使用系统命令、脚本、MCP 和任务委派 | Shizuku/Termux 通道、工具配置、执行记录 |

### 2.2 竞品参照

- **RikkaHub**：参考聊天阅读、助手和模型配置体验。
- **Kelivo**：参考 Flutter 聊天客户端的功能组织和服务商接入。
- **Operit**：参考 Android 执行通道、权限引导和工具管理。

竞品用于比较具体流程，不以 star 数、功能数量或技术栈相同证明产品价值。相月先验证用户是否愿意在聊天中使用设备执行，以及执行结果是否可靠、易理解。

## 3. 首版范围

### 3.1 P0：首版产品

| 能力 | 首版内容 |
|---|---|
| 服务商与模型 | 四种协议、自定义端点、Key/免 Key、模型获取和手动管理、能力与参数设置 |
| 多会话聊天 | 创建、搜索、重命名、置顶、删除；流式正文与公开思考；停止、复制和重新生成 |
| 消息展示 | Markdown、代码、图片、文档、工具调用及执行结果 |
| 助手 | 创建/编辑/删除，系统提示词、默认模型和工具范围；内置一个普通助手 |
| 附件 | 图片、文本、PDF/DOCX 本地文本抽取；扫描件 OCR 不进入首版 |
| Agent Loop | 单代理 ReAct、结构化工具调用、结果回填、轮次限制 |
| 应用级工具 | 时间/系统信息查询、HTTP 查询、用户选定文件的读写 |
| UI 执行 | 无障碍控件树、元素定位、点击/滚动/输入、任务控制面板及结果观察 |
| 任务控制 | 工具三档策略、执行确认、停止、已知结果保存与中断后的状态展示 |
| 记录与导出 | 会话与工具执行记录；会话 Markdown/JSON 导出，不包含密钥 |
| 外观 | 浅色/深色/跟随系统，遵循相月视觉规范 |

首版验收用两条任务闭环：

1. 读取用户选择的文档，生成摘要，经确认后保存成新文件。
2. 在选定目标 App 中搜索一个条目并打开详情，展示执行过程与最终观察结果。

第二条先使用固定的测试 App 和页面建立可重复用例，再验证实际目标应用。产品不以“适用于任意 App”作为首版承诺。

### 3.2 P1：执行与 Agent 扩展

- Shizuku 系统操作与 Termux 脚本执行，包含各自的授权和环境引导。
- MCP、Skills、plan mode、上下文摘要和长期记忆。
- 消息分支切换、完整加密备份/恢复、原生文档上传。
- 截屏、通知与前台应用感知增强。
- 单子代理委派、按任务分配模型与多 Key 管理。

### 3.3 P2：生态与研究

Root、更多子代理并发、fork 上下文、Code Mode、定时/事件触发、模板市场、角色卡和远程访问分别立项。它们不成为首版数据访问和单代理循环的依赖。

## 4. 产品原则

1. **聊天和执行使用同一会话入口**：纯聊天没有设备授权前置，工具能力按助手和模型配置开放。
2. **模型不拥有执行权限**：模型返回 tool call，应用根据工具范围与用户决定执行。
3. **结果可见**：等待确认、执行中、完成、失败、已取消和结果未确认是不同状态。
4. **用户可以停止**：停止结束后续模型调用与工具调度，已经产生的内容和外部效果如实保留。
5. **一套明确实现**：不猜协议、不为未见过的格式添加分支，不通过静默换模型或修改参数掩盖错误。
6. **按能力扩展**：先完成单代理与首版通道，再引入真实需要的多代理和生态能力。

## 5. 权限与动作确认

### 5.1 通道授权

| 级别 | 来源 | 能力 | 阶段 |
|---|---|---|---|
| L1 应用级 | 应用私有目录、SAF、普通运行时权限 | 文件、网络和基本设备信息；Termux 另有自身授权 | P0；Termux 为 P1 |
| L2 无障碍 | AccessibilityService 用户授权 | 界面元素读取、手势、输入 | P0 |
| L3 Shizuku | Shizuku 已安装、运行并授权 | shell 身份下的系统能力 | P1 |
| L4 Root | 用户主动提供 Root 环境 | 更高权限系统操作 | P2 研究 |

级别说明权限来源，不表示所有能力都逐级包含。无障碍、Shizuku 和 Termux 不能仅因工具名相同就互换。

### 5.2 工具策略

工具按文件、网络、系统信息、UI 操作、终端等分组。组策略可覆盖到具体工具。

| 策略 | 行为 |
|---|---|
| allow | 在已授予的数据/目标范围内直接执行 |
| ask | 展示本次动作，用户批准后执行 |
| deny | 不向模型开放，收到调用也不执行 |

默认对低风险本地查询使用 allow；文件写入、UI 操作和对外发送使用 ask；未开放的能力为 deny。第三方工具安装后先使用 ask。

只读工具仍可能接触私有内容。读取文件或屏幕与把内容发给模型是两个步骤，授权说明应明确所用模型端点及发送的数据类型。

### 5.3 确认流程

确认页显示：工具、目标、实际参数/内容、执行通道和主要影响。用户可允许一次、拒绝或停止任务。首版不做整会话的泛化自动批准。

确认对应固定的 runId、toolCallId、参数和目标，默认等待 60 秒；超时按拒绝处理。重新进入应用不重新计时。目标或参数改变后需生成新的确认。

支付、密码和验证码由用户手动处理。检测到这些场景或无法确定操作目标时暂停任务，不继续猜坐标。权限和确认由代码执行，提示词只负责向模型解释规则。

## 6. 页面与交互

### 6.1 页面结构

| 页面/区域 | 内容 |
|---|---|
| 聊天页 | 助手/模型入口、消息列表、附件草稿、发送/停止 |
| 会话侧栏 | 新会话、搜索、会话列表、设置 |
| 助手页 | 助手列表、系统提示词、默认模型、工具范围 |
| 服务商页 | 名称、协议、端点、凭据、模型和参数 |
| 工具设置 | 分组策略、单工具策略、权限状态 |
| 执行记录 | 按会话/任务展示工具、决定、结果及时间 |
| 权限引导 | 当前任务需要的授权项和前往设置入口 |
| 设置页 | 外观、导出、记录管理和应用信息 |

视觉 token、页面转场、Android 预测返回和布局规则使用 DESIGN。新增功能替换开发中占位，不把占位页当作产品范围限制。

### 6.2 聊天与思考

- 正文、公开思考、附件和工具卡片按 Part 顺序展示。
- 思考只显示接口实际公开的文字/摘要，签名与加密状态不显示为思考。
- 流式时接近底部才跟随滚动；用户回看历史时保持阅读位置。
- 重新生成创建新的回答/运行，不修改已结束回答的内容；有工具执行历史时不自动重做旧动作。
- 模型与推理设置允许修改，新的选择作用于下一次运行。一次运行内部使用开始时的配置。

### 6.3 工具卡片

| 状态 | 展示与操作 |
|---|---|
| 参数生成中 | 工具名称与准备状态，不显示可批准按钮 |
| 等待确认 | 动作摘要、确认/拒绝/停止 |
| 执行中 | 当前动作、可用进度和停止入口 |
| 已完成 | 结果摘要、产物/详情 |
| 已失败 | 原因和已知影响；是否新建一次尝试由用户决定 |
| 已取消 | 取消阶段及已保存的结果 |
| 结果未确认 | 最后已知动作，重新观察或人工确认入口 |

手机屏幕变化和执行状态属于业务反馈，不以堆叠日志代替。错误文案不展示原始异常、鉴权信息或用户输入的完整副本。

## 7. 首版质量要求

- 所有 P0 流程有明确的打开、取消、提交和完成状态。
- 结构化工具参数完整后才执行；一轮多个调用按顺序处理。
- 停止应传到底层请求和工具执行器，不只是隐藏生成动画。
- 已完成动作不因重启或显示失败被再次执行。
- 320/360dp、横屏、大字号、键盘及浅深主题按 DESIGN 验收。
- UI 与滚动性能用 Android Profile 测量，记录设备和 UI/raster 帧数据。
- 密钥只进入安全存储和必要的运行期鉴权，不进入业务 JSON、诊断或导出。

## 8. 发行

首版以 GitHub Releases 分发。正式签名、合并 Manifest 的网络/备份配置和安装启动是发布检查项；Profile 包不作为正式发行包。

F-Droid 接入与 Play 版本独立评估。不同分发渠道不改变应用内的授权和数据规则；商店政策按发布时要求检查，不以“用户手动触发”代替政策判断。

# 第二部分 聊天与 Agent Loop

## 1. 组件职责

```text
ChatPage / AssistantPage
          ↓ 指令
Riverpod Notifier
          ↓
LoopEngine ── PromptAssembler / ContextBuilder
     │
     ├── AiProvider ── Dio ── 模型端点
     ├── ToolRegistry ── ToolExecutor ── ChannelDriver
     └── ConversationRepository / RunRepository
                                  ↓
                                Drift
```

| 组件 | 职责 |
|---|---|
| 页面 | 输入与渲染，不直接访问 Dio、Drift 或平台插件 |
| Notifier | 会话/助手选择、运行状态和用户指令编排 |
| LoopEngine | 模型调用、工具调度、结果回填和结束判断 |
| PromptAssembler | 应用规则、助手提示词、工具定义与运行上下文装配 |
| ContextBuilder | 选取当前分支消息，控制上下文体积 |
| ToolRegistry | 工具定义、执行实现、所需能力和策略 |
| ToolExecutor | 参数校验、确认、实际执行和结果记录 |
| Repository | 消息、运行、工具与设置的数据访问 |

“一个 LoopEngine”表示一份循环实现，每次运行有独立状态。聊天时无工具调用也走这条循环，不建设另一套 Agent 聊天网络入口。

## 2. 运行对象

一次用户发送创建一个 `AgentRun`，记录：

- runId、conversationId、assistantId、输入消息与当前消息位置。
- providerProfileId、modelId、系统提示词、推理/输出参数及工具集合。
- 状态、轮次、模型尝试数、用量、开始/结束时间。
- 当前等待确认或执行的 toolCallId。

普通聊天、工具任务和后续子代理都使用这一对象。首版同一时间运行一个根任务；切换会话只改变查看位置，运行控制入口仍可到达。

## 3. 一次请求的生命周期

1. 用户提交文本/附件，创建用户消息和 AgentRun。
2. 创建助手消息，进入流式状态。
3. 装配助手提示词、消息上下文、模型参数和本次可用工具。
4. AiProvider 发起请求，Text/Reasoning 增量更新对应 Part。
5. 收集结构化工具调用，收到完整块后解析参数。
6. 没有工具调用时完成回答；有工具调用时依次进入 ToolExecutor。
7. ToolExecutor 根据策略直接执行、等待确认或拒绝，将结果写为工具记录与工具消息。
8. 把工具结果加入上下文，发起下一轮模型请求。
9. 无工具调用、用户停止、达到轮次限制或发生不能继续的错误时结束。

Dart 风格伪代码：

```dart
Future<void> run(AgentRun initialRun, RunCancellation cancellation) async {
  var run = initialRun;
  while (!cancellation.isCancelled && run.turnCount < run.maxTurns) {
    run = await runRepository.beginTurn(run.id);
    final request = contextBuilder.build(run);
    final response = await collectAndDisplay(
      provider.streamChat(request),
      cancellation,
    );
    if (cancellation.isCancelled) break;
    if (response.toolCalls.isEmpty) {
      await runRepository.finish(run.id, response.hasVisibleContent
          ? RunFinishReason.completed
          : RunFinishReason.emptyResponse);
      return;
    }
    for (final call in response.toolCalls) {
      if (cancellation.isCancelled) break;
      final result = await executor.execute(call, run, cancellation);
      if (cancellation.isCancelled) break;
      if (result.status == ToolStatus.unknown) {
        await runRepository.waitForResult(run.id, call.id);
        return;
      }
    }
    if (cancellation.isCancelled) break;
    run = await runRepository.finishTurn(run.id);
  }
  await runRepository.finish(run.id, cancellation.isCancelled
      ? RunFinishReason.cancelled
      : RunFinishReason.turnLimit);
}
```

beginTurn 在本轮模型调用前增加 turnCount；每次实际网络请求（包括重试）增加 modelAttemptCount。finishTurn 保存已完成工具轮的位置，不重复增加轮次。伪代码表达调用顺序；实际实现用 try/finally 释放订阅、请求和工具资源，错误通过统一类型到达 Notifier。

## 4. 流式工具调用

### 4.1 组装

适配器按响应内的块标识组织增量。一个工具调用包含稳定 callId、工具名、参数对象和协议需要回传的不透明数据。

- 参数片段只追加到当前调用缓冲，不每收到一段就重新解析全部 JSON。
- Part 完成与整个响应完成是不同事件。
- 工具参数完整、符合工具 schema，且所属模型响应正常结束后才开始执行。
- 格式错误显示模型响应错误，不尝试从普通文本/XML 中提取命令执行。
- 一轮多个调用串行执行，每个结果立即记录。

### 4.2 结果回填

内部使用统一的 ToolCall/ToolResult。Provider 负责将其变成各协议要求的工具消息格式；Loop 不判断某家协议把结果放在 user、tool 还是 functionResponse 中。

结果包含已知成功/失败、正文或产物引用、是否截断和必要的错误代码。拒绝是本次调用的结果，不是网络异常。结果未确认时暂停整个任务，不把它作为普通失败让模型再次执行。

## 5. 工具执行状态

```text
prepared
  ├── allow ───────────────────────→ executing
  ├── ask → awaitingConfirmation
  │           ├── approve ─────────→ executing
  │           ├── reject / timeout → rejected
  │           └── stop ────────────→ cancelled
  ├── deny ────────────────────────→ rejected
  └── stop ────────────────────────→ cancelled

executing → succeeded / failed / cancelled / unknown
```

| 状态 | 含义 |
|---|---|
| prepared | 模型调用已完整，参数已确定，尚未执行 |
| awaitingConfirmation | 等待用户决定 |
| executing | 已记录允许派发，外部动作可能正在发生 |
| succeeded | 有明确的成功结果 |
| failed | 有明确的失败结果，记录已知的部分影响 |
| rejected | 用户或工具策略拒绝 |
| cancelled | 派发前停止，或工具返回了明确的停止结果 |
| unknown | 已进入执行阶段，但没有取得可靠结果 |

执行前保存 executing，执行后保存结果。外部动作与数据库不能同时提交，因此“动作已经完成、结果尚未保存”会产生 unknown。首版只需如实展示并提供核验入口，不建设自动重放或补偿事务框架。

## 6. 确认、停止与中断

### 6.1 确认

ToolExecutor 负责确认流程；Loop 只等待结果。等待期间不调用模型、不占用设备动作队列。用户决定到达后，确认目标仍是当前目标，再执行同一份参数。

拒绝单个动作后可以继续回答或提出其他方案，但不能换工具重复被拒的同一效果。停止整个任务则结束循环，不把停止改写成“尝试其他方案”。

### 6.2 停止

RunCancellation 贯穿模型请求、工具执行和等待确认：

- 模型输出中停止：取消订阅与底层 HTTP 请求，保留已收正文/公开思考。
- 确认中停止：结束等待，本次确认不再生效。
- 工具执行中停止：立即停止后续调度，并请求工具取消；记录工具实际返回的结果。
- 迟到文本不再追加；已经停止的运行不因回调重新开始。
- 停止后的下一轮请求带上这一轮已产出的正文、已执行的调用与结果：用户看到的和模型知道的要对得上，否则模型不知道文件已经写过、请求已经发过。半截的思考块不进入上下文，避免把模型带回被打断的思路。

不能把取消请求本身当作外部动作已撤销。无法确定结果的在途动作使用 unknown。

### 6.3 重新打开应用

启动时读取未结束的 AgentRun 和 ToolCallRecord：

- 已保存结果只恢复显示和上下文，不重新执行。
- 未开始的动作由用户选择是否继续。
- 未决确认按原期限显示或结束。
- executing 且没有结果的调用显示“结果未确认”，先观察实际状态。

运行表直接保存继续所需的位置、参数和计数，不从诊断日志反推，不实现任意历史检查点回放。

## 7. 结束与错误

| 情况 | 行为 |
|---|---|
| 正常回答完成 | 标记 completed，记录用量 |
| 没有任何有效内容 | 运行标记 failed，结束原因 emptyResponse；显示可重新发送入口 |
| 用户停止 | 运行标记 stopped，结束原因 cancelled；保留已收内容和结果 |
| 轮次上限 | 默认 30 轮，展示已有结果与未完成状态 |
| 模型/网络错误 | 显示安全错误文案；收到部分输出后不自动重新拼一遍回复 |
| 工具已知失败 | 回填失败结果，按任务和用户许可决定后续步骤 |
| 工具结果未知 | 挂起并提供核验入口 |
| 存储失败 | 停止发起新动作并提示，不能显示“保存成功” |

首版对尚未产生输出的临时模型请求错误最多重试两次，计入运行预算；错误类型来自协议状态码/明确错误字段。没有普通工具自动重试器，也不通过修改输出上限、推理参数或切换协议消化错误。

## 8. 提示词与上下文

### 8.1 提示词装配

顺序为应用规则、助手系统提示词、工具描述、会话消息与当前观察。用户提供的文档、网页、屏幕和工具结果保持数据来源，不因出现某种标签变成应用指令。

设备状态按实际需要加入：当前 App、窗口、选定文件或工具结果。不每轮重复注入整套环境清单，不把 API Key 放入上下文。

### 8.2 首版上下文管理

首版使用可解释的长度管理：

1. 保留当前任务、助手提示词和最近完整交互轮次。
2. 大工具输出按工具定义的上限截断，附产物引用和截断标记。
3. 工具调用与结果成组保留，不留下孤立结果；调用存在而结果缺失（运行中断）时为它补一条如实的错误结果。
4. 请求超过模型上下文容量时提示新会话或减少附件，不临时改用其他模型。
5. 被停止或出错收场的轮次按第 3 条保留已产出的正文与已执行的调用、结果，半截的思考块不进入上下文（见 6.2）。
6. 跨模型时协议状态（思考签名、加密推理）不回传：它只对生成它的模型有效；有内容的思考降级为普通正文（Responses、Anthropic），Completions 不回传思考字段。

文件原文和历史消息仍保存在业务库；请求上下文裁剪不等于删除会话数据。模型用量以 API usage 为准，没有 usage 时可以显示估算标识。

P1 再增加摘要、长期记忆与工具检索。缓存命中率是成本观测值，不作为首版架构正确性的前提，也不为缓存冻结用户配置。

## 9. 工具、MCP 与 Skills

### 9.1 内置工具定义

```text
ToolDefinition
  name / description / inputSchema
  requiredCapabilities
  defaultPolicy
  describeAction(args)
  execute(args, cancellation)
```

每个工具实现自己的参数 schema 和执行逻辑。ToolRegistry 以名称注册；ToolExecutor 处理通用的确认、状态、取消和记录。

首版使用固定工具集，不实现动态 RAG-over-tools、模型生成代码执行器或任意插件脚本宿主。

### 9.2 MCP（P1）

MCP 工具进入同一注册表、执行器和确认流程。首条传输实现采用远程 Streamable HTTP；本地 stdio 随 Termux 接入。工具名称包含服务器命名空间，避免同名冲突。

服务器返回的描述/annotations 是工具资料，不是授权。新增服务器和工具范围由用户配置；工具定义发生变化时重新展示对应能力。

### 9.3 Skills（P1）

Skill 是任务指导与资源集合，不是另一套执行权限：

1. 常驻名称与简短描述。
2. 命中任务后读取 SKILL.md 指导。
3. 使用具体资源或脚本时，再通过已注册工具执行。

Skill 不能自授权限或覆盖应用规则。文件格式使用明确的 frontmatter 与目录结构，首版解析器只支持所定义字段，不为未采用的客户端格式增加转换逻辑。

## 10. Plan Mode（P1）

Plan Mode 是同一 Loop 的工具权限模式：仅开放调查/只读工具，输出计划后等待用户批准，再进入执行。计划批准不代替后续具体写操作的必要确认。

不另建 Plan-and-Execute 引擎。只有出现明确的长任务调度需求后，再扩展任务图、重排或并行步骤。

# 第三部分 Android 执行通道

## 1. 分层与运行位置

```text
Dart ToolExecutor
       ↓ ChannelDriver
Pigeon HostApi / FlutterApi
       ↓
Kotlin ExecutionCoordinator
       ├── AccessibilityDriver
       ├── AppFileDriver
       ├── ShizukuDriver       P1
       ├── TermuxDriver        P1
       └── PerceptionDriver    P1
```

Dart 负责任务含义、工具策略和模型循环；Kotlin 负责系统 API、线程、服务与实际动作。平台桥接使用类型化 Pigeon 定义，生成文件随定义一起维护。

应用级纯 Dart 工具不绕行 Kotlin。只有 SAF URI、无障碍、系统服务等需要平台能力的路径进入桥接。

## 2. 引擎与执行服务

UI 自动化会让相月离开前台，因此 FlutterEngine 的生命周期不由聊天 Activity 单独持有。

- 应用级运行宿主持有一个缓存 FlutterEngine，Activity 负责挂接 UI。
- 设备任务执行期间由 `ExecutionService` 持有运行宿主，显示任务通知和停止入口。
- Android 前台服务按设备自动化用途配置相应类型；目标 SDK 要求的声明和启动条件在服务实现时落实。
- 无障碍服务与桥接位于应用主进程；Activity 切换不重新创建 Loop。
- 任务完成后停止执行服务；普通聊天不常驻一个设备执行服务。

前台服务用于表达正在进行的用户任务，不保证进程永远存活。主进程被系统终止后，重新启动读取运行记录，按第二部分的中断语义展示。

## 3. 桥接契约

### 3.1 请求与结果

一次工具调用在 Dart、Kotlin 和通道内使用同一个应用侧 `toolCallId`。模型协议自己的调用 ID 由 Provider 保存和映射，不作为平台任务编号。

```text
ExecutionRequest
  toolCallId
  action
  arguments
  target
  timeoutMs

ExecutionResult
  toolCallId
  status: succeeded / failed / cancelled / unknown
  result
  artifacts
  errorCode

ExecutionProgress
  toolCallId
  sequence
  kind: stage / progress / stdout / stderr
  payload
```

| 接口 | 方向 | 内容 |
|---|---|---|
| execute | Dart → Kotlin，异步结果 | 接收已确定的动作，返回唯一终态 |
| cancel | Dart → Kotlin | 取消指定 toolCallId |
| queryCapabilities | Dart → Kotlin | 查询本机通道能力与授权状态 |
| progress | Kotlin → Dart，事件流 | 执行阶段、进度和受限大小的命令输出 |
| capabilityChanged | Kotlin → Dart | 服务连接、授权和可用状态变化 |
| confirmationDecision | Kotlin → Dart | 原生任务确认面板的用户决定 |

命令结果 Future 是终态入口，事件流只传进度，不让同一终态从多个入口重复结束任务。接收顺序以 toolCallId 和 sequence 组织。

首版 Dart/Kotlin 随同一个 APK 构建，不设计独立桥接版本协商、旧协议降级或多个引擎之间的事件回放。

### 3.2 线程与资源

- 平台 handler 不执行阻塞的网络、命令、文件读写或整树处理。
- 原生任务使用后台 executor/协程；UI、系统回调和平台通道交付遵循对应 API 的线程要求。
- 每个异步调用只交付一次结果，结束后释放其任务、订阅和计时器。
- 输出流按字节量限制，进度合并发送，不逐字符跨平台调用。
- 截图、文件和大输出返回私有文件引用，不通过桥接传巨型 JSON/base64。
- 进程终止造成的结果缺失交给运行状态处理，不再建一份 Kotlin 业务数据库。

## 4. 无障碍执行器（P0）

### 4.1 服务与能力

AccessibilityService 提供四类首版工具：

| 工具 | 输入 | 结果 |
|---|---|---|
| inspect_ui | 目标 App，可选关注区域 | UiSnapshot |
| click_node | snapshotId、nodeId | 动作结果与新观察 |
| scroll | snapshotId、nodeId、方向 | 动作结果与新观察 |
| input_text | snapshotId、nodeId、文本 | 输入结果与回读状态 |

服务配置包含控件树读取、交互窗口和手势能力。只订阅窗口/内容等需要的事件，不将全部无障碍事件逐条送给模型。

### 4.2 控件树

```text
UiSnapshot
  id / capturedAt
  packageName / windowId
  screenBounds
  nodes: UiNode[]

UiNode
  id / parentId
  viewId / className
  text / description
  bounds
  clickable / editable / scrollable / enabled
```

一次观察的处理顺序：

1. 取得目标应用窗口，排除本应用的执行浮层。
2. 遍历可见节点，提取文本、语义、边界和可操作属性。
3. 合并无信息的容器，保留控件关系和动作目标。
4. 按节点数/文本量生成有大小上限的快照，标明是否截断。
5. 保存本次 nodeId 到原生节点的映射，用于紧接着的动作。

nodeId 只在该 snapshot 内有效。操作前检查目标窗口与节点；目标改变时返回 targetChanged，由 Loop 重新观察。首版不维护跨版本/跨页面的五级猜测定位链。

### 4.3 点击、滚动与输入

- 对具备标准动作的节点优先调用相应 Accessibility action。
- 需要手势时使用 dispatchGesture；坐标取已定位节点边界，不让模型凭空编造位置。
- 文本输入首先支持标准可编辑控件的 ACTION_SET_TEXT，提交后回读实际文本。
- 输入不能因为没有收到预期回读就自动重复两次。已接受但未确认的输入保留实际状态，重新观察。
- 首版不自动切换用户输入法或使用剪贴板替代输入。复杂 IME/WebView 输入作为后续独立能力。

所有屏幕坐标统一为设备像素，并附旋转/窗口信息。后续截图缩放时额外保存映射关系，不混用 Flutter dp 与原生像素。

### 4.4 结果观察

Android 接受动作不等于任务目标完成。执行器分别记录动作回调与之后的观察：

| 动作 | 主要观察 |
|---|---|
| 点击/导航 | 目标页面、窗口或相关控件是否变化 |
| 输入 | 目标字段是否包含预期文本 |
| 滚动 | 可见内容/滚动位置是否变化 |
| 搜索并打开 | 结果条目及详情页是否符合任务 |

观察使用相关窗口事件和一次新的快照；超时返回明确结果，不无限轮询。固定等待时间不作为唯一成功判据。

### 4.5 执行中的用户控制

相月在前台时使用 Flutter 确认界面。在目标 App 中执行时，无障碍服务显示任务范围内的执行条和必要确认面板，使用 Accessibility overlay，不做常驻全局悬浮球。

原生面板展示 Dart 提交的固定动作内容，将允许/拒绝/停止回传到同一待确认调用。面板关闭后重新检查目标节点再执行；它不自行规划下一步。

停止、锁屏、授权关闭、目标 App 改变或遇到需人工处理的界面时结束当前自动动作链。已经发生的结果在工具记录中展示。

## 5. 应用级文件与网络工具（P0）

### 5.1 文件

用户通过系统选择器授予文件/目录范围；内部产物位于应用私有目录。工具使用文件句柄/URI，不把任意绝对路径当作已有授权。

首版工具包括 read_file、write_file 和 list_files：

- read_file 返回文本或受控的产物引用，说明内容是否截断。
- write_file 展示文件位置、内容与新建/覆盖含义，确认后执行。
- list_files 只列出用户选定的目录。

文件结果记录实际 URI、名称、大小和必要校验信息。数据库记录和文件内容分别保存，文件写完后再提交成功结果。

### 5.2 HTTP 查询

HTTP 工具用于获取任务需要的数据，定义方法、URL、查询和正文结构。凭据不由模型以明文参数提供；需要服务凭证时由配置引用解析。

HTTP 错误正常返回工具结果，不改变用户选定的模型协议，也不自动换请求方法。网页正文作为不可信内容进入上下文。

## 6. Shizuku 通道（P1）

### 6.1 宿主与接口

ShizukuDriver 在主进程绑定 UserService。UserService 只承载系统能力，不运行 Flutter 或 Agent Loop。

按职责提供 shell、包管理、系统设置和必要的 UI 辅助接口。业务层面对 ChannelDriver，不直接调用隐藏 API 或 Binder。

P1 使用 shell 身份的能力；Root 不是另一种自动启动路径。授权状态来自 Shizuku 运行时查询。

### 6.2 命令执行

首条实现采用一次调用一个进程的 CommandRunner：传入命令、参数、工作目录和环境，返回退出码、stdout/stderr 与执行产物。

- 命令执行不占用 Binder 接收线程。
- 大输出通过 ParcelFileDescriptor/管道或私有文件传递，不逐行同步 Binder 调用。
- 超时/停止终止任务进程及其受管理子进程，记录实际结果。
- Binder 断开后可以重建连接，但不据此重新运行上一条命令。

常驻 shell、跨命令环境保留和隐藏 API 性能优化在单次命令链路完成后实现；不把它们作为第一次接入 Shizuku 的条件。

### 6.3 环境引导

依次检查安装、服务运行、应用授权和具体能力。只展示缺少的步骤，不在第一次打开应用时要求用户一次性开启全部权限。

ROM 菜单和激活流程记录为设备测试资料，不在执行代码里堆叠没有样本依据的厂商猜测分支。

## 7. Termux 通道（P1）

### 7.1 单次命令

通过 Termux RUN_COMMAND 发送可执行文件、参数、工作目录和后台标记，用 PendingIntent 接收结果。主进程负责请求与 toolCallId 的关联。

启用时检查：Termux 是否安装、RUN_COMMAND 权限、allow-external-apps 和所需脚本环境。缺少环境时给出安装/设置步骤，不暗中改走 Shizuku。

命令在 Termux 自己的 UID、目录和环境中执行，不能当成系统 shell。调用超时或 Termux 进程被终止时按实际回执处理。

### 7.2 输出与长任务

输出较大时写入双方已明确可访问的文件位置，再返回结果引用。截断只意味着返回内容不全，不能为了拿到全文重新执行有副作用的命令。

长会话在单次模式之后建设：使用独立会话 ID、经过鉴权的本地连接与带长度的帧，传输命令、stdout、stderr 和终态。取消与退出属于协议本身，不用文本哨兵猜任务是否成功。

## 8. 感知通道（P1）

| 能力 | 主路径 | 产品边界 |
|---|---|---|
| 截屏 | 已授权的无障碍截图或 MediaProjection | 附尺寸/旋转/坐标映射；内容不可读时不假定画面为空 |
| 通知 | NotificationListenerService | 按用户选择的 App 监听，不默认读全部通知 |
| 通知回复 | 通知提供的 RemoteInput 动作 | 明确收件对象和内容，经确认后发送 |
| 前台 App | 无障碍窗口信息 | 用于当前任务定位，不构建长期应用使用画像 |

FLAG_SECURE、支付/密码等受限内容不通过自动换截图路径绕过。截图和原始通知内容不写入诊断日志。

## 9. 通道调度与错误

首版使用一个设备动作队列，同一时间只执行一个会改变目标界面的动作。模型调用与普通数据处理不占设备队列；等待用户确认时释放队列位置。

ChannelError 使用有限的业务分类：permissionRequired、unavailable、targetChanged、invalidArguments、timeout、executionFailed、cancelled、resultUnknown。向用户显示实际发生的状态，不维护面向每个网关/ROM 变体的庞大错误编号和自动降级矩阵。

不同通道的替代方案由新的工具调用表达，重新说明目标与权限；不能在同一 execute 内静默换实现去重复上一动作。

# 第四部分 多代理与调度（P1）

## 1. 定位

子代理用于把独立的调查、整理或工具任务分开上下文处理。子代理复用同一个 LoopEngine，不引入另一套模型、工具或存储基础设施。

P0 只实现单代理。P1 从一个活跃子代理开始，先完成委派、结果回传与停止；更多并发和 fork 属于 P2。

## 2. 代理定义与运行

```text
AgentDefinition
  id / name / description
  systemPrompt
  modelSelection
  allowedTools
  maxTurns

AgentHandle
  runId / parentRunId
  status
  resultFuture
  progressStream
  cancellation
```

AgentRegistry 保存代理定义并创建子运行。父代理通过 SubAgentTool 指定任务与允许的输入，子运行获得独立消息上下文。

子代理工具范围不超过父任务允许范围。模型可以选择合适的代理，但不能通过委派获得父任务没有的权限。

## 3. 上下文与结果

- 默认使用 spawn：传入任务、相关输入和必要约束，不复制整段父会话。
- 子运行保留自己的完整消息与工具记录，父运行得到结论、产物和状态。
- 结果区分完成、未完成、失败、取消与待核验，不只返回一个“成功摘要”。
- 父代理等待子结果时不继续抢占同一设备任务。
- P1 不做共享可变对话、不做任意历史 fork，也不让子代理再创建子代理。

## 4. 设备资源

DeviceScheduler 为代理提供同一条设备动作队列。UI 观察—动作—结果观察作为一个任务段占用目标设备资源；确认等待不长期持有它。

命令任务按自己的进程/会话管理。若多个代理操作同一目录或同一 Termux 会话，先按任务划分专属工作区，不提前引入分布式锁、租约、fencing 或多级抢占框架。

P2 开放真正并发时，再根据资源竞争场景扩展调度器。

## 5. 取消与生命周期

父任务停止时向所有子运行传播取消。Registry 等待子任务收尾并回收句柄；已产生的内容和工具结果仍属于各自运行。

子运行没有可靠外部结果时向父返回待核验，父也停止相关执行。不能把“子代理退出/进程被杀”直接当成可重新委派的普通失败。

不因为 Future/句柄结束就认为原生命令已经被撤销。网络请求、设备动作和命令进程分别通过自己的取消入口结束。

## 6. 确认与归因

子代理与主代理使用同一确认界面，增加代理名称与父任务说明。决定仍对应同一个 toolCallId、参数和目标。

运行和工具记录保存 runId、parentRunId、agentId 和 toolCallId，用于说明谁提出了动作、谁批准、结果是什么。首轮多代理实现不引入 OTel SDK、外部追踪后端或另一份全量事件日志。

# 第五部分 数据模型与 Provider

## 1. 设计原则

首版定义一套共享模型和一个正式数据库结构，原型代码直接按此实现。业务类型不同时维护 content 版/parts 版，也不写两套序列化后互相转换。

- `ChatMessage` 保存内容顺序与会话结构。
- `ToolCallRecord` 保存工具参数、用户决定和结果。
- `AgentRun` 保存循环当前位置、模型配置和计数。
- `ProviderProfile` 与 `ModelInfo` 保存连接和模型配置，API Key 独立存放。
- 文件本体在私有文件区，数据库保存引用。

以下字段定义初版领域契约，Dart 模型、Drift 表、序列化与测试使用同一套结构。

## 2. 共享模型

### 2.1 服务商与模型

```text
ApiProtocol
  openaiCompletions
  openaiResponses
  anthropicMessages
  googleGenerativeAi

ProviderProfile
  id / name / protocol / baseUrl / requiresKey

ModelInfo
  profileId / id / displayName / enabled
  supportsReasoning / supportsTools / supportsImages
  contextWindow / maxOutputTokens

ModelSelection
  profileId / modelId
  reasoningEffort / temperature / maxOutputTokens
```

协议由 profile 明确选择，预设只填写创建表单，不在运行期按域名或模型名切换协议。模型 ID 在服务商内唯一，展示名称与请求 ID 分开。

能力通过模型配置明示，用户可以编辑。模型列表用于发现可选模型；添加的模型按 ID 合并，手动能力设置优先，只有启用的模型进入聊天选择列表。没有有效模型选择时先完成配置，不静默选择一个猜测型号。

### 2.2 助手与会话

```text
Assistant
  id / name / systemPrompt
  defaultModelSelection?
  enabledTools / toolPolicies

Conversation
  id / title / assistantId
  currentMessageId
  modelSelectionOverride
  pinned / createdAt / updatedAt
```

会话采用父指针消息树，`currentMessageId` 指向当前分支末尾。P0 展示当前分支和重新生成；P1 增加完整分支导航。

模型与推理等级的选择优先级为会话显式覆盖、助手默认、最近使用、服务商默认。模型面板仅在确认后写入 `modelSelectionOverride`，取消不改变选择，也不修改助手默认值；新会话的显式选择先保存在草稿中，首次发送时与会话一起创建。重新打开或复制会话保留其显式覆盖。

重新生成新建分支与 AgentRun，不覆盖历史内容。删除助手不删除已有会话，之后可为会话重新选择助手。

### 2.3 消息与内容 Part

```text
ChatRole = user / assistant / system / tool
MessageStatus = streaming / completed / failed / cancelled

ChatMessage
  id / conversationId / parentId / runId
  role / status
  parts: ContentPart[]
  modelLabel / usage / thinkingDurationMs
  createdAt

ContentPart =
  TextPart       { text }
  ReasoningPart  { publicText, providerData }
  ImagePart      { attachmentId }
  DocumentPart   { attachmentId }
  ToolCallPart   { toolCallId }
  ToolResultPart { toolCallId }
  ProviderPart   { protocol, modelId, data }
```

TextPart 与 ReasoningPart 分别用于正文和实际公开思考。ProviderPart/各块的 providerData 保存协议要求的不透明状态，不显示为思考。

工具 Part 只引用 ToolCallRecord，参数和结果不再复制进另一份消息 JSON。Provider 构建请求时解析这些引用，得到完整的 tool call/result。

Part 使用封闭类型集合，适配器只产生已定义的内容块；未实现的协议内容类型报告明确错误。

### 2.4 工具记录

```text
ToolCallRecord
  id / runId / assistantMessageId / resultMessageId
  providerCallId
  toolName / arguments / providerData
  target / channel
  status
  approvalMode / decision
  confirmationRequestedAt / confirmationExpiresAt / decidedAt
  result / artifacts / errorCode
  createdAt / startedAt / finishedAt
```

`id` 由应用生成并传到执行通道；`providerCallId` 用于模型协议回填。工具参数完整后创建正式记录，执行期间不再修改参数；新尝试使用新记录。

结果记录和 role=tool 的结果消息在同一事务提交。页面工具卡片从同一工具记录取得状态，不维护另一份可变业务副本。

### 2.5 运行与用量

```text
RunStatus
  running / awaitingConfirmation / awaitingResult
  completed / stopped / failed

RunFinishReason
  completed / cancelled / turnLimit
  modelError / emptyResponse / storageError

AgentRun
  id / conversationId / assistantId
  inputMessageId / currentMessageId / activeToolCallId
  configuration: RunConfiguration
  status / finishReason
  turnCount / modelAttemptCount / maxTurns
  usage / createdAt / finishedAt

RunConfiguration
  connection: { profileId, protocol, baseUrl, requiresKey }
  modelSelection / systemPrompt / enabledTools / toolPolicies

TokenUsage
  inputTokens / outputTokens / reasoningTokens / cachedInputTokens
  estimated
```

运行配置在创建时确定，包含当次使用的连接信息；后续编辑服务商、助手或模型用于新运行。调用时按 profile ID 读取必要的 Key，RunConfiguration 不保存密钥。

用量字段允许接口没有提供，不将缺失值显示成真实的零。估算数据单独标识。

### 2.6 附件

```text
Attachment
  id / conversationId
  kind: image / text / pdf / docx / artifact
  name / mimeType / size
  localPath / sha256
  extractedTextPath
  width / height
```

附件可以被同一会话的多个分支引用，因此不使用“删除一条消息就删除文件”的关系。复制会话时为附件生成新 ID，独立复制原文件和提取文本，并同步替换所有分支消息里的附件引用，不跨会话共用文件路径。会话删除时清理其附件、提取文本和执行产物；复制失败时清理新文件并回滚副本记录。

## 3. 数据库

### 3.1 首版 schema

使用 Drift，正式 schema 从 1 开始。首版直接创建以下表，不建立开发期旧表到新表的迁移工作包。

| 表 | 主要列与约束 |
|---|---|
| provider_profiles | id 主键，name、protocol、base_url、requires_key、preset_id、default_model、compat_json、created_at |
| models | profile_id + model_id 复合主键，display_name、enabled、能力、上下文/输出上限；profile 删除时级联 |
| assistants | id 主键，name、system_prompt、default_selection_json、tool_policy_json（工具名 → allow/ask/deny 的 JSON 对象） |
| conversations | id 主键，assistant_id 可空，title、current_message_id、selection_json、pinned、created_at、updated_at |
| messages | id 主键，conversation_id、parent_id、run_id、role、status、parts_json、model_label、usage_json、thinking_duration_ms、created_at |
| attachments | id 主键，conversation_id、kind、name、mime_type、local_path、size、sha256、提取文本/图像元数据 |
| agent_runs | id 主键，conversation_id、输入/当前消息位置、active_tool_call_id、configuration_json、状态/原因/计数/用量/时间 |
| tool_calls | id 主键，run_id、助手/结果消息引用、provider_call_id、参数/目标/协议数据、通道、状态、确认、结果/产物/时间 |

`messages.parent_id` 是消息树的父指针（首条消息为空），`run_id` 指回产生该消息的运行；
两者都按外键之外的显式关联维护，查询各自建索引。conversations、attachments 与 agent_runs
删除时级联清理 messages 与 tool_calls，避免遗留孤立记录。

ID 使用统一 IdGenerator 产生，排序依赖时间与显式关联，不要求 ID 承载业务顺序。时间统一以毫秒保存，展示时转成本地时区。

索引围绕实际查询建立：

- conversations 的置顶/更新时间列表。
- messages 的 conversation_id、parent_id 和 run_id。
- tool_calls 的 run_id、status 和 created_at。
- agent_runs 的 conversation_id 与 status。

当前分支沿 parentId 取完整消息链，分页按分支顺序进行，不将其他分支按时间混进来。

### 3.2 存储实现

- Drift 数据库使用 SQLite3MultipleCiphers 加密，从创建数据库时启用。
- 数据库密钥由 SecureKeyStorage 保存，数据库内不保存密钥本体。
- 数据库加密使用 SQLite3MultipleCiphers：pubspec 的 `hooks.user_defines.sqlite3.source` 声明 `sqlite3mc`，由构建钩子编译进包；打开时在 `NativeDatabase.createInBackground` 的 setup 阶段执行 `PRAGMA key`。drift 2.32 起该路径取代了已停止维护的 `sqlcipher_flutter_libs`，工程不再依赖后者。
- SettingsStorage 保存主题、界面偏好和当前选择等小型非敏感设置。
- 附件由 AttachmentStorage 管理；原始输入、提取文本和执行产物有明确的会话归属。

所需依赖与构建配置在实现时加入 manifest/lockfile，版本以工程文件为准。

### 3.3 事务边界

| 操作 | 事务内完成 |
|---|---|
| 发送 | 用户消息、AgentRun 和会话当前位置 |
| 模型响应收口 | 助手消息的最终 Parts、完整工具记录与用量 |
| 等待确认 | 工具状态、确认时间/决定与运行等待状态 |
| 派发 | tool_calls.executing 与 active_tool_call_id |
| 工具结果 | 工具结果、结果消息、会话/运行当前位置 |
| 结束 | 消息终态、运行原因、计数与时间 |

模型流式输出在内存合并后节流更新消息；结束/停止时写最终内容。网络调用、用户等待和原生命令不能放在数据库事务内。

ToolCallRecord 本身就是执行历史的数据来源。初版不再添加审计镜像表、run_events、全量 snapshots 或按 JSONL 偏移建立的索引。

### 3.4 内容与诊断

业务库保存用户可以查看和删除的消息、参数及结果。AppLogger 只保存事件类型、错误代码和必要耗时，不记录密钥、鉴权头、用户正文、原始请求/响应或屏幕内容。

导出的会话来自业务模型，不来自诊断日志。JSON 导出使用初版固定结构，Markdown 导出用于阅读；包含工具产物时由用户选择范围，密钥不进入导出。

## 4. AI 协议契约

### 4.1 Provider 接口

```dart
abstract interface class AiProvider {
  ApiProtocol get protocol;
  Future<List<ModelInfo>> listModels();
  Stream<ChatChunk> streamChat(ChatRequest request);
}
```

实例绑定一份服务商连接配置和运行期凭据。工厂按 ApiProtocol 创建对应实现。取消 streamChat 的订阅应关闭底层 HTTP 请求。

Provider 只处理所选协议的连接、请求和响应；模型、调用者与测试共同使用这一接口。

### 4.2 请求

```text
ChatRequest
  modelId
  systemPrompt
  messages: ResolvedMessage[]
  tools: ToolDefinition[]
  reasoningEffort
  temperature
  maxOutputTokens

ResolvedMessage
  role
  parts: ResolvedPart[]
```

ContextBuilder 从消息与工具记录得到 ResolvedMessage；这一结构是一次请求的内容，不是第二套持久化消息格式。

请求参数遵循模型配置和所选协议。不支持推理的模型不发送推理字段；off 使用对应协议的关闭语义。工具不启用时不发送工具定义。

### 4.3 流式事件

ChatChunk 使用类型化事件，不把所有情况塞进带一组可空字段的 delta 对象。

| 事件 | 内容 | Loop/UI 行为 |
|---|---|---|
| PartStart | partId、Part 类型和初始信息 | 创建内存内容块 |
| TextDelta | partId、正文片段 | 追加正文 |
| ReasoningDelta | partId、公开思考片段 | 追加思考 |
| ToolCallDelta | partId、工具名/调用 ID/参数片段 | 只组装，不执行 |
| PartEnd | partId、完整块与 providerData | 完成当前块，保存协议状态 |
| Usage | TokenUsage | 更新本次调用用量 |
| ResponseEnd | 结束原因、完整响应信息 | 收口消息并决定进入工具或结束 |
| ResponseError | 类型化错误 | 停止本次响应，保留已收到内容 |

增量与完成快照归并在同一 partId 上，不把完整快照作为增量再追加一次。SSE 处理合法的 UTF-8 分片、多行事件和注释行；不添加针对未知网关私有格式的试探性解析。

### 4.4 四种协议实现

| 协议 | 请求组织 | 响应与工具回填 |
|---|---|---|
| OpenAI Completions | messages、tools 与所选模型参数 | delta 组装；工具请求与 tool 结果按调用 ID 配对 |
| OpenAI Responses | input items 与 tools，客户端提供完整上下文 | 类型化响应事件；函数调用/输出项与公开 reasoning 摘要分开 |
| Anthropic Messages | 顶层 system、messages 和工具 schema | content block 组装；tool_use/tool_result 配对，连续工具结果按协议组织 |
| Google Generative AI | systemInstruction、contents 和 function declarations | parts 组装；functionCall/functionResponse 与协议状态一起组织 |

四种实现按官方协议处理。第三方端点使用其明确支持的那一种，不根据模型名字改协议，不在请求失败后猜另一套字段或自动换端点。

服务端内置搜索/MCP、服务端会话状态等不进入 P0；客户端 Loop 与本地工具保持完整控制。

### 4.5 公开思考与协议状态

公开思考是用户可见内容；签名、加密内容和其他协议状态是回传数据。两者不能相互推导。

适配器保存同一模型后续请求所需的原始协议状态，并绑定所属响应/Part。构建请求时仅使用当前协议所需数据，不伪造、不从 token 用量生成思考。

切换模型或协议后，新运行重新装配上下文；协议专属状态不被当成另一种协议的通用文字。具体回填结构用多轮报文样本测试。

## 5. 连接、模型与错误

### 5.1 配置流程

1. 选择协议或服务商预设。
2. 填写端点及是否需要 Key；Key 通过 SecureKeyStorage 保存。
3. 获取模型或手动添加，设置能力与默认选择。
4. 保存配置，选择助手/会话使用的模型。

获取模型验证的是该请求的连接与权限。聊天、推理和工具分别有测试入口，不用一个“连接成功”标签替代全部能力结果。

编辑已有配置时，Key 输入留空表示不修改；免 Key 调用不发送鉴权头。删除凭据是独立明确动作。

### 5.2 错误分类

| 类别 | 处理 |
|---|---|
| 配置不完整 | 表单就地提示，不发送请求 |
| Auth | 提示检查凭据与权限 |
| RateLimit | 展示等待/重新发送入口；未输出内容的请求可按有限策略重试 |
| Network / Timeout | 停止当前请求，保留已收到内容 |
| InvalidRequest / ContextLimit | 说明参数/上下文问题，不自动修改用户参数 |
| ProviderError | 按明确的协议错误记录失败 |
| StorageError | 显示保存失败并结束当前工作 |

网络与存储边界映射为分类错误（`ProviderError.category`），界面展示 `userMessage` 给出的安全文案；协议原文只进诊断，不落库也不上屏。错误解析读取标准字段，不建立面向错误文本变体的正则链或跨协议补救机制。流式响应内的错误事件（`ResponseError`）即本次响应结束：保留已收内容、按分类收口，不把网关错误文案当作正文。

多 Key 轮换、模型分派与成本统计属于 P1；它们是用户配置的功能，不作为首版错误处理的默认后备路径。

## 6. 附件输入

### 6.1 图片

处理链为：选择/拍照 → 解码 → 烘焙 EXIF 方向 → 限制尺寸 → 编码 → 保存 → 建立 ImagePart。

首版以长边 1568px、JPEG 质量 85 作为默认处理参数；需要透明度的图片使用 PNG。处理在后台 isolate 完成，UI 只接收元数据和缩略图。

图片只在所选模型启用图片能力时进入请求。Provider 按本协议编码图片；本地文件路径不是模型可以直接读取的 URL。

### 6.2 文本与文档

- 文本文件按支持的编码读取，保存为附件内容。
- PDF 使用本地 PDF 解析库提取文本（当前为 `syncfusion_flutter_pdf`：纯 Dart、无原生依赖，代码为专有许可下的 Community License，本项目未发布、非商业使用范围内可用；若要换 MIT 实现，只需替换 `DocumentExtractor` 里的 PDF 分支），不自行实现 PDF 格式解析器。
- DOCX 读取 ZIP 包内的文档 XML（`archive`），按文档顺序取 `w:t`、`w:tab`、`w:br` 与段落结束，段落/表格的文字顺序与阅读顺序一致。
- 抽取在导入附件时完成：结果写成 `<附件 id>.extracted.txt`，附件记录保存路径；失败（扫描件、损坏文件）把原因写进 `extraction_error`，界面在附件条上给出警告，请求里用一句说明代替内容，而不是让附件凭空消失。
- 抽取结果保存到附件的提取文本文件，Provider 统一作为文本上下文发送。
- 没有可提取文字的扫描件显示“需要 OCR”，不把空文本当作已读取文档。

大文档由用户选择范围或以工具分段读取。P0 不为每个协议分别设计一次文件上传；原生文件上传作为 P1 增强。

### 6.3 执行产物

写文件、下载或命令产生的文件建立 artifact 类型 Attachment，ToolResult 引用该附件。用户可以查看、分享或删除，模型收到名称/类型和必要内容，不收到设备上无关目录信息。

## 7. 密钥与加密

API Key 与数据库密钥按不同用途交给 SecureKeyStorage，普通业务模型只保存配置 ID。

- Key 不进入 ChatRequest 的可序列化业务内容，由 Provider 发送时添加鉴权。
- 安全存储读写失败直接显示错误，不自动清空或重建整个密钥库。
- 模型配置、日志、会话分享和导出均不包含 Key。
- 系统备份规则排除不能跨设备直接解密的密钥/数据库文件。

P1 的加密备份使用独立口令和认证加密格式导出选定数据。格式验证后才导入；认证失败提示“口令错误或文件损坏”，不声称能通过一个 canary 确定区分二者。

## 8. 记忆（P1）

记忆与会话内容分开建模，包含内容、来源、创建/更新时间及用户编辑/删除状态。只有经过定义的记忆写入流程更新记录，普通工具结果不直接升级为长期事实。

起步采用文本记录与简单检索；实际条目规模和查询需求需要向量检索时，再接入 embedding 与 sqlite-vec。检索出的条目作为上下文数据，不覆盖当前任务和应用规则。

## 9. 代码组织

```text
lib/
  core/                       # 共享主题、路由、错误、通用基础设施
  data/
    models/                   # Part、消息、工具、运行、配置等正式模型
    repositories/             # 会话、运行、工具记录、配置访问
    datasources/              # Drift、偏好、密钥、附件、网络设施
  providers/                  # 四协议 AiProvider 实现
  features/
    chat/                     # 聊天、消息/工具卡片与输入
    assistants/               # 助手配置
    providers_config/         # 服务商与模型配置
    execution/                # Loop、工具注册/执行、通道与运行 UI
    settings/                 # 外观与数据管理
pigeons/                      # Android 桥接定义
android/app/src/main/kotlin/app/xiangyue/phase/
  bridge/
  execution/
  accessibility/
  files/
```

分工以业务职责为准，不为每个名词再建一层 entity/service/manager。现有原型模块可以直接改成目标实现；生成文件由生成器维护。

## 10. 测试设计

| 测试层 | 首版用例 |
|---|---|
| 数据模型/数据库 | schema 1 建表、Part 读写、消息树、工具记录与结果消息事务、附件归属 |
| Provider | 四种协议请求构建；原始 SSE 经适配器输出事件；思考/工具/完成快照/错误；多轮回填 |
| Loop | 无工具回答、单/多工具、拒绝、轮次上限、空回复、停止 |
| 输入 | 图片方向/尺寸、文本/PDF/DOCX 抽取、附件到请求 |
| 配置 | 表单保存、模型获取/手动管理、Key/免 Key、用户取消 |
| UI | 聊天、助手、模型、确认与工具状态；浅深主题、窄屏、大字、返回 |
| Android | 实际无障碍观察/动作/输入、执行确认、Activity 切换、服务与停止 |
| 中断 | 动作前停止、执行中取消、结果落库前进程终止、重新打开后的已知/未知状态 |

模型测试使用脱敏报文、假凭据与本地可控网络，不调用付费接口或读取手机私人配置。正常数据契约直接测试，不建设开发期历史格式迁移用例。

检查命令和各阶段交付条件集中在 [初版实施计划](./implementation_plan.md)。

# 参考资料

以下为实现时的主要资料入口，协议字段和 Android 行为以实际使用版本的官方文档为准。

- [Flutter 平台通道](https://docs.flutter.dev/platform-integration/platform-channels)
- [Pigeon](https://pub.dev/packages/pigeon)
- [Drift](https://drift.simonbinder.eu/)
- [Drift 数据库加密](https://drift.simonbinder.eu/platforms/encryption/)
- [Dio](https://pub.dev/packages/dio)
- [Android AccessibilityService](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService)
- [Android 前台服务](https://developer.android.com/develop/background-work/services/fgs)
- [Shizuku API](https://github.com/RikkaApps/Shizuku-API)
- [Termux RUN_COMMAND](https://github.com/termux/termux-app/wiki/RUN_COMMAND-Intent)
- [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions)
- [OpenAI Responses](https://developers.openai.com/api/reference/resources/responses)
- [Anthropic Messages](https://platform.claude.com/docs/en/api/messages)
- [Google Generative AI](https://ai.google.dev/gemini-api/docs)
- [MCP](https://modelcontextprotocol.io/specification)
- 竞品：[RikkaHub](https://github.com/rikkahub/rikkahub)、[Kelivo](https://github.com/Chevey339/kelivo)、[Operit](https://github.com/AAswordman/Operit)
