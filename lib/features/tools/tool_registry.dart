import '../workspace/shell_tool.dart';
import 'file_tools.dart';
import 'http_tool.dart';
import 'tool.dart';
import '../execution/channel_driver.dart';
import '../execution/execution_api.g.dart';
import '../execution/platform_tools.dart';
import '../execution/visual_tools.dart';

/// 首版内置工具集。
///
/// 私有文件在 Dart 处理，显式授权 URI 与 UI 工具经同一平台通道执行。
ToolRegistry buildBuiltInRegistry({
  required Future<HttpFetchResult> Function(HttpFetchRequest request) httpFetch,
  int maxHttpBytes = 512 * 1024,
  ChannelDriver Function()? platform,
}) {
  return ToolRegistry([
    const SystemInfoTool(),
    const ShellTool(),
    for (final tool in const [ReadFileTool(), WriteFileTool(), ListFilesTool()])
      if (platform == null) tool else ScopedFileTool(tool, platform),
    if (platform != null)
      for (final action in const [
        ExecutionAction.listApps,
        ExecutionAction.openApp,
        ExecutionAction.inspectUi,
        ExecutionAction.clickNode,
        ExecutionAction.scroll,
        ExecutionAction.inputText,
      ])
        ApplicationTool(action, platform),
    if (platform != null) ...[
      VisualTool(ExecutionAction.captureScreen, platform),
      VisualTool(ExecutionAction.performGestures, platform),
    ],
    HttpRequestTool(fetch: httpFetch, maxBytes: maxHttpBytes),
  ]);
}
