import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class ConnectivityController {
  static ConnectivityController get inst => _instance;
  static final ConnectivityController _instance = ConnectivityController._internal();
  ConnectivityController._internal();

  StreamSubscription<ConnectivityResult>? _streamSub;

  void initialize() {
    _streamSub?.cancel();
    _streamSub = _connectivity.onConnectivityChanged.listen((connection) {
      _connectionType.value = connection;
      _hasConnection.value = connection != ConnectivityResult.none;
    });
  }

  bool get hasConnection => _hasConnection.value;
  ConnectivityResult get connectionType => _connectionType.value;

  final _connectivity = Connectivity();
  final _hasConnection = false.obs;
  final _connectionType = ConnectivityResult.none.obs;
}
