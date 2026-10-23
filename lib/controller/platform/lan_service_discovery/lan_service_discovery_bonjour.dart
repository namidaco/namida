part of 'lan_service_discovery.dart';

// by claude
/// ios only lets apps with an apple-granted entitlement send multicast themselves, the system's bonjour service does it for them.
/// interfaces & loggers are mdns_dart concerns, bonjour picks the interfaces on its own.
class _LanServiceDiscoveryBonjour extends LanServiceDiscovery {
  _LanServiceDiscoveryBonjour() {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static const _channel = MethodChannel('namida/bonjour');

  final _queries = <int, StreamController<ServiceEntry>>{};
  int _nextQueryId = 0;

  Future<void> _onMethodCall(MethodCall call) async {
    final args = call.arguments as Map;
    final queryId = args['queryId'] as int;
    final controller = _queries[queryId];
    if (controller == null) return;
    switch (call.method) {
      case 'onServiceFound':
        controller.add(_entryFromMap(args));
      case 'onQueryDone':
        _queries.remove(queryId);
        final error = args['error'] as String?;
        if (error != null) controller.addError(StateError(error));
        controller.close();
    }
  }

  static ServiceEntry _entryFromMap(Map args) {
    final ipv4 = (args['ipv4'] as List).cast<String>();
    final txt = (args['txt'] as List).cast<String>();
    final addresses = ipv4.map(InternetAddress.new).toFixedList();
    return ServiceEntry(
      name: args['name'] as String,
      host: args['host'] as String,
      addrsV4: addresses,
      port: args['port'] as int,
      info: txt.isEmpty ? '' : txt.first,
      infoFields: txt,
    );
  }

  @override
  Future<LanServiceAdvertisement> advertise(
    MDNSService service, {
    required NetworkInterface? networkInterface,
    void Function(String message)? logger,
  }) async {
    final txt = MDNSService.parseTXTRecords(service.txt);
    final registrationId = await _channel.invokeMethod<int>('register', {
      'type': service.service,
      'name': service.instance,
      'port': service.port,
      'txt': txt,
    });
    return _BonjourAdvertisement(registrationId!);
  }

  @override
  Future<Stream<ServiceEntry>> query(
    String service, {
    required Duration timeout,
    required NetworkInterface? networkInterface,
    void Function(String message)? logger,
  }) async {
    final queryId = _nextQueryId++;
    final controller = StreamController<ServiceEntry>();
    _queries[queryId] = controller;
    try {
      await _channel.invokeMethod('browse', {
        'queryId': queryId,
        'type': service,
        'timeoutMS': timeout.inMilliseconds,
      });
    } catch (_) {
      _queries.remove(queryId);
      controller.close();
      rethrow;
    }
    return controller.stream;
  }
}

class _BonjourAdvertisement extends LanServiceAdvertisement {
  final int _registrationId;
  _BonjourAdvertisement(this._registrationId);

  @override
  Future<void> stop() {
    return _LanServiceDiscoveryBonjour._channel.invokeMethod('unregister', {'registrationId': _registrationId});
  }
}
