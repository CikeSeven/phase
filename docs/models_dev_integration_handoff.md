# models.dev 模型元数据集成 — 完成记录

2026-09-24 审查并补齐原交接任务 1–9。有效契约见 [上下文与用量设计 §9](./context_management_and_usage_design.md#93-modelsdev-模型目录机制)，不再依赖仓库外计划文件。

## 当前实现

- 窗口：用户手填 > models.dev 目录 > 本地默认 **128000**。
- 输出预留：适配器实际参数 > 目录输出上限 > 本地 **4096**；**目录值绝不写入聊天请求参数**。
- 按模型 ID 跨服务商匹配，custom / ollama 同样生效，不猜测协议。精确 ID 优先于命名空间末段；同级优先已选预设，再按模型 ID、服务商 ID 稳定排序。精简时保留所有服务商的有效模型上限；版本 2 目录不复用旧白名单缓存与 ETag。
- 窗口、来源和候选目录输出上限随 `RunConfiguration` 固定。恢复和运行后续轮次不重解析；目录刷新仅影响空闲预览与新运行。
- 内置 JSON 快照 + 应用私有文件缓存；用户手动刷新，支持 ETag / 304，无自动联网、无新增依赖、无数据库 schema 变更。
- 编辑器显示目录/默认提示，按解析后预算校验；不会把目录值预填或回写为用户配置。

## 审查修复

1. **冷启动缓存竞争**：原实现读取尚未完成的缓存 provider 的 `.value`，会先用内置值固定运行快照。现在等待本地缓存后再决定回退；关闭可选缓存初始化的自动重试，失败立即回退，用户刷新可重试初始化。
2. **空配置页与首次刷新**：目录不再依赖已有服务商列表才初始化；空页也有状态与可用的刷新入口，首次点击会等待缓存就绪。
3. **数据与成功状态真实性**：零、负数、非有限数不作为有效上限；空/错误的 200 响应、无条件请求得到的 304 不算成功，不覆盖原目录。没有可用目录时不宣称“内置快照”。
4. **写入与生命周期**：每次写入有独立暂存目录、原子替换和清理，失败映射存储错误；页面销毁取消网络请求，迟到网络结果不落盘；已进入原子写的操作完成后，即使页面已退出仍刷新应用级目录。客户端随 provider 释放。
5. **测试挂起**：聊天控制器测试注入确定的目录，不依赖未装配的平台通道或资产 IO；需要真实缓存的 widget 测试按完成条件推进真实 IO 与 fake-async，不再用固定帧数猜测完成。
6. **请求参数隔离**：修正摘要请求从计量预留反推输出上限的路径；目录值不影响聊天或摘要的协议参数。
7. **文案与预算冲突**：编辑器提交等待目录就绪后校验，输出提示明确协议默认优先；目录输出占满窗口时显示具体预算配置错误，不暗改模型参数或缩小预留。

## 源码与回归入口

| 范围 | 入口 |
| --- | --- |
| 精简、匹配、优先级 | `lib/data/models/model_catalog.dart` / `test/data/models/model_catalog_test.dart` |
| 资产生成 | `tool/generate_models_catalog.dart` → `assets/models_catalog.json`（按模型名匹配版本生成 223 个服务商、8047 个有效模型，381090 字节） |
| 文件缓存与冷启动 | `lib/data/datasources/local/model_catalog_cache.dart` / 同名测试 |
| ETag、响应校验、取消 | `lib/data/datasources/remote/models_dev_client.dart` / 同名测试 |
| 刷新、编辑器 | `lib/features/providers_config/` / `test/features/providers_config/` |
| 运行快照、请求与预览 | `chat_controller.dart`、`chat/context/` / `test/features/chat/context/model_catalog_flow_test.dart` |
| 数据往返 | `test/data/repositories/repositories_test.dart` |

自动化覆盖首次缓存读取、损坏回退、并发原子写、200 / 304 / 失败 / 取消、空配置页首次刷新、写盘失败不报成功、编辑器边界及草稿不回写，以及四协议请求参数、运行中刷新、新运行、空闲预览和中断恢复的快照语义。

## 检查与未验范围

收尾命令：

```bash
dart run tool/generate_models_catalog.dart
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
git diff --check
```

2026-09-24 上述命令已执行：快照生成和 Riverpod 生成成功；格式检查 445 个 Dart 文件、0 改动；`flutter analyze` 无问题；全量 `flutter test` **1273 项通过、4 项按既有条件跳过**（未启用 `CAPTURE_UI` 的截图预览用例）；`git diff --check` 通过。

未执行设备安装或清数据；真机目录联网/断网、视觉/读屏、预测返回与 Profile 性能仍需单独验收。自动化中的协议请求验证不等于真实模型网关或摘要质量验收。

2026-09-24 后续按用户要求改为跨服务商按模型 ID 匹配，重建全量内置目录并移除模型参数区的解释文案。此变更未新增或更新测试用例，也未重跑测试套件；上面的测试结果仅对应先前的集成审查。
