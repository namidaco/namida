import 'dart:io';

class HttpClientWrapper {
  HttpClientWrapper() : _client = HttpClient();

  bool get isClosed => _closed;

  bool _closed = false;

  final HttpClient _client;

  Future<HttpClientResponse?> getUrlNullable(Uri url, {Map<String, String>? headers}) async {
    try {
      return await getUrl(url);
    } catch (_) {
      return null;
    }
  }

  Future<HttpClientResponse?> getUrlWithHeadersNullable(Uri url, {Map<String, String>? headers}) async {
    try {
      return await getUrlWithHeaders(url, headers);
    } catch (_) {
      return null;
    }
  }

  Future<HttpClientResponse> getUrl(Uri url) async {
    if (_closed) throw Exception('client is closed');
    final request = await _client.getUrl(url);
    return await request.close();
  }

  Future<HttpClientResponse> getUrlWithHeaders(Uri url, Map<String, String>? headers) async {
    if (_closed) throw Exception('client is closed');
    final request = await _client.getUrl(url);
    if (headers != null) {
      for (final h in headers.entries) {
        request.headers.set(h.key, h.value);
      }
    }
    return await request.close();
  }

  Future<void> close() async {
    _closed = true;
    _client.close(force: true);
  }
}
