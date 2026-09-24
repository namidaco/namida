import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

typedef SearchRequest = ({String text, bool temp, bool? isVideo});

class SendPortWithCachedMessage {
  final SendPort _sendPort;
  final void Function(Object? message) _cacheMessage;

  const SendPortWithCachedMessage._(this._sendPort, this._cacheMessage);

  void send(Object? message) {
    _cacheMessage(message);
    _sendPort.send(message);
  }
}

abstract class SearchPortsProvider {
  final _ports = <MediaType, PortsComm>{};
  final _sendPorts = <MediaType, SendPortWithCachedMessage>{};

  /// kept per type rather than per port, a port being reopened must still resend it.
  final _latestMessages = <MediaType, Object?>{};

  final _reopeningTypes = <MediaType>{};
  final _reopenAgainTypes = <MediaType>{};

  Future<SendPortWithCachedMessage?> Function() mediaTypeToPrepareFn(MediaType type);

  @protected
  Future<void> disposeAll() async {
    await Future.wait(MediaType.values.map(closePorts));
    _latestMessages.clear();
  }

  Future<void> closePorts(MediaType type) async {
    _sendPorts.remove(type);
    _ports.remove(type)?.close();
  }

  /// null means the port was closed before it became usable, the search has to be sent again.
  Future<SendPortWithCachedMessage?> preparePorts({
    required MediaType type,
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
  }) async {
    final existingPort = _ports[type];
    if (existingPort != null) return _wrapSendPort(type, existingPort, await existingPort.sendPort);

    final port = _ports[type] = PortsComm();
    port.listen(onResult);

    try {
      await isolateFunction(port.items.sendPort);
    } catch (_) {
      port.abort();
      if (identical(_ports[type], port)) await closePorts(type);
      rethrow;
    }

    return _wrapSendPort(type, port, await port.sendPort);
  }

  SendPortWithCachedMessage? _wrapSendPort(MediaType type, PortsComm port, SendPort? sendPort) {
    // -- the port could've been closed or replaced while being awaited
    if (sendPort == null || !identical(_ports[type], port)) return null;
    return _sendPorts[type] ??= SendPortWithCachedMessage._(sendPort, (message) => _latestMessages[type] = message);
  }

  Future<void> refreshPortIfNecessary(MediaType type) async {
    await _reopenPortOnMainListChanges(type);
  }

  /// includes ports still starting, they were spawned with the old lists too.
  Future<void> refreshPortsIfNecessary() async {
    final activeTypes = _ports.keys.toFixedList();
    await Future.wait(activeTypes.map(_reopenPortOnMainListChanges));
  }

  /// lists can change rapidly (ex: while indexing), requests arriving mid reopen are coalesced into one more pass.
  Future<void> _reopenPortOnMainListChanges(MediaType type) async {
    if (!_reopeningTypes.add(type)) {
      _reopenAgainTypes.add(type);
      return;
    }

    try {
      do {
        _reopenAgainTypes.remove(type);
        final wasActive = _ports[type] != null;
        await closePorts(type);

        final latestMessage = _latestMessages[type];
        if (!wasActive || latestMessage == null) continue;

        final sendPort = await mediaTypeToPrepareFn(type)();
        if (!_reopenAgainTypes.contains(type)) sendPort?.send(latestMessage);
      } while (_reopenAgainTypes.contains(type));
    } finally {
      _reopeningTypes.remove(type);
      _reopenAgainTypes.remove(type);
    }
  }
}
