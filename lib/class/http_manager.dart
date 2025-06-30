import 'package:queue/queue.dart';
import 'package:rhttp/rhttp.dart';

class HttpMultiRequestManager {
  HttpMultiRequestManager._(this._mainClients, {required this.listsMaxItems});

  static Future<HttpMultiRequestManager> create([int clientsCount = 1]) async {
    return HttpMultiRequestManager._(
      List<RhttpClient>.filled(clientsCount, await RhttpClient.create()),
      listsMaxItems: clientsCount,
    );
  }

  factory HttpMultiRequestManager.createSync({int listsMaxItems = 2}) {
    return HttpMultiRequestManager._(
      List<RhttpClient>.filled(listsMaxItems, RhttpClient.createSync()),
      listsMaxItems: listsMaxItems,
    );
  }

  final int listsMaxItems;
  final List<RhttpClient> _mainClients;

  late final _thumbQueues = List<Queue>.filled(listsMaxItems, Queue(parallel: 12)); // queue not only handle performance, but also help preventing RST packets

  late final _runningRequestsCount = List<int>.filled(listsMaxItems, 0);

  int _getEffectiveIndex() {
    int minimum = _runningRequestsCount[0];

    for (int i = 0; i < _runningRequestsCount.length; i++) {
      final e = _runningRequestsCount[i];
      if (e < minimum) minimum = e;
    }

    return minimum;
  }

  Future<T> execute<T>(Future<T> Function(RhttpClient requester) closure) async {
    final int listsIndex = _getEffectiveIndex();
    _runningRequestsCount[listsIndex]++;
    final client = _mainClients[listsIndex];
    final res = await closure(client);
    _runningRequestsCount[listsIndex]--;
    return res;
  }

  Future<T> executeQueued<T>(Future<T> Function(RhttpClient requester) closure) async {
    final int listsIndex = _getEffectiveIndex();
    _runningRequestsCount[listsIndex]++;
    final client = _mainClients[listsIndex];
    final res = await _thumbQueues[listsIndex].add(() => closure(client));
    _runningRequestsCount[listsIndex]--;
    return res;
  }

  void closeClients() {
    for (final client in _mainClients) {
      client.dispose(cancelRunningRequests: true);
    }
  }
}
