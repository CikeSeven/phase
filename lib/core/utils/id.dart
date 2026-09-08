import 'dart:math';

final _random = Random();

/// 生成本地唯一 id（时间戳 + 随机后缀，无第三方 uuid 依赖）。
String generateId() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final suffix = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
  return '${timestamp}_$suffix';
}
