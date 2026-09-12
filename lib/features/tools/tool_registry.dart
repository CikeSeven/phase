import 'file_tools.dart';
import 'http_tool.dart';
import 'tool.dart';

/// 首版内置工具集。
///
/// 文件工具只访问应用私有目录（当前会话的附件与本会话产物）；
/// 用户选定外部目录的 SAF 路径在 S4 接通。
ToolRegistry buildBuiltInRegistry({
  required Future<HttpFetchResult> Function(HttpFetchRequest request) httpFetch,
  int maxHttpBytes = 512 * 1024,
}) {
  return ToolRegistry([
    const SystemInfoTool(),
    const ReadFileTool(),
    const WriteFileTool(),
    const ListFilesTool(),
    HttpRequestTool(fetch: httpFetch, maxBytes: maxHttpBytes),
  ]);
}
