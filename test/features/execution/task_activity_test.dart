import 'package:flutter_test/flutter_test.dart';
import 'package:phase/features/execution/execution_api.g.dart';
import 'package:phase/features/execution/task_activity.dart';

TaskMessage message(
  String id,
  String text, {
  TaskPanelMessageKind kind = TaskPanelMessageKind.text,
}) => TaskMessage(
  id: id,
  kind: kind,
  label: kind == TaskPanelMessageKind.reasoning ? '思考' : '相月',
  text: text,
);

void main() {
  test('流式完成快照原位替换，前轮消息和工具保持实际顺序', () {
    var activity = const TaskActivity().replaceResponse('first', [
      message('first/r', '思考片段', kind: TaskPanelMessageKind.reasoning),
      message('first/t', '先读取文件'),
    ]);
    activity = activity.upsert(
      message('tool/read', 'notes.md', kind: TaskPanelMessageKind.tool),
    );
    activity = activity.replaceResponse('second', [message('second/t', '读到了')]);
    activity = activity.replaceResponse('second', [
      message('second/t', '读到了完整的正文'),
    ]);
    expect(activity.messages.map((m) => m.id), [
      'first/r',
      'first/t',
      'tool/read',
      'second/t',
    ]);
    expect(activity.messages.last.text, '读到了完整的正文');
    activity = activity.upsert(
      message('tool/read', '读取已完成', kind: TaskPanelMessageKind.tool),
    );
    expect(activity.messages.map((m) => m.id), [
      'first/r',
      'first/t',
      'tool/read',
      'second/t',
    ]);
  });

  test('最多携带最近六项，每项限长且不截断 UTF-16 代理对', () {
    var activity = const TaskActivity();
    for (var index = 0; index < 12; index++) {
      activity = activity.upsert(
        message('item/$index', '${'月' * 600}😀$index'),
      );
    }
    expect(activity.messages, hasLength(6));
    expect(activity.messages.first.id, 'item/6');
    expect(activity.messages.last.id, 'item/11');
    expect(activity.messages.every((m) => m.text.length <= 481), isTrue);
    expect(activity.messages.last.text, endsWith('😀11'));
    expect(
      () => activity.messages.add(message('more', '不应变更')),
      throwsUnsupportedError,
    );
  });

  test('开始后续模型请求保留工具结果文案与消息，不退回等待模型响应', () {
    final activity = const TaskActivity()
        .copyWith(status: '执行了读取文件', lastToolStatus: '执行了读取文件')
        .upsert(
          message('tool/read', 'notes.md', kind: TaskPanelMessageKind.tool),
        );
    final waiting = activity.waitForResponse();
    expect(waiting.phase, TaskPanelPhase.waitingModel);
    expect(waiting.status, '执行了读取文件');
    expect(waiting.messages.single.text, 'notes.md');
    expect(const TaskActivity().waitForResponse().status, '正在处理');
  });
}
