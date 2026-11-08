import 'package:rhttp/rhttp.dart';

class HttpClientWrapper {
  HttpClientWrapper._(this._client);

  /// [settings] is [NetworkProxyController.rhttpSettings], or what a worker isolate got.
  static Future<HttpClientWrapper> create(ClientSettings? settings) async {
    return HttpClientWrapper._(await RhttpClient.create(settings: settings));
  }

  static HttpClientWrapper createSync(ClientSettings? settings) {
    return HttpClientWrapper._(RhttpClient.createSync(settings: settings));
  }

  bool get isClosed => _closed;

  bool _closed = false;

  final RhttpClient _client;

  Future<HttpTextResponse?> getUrlNullable(
    String url, {
    Map<String, String>? headers,
    required CancelToken? cancelToken,
  }) async {
    try {
      return await getUrl(
        url,
        headers: headers,
        cancelToken: cancelToken,
      );
    } catch (_) {
      return null;
    }
  }

  Future<HttpTextResponse> getUrl(
    String url, {
    Map<String, String>? headers,
    required CancelToken? cancelToken,
  }) async {
    return await _client.get(
      url,
      headers: headers == null ? null : HttpHeaders.rawMap(headers),
      cancelToken: cancelToken,
    );
  }

  Future<HttpBytesResponse> getBytes(
    String url, {
    Map<String, String>? headers,
    required CancelToken? cancelToken,
  }) async {
    if (_closed) throw Exception('client is closed');
    return await _client.getBytes(
      url,
      headers: headers == null ? null : HttpHeaders.rawMap(headers),
      cancelToken: cancelToken,
    );
  }

  Future<HttpStreamResponse> getStream(
    String url, {
    Map<String, String>? headers,
    required CancelToken? cancelToken,
  }) async {
    if (_closed) throw Exception('client is closed');
    return await _client.getStream(
      url,
      headers: headers == null ? null : HttpHeaders.rawMap(headers),
      cancelToken: cancelToken,
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _client.dispose(cancelRunningRequests: true);
  }
}

/// one-off requests, instead of calling [Rhttp] directly. [settings] is required so the proxy can't be forgotten:
/// [NetworkProxyController.rhttpSettings] in the main isolate, the value passed in for other isolates.
abstract final class NamidaHttp {
  static Future<HttpTextResponse> get(
    String url, {
    required ClientSettings? settings,
    HttpHeaders? headers,
    CancelToken? cancelToken,
  }) {
    return Rhttp.get(
      url,
      settings: settings,
      headers: headers,
      cancelToken: cancelToken,
    );
  }

  static Future<HttpBytesResponse> getBytes(
    String url, {
    required ClientSettings? settings,
    HttpHeaders? headers,
    CancelToken? cancelToken,
  }) {
    return Rhttp.getBytes(
      url,
      settings: settings,
      headers: headers,
      cancelToken: cancelToken,
    );
  }
}
