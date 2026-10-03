# AGENTS.md — 代码规范

本文件仅规定项目代码的组织、实现与质量要求；界面规范见 [DESIGN.md](./DESIGN.md)，具体功能契约以对应需求和产品文档为准，不在此重复功能实现说明。

## 技术与依赖

- 使用项目 `pubspec.yaml` 声明的 Flutter/Dart SDK 与依赖；解析版本以 `pubspec.lock` 为准，工具链以本机 `flutter --version` 为准。
- 业务状态使用 Riverpod 3 注解 API，路由使用 go_router，网络与持久化遵循项目已有的适配层和仓储边界。优先使用 SDK、标准库和已有依赖。
- 新增或升级依赖前说明必要性与影响，并同步维护 manifest 和 lockfile；分析器规则以 `analysis_options.yaml` 为准，不通过关闭 lint 绕过问题。

## 代码结构与依赖方向

- 按业务职责组织 `lib/features/`；只有真正跨业务复用的能力放入 `lib/core/`。
- 共享数据契约放在 `lib/data/models/`，数据访问分别由 `lib/data/repositories/` 和 `lib/data/datasources/` 承担；避免无实际价值的重复抽象层。
- `lib/providers/` 用于协议适配，不作为 Riverpod 状态目录；状态定义放在其所属职责附近。
- 页面通过注入的状态对象和仓储访问业务，不直接操作网络、数据库或存储插件。数据层和协议适配层不得依赖页面。
- 初始化、路由和依赖装配集中在应用装配边界；共享组件不因装配需要而反向依赖具体 feature。

## Dart 与状态

- 文件名使用 `snake_case`，类型使用 `PascalCase`，成员和常量使用 `camelCase`。按主职责拆分文件，避免无关改动和重复逻辑。
- 注释只说明必要的原因、约束或非显然行为；修改行为时同步清理失效注释。
- 共享业务状态使用 Riverpod 3 的 `Notifier` / `AsyncNotifier` 注解 API，不使用 legacy API。焦点、草稿、展开和动画等局部状态可由 Widget 持有。
- `build()` 不执行网络或存储副作用。优先使用 `async` / `await`；异步流程处理重复提交、过期结果、生命周期、异常和资源释放。
- 生成代码（如 `*.g.dart`）不得手改。修改生成输入后运行对应生成命令，并将生成物与源码一并维护。

## 数据、错误与安全

- 业务数据访问经仓储和数据源边界；模型、持久化结构及生成代码保持一致。修改结构时同步更新相关定义与生成物。
- 网络、存储和平台边界将异常映射为项目统一的 `Failure`；调用方明确处理失败，不吞异常或伪装成功。
- 敏感凭据只通过安全存储接口按用途存取，不放入普通模型、偏好、日志或面向模型的上下文。
- 使用项目日志设施，禁止直接 `print`。不得记录密钥、鉴权信息、用户对话或未经脱敏的请求/响应正文；URL 参数和异常内容也须按敏感信息处理。
- 协议或平台差异隔离在适配层，对业务层提供明确的类型化接口；取消、错误和资源释放须沿调用链正确传递。

## 格式与检查

- Dart 改动按项目分析器和格式化规则维护；适用时运行：

  ```bash
  dart format --output=none --set-exit-if-changed lib test
  flutter analyze
  git diff --check
  ```

- 除非用户主动明确要求，否则不编写、不修改、不运行测试；不得因代码改动自行补测或执行回归测试。格式化、静态分析、代码生成、构建和安装不属于测试，仍按本规范执行。
- 测试范围遵循任务要求，验证结果只陈述实际执行的内容；不把静态检查、构建或生成代码等同于运行时验收。

## Android 真机安装

- 先用 `adb devices -l` 确认授权的 USB Android 设备，并将目标 ID 明确传给 `adb -s`。代码修改完成、适用检查通过且设备目标明确后，直接构建 Profile 包、覆盖安装并启动，无需再次询问；纯文档修改除外。

  ```bash
  flutter build apk --profile
  adb -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-profile.apk
  adb -s "$DEVICE" shell am start -W -n app.xiangyue.phase/.MainActivity
  ```

- 更新已有安装只用 `adb install -r`；禁止 `flutter install`、卸载重装和清数据。不得通过修改应用 ID、签名或破坏性操作绕过安装错误。
- 多台 USB Android 设备时不得猜测目标；安装失败时报告实际错误，不将构建成功当作安装成功。Debug 包仅用于调试，不作为真机 UI/性能验收包。
