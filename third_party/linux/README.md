# Linux 运行资源

首批仅交付 ARM64 Ubuntu Base 24.04.5。环境按需下载，不随 APK 打包。镜像清单在 `lib/features/workspace/linux_installer.dart`；PRoot、loader、talloc 与 supervisor 经 APK 的 JNI 库目录交付，运行时只从 `nativeLibraryDir` 启动。

| 资源 | 固定版本 / 来源 | SHA-256 |
|---|---|---|
| Ubuntu Base ARM64 | [24.04.5](https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-arm64.tar.gz)；[发布摘要](https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/SHA256SUMS) | `a91d5a93010193712d346d761372b7c9db6dfcf093893161c64ca107f05914f2` |
| PRoot，Termux 分支 | [v5.1.107.92](https://codeload.github.com/termux/proot/tar.gz/refs/tags/v5.1.107.92)，GPL-2.0 | `a1b070f55ec32b78e5033621476533d7230eb110275fe0cc3ee79c4fb334cfaa` |
| talloc | [2.4.3](https://www.samba.org/ftp/talloc/talloc-2.4.3.tar.gz)，LGPL-3.0-or-later；独立动态库 | `dc46c40b9f46bb34dd97fe41f548b0e8b247b77a918576733c528e83abd854dd` |

`tool/build_linux_native.sh` 使用 Gradle 配置的 NDK，以 Android API 24 和 16 KiB 页面对齐交叉构建。构建前校验源码归档；源码、日志和二进制均在忽略的 `build/linux-native/`。第一次构建需要下载两个固定源码包，后续按源码输入指纹复用缓存。`preBuild` 自动执行，也可手动运行：

```bash
bash tool/build_linux_native.sh
```

PRoot 的本地补丁仅增加缺失的 `<string.h>` 头文件；不禁用编译错误。talloc 用 `tool/native/talloc_replace.h` 声明 bionic 已有接口，不引入 Samba 替代库。`tool/native/process_runner.c` 是相月的进程 supervisor：独立子进程组、父进程死亡通知、TERM/KILL 和后代回收。桥接只把内部握手后的字节作为 stdout。

许可和来源说明随 APK 放入 `android/app/src/main/assets/linux/`。发布前仍需随实际分发方式核对完整源码和许可交付；当前构建仍为开发预览。

本机下载镜像为 29,936,675 字节；归档 regular file 内容合计 100,784,109 字节，解压器展开两个硬链接副本后为 104,728,695 字节。实际磁盘占用还包含目录和文件系统开销；安装空间预算采用压缩包、两份有界解压内容及预留空间，总计至少 605 MiB。APK 原生新增 ELF 内容合计 298,648 字节，压缩后约 130 KiB；为了 `nativeLibraryDir` 提取而启用 legacy JNI packaging 后，整个 APK 大小变化不能当作这四个文件的增量。

验证命令与工程检查见 AGENTS。额外的真实本机 supervisor 测试：

```bash
python3 test/native/process_runner_test.py
```

Android instrumentation 的 `linux-native` 场景使用已准备在应用 `no_backup/e3-native-fixture/rootfs` 的测试镜像，验证实际 JNI 目录启动、stdin/stdout/stderr、非零退出、工作区文件及停止后的子进程回收。该场景不启动 Dart、不打开业务数据库；2026-09-19 已在 Android 16 / targetSdk 36 的授权设备通过；启动需显式设置 `PROOT_TMP_DIR`。它不替代进程桥、前台服务、Activity 重建或环境 UI 的真机验收。设备测试前仍按 AGENTS 确认授权设备与保留数据的安装路径。

## 同类项目对照（2026-09-19 本地检出）

| 项目 | 源码入口（相对各项目根目录） | 对相月的适用范围 |
|---|---|---|
| Kelivo | `android/app/src/main/kotlin/com/psyche/kelivo/workspace/{ProotCommand,RootfsExtractor,ExecRunner}.kt` | JNI 执行文件、独立宿主 tmp、应用内解压、字节事件与可持续 stdin；PTY 独立。测试见 `integration_test/workspace/android_proot_test.dart`。 |
| RikkaHub | `workspace/src/main/java/me/rerere/workspace/{ProotShellRunner,RootfsInstaller,WorkspaceShellRunner}.kt` | targetSdk 37 + JNI 提取，固定 PRoot/loader 路径；下载和解压阶段、双路消费、stdin 关闭。其超时/截断语义与相月不同，不直接替换本项目进程契约。 |
| Operit | `app/src/main/java/com/ai/assistance/operit/core/tools/system/Terminal.kt`；终端子模块的 `TerminalManager.kt` / `provider/type/LocalTerminalProvider.kt` | PRoot/loader 位于 JNI 目录；可见终端使用 PTY，隐藏执行使用持久 shell、合并输出和文本标记，并向命令进程组发送 TERM/KILL。只参考任务归属和生命周期，原始 stdio 不采用文本标记。 |
| Aether | `app/src/main/java/com/zhousl/aether/runtime/AlpineRuntime.kt`、`app/build.gradle.kts` | Alpine assets、应用内解压与宿主 tmp 分离；当前 targetSdk 28，使用 linker64 启动私有目录程序，这条执行路径不用于相月。 |

Operit 本地 `terminal` 未初始化，本批按主仓库固定的 `e4442bc6a047b6165bf59103721ad143149c620d` 下载 [OperitTerminalCore 源码](https://github.com/AAswordman/OperitTerminalCore/tree/e4442bc6a047b6165bf59103721ad143149c620d) 至忽略的 `build/e3_references/` 后检查，没有修改四个参考仓库。

相月保留 Ubuntu、targetSdk 36、JNI 目录执行、Dart 工具循环和独立原始管道。环境根目录由原生返回规范化路径，避免 `/data/user/0` 与 `/data/data` 别名触发 `setModes` 的路径一致性校验；每个进程使用独立宿主临时目录。

真机复验还纠正了测试准备竞态：覆盖安装后原 Activity 可能恢复，自动探针在 shell 解压完成之前开始读目录。测试应先停止旧进程，完成测试文件准备后写入明确就绪信号，再启动/放行探针。加入该信号后，原预解压镜像与应用内解压均通过；没有发现 PRoot 删除 rootfs 链接的证据。复现与结果分别在本批忽略的 `build/e3_bridge_probe.dart`、`build/e3_bridge_verify.py` 和 `build/e3_device/`。
