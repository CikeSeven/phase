#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

dart run pigeon --input pigeons/execution_api.dart
dart run pigeon --input pigeons/process_api.dart
dart run pigeon --input pigeons/command_api.dart
dart format lib/features/execution/execution_api.g.dart lib/features/workspace/process_api.g.dart lib/features/commands/command_api.g.dart
# Pigeon 的 Kotlin 输出带行尾空格；统一由生成入口归一化，不手改生成物。
sed -i 's/[[:blank:]]*$//' android/app/src/main/kotlin/app/xiangyue/phase/bridge/ExecutionApi.g.kt android/app/src/main/kotlin/app/xiangyue/phase/bridge/ProcessApi.g.kt android/app/src/main/kotlin/app/xiangyue/phase/bridge/CommandApi.g.kt
