# 相月（Phase）

相月是一个仅支持 Android 的多模型聊天与设备执行 Agent 应用，当前处于初版建设阶段，尚未发布。

## 项目文档

- [产品与技术设计](docs/product_and_technical_design.md)：首版产品范围、Agent Loop、Android 执行通道、数据模型和 Provider 契约。
- [初版实施计划](docs/implementation_plan.md)：从正式契约到首版验收的建设顺序。
- [工程规范](AGENTS.md)：代码边界、数据安全、测试和 Android 操作约定。
- [UI 规范](DESIGN.md)：Material 3 Expressive 组件、月色玻璃主题、交互和验收要求。

## 开发检查

项目使用 Flutter stable。代码改动后执行：

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
```

Android 真机验收、依赖变更和生成文件维护遵循 `AGENTS.md` 与实施计划。
