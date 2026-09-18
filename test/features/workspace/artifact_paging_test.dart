import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phase/features/chat/artifact_text_sheet.dart';

void main() {
  test('large UTF-8 output pages read the entire artifact without broken boundaries', () async {
    final directory = Directory.systemTemp.createTempSync(
      'phase_artifact_pages_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/stdout.txt');
    final content = '${'相月' * 100000}\n末尾输出';
    await file.writeAsString(content);
    var offset = 0;
    final collected = StringBuffer();
    var count = 0;
    while (true) {
      final page = await readArtifactPage(file, offset);
      collected.write(page.text);
      count++;
      if (page.next == null) break;
      offset = page.next!;
    }
    expect(count, greaterThan(1));
    expect(collected.toString(), content);
  });
}
