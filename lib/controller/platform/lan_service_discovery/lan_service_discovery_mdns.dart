part of 'lan_service_discovery.dart';

class _LanServiceDiscoveryMdns extends LanServiceDiscovery {
  @override
  Future<LanServiceAdvertisement> advertise(
    MDNSService service, {
    required NetworkInterface? networkInterface,
    void Function(String message)? logger,
  }) async {
    final server = MDNSServer(
      MDNSServerConfig(
        zone: service,
        networkInterface: networkInterface,
        logger: logger,
      ),
    );
    await server.start();
    return _MdnsAdvertisement(server);
  }

  @override
  Future<Stream<ServiceEntry>> query(
    String service, {
    required Duration timeout,
    required NetworkInterface? networkInterface,
    void Function(String message)? logger,
  }) {
    return MDNSClient.query(
      QueryParams(
        service: service,
        timeout: timeout,
        networkInterface: networkInterface,
        wantUnicastResponse: true, // -- replies come directly to us, bypassing routers that filter multicast
        logger: logger,
      ),
    );
  }
}

class _MdnsAdvertisement extends LanServiceAdvertisement {
  final MDNSServer _server;
  _MdnsAdvertisement(this._server);

  @override
  Future<void> stop() => _server.stop();
}
