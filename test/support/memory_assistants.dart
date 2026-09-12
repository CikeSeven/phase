import 'package:phase/data/models/assistant.dart';
import 'package:phase/data/repositories/assistant_repository.dart';

/// 内存助手仓储：只依赖助手列表的用例用它代替真实数据库。
///
/// 聊天链路会解析「当前助手」，因此凡是渲染聊天页或依赖模型选择的
/// widget 测试都需要注入它，避免去开真实数据库。
class MemoryAssistants implements AssistantRepository {
  MemoryAssistants([List<Assistant>? seed])
    : items =
          seed ??
          [
            Assistant(
              id: 'assistant-default',
              name: '普通助手',
              systemPrompt: '',
              createdAt: DateTime(2026),
            ),
          ];

  final List<Assistant> items;

  @override
  Stream<List<Assistant>> watchAssistants() => Stream.value(items);

  @override
  Future<List<Assistant>> getAssistants() async => items;

  @override
  Future<Assistant?> getById(String id) async =>
      items.where((item) => item.id == id).firstOrNull;

  @override
  Future<Assistant> ensureDefault() async => items.first;

  @override
  Future<Assistant> save(Assistant assistant) async => assistant;

  @override
  Future<void> delete(String id) async {}
}
