part of 'lan_service_discovery.dart';

/// advertises & finds namida services (sync, party) on the local network.
abstract class LanServiceDiscovery {
  static final LanServiceDiscovery inst = NamidaPlatformBuilder.init(
    android: _LanServiceDiscoveryMdns.new,
    ios: _LanServiceDiscoveryBonjour.new,
    windows: _LanServiceDiscoveryMdns.new,
    linux: _LanServiceDiscoveryMdns.new,
    macos: _LanServiceDiscoveryBonjour.new,
  );

  /// answers queries for [service] until stopped. throws only when advertising can't start,
  /// later failures (ex: local network access denied) land in [LanServiceAdvertisement.error].
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
  /// why other devices can't find the service right now, null once advertised.
  final error = Rxn<String>();

  Future<void> stop();
}
