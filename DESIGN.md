# DESIGN.md — UI 设计规范

> 本文件定义「相月」的 Material 3 视觉与交互规范。
> 工程规范见 [AGENTS.md](./AGENTS.md)，实现集中在 `lib/core/theme/`。

## 1. 设计方向

- **简洁高效**：一屏一个核心任务，高频操作（发送、停止、切换会话）一步到位。
- **内容优先**：聊天内容占主要面积，装饰只承担分区、状态和方向提示。
- **大圆角**：圆角是品牌识别的一部分，但按组件尺寸分级使用，不把所有组件做成胶囊。
- **克制的色彩**：靛蓝为主、月华金为唯一品牌强调色。不靠多色渐变和彩色色块做装饰。
- **深浅色对等**：深色主题独立调优，不是浅色主题简单反相。

## 2. 主题与色彩

### 2.1 色彩角色

- 主种子色：`Color(0xFF3D5A98)`（靛蓝），通过 `ColorScheme.fromSeed()` 生成全部语义色；浅色主题白底沉静，深色主题呈深夜蓝调。
- `BrandColors.gold`（月华金，基准 `#C9A227`）：品牌标识、置顶标记等低频高辨识场景，**每屏至多一处金色元素**。动态取色开启时金色保持不变。
- 除此之外不设品牌辅助色。分区与层次靠 tonal surface（`surfaceContainer*` 阶梯）完成，不用彩色渐变铺背景。

### 2.2 取色纪律

- 一律经 `Theme.of(context).colorScheme` 或 `context.brandColors` 取色，禁止在组件里硬编码色值。例外：`core/theme` 内的种子色与金色定义、代码块高亮配色表。
- 语义映射约定：

| 场景 | 槽位 |
| --- | --- |
| 用户消息气泡 | `primaryContainer` / `onPrimaryContainer` |
| AI 消息气泡 | `surfaceContainerHighest` / `onSurface` |
| 发送按钮（可用态） | `primary` / `onPrimary` |
| 错误提示（气泡、Banner、删除确认） | `error` 系 / `errorContainer` 系 |
| 代码块背景 | `surfaceContainerHigh`，文字 `onSurfaceVariant` |
| 次要信息（时间戳、模型名） | `onSurfaceVariant` |
| 输入栏背景 | `surfaceContainerHigh`（磨砂） |
| 品牌强调（选中态、置顶、标识） | `BrandColors.gold` 系 |

### 2.3 透明度与表面

- 页面背景使用 `surfaceContainerLowest`，纯色，不铺多色渐变。
- `FrostedSurface` 是唯一的通用半透明/模糊表面，且**只用于背后有内容流动的区域**：输入栏、抽屉。页面级空状态、卡片等静态区域用 tonal surface，不做无谓的模糊。
- 半透明表面必须同时保证正文对比度满足 WCAG AA。
- 模糊只使用轻量 `BackdropFilter`，不在长列表的每一行使用模糊。
- 禁止用阴影制造主要层级；仅 Dialog、BottomSheet、FAB 等真正悬浮的组件使用 elevation。

## 3. 字体与排版

- 遵循 Material 3 Type Scale，组件通过 `Theme.of(context).textTheme` 取用，不手写字号。
- 页面标题 `titleLarge`，列表标题 `titleMedium`，正文 `bodyLarge`，辅助信息 `bodySmall`，按钮 `labelLarge`。
- 中文跟随 Android 系统字体；代码块使用等宽 fallback，字号比正文小 1sp。

## 4. 间距与形状

间距使用 4dp 网格：`4 / 8 / 12 / 16 / 24 / 32`，定义在 `AppSpacing`。

| 档位 | 值 | 用途 |
| --- | ---: | --- |
| small | 12 | 列表项、Chip、小控件 |
| medium | 20 | 输入框、卡片、表单控件 |
| large | 28 | 聊天气泡、磨砂面板 |
| extraLarge | 36 | 页面级面板、Dialog、BottomSheet |
| full | 40 | 输入栏、FAB、FilledButton、发送按钮 |

## 5. 页面与组件

### 5.1 聊天页

- AppBar 半透明、底部圆角，内容在其下滚动。
- 消息列表是页面主体。用户气泡靠右、AI 气泡靠左，最大宽度为屏宽的 80%，圆角 `large`，纯色 tonal 填充，不描边。
- AI 消息上方用 `bodySmall` + `onSurfaceVariant` 标注模型名；内容用 gpt_markdown 渲染 Markdown，代码块带语言标签与复制按钮。
- 输入栏是底部通栏磨砂面板（`FrostedSurface`，圆角 `full`，背景 `surfaceContainerHigh` 高不透明度），最多 5 行；发送/停止按钮同一位置切换。
- 空状态：圆形 tonal 图标容器（`primaryContainer` 系）+ 一句引导文案 + 一个 `FilledButton.tonal` 主操作，不使用磨砂面板。

### 5.2 会话抽屉

- 宽度约为屏宽的 88%，最大 420dp，右侧大圆角（`extraLarge`）+ 磨砂表面。
- 新会话固定在顶部，设置固定在底部，中间会话条目使用圆角 `ListTile` 列表。
- 主页面内容区域的任意位置都支持向右滑打开抽屉（位移 ≥56，或 ≥24 且速度 ≥450）；Android 边缘返回手势仍由系统优先处理。
- 长按条目弹出菜单：重命名 / 置顶 / 删除；置顶标记是抽屉内唯一的金色元素。
- 删除会话必须二次确认。

### 5.3 弹窗（Dialog）

- 统一 M3 弹窗范式：顶部语义图标（普通操作用 `primary`，破坏性操作用 `error`）+ 居中标题 + 内容 + 按钮组（`TextButton` 取消 + `FilledButton` 确认）。
- 破坏性操作（删除等）的确认按钮使用 `error` / `onError` 配色，不用主色。
- 含输入框的弹窗隐藏字数计数器（`counterText: ''`），保持版面干净。
- 选择类弹窗（如主题模式）使用同一范式，当前选中项尾部显示 `primary` 色对勾。

### 5.4 设置与 Provider

- 设置按分区排列，分区标题使用 `titleSmall` + `primary`，条目之间保留至少 8dp。
- 表单控件使用 filled + 大圆角样式；API Key 必须支持显隐切换，并以 `bodySmall` 提示仅存储在安全存储。
- 空状态：语义色图标（48dp）+ 一句引导文案，可附一个主操作或重试入口。

## 6. Android 返回与动效

- Android Manifest 开启 `android:enableOnBackInvokedCallback="true"`。
- Theme 使用 `PredictiveBackPageTransitionsBuilder`，在 Android 14+ 设备上提供预测性返回预览；较低版本回退到普通转场。
- 可拦截返回时使用 `PopScope`，禁止新增 `WillPopScope`；`canPop` 必须提前可计算，不能在返回手势开始后异步决定。
- 页面切换遵循 Material 3 / Android predictive back 动效，常规时长 200–300ms。
- 流式输出不做逐字动画，文本直接追加；动画只出现在状态切换（发送→生成中→完成）。
- 支持系统减少动态效果设置时，降低模糊与非必要动画。

## 7. 图标与无障碍

- 统一使用 `material_symbols_icons` 的 `Symbols.xxx`，不混用 Flutter 旧版 `Icons`。
- 图标默认 24dp，次要 20dp，空状态主图标 44–52dp；颜色继承所在槽位的 on 色。
- 图标按钮触控目标至少 48×48dp，并提供 `tooltip` 或 `Semantics` 标签。
- 正文对比度至少 4.5:1，聊天正文在 1.3x 字体缩放下不能溢出。
- 所有状态变化需要同时有颜色和文字/图标表达，不能只依赖颜色。

## 8. 落地约定

- 主题、圆角、间距、品牌色和磨砂表面只在 `lib/core/theme/` 集中维护。
- 新增页面先复用 Material 3 组件和现有主题；确实需要自绘时，先补充本文件和 `core/theme`。
- 规范变更先改本文件，再改代码。
