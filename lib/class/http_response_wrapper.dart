import 'package:rhttp/rhttp.dart';

class HttpClientWrapper {
  HttpClientWrapper._(this._client);

  static Future<HttpClientWrapper> create() async {
    return HttpClientWrapper._(await RhttpClient.create());
  }

  static HttpClientWrapper createSync() {
    return HttpClientWrapper._(RhttpClient.createSync());
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
