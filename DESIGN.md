# DESIGN.md — UI 设计规范

> 本文件是项目的 UI / 视觉规范，基于 **Material Design 3（Material You）**。
> 工程规范见 [AGENTS.md](./AGENTS.md)；本文件的落地代码位于 `lib/core/theme/`，术语与 AGENTS.md 保持一致（如 AI 服务商统一称 Provider）。

## 1. 设计原则

- **简洁高效**：一屏一个核心任务，不堆砌入口；高频操作（发送、停止、切换会话）一步到位。
- **内容优先**：对话内容是主角，UI 元素退后——克制使用分割线、阴影和装饰色。
- **单手可操作**：主要交互集中在屏幕下方拇指区；导航类操作走抽屉或底部区域，不把关键按钮放顶部角落。
- **深浅色对等**：深色不是浅色的反色补丁，两者独立调优、同步交付。

## 2. 主题与配色

### 2.1 品牌色：月夜靛蓝

产品名「相月」出自《尔雅》，指农历七月（孟秋）。配色取「秋夜月出」的意象：**靛蓝为夜，月华金为月**。

- **主种子色**：`Color(0xFF3D5A98)`（靛蓝）。使用 `ColorScheme.fromSeed()` 由它生成完整主色系：
  - 浅色主题：白底 + 靛蓝主色，沉静不刺眼；
  - 深色主题：自然的深夜蓝调，契合「夜谈」场景。
- **品牌辅助色「月华金」**：`Color(0xFFC9A227)`。不经过 fromSeed，以自定义 `ThemeExtension`（`BrandColors`，含 `gold` / `onGold` / `goldContainer` / `onGoldContainer`）挂入主题，用于：品牌标识、选中态强调、收藏/置顶标记、空状态插画点缀等低频高辨识场景。**日常组件不得滥用金色**，一个屏幕最多一处金色元素。
- `themeMode` 支持：跟随系统（默认）/ 浅色 / 深色，在设置页切换。
- 预留动态取色（Android 12+ `dynamic_color` 能力）的接入点，但默认关闭，由设置开启；动态取色开启时月华金保持不变（它是品牌色，不随壁纸变化）。

### 2.2 取色纪律

- **一律通过 `Theme.of(context).colorScheme` 取色，禁止在组件里硬编码色值**（`Color(0x...)` / `Colors.xxx`）。唯三例外：种子色与月华金本身（只出现在 `core/theme`）、代码块高亮配色表。金色一律经 `BrandColors` 扩展取用。
- 语义映射约定：

| 场景 | ColorScheme 槽位 |
| --- | --- |
| 用户消息气泡 | `primaryContainer` / `onPrimaryContainer` |
| AI 消息气泡 | `surfaceContainerHighest` / `onSurface` |
| 发送按钮（可用态） | `primary` / `onPrimary` |
| 错误提示（气泡、Banner） | `errorContainer` / `onErrorContainer` |
| 代码块背景 | `surfaceContainerHigh`，文字 `onSurfaceVariant` |
| 次要信息（时间戳、模型名） | `onSurfaceVariant` |
| 输入栏背景 | `surfaceContainerHigh` |
| 品牌强调（选中态、置顶、标识） | `BrandColors.gold` 系（月华金，每屏至多一处） |

## 3. 字体排版

- 遵循 M3 Type Scale，通过 `Theme.of(context).textTheme` 取用，不手写 `fontSize`。
- 常用档位：

| 场景 | 档位 |
| --- | --- |
| 页面标题（AppBar） | `titleLarge` |
| 会话列表标题 | `titleMedium` |
| 聊天正文 / 气泡 | `bodyLarge`（约 16sp，行高 1.5） |
| 辅助说明（时间、token 数） | `bodySmall` |
| 按钮 / 输入框 | `labelLarge` |

- 中文：不单独指定字体族，跟随系统默认（Android 上 Noto Sans CJK）；如需自定义，仅在 `core/theme` 的 `fontFamilyFallback` 中配置一处。
- 代码块使用等宽字体（`monospace` fallback），字号比正文小 1sp。

## 4. 间距与形状

- **间距**：4dp 网格，只取 `4 / 8 / 12 / 16 / 24 / 32`。组件内边距常用 12 / 16，卡片间距 8 / 12，页面边距 16。
- **圆角档位**（M3 shape scale）：

| 档位 | 圆角 | 用途 |
| --- | --- | --- |
| small | 8 | 小按钮、Chip |
| medium | 12 | 卡片、Dialog |
| large | 16 | 聊天气泡 |
| full | 28 /  Stadium | 输入栏、FAB、发送按钮 |

- **层级**：遵循 M3 的 tonal surface 体系（`surfaceContainerLowest → Highest`），**优先用色调分层，不用阴影**；elevation 仅在 Dialog、BottomSheet、悬浮按钮等真正悬浮的元素上出现。

## 5. 核心组件规范

### 5.1 会话列表

- 移动端用 `NavigationDrawer`（从聊天页左侧滑出），宽屏（≥600dp）可常驻侧边栏。
- 会话条目用 `ListTile`：标题单行省略、副标题为最后一条消息预览、尾部为相对时间。
- 长按条目弹出 `MenuAnchor` 菜单：重命名 / 置顶 / 删除；删除需二次确认（`AlertDialog`）。
- 「新会话」入口固定在抽屉顶部，用 `FilledButton.tonal`。

### 5.2 聊天气泡

- 用户消息靠右、AI 消息靠左；气泡最大宽度为屏宽的 80%，圆角 16（large），气泡间距 8。
- AI 消息不带头像框，仅在气泡上方用小字（`bodySmall` + `onSurfaceVariant`）标注模型名；用户消息无任何标注。
- **流式输出**：气泡内容实时追加，末尾显示闪烁光标（`onSurfaceVariant` 的 `▍` 或等效动画）；自动跟随滚动仅当用户本就在底部，用户上翻后不打断。
- AI 消息内容按 Markdown 渲染（标题、列表、表格、代码块）；代码块带语言标签与「复制」按钮（图标按钮，置于代码块右上角）。
- 长按气泡弹出菜单：复制 / 重新生成（仅 AI 消息）/ 删除。复制成功用 `SnackBar` 轻提示。

### 5.3 输入栏

- 底部通栏，背景 `surfaceContainerHigh`，Stadium 圆角（full）。
- 结构：`[+ 附件按钮] [多行 TextField，无边框样式] [发送/停止按钮]`，高度随输入行数增长，最多 5 行后内部滚动。
- 发送按钮两态：空闲时为 `Icons.send`（`primary` 填充圆钮）；生成中变为 `Icons.stop`（`error` 语义不可用，仍用 `primary` 槽位，以 `filled` 呈现），点击即停止生成。
- 附件按钮预留（图片 / 文件），未接入多模态前可隐藏，但布局上保留位置。

### 5.4 设置与服务商配置

- 设置页遵循 M3 设置范式：`ListTile` + 尾部 `Switch` / 摘要文字，分组用 `titleSmall` + `primary` 色的分组标题。
- 服务商（Provider）配置项：名称、Base URL、API Key（`TextField` 设 `obscureText`，尾部眼睛图标切换可见）、模型选择（拉取后下拉）。
- API Key 输入框下方用 `bodySmall` 注明「密钥仅保存在本机安全存储中」。
- 每项配置保存后立即给出反馈（`SnackBar`），连接性校验结果显示为行内状态（成功 `primary` / 失败 `error`）。

### 5.5 空状态 / 加载 / 错误

- 空状态：居中图标（Material Symbols，48dp，`onSurfaceVariant`）+ 一句引导文案 + 一个主操作按钮。例：新会话页显示「向 Phase 提问，或选择一个助手」。
- 加载：局部加载用 `CircularProgressIndicator`；整页骨架屏优于转圈，列表类页面用骨架。
- 错误：页面级错误用 `errorContainer` 的 `Banner` 或居中错误态 + 重试按钮；气泡级错误在气泡下方显示错误文案与「重试」按钮。

## 6. 图标

- 统一使用 **Material Symbols**（rounded 变体为默认），通过 `material_symbols_icons` 包（`Symbols.xxx`）取用，不混用其他图标库，不用 Flutter 内置的旧版 `Icons`。
- 图标尺寸默认 24dp，次要图标 20dp；颜色继承所在槽位的 on 色。

## 7. 动效

- 遵循 M3 Motion：过渡用 `Emphasized` easing（Flutter 中 `Easing.emphasizedAccelerate / Decelerate`），常规时长 200–300ms。
- 页面切换用 `FadeThrough`（同级导航）与 `SharedAxis`（前进/后退）模式，go_router 中统一配置，不逐页自定义。
- 流式输出不做逐字动画，文本直接追加；动画只出现在状态切换（发送→生成中→完成）。
- 支持系统「减少动态效果」设置时，降级为无动画。

## 8. 无障碍

- 所有可交互元素触控目标 ≥ 48×48dp。
- 文本与背景对比度满足 WCAG AA（正文 ≥ 4.5:1）。
- 图标按钮必须有 `tooltip` / `Semantics` 标签（如「发送」「停止生成」「复制代码」）。
- 字号跟随系统字体缩放，聊天正文布局需在 1.3x 缩放系数下不溢出。

## 9. 落地约定

- 本规范的所有取值集中在 `lib/core/theme/`（ThemeData 构建、间距常量、圆角常量），UI 代码引用常量，不散落字面量。
- 新增组件前先复用 Flutter Material 组件并套主题；确实没有对应 M3 组件时才自绘，并在 `core/theme` 登记。
- 规范变更先改本文件，再改代码。
