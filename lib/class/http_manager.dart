import 'dart:io';

import 'package:queue/queue.dart';

class HttpMultiRequestManager {
  HttpMultiRequestManager({this.listsMaxItems = 2});
  final int listsMaxItems;

  late final _thumbQueues = List.filled(listsMaxItems, Queue(parallel: 12)); // queue not only handle performance, but also help preventing RST packets
  late final _mainClients = List.filled(listsMaxItems, HttpClient());
  late final _runningRequestsCount = List.filled(listsMaxItems, 0);

  int _getEffectiveIndex() {
    int minimum = _runningRequestsCount[0];

    for (int i = 0; i < _runningRequestsCount.length; i++) {
      final e = _runningRequestsCount[i];
      if (e < minimum) minimum = e;
    }

    return minimum;
  }

  Future<T> execute<T>(Future<T> Function() closure) async {
    final int listsIndex = _getEffectiveIndex();
    _runningRequestsCount[listsIndex]++;
    final res = await closure();
    _runningRequestsCount[listsIndex]--;
    return res;
  }

  Future<T> executeQueued<T>(Future<T> Function() closure) async {
    final int listsIndex = _getEffectiveIndex();
    _runningRequestsCount[listsIndex]++;
    final res = await _thumbQueues[listsIndex].add(closure);
    _runningRequestsCount[listsIndex]--;
    return res;
  }

  void closeClients() {
    for (final client in _mainClients) {
      client.close(force: true);
    }
  }
}
