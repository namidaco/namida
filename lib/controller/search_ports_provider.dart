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
  final _sendPortsStreamSubs = <MediaType, StreamSubscription?>{};

  Future<SendPortWithCachedMessage> Function() mediaTypeToPrepareFn(MediaType type);

  @protected
  Future<void> disposeAll() async {
    await Future.wait(MediaType.values.map(closePorts));
  }

  Future<void> closePorts(MediaType type) async {
    _sendPortsStreamSubs[type]?.cancel();
    _sendPortsStreamSubs[type] = null;

    final port = _ports[type];
    if (port != null) {
      _ports[type] = null;
      await _closePortAndRemoveListener(port);
    }
    _sendPorts[type] = null;
  }

  Future<void> _closePortAndRemoveListener(PortsComm port) async {
    port.items.close();
    final sendPort = await port.search.future;
    PortsProvider.sendDisposeMessage(sendPort);
  }

  Future<SendPortWithCachedMessage> preparePorts({
    required MediaType type,
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
    bool force = false,
  }) async {
    final sendPort = await preparePortBase(
      type: type,
      portN: _ports[type],
      onPortNull: () async {
        await closePorts(type);
        return _ports[type] ??= (items: ReceivePort(), search: Completer<SendPort>());
      },
      onResult: onResult,
      isolateFunction: isolateFunction,
    );
    return _sendPorts[type] ??= SendPortWithCachedMessage(sendPort);
  }

  Future<SendPort> preparePortBase({
    required MediaType type,
    required PortsComm? portN,
    required Future<PortsComm> Function() onPortNull,
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
    bool force = false,
  }) async {
    if (portN != null && !force) return await portN.search.future;

    final port = await onPortNull();
    _sendPortsStreamSubs[type] = port.items.listen((result) {
      if (result is SendPort) {
        port.search.completeIfWasnt(result);
      } else {
        onResult(result);
      }
    });
    await isolateFunction(port.items.sendPort);
    return await port.search.future;
  }

  Future<void> refreshPortIfNecessary(MediaType type) async {
    await _reopenPortOnMainListChanges(type);
  }

  Future<void> refreshPortsIfNecessary() async {
    final activeTypes = _sendPorts.keys.toList();
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
