# AGENTS.md — 工程规范

本文件规定项目边界与开发流程；视觉、交互和 UI 验收统一见 [DESIGN.md](./DESIGN.md)。规范是改动要求，不代表所有场景已经验证。

## 1. 项目范围

- 产品「相月」，取自《尔雅》中农历七月的雅称；工程名 `phase`，仅支持 Android，应用 ID 为 `app.xiangyue.phase`。
- 当前核心是文本流式对话、公开思考展示、多会话、服务商/模型配置和主题设置；助手页仍是开发中入口，不将规划能力描述为已实现。
- 保持用户数据与应用身份稳定；未经要求不扩展平台、不改协议参数、不顺带重构无关模块。

## 2. 技术与依赖

- 使用 Flutter stable；SDK 约束与依赖声明见 `pubspec.yaml`，解析版本见 `pubspec.lock`，实际工具链用 `flutter --version` 确认，不维护第二份版本表。
- UI 使用 Material 3、`material_symbols_icons`、`gpt_markdown`；业务状态用 Riverpod 3 注解生成，路由用 go_router，网络用 Dio，存储用 Drift / shared_preferences / flutter_secure_storage。
- 优先复用 SDK、标准库和已有依赖；新增或升级依赖先说明必要性与影响，同步 manifest 和 lockfile。分析器规则以 `analysis_options.yaml` 为准，不为通过检查关闭 lint。

## 3. 结构与依赖边界

- `lib/features/` 按业务组织页面、局部组件和状态；仅真正跨业务复用的能力进入 `lib/core/`。
- `lib/data/models/` 定义共享数据契约，不机械增加 entity 层。消息角色沿用 `ChatRole.user/assistant/system`，持久化取值不得随意更名。
- `lib/data/repositories/` 封装业务数据访问；`lib/data/datasources/` 封装数据库、偏好、密钥与网络设施。
- `lib/providers/` 是 AI 协议适配层，不是 Riverpod 状态目录；Riverpod 定义随所属职责放置。
- feature 通过注入的 notifier、repository、设置/密钥封装和 AI 工厂组织业务，不在页面直接操作 Dio、Drift 或存储插件；数据与协议层不反向依赖页面。
- `lib/main.dart`、`lib/app.dart`、`lib/core/router/app_router.dart` 是初始化与装配点；路由引用页面是装配职责，不推广为共享组件依赖 feature 的理由。

## 4. AI 协议、流式与错误

- 对上使用 `AiProvider`、`ChatRequest`、`ChatChunk`；OpenAI Completions / Responses、Anthropic Messages、Google Generative AI 的差异留在协议适配层。
- `ProviderProfile.protocol` 决定协议，`presetId` 提供预设信息；编辑、切换预设、获取模型不得意外覆盖已保存的协议、兼容配置和手动模型。模型按 ID 合并并保留显式能力，空结果或请求失败不清空已有列表。
- 请求尊重模型能力与用户推理等级；不支持推理时不下发推理字段，`off` 按各协议的关闭语义映射。补响应解析不能暗改请求参数。
- 正文与思考分通道累积；思考只取实际公开文本/摘要，不由模型名、token 数、签名或加密字段伪造。SSE 须处理分片、多行事件、完成快照及带内错误，避免重复追加。
- 流式更新合并、节流写库；正常完成、停止、空回复和错误必须有明确结果。停止保留已收内容，丢弃迟到增量；取消应传递到底层请求，修改此路径须验证等待响应、空闲流和最终落库。
- 网络与存储边界将异常映射为 `lib/core/error/failure.dart` 中的 `Failure`；界面展示安全文案，不吞异常伪装成功。异步写入失败和资源销毁也要收尾。
- 兼容问题依据脱敏请求/响应和回归定位，不凭模型名称或猜测归咎网关；获取模型成功不等于该模型聊天、推理均已验证。

## 5. 编码、状态与数据安全

- 文件 `snake_case`，类型 `PascalCase`，成员/常量 `camelCase`；按主职责拆文件。注释只解释必要原因与契约，修改行为时清理过期注释。
- 共享业务状态使用 Riverpod 3 注解 API；可变业务状态用 `Notifier` / `AsyncNotifier`，禁止 legacy API。草稿、搜索、焦点、展开和动画可用局部 widget 状态，确认前不提前覆盖持久化选择。
- `build()` 无网络/存储副作用；优先 `async/await`。异步操作处理防重复、过期结果、`mounted` 与异常；释放 controller、监听器、订阅等资源。
- `*.g.dart` 等生成文件不手改；修改注解、模型、表结构后重新生成并随源码维护。
- 会话/消息/非敏感配置用 Drift，偏好用 `SettingsStorage`；存储变更同步 schema、迁移和生成物，验证旧 schema/JSON 升级，不以清库或新建数据库测试代替迁移验证。
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
- 配置改动覆盖往返保存、模型合并、免 Key、失败重试和异步结果过期；数据结构改动另加升级回归。
- UI 验收按 DESIGN 第 9 节；保留显式 `MaterialPage` 与 Android 预测返回，验证打开、取消、提交及页面状态恢复。
- 交付只陈述实际执行的检查和未验证范围；构建、截图生成、模拟响应分别不是视觉、性能或真实网关验收。纯文档改动核对事实、引用、命令及 diff，无需为此装机。
