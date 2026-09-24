import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_scaffold.dart';

/// 只预览打开时的代码快照，不跟随聊天流刷新或写回消息。
class HtmlPreviewPage extends StatefulWidget {
  const HtmlPreviewPage({required this.code, super.key});

  final String? code;

  @override
  State<HtmlPreviewPage> createState() => _HtmlPreviewPageState();
}

class _HtmlPreviewPageState extends State<HtmlPreviewPage> {
  WebViewController? _controller;
  bool _opening = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(_stop(controller));
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening) return;
    final code = widget.code;
    if (code == null) {
      setState(() {
        _error = '没有可预览的 HTML 代码';
        _loading = false;
      });
      return;
    }
    final previous = _controller;
    setState(() {
      _controller = null;
      _opening = true;
      _loading = true;
      _error = null;
    });
    WebViewController? controller;
    try {
      if (previous != null) await _stop(previous);
      if (!mounted) return;
      final preview = WebViewController();
      controller = preview;
      final android = preview.platform as AndroidWebViewController;
      // HTML 不获得文件、内容提供器或定位访问，也不注册应用 JS 桥。
      // 媒体权限和文件选择沿用插件默认拒绝行为。
      await android.setAllowFileAccess(false);
      await android.setAllowContentAccess(false);
      await android.setGeolocationEnabled(false);
      await android.setMediaPlaybackRequiresUserGesture(true);
      // 接管控制台但不输出，避免网页把代码或用户内容写入系统日志。
      await preview.setOnConsoleMessage((_) {});
      await preview.setBackgroundColor(Colors.white);
      await preview.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (!mounted || _controller != preview) {
              return NavigationDecision.prevent;
            }
            // 保留文档内锚点；预览页不作为外链浏览器或应用启动入口。
            final uri = Uri.tryParse(request.url);
            return uri?.scheme == 'about' && uri?.path == 'blank'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (!mounted || _controller != preview) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (!mounted ||
                _controller != preview ||
                error.isForMainFrame != true) {
              return;
            }
            // 图片、字体等子资源失败不覆盖仍可阅读的页面。
            setState(() {
              _error = 'HTML 预览加载失败';
              _loading = false;
            });
          },
        ),
      );
      await preview.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (!mounted) return;
      setState(() => _controller = preview);
      // 直接加载原文，不生成临时文件，不赋予应用或工作区的来源地址。
      await preview.loadHtmlString(code);
    } catch (_) {
      AppLogger.warning('HTML preview could not be opened.');
      if (mounted) {
        setState(() {
          _controller = null;
          _error = '无法打开 HTML 预览，请检查系统 WebView 后重试';
          _loading = false;
        });
      }
    } finally {
      if (controller != null && (!mounted || _controller != controller)) {
        await _stop(controller);
      }
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _stop(WebViewController controller) async {
    try {
      await controller.setJavaScriptMode(JavaScriptMode.disabled);
      // 控制器没有 dispose；移除文档以停止脚本和媒体，原生对象由插件管理。
      await controller.loadHtmlString('');
    } catch (_) {
      AppLogger.warning('HTML preview cleanup failed.');
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'HTML 预览',
    maxBodyWidth: double.infinity,
    body: _error != null
        ? Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  if (widget.code != null) ...[
                    const SizedBox(height: AppSpacing.l),
                    FilledButton.tonal(
                      onPressed: _opening ? null : _open,
                      child: const Text('重试'),
                    ),
                  ],
                ],
              ),
            ),
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              if (_controller case final controller?)
                WebViewWidget(controller: controller),
              if (_loading)
                const IgnorePointer(
                  child: Center(
                    child: AppLoadingIndicator(semanticsLabel: '正在加载 HTML 预览'),
                  ),
                ),
            ],
          ),
  );
}
