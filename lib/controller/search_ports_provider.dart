import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class SendPortWithCachedMessage {
  final SendPort sendPort;
  Object? _latestMessage;

  SendPortWithCachedMessage(this.sendPort);

  void send(Object? message) {
    _latestMessage = message;
    sendPort.send(message);
  }
}

abstract class SearchPortsProvider {
  final _ports = <MediaType, PortsComm?>{};
  final _sendPorts = <MediaType, SendPortWithCachedMessage?>{};

  Future<SendPortWithCachedMessage?> Function() mediaTypeToPrepareFn(MediaType type);

  @protected
  Future<void> disposeAll() async {
    await Future.wait(MediaType.values.map(closePorts));
  }

  Future<void> closePorts(MediaType type) async {
    _sendPorts[type] = null;

    final port = _ports[type];
    if (port != null) {
      _ports[type] = null;
      await port.close();
    }
  }

  /// null means the port was closed before it became usable, the search has to be sent again.
  Future<SendPortWithCachedMessage?> preparePorts({
    required MediaType type,
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
  }) async {
    final existingPort = _ports[type];
    if (existingPort != null) return _wrapSendPort(type, await existingPort.sendPort);

    final port = _ports[type] = PortsComm();
    port.listen(onResult);

    try {
      await isolateFunction(port.items.sendPort);
    } catch (_) {
      port.abort();
      await closePorts(type);
      rethrow;
    }

    return _wrapSendPort(type, await port.sendPort);
  }

  SendPortWithCachedMessage? _wrapSendPort(MediaType type, SendPort? sendPort) {
    if (sendPort == null) return null;
    return _sendPorts[type] ??= SendPortWithCachedMessage(sendPort);
  }

  Future<void> refreshPortIfNecessary(MediaType type) async {
    await _reopenPortOnMainListChanges(type);
  }

  Future<void> refreshPortsIfNecessary() async {
    final activeTypes = _sendPorts.keys.toFixedList();
    await Future.wait(activeTypes.map(_reopenPortOnMainListChanges));
  }

  Future<void> _reopenPortOnMainListChanges(MediaType type) async {
    final wasActive = _ports[type] != null;
    final cachedMsg = _sendPorts[type]?._latestMessage;
    await closePorts(type);

    if (wasActive && cachedMsg != null) {
      final prepareFn = mediaTypeToPrepareFn(type);
      await prepareFn();
      _sendPorts[type]?.send(cachedMsg);
    }
  }
}
