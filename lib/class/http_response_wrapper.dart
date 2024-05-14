import 'dart:io';

class HttpClientResponseWrapper {
  HttpClientResponseWrapper(this.client);

  bool get isClosed => _closed;

  final HttpClient client;
  bool _closed = false;

  HttpClientRequest? _request;
  HttpClientResponse? _response;

  Future<HttpClientResponse?> getUrlNullable(Uri url, {Map<String, String>? headers}) async {
    if (_closed) return null;
    try {
      _request = await client.getUrl(url);
      if (headers != null) {
        for (final h in headers.entries) {
          _request!.headers.set(h.key, h.value);
        }
      }
      _response = await _request!.close();
      return _response!;
    } catch (_) {
      return null;
    }
  }

  Future<HttpClientResponse> getUrl(Uri url, {Map<String, String>? headers}) async {
    if (_closed) throw Exception('socket is closed');
    _request = await client.getUrl(url);
    if (headers != null) {
      for (final h in headers.entries) {
        _request!.headers.set(h.key, h.value);
      }
    }
    _response = await _request!.close();
    return _response!;
  }

  Future<void> close() async {
    final socket = await _response?.detachSocket();
    await socket?.close();
    _request?.abort();
    _closed = true;
  }
}
