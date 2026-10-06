import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/error/failure.dart';
import '../../models/web_search_result.dart';
import 'web_page_text.dart';
import 'web_request_scope.dart';

/// 匿名网页读取。每跳重新审查 DNS 并固定实际连接地址，禁止访问私网和携带凭据。
class WebFetchClient {
  const WebFetchClient();
  static const maxResponseBytes = 2 * 1024 * 1024;
  static const maxRedirects = 5;

  static Uri validateUrl(String value) {
    final uri = Uri.tryParse(value);
    if (value.length > 4096 ||
        uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw const WebFailure('invalidUrl', '网页地址须为不含凭据的完整 HTTP(S) URL');
    }
    return uri.replace(fragment: '');
  }

  Future<WebFetchResult> fetch(
    String url,
    WebRequestScope scope, {
    required int maxCharacters,
  }) async {
    var uri = validateUrl(url);
    try {
      for (var hop = 0; hop <= maxRedirects; hop++) {
        scope.check();
        final addresses = await scope.guard(InternetAddress.lookup(uri.host));
        if (addresses.isEmpty ||
            addresses.any((address) => !_publicAddress(address))) {
          throw const WebFailure(
            'blockedDestination',
            '网页读取仅支持公网地址，不访问本机、私网或保留地址',
          );
        }
        final client = HttpClient()
          ..autoUncompress = true
          // 连接固定到已审查的目标 IP，不让环境代理改变连接协议。
          ..findProxy = null;
        // 自定义 factory 必须提供已完成 TLS 握手的 HTTPS socket；
        // HttpClient 不会为 factory 返回的普通 Socket 自动启用 TLS。
        client.connectionFactory = (target, proxyHost, proxyPort) async {
          scope.check();
          return _connect(addresses, target, scope);
        };
        var active = true;
        scope.whenAborted.then((_) {
          if (active) client.close(force: true);
        }).ignore();
        try {
          final request = await scope.guard(client.getUrl(uri));
          request.followRedirects = false;
          request.headers.set(
            HttpHeaders.userAgentHeader,
            'Phase/1.0 (Web Fetch)',
          );
          request.headers.set(
            HttpHeaders.acceptHeader,
            'text/html, text/plain, application/json, application/pdf;q=0.8',
          );
          final response = await scope.guard(request.close());
          final status = response.statusCode;
          if (const {301, 302, 303, 307, 308}.contains(status)) {
            final location = response.headers.value(HttpHeaders.locationHeader);
            if (location == null || hop == maxRedirects) {
              throw const WebFailure('redirectLimit', '网页重定向无效或次数超过上限');
            }
            uri = validateUrl(uri.resolve(location).toString());
            continue;
          }
          final body = await readWebResponse(
            response,
            scope,
            maxBytes: maxResponseBytes,
            allowTruncation: true,
          );
          scope.check();
          final raw = body.bytes;
          var truncated = body.truncated;
          final type = response.headers.contentType;
          final mime = type?.mimeType.toLowerCase() ?? '';
          String content;
          String? title;
          if (mime == 'application/pdf') {
            if (truncated) {
              throw const WebFailure('responseTooLarge', 'PDF 超过读取上限，请使用较小的文档');
            }
            final document = PdfDocument(inputBytes: raw);
            try {
              if (document.pages.count > 100) {
                throw const WebFailure(
                  'responseTooLarge',
                  'PDF 超过 100 页，请读取较小的文档',
                );
              }
              final text = StringBuffer();
              final extractor = PdfTextExtractor(document);
              for (var page = 0; page < document.pages.count; page++) {
                scope.check();
                final pageText = extractor.extractText(
                  startPageIndex: page,
                  endPageIndex: page,
                );
                final remaining = maxCharacters - text.length;
                text.write(clipWebText(pageText, remaining));
                if (pageText.length > remaining ||
                    text.length == maxCharacters) {
                  truncated |=
                      pageText.length > remaining ||
                      page < document.pages.count - 1;
                  break;
                }
                if (page < document.pages.count - 1 &&
                    text.length < maxCharacters) {
                  text.write('\n');
                }
              }
              content = text.toString();
              title = document.documentInformation.title;
            } finally {
              document.dispose();
            }
          } else {
            if (!(mime.startsWith('text/') ||
                const {
                  'application/json',
                  'application/xml',
                  'application/xhtml+xml',
                }.contains(mime))) {
              throw const WebFailure(
                'unsupportedContent',
                '此网页未返回可读文本、HTML 或 PDF',
              );
            }
            final encoding = Encoding.getByName(type?.charset ?? 'utf-8');
            if (encoding == null) {
              throw const WebFailure('unsupportedEncoding', '此网页使用了不支持的字符编码');
            }
            final text = encoding == latin1
                ? latin1.decode(raw)
                : encoding == utf8
                ? utf8.decode(raw, allowMalformed: truncated)
                : encoding.decode(raw);
            if (mime == 'text/html' || mime == 'application/xhtml+xml') {
              final rendered = webPageText(text, uri, maxCharacters);
              content = rendered.content;
              title = rendered.title;
              truncated |= rendered.truncated;
            } else {
              content = text;
            }
          }
          scope.check();
          truncated |= content.length > maxCharacters;
          return WebFetchResult(
            url: uri.toString(),
            statusCode: status,
            content: clipWebText(content, maxCharacters),
            title: title,
            retrievedAt: DateTime.now().toUtc(),
            truncated: truncated,
          );
        } finally {
          active = false;
          client.close(force: true);
        }
      }
      throw const WebFailure('redirectLimit', '网页重定向次数超过上限');
    } on WebFailure {
      rethrow;
    } on HandshakeException {
      scope.check();
      throw const WebFailure('certificate', '网页证书校验失败');
    } on SocketException {
      scope.check();
      throw const WebFailure('network', '网页连接失败，请检查地址与网络');
    } on Object {
      scope.check();
      throw const WebFailure('invalidResponse', '未收到可解析的完整网页内容');
    }
  }

  static ConnectionTask<Socket> _connect(
    List<InternetAddress> addresses,
    Uri uri,
    WebRequestScope scope,
  ) {
    ConnectionTask<Socket>? pending;
    var cancelled = false;
    Future<Socket> dial() async {
      // lookup 返回的 InternetAddress 保留原始 host：连接固定 IP，
      // SecureSocket 仍以原域名发送 SNI 并校验证书，不再查询 DNS。
      for (final address in addresses) {
        scope.check();
        if (cancelled) throw const WebFailure('cancelled', '网页请求已停止');
        try {
          final ConnectionTask<Socket> task = uri.isScheme('https')
              ? await SecureSocket.startConnect(address, uri.port)
              : await Socket.startConnect(address, uri.port);
          pending = task;
          if (cancelled) task.cancel();
          final socket = await scope.guard(
            task.socket.timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                task.cancel();
                throw const SocketException('Connection timed out');
              },
            ),
          );
          if (cancelled) {
            socket.destroy();
            throw const WebFailure('cancelled', '网页请求已停止');
          }
          return socket;
        } on SocketException {
          pending?.cancel();
          scope.check();
        }
      }
      throw const WebFailure('network', '网页连接失败，请检查地址与网络');
    }

    return ConnectionTask.fromSocket(dial(), () {
      cancelled = true;
      pending?.cancel();
    });
  }

  static bool _publicAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      final a = bytes[0], b = bytes[1], c = bytes[2];
      return !(a == 0 ||
          a == 10 ||
          a == 127 ||
          a >= 224 ||
          (a == 100 && b >= 64 && b <= 127) ||
          (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && (b == 168 || b == 0 || (b == 88 && c == 99))) ||
          (a == 198 && (b == 18 || b == 19 || (b == 51 && c == 100))) ||
          (a == 203 && b == 0 && c == 113));
    }
    final mapped =
        bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 0xff &&
        bytes[11] == 0xff;
    final nat64 =
        bytes[0] == 0 &&
        bytes[1] == 0x64 &&
        bytes[2] == 0xff &&
        bytes[3] == 0x9b &&
        bytes.skip(4).take(8).every((byte) => byte == 0);
    if (mapped || nat64) {
      return _publicAddress(
        InternetAddress.fromRawAddress(
          bytes.sublist(12),
          type: InternetAddressType.IPv4,
        ),
      );
    }
    // 原生 IPv6 仅全球单播；排除文档和未审查的隧道地址空间。
    return (bytes[0] & 0xe0) == 0x20 &&
        !(bytes[0] == 0x20 && bytes[1] == 0x02) &&
        !(bytes[0] == 0x20 &&
            bytes[1] == 0x01 &&
            ((bytes[2] == 0x0d && bytes[3] == 0xb8) || bytes[2] == 0));
  }
}
