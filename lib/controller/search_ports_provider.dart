import 'dart:async';
import 'dart:isolate';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class _PortsCommWithListener {
  final PortsComm comm;
  final RxBaseCore? rx;
  final void Function() listener;

  _PortsCommWithListener(
    this.comm,
    this.rx,
    this.listener,
  ) {
    rx?.addListener(listener);
  }

  void dispose() {
    rx?.removeListener(listener);
  }
}

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
  final _ports = <MediaType, _PortsCommWithListener?>{};
  final _sendPorts = <MediaType, SendPortWithCachedMessage?>{};
  final _sendPortsStreamSubs = <MediaType, StreamSubscription?>{};

  Future<SendPortWithCachedMessage> Function() mediaTypeToPrepareFn(MediaType type);

  void disposeAll() async {
    final ports = _ports.values.whereType<_PortsCommWithListener>().toList();
    _ports.clear();
    await ports.loopAsync(_closePortAndRemoveListener);
  }

  Future<void> closePorts(MediaType type) async {
    final port = _ports[type];
    if (port != null) {
      _ports[type] = null;
      await _closePortAndRemoveListener(port);
    }
    _sendPortsStreamSubs[type]?.cancel();
    _sendPortsStreamSubs[type] = null;
    _sendPorts[type] = null;
  }

  Future<void> _closePortAndRemoveListener(_PortsCommWithListener portWrapper) async {
    portWrapper.dispose(); // remove listener
    final port = portWrapper.comm;
    port.items.close();
    final sendPort = await port.search.future;
    PortsProvider.sendDisposeMessage(sendPort);
  }

  Future<SendPortWithCachedMessage> preparePorts({
    required MediaType type,
    required RxBaseCore? portRefreshListener,
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
    bool force = false,
  }) async {
    final sendPort = await preparePortBase(
      type: type,
      portN: _ports[type]?.comm,
      onPortNull: () async {
        await closePorts(type);
        final newPort = _PortsCommWithListener((items: ReceivePort(), search: Completer<SendPort>()), portRefreshListener, () => _reopenPortOnMainListChanges(type));
        _ports[type] = newPort;
        return newPort.comm;
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

  void _reopenPortOnMainListChanges(MediaType type) async {
    final cachedMsg = _sendPorts[type]?._latestMessage;
    await closePorts(type);
    final prepareFn = mediaTypeToPrepareFn(type);
    await prepareFn();
    if (cachedMsg != null) _sendPorts[type]?.send(cachedMsg);
  }
}
