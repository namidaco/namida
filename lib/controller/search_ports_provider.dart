import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

typedef SearchRequest = ({String text, bool temp, bool? isVideo});

abstract class SearchPortsProvider {
  final _ports = <MediaType, PortsComm>{};

  /// kept per type rather than per port, a port being reopened must still resend them.
  /// global and tab searches share a port but not their latest request.
  final _latestGlobalMessages = <MediaType, SearchRequest>{};
  final _latestTabMessages = <MediaType, SearchRequest>{};

  final _reopeningTypes = <MediaType>{};
  final _reopenAgainTypes = <MediaType>{};

  Future<SendPort?> Function() mediaTypeToPrepareFn(MediaType type);

  @protected
  Future<void> disposeAll() async {
    await Future.wait(MediaType.values.map(closePorts));
    _latestGlobalMessages.clear();
    _latestTabMessages.clear();
  }

  Future<void> closePorts(MediaType type) async => _closePort(type);

  void _closePort(MediaType type) => _ports.remove(type)?.close();

  /// saved as the latest before waiting, so a port reopened meanwhile resends it instead of losing it.
  @protected
  void sendRequest(MediaType type, Future<SendPort?> sendPortFuture, SearchRequest request) async {
    final latestMessages = request.temp ? _latestGlobalMessages : _latestTabMessages;
    latestMessages[type] = request;
    final sendPort = await sendPortFuture;
    if (sendPort == null) return;
    final isStillLatest = latestMessages[type] == request;
    if (!isStillLatest) return; // -- typed more while the port was starting
    sendPort.send(request);
  }

  /// null means the port was closed before it became usable.
  Future<SendPort?> preparePorts({
    required MediaType type,
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
  }) async {
    final existingPort = _ports[type];
    if (existingPort != null) return _currentSendPort(type, existingPort, await existingPort.sendPort);

    final port = _ports[type] = PortsComm();
    port.listen(onResult);

    try {
      await isolateFunction(port.items.sendPort);
    } catch (_) {
      port.abort();
      if (identical(_ports[type], port)) await closePorts(type);
      rethrow;
    }

    return _currentSendPort(type, port, await port.sendPort);
  }

  SendPort? _currentSendPort(MediaType type, PortsComm port, SendPort? sendPort) {
    // -- the port could've been closed or replaced while being awaited
    if (sendPort == null || !identical(_ports[type], port)) return null;
    return sendPort;
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
        _closePort(type); // -- not closePorts(), the searches keep running since they're resent

        final latestGlobalMessage = _latestGlobalMessages[type];
        final latestTabMessage = _latestTabMessages[type];
        final hasMessages = latestGlobalMessage != null || latestTabMessage != null;
        if (!wasActive || !hasMessages) continue;

        final sendPort = await mediaTypeToPrepareFn(type)();
        if (sendPort == null || _reopenAgainTypes.contains(type)) continue;
        if (latestGlobalMessage != null) sendPort.send(latestGlobalMessage);
        if (latestTabMessage != null) sendPort.send(latestTabMessage);
      } while (_reopenAgainTypes.contains(type));
    } finally {
      _reopeningTypes.remove(type);
      _reopenAgainTypes.remove(type);
    }
  }
}
