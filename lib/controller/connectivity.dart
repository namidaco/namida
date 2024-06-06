// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:namida/core/utils.dart';

class ConnectivityController {
  static ConnectivityController get inst => _instance;
  static final ConnectivityController _instance = ConnectivityController._internal();
  ConnectivityController._internal();

  StreamSubscription<List<ConnectivityResult>>? _streamSub;

  void initialize() {
    _streamSub?.cancel();
    _streamSub = _connectivity.onConnectivityChanged.listen((connections) {
      if (connections.contains(ConnectivityResult.none)) {
        _hasConnection.value = false;
        _hasHighConnection.value = false;
      } else {
        final highConnection = connections.contains(ConnectivityResult.wifi) ||
            connections.contains(ConnectivityResult.ethernet) ||
            connections.contains(ConnectivityResult.vpn) ||
            connections.contains(ConnectivityResult.other);
        _hasHighConnection.value = highConnection;
        _hasConnection.value = true;
      }
    });
  }

  bool get hasConnection => _hasConnection.value;
  bool get hasHighConnection => _hasHighConnection.value;

  bool get hasConnectionR => _hasConnection.valueR;
  bool get hasHighConnectionR => _hasHighConnection.valueR;

  final _connectivity = Connectivity();
  final _hasConnection = false.obs;
  final _hasHighConnection = false.obs;
}
