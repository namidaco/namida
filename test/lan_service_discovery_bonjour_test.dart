// by claude
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mdns_dart/mdns_dart.dart';

import 'package:namida/controller/platform/lan_service_discovery/lan_service_discovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'namida/bonjour';
  const codec = StandardMethodCodec();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;

  // -- the instance is picked on first access, ios gets the bonjour one
  late final LanServiceDiscovery discovery;

  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    discovery = LanServiceDiscovery.inst;
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(const MethodChannel(channelName), (call) async {
      calls.add(call);
      return switch (call.method) {
        'register' => 7,
        _ => null,
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel(channelName), null);
  });

  Future<void> sendFromNative(String method, Map<String, Object?> args) async {
    final data = codec.encodeMethodCall(MethodCall(method, args));
    await messenger.handlePlatformMessage(channelName, data, (_) {});
  }

  test('advertising registers the service with its txt records and unregisters on stop', () async {
    final service = await MDNSService.create(
      instance: 'My Phone',
      service: '_namida-server._tcp',
      port: 62310,
      txt: MDNSService.createTXTRecords({'device_name': 'My Phone', 'device_id': 'abc'}),
    );

    final advertisement = await discovery.advertise(service, networkInterface: null);
    expect(calls.single.method, 'register');
    expect(calls.single.arguments, {
      'type': '_namida-server._tcp',
      'name': 'My Phone',
      'port': 62310,
      'txt': {'device_name': 'My Phone', 'device_id': 'abc'},
    });

    await advertisement.stop();
    expect(calls.last.method, 'unregister');
    expect(calls.last.arguments, {'registrationId': 7});
  });

  test('a query streams every resolved service and closes when native is done', () async {
    final stream = await discovery.query('_namida-server._tcp', timeout: const Duration(seconds: 3), networkInterface: null);
    final browse = calls.single;
    expect(browse.method, 'browse');
    final queryId = (browse.arguments as Map)['queryId'] as int;
    expect((browse.arguments as Map)['timeoutMS'], 3000);

    final entriesFuture = stream.toList();
    await sendFromNative('onServiceFound', {
      'queryId': queryId,
      'name': 'Desktop',
      'host': 'desktop.local.',
      'port': 62310,
      'ipv4': ['192.168.1.20'],
      'txt': ['device_name=Desktop', 'device_id=xyz'],
    });
    await sendFromNative('onQueryDone', {'queryId': queryId});
    final entries = await entriesFuture;

    expect(entries, hasLength(1));
    final entry = entries.single;
    expect(entry.name, 'Desktop');
    expect(entry.port, 62310);
    expect(entry.addrV4?.address, '192.168.1.20');
    expect(MDNSService.parseTXTRecords(entry.infoFields), {'device_name': 'Desktop', 'device_id': 'xyz'});
  });

  test('a failed browse ends the stream with an error', () async {
    final stream = await discovery.query('_namida-party._tcp', timeout: const Duration(seconds: 1), networkInterface: null);
    final queryId = (calls.single.arguments as Map)['queryId'] as int;
    final done = expectLater(stream, emitsError(isA<StateError>()));
    await sendFromNative('onQueryDone', {'queryId': queryId, 'error': 'local network access denied'});
    await done;
  });

  test('callbacks for another query are ignored', () async {
    final stream = await discovery.query('_namida-server._tcp', timeout: const Duration(seconds: 1), networkInterface: null);
    final queryId = (calls.single.arguments as Map)['queryId'] as int;
    final entriesFuture = stream.toList();
    await sendFromNative('onServiceFound', {
      'queryId': queryId + 1000,
      'name': 'Other',
      'host': '',
      'port': 1,
      'ipv4': ['10.0.0.1'],
      'txt': <String>[],
    });
    await sendFromNative('onQueryDone', {'queryId': queryId});
    expect(await entriesFuture, isEmpty);
  });
}
