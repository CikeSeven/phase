// 拉取 models.dev 全量目录并生成内置快照 assets/models_catalog.json。
// 运行：dart run tool/generate_models_catalog.dart
// 快照随仓库提交，按需重跑，不进 CI。
import 'dart:convert';
import 'dart:io';

import 'package:phase/data/models/model_catalog.dart';

const _source = 'https://models.dev/api.json';
const _output = 'assets/models_catalog.json';

Future<void> main() async {
  final client = HttpClient();
  try {
    stdout.writeln('正在拉取 $_source ...');
    final request = await client.getUrl(Uri.parse(_source));
    final response = await request.close();
    if (response.statusCode != 200) {
      stderr.writeln('拉取失败：HTTP ${response.statusCode}');
      exitCode = 1;
      return;
    }
    final body = await utf8.decoder.bind(response).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      stderr.writeln('响应不是预期的 JSON 对象');
      exitCode = 1;
      return;
    }
    final catalog = ModelCatalog.slimFromModelsDevJson(decoded);
    if (catalog.modelCount == 0) {
      stderr.writeln('响应未包含有效模型上限，保留现有快照');
      exitCode = 1;
      return;
    }
    // key 排序保证 diff 稳定。
    final sorted = <String, dynamic>{
      ...catalog.toJson(),
      'providers': {
        for (final providerId in catalog.providers.keys.toList()..sort())
          providerId: {
            for (final modelId
                in catalog.providers[providerId]!.keys.toList()..sort())
              modelId: catalog.providers[providerId]![modelId]!.toJson(),
          },
      },
    };
    final out = File(_output);
    await out.parent.create(recursive: true);
    await out.writeAsString(jsonEncode(sorted));
    final bytes = await out.length();
    stdout.writeln(
      '已写入 $_output：${catalog.providers.length} 个服务商、'
      '${catalog.modelCount} 个模型、$bytes 字节',
    );
  } finally {
    client.close();
  }
}
