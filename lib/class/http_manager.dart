import 'dart:typed_data';

import 'package:queue/queue.dart';
import 'package:rhttp/rhttp.dart';

// some fixes rewrite by claude
class HttpMultiRequestManager {
  HttpMultiRequestManager._(this._mainClients)
    : _thumbQueues = List<Queue>.generate(
        _mainClients.length,
        (_) => Queue(parallel: 12),
        growable: false,
      ), // queue not only handle performance, but also help preventing RST packets
      _runningRequestsCount = Int32List(_mainClients.length);

  static Future<HttpMultiRequestManager> create([int clientsCount = 1]) async {
    final clients = await Future.wait(List.generate(clientsCount, (_) => RhttpClient.create()));
    return HttpMultiRequestManager._(clients);
  }

  factory HttpMultiRequestManager.createSync({int listsMaxItems = 2}) {
    return HttpMultiRequestManager._(
      List<RhttpClient>.generate(listsMaxItems, (_) => RhttpClient.createSync(), growable: false),
    );
  }

  final List<RhttpClient> _mainClients;
  final List<Queue> _thumbQueues;
  final Int32List _runningRequestsCount;

  int _getLeastBusyIndex() {
    final counts = _runningRequestsCount;
    int index = 0;
    int minimum = counts[0];
    for (int i = 1; i < counts.length; i++) {
      final count = counts[i];
      if (count < minimum) {
        minimum = count;
        index = i;
      }
    }
    return index;
  }

  Future<T> execute<T>(Future<T> Function(RhttpClient requester) closure) async {
    final index = _getLeastBusyIndex();
    _runningRequestsCount[index]++;
    try {
      return await closure(_mainClients[index]);
    } finally {
      _runningRequestsCount[index]--;
    }
  }

  Future<T> executeQueued<T>(Future<T> Function(RhttpClient requester) closure) async {
    final index = _getLeastBusyIndex();
    _runningRequestsCount[index]++;
    try {
      final client = _mainClients[index];
      return await _thumbQueues[index].add(() => closure(client));
    } finally {
      _runningRequestsCount[index]--;
    }
  }

  void closeClients() {
    for (final client in _mainClients) {
      client.dispose(cancelRunningRequests: true);
    }
  }
}
