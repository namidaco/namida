// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

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

  Future<void> initialize() async {
    await _initValues();
    _setupListener();
  }

  Future<void> _initValues() async {
    final initialConnections = await _connectivity.checkConnectivity();
    return _onConnectionsChanged(initialConnections);
  }

  void _setupListener() {
    _streamSub?.cancel();
    _streamSub = _connectivity.onConnectivityChanged.listen(_onConnectionsChanged);
  }

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
