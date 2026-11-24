import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/error/failure.dart';
import '../../data/models/attachment.dart';
import '../execution/execution_api.g.dart';

Future<bool> saveContentFile(Attachment attachment) async {
  final file = File(attachment.localPath);
  try {
    if (!await file.exists()) throw const OperationFailure('附件文件暂不可用');
    if (await file.length() > 256 * 1024 * 1024) {
      throw const OperationFailure('单次保存的文件上限为 256 MiB');
    }
    final name = p.basename(attachment.name);
    if (Platform.isAndroid) {
      return await ExecutionSetupApi().exportAttachment(
        file.path,
        name,
        attachment.mimeType,
      );
    }
    return await FilePicker.saveFile(
          fileName: name,
          mimeType: attachment.mimeType,
          bytes: await file.readAsBytes(),
        ) !=
        null;
  } on PlatformException catch (error) {
    throw OperationFailure(
      error.code == 'unavailable'
          ? '已有文件选择器打开，或保存位置未选择完成'
          : '保存文件失败，请检查附件和目标位置',
    );
  } on FileSystemException {
    throw const OperationFailure('无法读取或保存附件');
  }
}
