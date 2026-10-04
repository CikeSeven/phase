import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_snack_bar.dart';

/// 外部内容不能借链接执行自定义 URI、intent 或带内嵌凭据的地址。
Future<void> openExternalWebLink(BuildContext context, String value) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !const {'https', 'http'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    messenger?.showSnackBar(
      buildAppSnackBar(content: const Text('此链接不是有效的网页地址')),
    );
    return;
  }
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (context.mounted && !opened) {
      messenger?.showSnackBar(
        buildAppSnackBar(content: const Text('暂时无法打开链接')),
      );
    }
  } on Object {
    if (context.mounted) {
      messenger?.showSnackBar(
        buildAppSnackBar(content: const Text('暂时无法打开链接')),
      );
    }
  }
}
