// by claude
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:archive/archive.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

const _kDocsAssetPath = 'assets/docs.tar.xz';

/// serves the docs site bundled by `scripts/bundle_docs.py` on localhost.
class OfflineDocs {
  const OfflineDocs._();

  static Future<_OfflineDocsServer>? _serverFuture;

  static Future<bool> open(String link) async {
    final _OfflineDocsServer server;
    try {
      final serverFuture = _serverFuture ??= _OfflineDocsServer.start();
      server = await serverFuture;
    } catch (e, st) {
      _serverFuture = null;
      logger.error('Offline docs failed to start', e: e, st: st);
      return NamidaLinkUtils.openLink(link);
    }

    final localUrl = server.toLocalUrl(link);
    if (Platform.isAndroid) {
      NamidaNavigator.inst.navigateToRoot(
        _OfflineDocsPage(url: localUrl),
        transition: Transition.native,
      );
      return true;
    }
    return NamidaLinkUtils.openLink(localUrl);
  }

  static Future<void> _closeServer() async {
    final serverFuture = _serverFuture;
    _serverFuture = null;
    final server = await serverFuture;
    await server?.close();
  }
}

class _OfflineDocsServer {
  final HttpServer _httpServer;
  final Map<String, Uint8List> _files;

  _OfflineDocsServer._(this._httpServer, this._files) {
    _httpServer.listen(_onRequest);
  }

  static Future<_OfflineDocsServer> start() async {
    final data = await rootBundle.load(_kDocsAssetPath);
    final xzBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final files = await _decodeArchive.thready(xzBytes);
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _OfflineDocsServer._(httpServer, files);
  }

  static Map<String, Uint8List> _decodeArchive(Uint8List xzBytes) {
    final tarBytes = XZDecoder().decodeBytes(xzBytes);
    final archive = TarDecoder().decodeBytes(tarBytes);
    final files = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final bytes = file.readBytes();
      if (bytes != null) files[file.name] = bytes;
    }
    return files;
  }

  String toLocalUrl(String link) {
    final uri = Uri.parse(link);
    final localUri = uri.replace(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: _httpServer.port,
    );
    return localUri.toString();
  }

  Future<void> close() => _httpServer.close(force: true);

  void _onRequest(HttpRequest request) {
    final response = request.response;
    final decodedPath = Uri.decodeComponent(request.uri.path);
    final path = decodedPath.substring(1);
    final isDirectory = path.isEmpty || path.endsWith('/');
    final filePath = isDirectory ? '${path}index.html' : path;

    final bytes = _files[filePath];
    if (bytes != null) {
      _respond(response, HttpStatus.ok, filePath, bytes);
      return;
    }

    // -- pages link relative to their own folder, so the folder needs its trailing slash
    if (_files.containsKey('$path/index.html')) {
      final folderUri = Uri(path: '/$path/');
      response.redirect(folderUri, status: HttpStatus.movedPermanently).ignoreError();
      return;
    }

    final notFoundBytes = _files['404.html'] ?? Uint8List(0);
    _respond(response, HttpStatus.notFound, '404.html', notFoundBytes);
  }

  static const _kContentTypes = {
    'html': 'text/html; charset=utf-8', 'css': 'text/css; charset=utf-8', 'js': 'text/javascript; charset=utf-8', //
    'json': 'application/json', 'png': 'image/png', 'svg': 'image/svg+xml', //
  };

  static void _respond(HttpResponse response, int statusCode, String filePath, Uint8List bytes) {
    final fileExtension = filePath.splitLast('.');
    final contentType = _kContentTypes[fileExtension];
    response.statusCode = statusCode;
    if (contentType != null) response.headers.set(HttpHeaders.contentTypeHeader, contentType);
    response.contentLength = bytes.length;
    response.add(bytes);
    response.close().ignoreError();
  }
}

class _OfflineDocsPage extends StatefulWidget {
  final String url;

  const _OfflineDocsPage({required this.url});

  @override
  State<_OfflineDocsPage> createState() => _OfflineDocsPageState();
}

class _OfflineDocsPageState extends State<_OfflineDocsPage> {
  InAppWebViewController? _controller;
  final _title = ''.obso;

  @override
  void dispose() {
    _title.close();
    OfflineDocs._closeServer();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final controller = _controller;
    if (controller != null) {
      final canGoBack = await controller.canGoBack();
      if (canGoBack) {
        await controller.goBack();
        return false;
      }
    }
    NamidaNavigator.inst.popRoot();
    return false;
  }

  Future<NavigationActionPolicy> _onNavigation(InAppWebViewController controller, NavigationAction action) async {
    final url = action.request.url;
    if (url == null || url.host == InternetAddress.loopbackIPv4.address) return NavigationActionPolicy.ALLOW;
    NamidaLinkUtils.openLink(url.toString());
    return NavigationActionPolicy.CANCEL;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final initialUrl = WebUri(widget.url);
    final docsTheme = theme.brightness == Brightness.dark ? 'dark' : 'light';
    final themeScript = UserScript(
      source: "localStorage.setItem('docmd-theme', '$docsTheme');",
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );
    return NamidaPopScope(
      onWillPop: _onWillPop,
      child: BackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 4.0),
                  IconButton(
                    onPressed: NamidaNavigator.inst.popRoot,
                    icon: const Icon(
                      Broken.arrow_left_2,
                      size: 24.0,
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Expanded(
                    child: ObxO(
                      rx: _title,
                      builder: (context, title) => NamidaText(
                        title,
                        style: NText.medium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                ],
              ),
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: initialUrl),
                  initialUserScripts: UnmodifiableListView([themeScript]),
                  initialSettings: InAppWebViewSettings(
                    transparentBackground: true,
                    useShouldOverrideUrlLoading: true,
                  ),
                  onWebViewCreated: (controller) => _controller = controller,
                  onTitleChanged: (controller, title) => _title.value = title ?? '',
                  shouldOverrideUrlLoading: _onNavigation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
