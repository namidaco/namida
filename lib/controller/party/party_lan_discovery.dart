part of 'party_controller.dart';

/// answers mdns queries for a public room hosted on this device, nothing is sent until someone asks.
class _PartyLanAdvertiser {
  _PartyLanAdvertiser._();

  static const kServiceType = '_namida-party._tcp';

  LanServiceAdvertisement? _advertisement;
  bool _isStopped = false;

  static _PartyLanAdvertiser start({required int port, required String code}) {
    final advertiser = _PartyLanAdvertiser._();
    advertiser._start(port, code);
    return advertiser;
  }

  Future<void> _start(int port, String code) async {
    NamidaChannel.inst.setMulticastLock(.partyHost, true);
    try {
      final preferredInterface = await SyncUtils.getPreferredInterface();
      final deviceId = await SyncUtils.currentDeviceId;
      final ips = await SyncUtils.getAdvertisedAddresses(preferredInterface);
      final service = await MDNSService.create(
        instance: code,
        service: kServiceType,
        port: port,
        domain: SyncUtils.kDefaultDomain,
        hostName: SyncUtils.createMdnsHostName(deviceId),
        ips: ips,
        txt: MDNSService.createTXTRecords({'c': code}),
      );
      if (_isStopped) return;
      final advertisement = await LanServiceDiscovery.inst.advertise(
        service,
        networkInterface: preferredInterface,
      );
      if (_isStopped) {
        await advertisement.stop();
        return;
      }
      _advertisement = advertisement;
    } catch (e, st) {
      NamidaChannel.inst.setMulticastLock(.partyHost, false);
      logger.error('party lan advertising failed', e: e, st: st);
    }
  }

  void stop() {
    _isStopped = true;
    NamidaChannel.inst.setMulticastLock(.partyHost, false);
    _advertisement?.stop();
    _advertisement = null;
  }
}

abstract final class _PartyLanScanner {
  static const _queryTimeout = Duration(seconds: 3);
  static const _fetchConnectionTimeout = Duration(seconds: 3);

  static Future<List<PartyPublicRoom>> scan() async {
    final servers = await _findServers();
    if (servers.isEmpty) return const [];
    final fetches = servers.map((server) => PartyController._fetchRooms(server, isLocal: true, connectionTimeout: _fetchConnectionTimeout));
    final pages = await Future.wait(fetches);
    return pages.expand((page) => page?.rooms ?? const <PartyPublicRoom>[]).toFixedList();
  }

  static Future<Set<Uri>> _findServers() async {
    final servers = <Uri>{};
    NamidaChannel.inst.setMulticastLock(.partyScan, true);
    try {
      final preferredInterface = await SyncUtils.getPreferredInterface();
      final stream = await LanServiceDiscovery.inst.query(
        _PartyLanAdvertiser.kServiceType,
        timeout: _queryTimeout,
        networkInterface: preferredInterface,
      );
      await for (final entry in stream) {
        final address = entry.addrV4?.address;
        if (address == null) continue;
        final server = Uri(scheme: 'http', host: address, port: entry.port);
        servers.add(server);
      }
    } catch (e, st) {
      logger.error('party lan scan failed', e: e, st: st);
    } finally {
      NamidaChannel.inst.setMulticastLock(.partyScan, false);
    }
    return servers;
  }
}
