part of 'lan_service_discovery.dart';

/// advertises & finds namida services (sync, party) on the local network.
abstract class LanServiceDiscovery {
  static final LanServiceDiscovery inst = NamidaPlatformBuilder.init(
    android: _LanServiceDiscoveryMdns.new,
    ios: _LanServiceDiscoveryBonjour.new,
    windows: _LanServiceDiscoveryMdns.new,
    linux: _LanServiceDiscoveryMdns.new,
    macos: _LanServiceDiscoveryMdns.new,
  );

  /// answers queries for [service] until stopped.
  Future<LanServiceAdvertisement> advertise(
    MDNSService service, {
    required NetworkInterface? networkInterface,
    void Function(String message)? logger,
  });

  /// every [service] instance found within [timeout], the stream closes after it.
  Future<Stream<ServiceEntry>> query(
    String service, {
    required Duration timeout,
    required NetworkInterface? networkInterface,
    void Function(String message)? logger,
  });
}

abstract class LanServiceAdvertisement {
  Future<void> stop();
}
