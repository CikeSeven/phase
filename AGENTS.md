# AGENTS.md — 项目规范

> 本文件是项目的工程规范，所有代码贡献（人类或 AI）都必须遵守。
> UI / 视觉规范见 [DESIGN.md](./DESIGN.md)，两份文件术语保持一致。

## 1. 项目概述

**相月**（工程代号 `phase`，取「月相」双关；名称出自《尔雅》对农历七月的雅称）是一个基于 Flutter 的 AI 全能助手 App：以对话为核心，可接入多家 AI 服务商（Provider），并在此之上扩展翻译、总结、写作等助手能力。

核心能力：

- 多 AI 服务商接入：OpenAI、Anthropic、Gemini、DeepSeek、Ollama，以及任意 OpenAI 兼容接口（自定义 Base URL）。
- 流式对话：SSE 流式输出，可随时停止。
- 多会话管理：会话创建、重命名、置顶、删除，消息本地持久化。
- 助手能力扩展：以「助手（Assistant）」为单位封装 system prompt、默认模型与参数。

## 2. 技术栈

| 领域 | 选型（当前版本） | 说明 |
| --- | --- | --- |
| SDK | Flutter stable 3.47.2 / Dart 3.13.2 | 始终使用 stable 通道；**平台仅限 Android**（applicationId `app.xiangyue.phase`，桌面/iOS 待架构稳定后再补） |
| UI | Material 3 | `useMaterial3: true`（默认），UI 细节见 DESIGN.md |
| 图标 | material_symbols_icons ^4.2960.0 | Material Symbols rounded，见 DESIGN.md 第 6 章 |
| 状态管理 | flutter_riverpod ^3.4.3 + riverpod_annotation ^4.0.7 + riverpod_generator ^4.0.9 + riverpod_lint | 编译期安全、便于按 Provider 拆分、测试友好；Riverpod 3.x 语法 |
| 网络 | dio ^5.11.1 | 拦截器处理鉴权 / 重试 / SSE 流式响应 |
| 路由 | go_router ^18.0.1 | 声明式路由 |
| 本地持久化 | drift ^2.34.4 + drift_flutter ^0.3.1（会话与消息）+ shared_preferences ^2.5.5（设置项） | drift 提供类型安全 SQL 与流式查询，适合消息列表这种大数据量、需实时刷新的场景；drift_flutter 封装了各平台 sqlite 初始化 |
| 密钥存取 | flutter_secure_storage ^11.0.0 | API Key 只允许存这里 |
| 序列化 | json_annotation ^4.12.0 + json_serializable ^6.14.1 | |
| Markdown 渲染 | gpt_markdown ^1.2.1 | AI 消息的 Markdown 渲染、流式输出与代码块高亮/复制 |
| 代码生成 | build_runner ^2.16.1 | 驱动 riverpod_generator / json_serializable / drift_dev |
| Lint | flutter_lints ^6.0.0 | 如需更严格可升级 very_good_analysis，需团队确认 |

**依赖纪律**：不引入本文件未列出的第三方依赖。确需新增时，先在本表登记用途与理由，再修改 `pubspec.yaml`。能用 Flutter SDK / Dart 标准库解决的，不加依赖。

## 3. 架构

采用 feature-first 分层，`lib/` 目录结构：

```
lib/
  app.dart              # MaterialApp / 主题 / 路由装配
  main.dart             # 入口，仅做初始化与 ProviderScope
  core/                 # 跨业务的基础设施
    theme/              # ThemeData 构建（落地 DESIGN.md 的规范）
    router/             # go_router 路由表
    error/              # Failure 类型与错误映射
    utils/              # 纯工具函数
  data/
    models/             # 数据模型（json_serializable / drift table）
    datasources/
      local/            # drift 数据库、shared_preferences 封装
      remote/           # dio client 封装
    repositories/       # 仓库：对上层屏蔽数据来源
  providers/            # AI 服务商抽象层（注意：目录名即 Provider，勿混淆 Riverpod provider）
    ai_provider.dart    # AiProvider 抽象接口
    openai/ anthropic/ gemini/ ...   # 各厂商实现
    provider_factory.dart
  features/
    chat/               # 会话列表、聊天页、输入栏、流式状态
    settings/           # 设置页
    providers_config/   # 服务商配置（Base URL、Key、模型列表）
    assistants/         # 助手管理
test/                   # 目录结构镜像 lib/
```

分层规则：

- 依赖方向单向：`features → repositories → datasources`，禁止反向依赖。
- UI 层只读 Riverpod provider 状态、调用 notifier 方法，不直接触碰 dio / drift。
- `data/models` 与 UI 之间允许直接传递模型，不强制再封装一层 entity。

## 4. AI 服务商抽象层

所有厂商差异收敛在 `lib/providers/` 内，上层只面对统一接口：

```dart
abstract class AiProvider {
  String get id;                    // 'openai' | 'anthropic' | ...
  ProviderCapabilities get capabilities;  // 是否支持流式 / 视觉 / 工具调用
  Stream<ChatChunk> streamChat(ChatRequest request);  // 流式对话
  Future<List<AiModel>> listModels();     // 拉取可用模型
  Future<void> validateKey();             // 校验配置可用性
}
```

约定：

- **OpenAI 兼容协议是默认实现**：DeepSeek、Ollama、自定义网关等一律复用 OpenAI 实现，仅配置不同 Base URL。
- 非兼容厂商（Anthropic、Gemini 原生协议）各自做协议适配，输出统一的 `ChatChunk` 事件流。
- 错误统一映射为 `core/error` 中的 `Failure` 子类型（网络错误 / 鉴权失败 / 限流 / 服务端错误 / 取消），UI 只处理 `Failure`。
- 取消语义：`streamChat` 必须响应取消（`CancelToken` / stream 订阅取消），保证「停止生成」即时生效。

## 5. 编码规范

- 命名：文件 / 目录用 `snake_case`；类用 `PascalCase`；变量、方法用 `camelCase`；私有成员加 `_` 前缀；常量用 `camelCase` 而非 SCREAMING_CAPS。
- **Riverpod 3.x 语法纪律**：只允许 3.x 新 API——状态一律用 `@riverpod` 代码生成 + `Notifier` / `AsyncNotifier`；**禁止 import `package:riverpod/legacy.dart`**（`StateProvider`、`ChangeNotifierProvider` 等旧 API 一律不得使用）。`riverpod_lint` 已通过 `analysis_options.yaml` 的新版分析器插件系统（顶层 `plugins:`）启用，其诊断必须全部处理，不得无视。
- 一个文件一个主类，文件名与类名对应。
- 注释只写「为什么」，不复述代码做什么；公共 API 写 dartdoc。
- 禁止 `print`，调试用 `debugPrint`，需要分级日志时用 `core` 内统一的 logger 封装。
- 异步：一律 `async/await`；不在 widget `build()` 中触发副作用（用 provider / `ref.listen` / 生命周期回调）。
- 错误处理：repository 层捕获异常并转为 `Failure`；UI 层根据 `Failure` 类型展示对应文案，禁止向上抛裸异常。
- 密钥安全：API Key 只经 flutter_secure_storage 读写；严禁硬编码、严禁写入普通持久化、严禁进日志。
- 代码生成文件（`*.g.dart`、`*.gr.dart`、drift 生成物）不手改，随源码一起提交。

## 6. 工程命令

```bash
flutter pub get                              # 安装依赖
dart run build_runner build --delete-conflicting-outputs   # 代码生成
flutter analyze                              # 静态检查（提交前必须通过）
flutter test                                 # 运行测试
flutter run                                  # 调试运行
```

提交代码前必须保证 `flutter analyze` 零问题、`flutter test` 全绿。

### 本机 Android 环境说明

- Flutter 已配置 `--android-sdk ~/android-sdk`：系统 SDK（`/opt/android-sdk`，root 所有只读）的用户级覆盖目录，大组件以符号链接共享，NDK 28.2.13676358 与 build-tools 36.0.0 安装于该目录（系统 SDK 缺这两个组件且无写权限）。
- 系统自带的 `sdkmanager`（新版 android CLI）在只读 SDK 上会崩溃；如需安装 SDK 组件，用 `~/android-sdk/cmdline-tools-classic/latest/bin/sdkmanager --sdk_root=$HOME/android-sdk "<组件>"`。
- `android/app/build.gradle.kts` 中 `compileSdk = 37` 是显式覆盖（flutter_secure_storage 11.x 要求 ≥37），不要改回 `flutter.compileSdkVersion`。

## 7. Git 规范

- Commit message 遵循 Conventional Commits：`feat:` / `fix:` / `refactor:` / `docs:` / `test:` / `chore:`，例如 `feat(chat): 支持流式输出停止`。
- 分支：`main` 保持稳定；功能开发用 `feat/<名称>`，修复用 `fix/<名称>`。

## 8. 测试规范

- `test/` 目录结构镜像 `lib/`。
- 单元测试：repository、AiProvider 实现（用 mock 的 dio 适配器）、状态 notifier。
- Widget 测试：聊天页、输入栏、设置页等关键页面覆盖主要交互路径。
- 不测 getter/setter 之类的平凡代码，优先保证业务逻辑与协议适配的覆盖。
