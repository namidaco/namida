// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dbus/dbus.dart';

import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class ConnectivityController {
  static ConnectivityController get inst => _instance;
  static final ConnectivityController _instance = ConnectivityController._internal();
  ConnectivityController._internal();

  DataSaverMode get dataSaverMode {
    final hasHighConnection = ConnectivityController.inst.hasHighConnection;
    return hasHighConnection ? settings.youtube.dataSaverMode.value : settings.youtube.dataSaverModeMobile.value;
  }

  StreamSubscription<List<ConnectivityResult>>? _streamSub;
  StreamSubscription<DBusSignal>? _portalSub;

  static const _backendTimeout = Duration(seconds: 3);

  Future<void> initialize() async {
    try {
      // -- doesn't throws when the system bus is missing, it hangs forever, hence the timeout.
      _onConnectionsChanged(await _connectivity.checkConnectivity().timeout(_backendTimeout));
      _setupListener();
    } catch (e, st) {
      logger.error('connectivity backend unavailable', e: e, st: st);
      await _setupPortalFallback();
    }
  }

  void _setupListener() {
    _streamSub?.cancel();
    _streamSub = _connectivity.onConnectivityChanged.listen(
      _onConnectionsChanged,
      onError: (_) => _assumeConnected(),
    );
  }

  /// [package:connectivity_plus] needs NetworkManager on the system bus, which flatpak sandboxes hide and
  /// systemd-networkd/iwd hosts don't run. the portal sits on the session bus and reports metered state itself.
  Future<void> _setupPortalFallback() async {
    if (!Platform.isLinux) return _assumeConnected();

    final portal = _NetworkMonitorPortal();
    try {
      _onConnectionsChanged(await portal.getConnections());
      _portalSub?.cancel();
      _portalSub = portal.onChanged.listen(
        (_) async => _onConnectionsChanged(await portal.getConnections()),
        onError: (_) => _assumeConnected(),
      );
    } catch (e, st) {
      portal.dispose();
      _assumeConnected();
      logger.error('network monitor portal unavailable', e: e, st: st);
    }
  }

  /// last resort, staying offline would stall everything network-gated.
  void _assumeConnected() => _onConnectionsChanged(const [ConnectivityResult.other]);

  void _onConnectionsChanged(List<ConnectivityResult> connections) {
    if (connections.contains(ConnectivityResult.none)) {
      _hasConnection.value = false;
      _hasHighConnection.value = false;
    } else {
      final highConnection =
          connections.contains(ConnectivityResult.wifi) ||
          connections.contains(ConnectivityResult.ethernet) || //
          connections.contains(ConnectivityResult.other);
      _hasHighConnection.value = highConnection;
      _hasConnection.value = true;
      if (_onConnectionRestored.isNotEmpty) {
        final indicesToRemove = <int>{};
        _onConnectionRestored.loopAdv((item, i) {
          item();
          indicesToRemove.add(i);
        });
        _onConnectionRestored.removeWhere(indicesToRemove.remove);
      }
    }
  }

  void executeOrRegister(void Function() callback) {
    if (hasConnection) {
      callback();
    } else {
      registerOnConnectionRestored(callback);
    }
  }

  final _onConnectionRestored = <void Function()>[];

  void registerOnConnectionRestored(void Function() fn) {
    _onConnectionRestored.add(fn);
  }

  void removeOnConnectionRestored(void Function() fn) {
    _onConnectionRestored.remove(fn);
  }

  bool get hasConnection => _hasConnection.value;
  bool get hasHighConnection => _hasHighConnection.value;

  bool get hasConnectionR => _hasConnection.valueR;
  bool get hasHighConnectionR => _hasHighConnection.valueR;

  final _connectivity = Connectivity();
  final _hasConnection = false.obs;
  final _hasHighConnection = false.obs;
}

/// `org.freedesktop.portal.NetworkMonitor`, sandbox friendly alternative for NetworkManager
// by claude
class _NetworkMonitorPortal {
  static const _interface = 'org.freedesktop.portal.NetworkMonitor';

  final _client = DBusClient.session();
  late final _object = DBusRemoteObject(
    _client,
    name: 'org.freedesktop.portal.Desktop',
    path: DBusObjectPath('/org/freedesktop/portal/desktop'),
  );

  Stream<DBusSignal> get onChanged => DBusRemoteObjectSignalStream(object: _object, interface: _interface, name: 'changed');

  Future<List<ConnectivityResult>> getConnections() async {
    final response = await _object.callMethod(_interface, 'GetStatus', const [], replySignature: DBusSignature('a{sv}')).timeout(ConnectivityController._backendTimeout);
    final status = response.values.first.asStringVariantDict();
    if (status['available']?.asBoolean() == false) return const [ConnectivityResult.none];
    // -- metered maps to mobile, so data saver kicks in like on a real mobile connection.
    return status['metered']?.asBoolean() == true ? const [ConnectivityResult.mobile] : const [ConnectivityResult.ethernet];
  }

  void dispose() => _client.close();
}
