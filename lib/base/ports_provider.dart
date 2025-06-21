import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:namida/core/extensions.dart';

typedef PortsComm = ({ReceivePort items, Completer<SendPort> search});

abstract class _PortsProviderDisposeMessage {}

class IsolateMessageTokenWrapper {
  int _initial = 0;
  IsolateMessageTokenWrapper.create();

  int getToken() => _initial++;
}

class IsolateFunctionReturnBuild<T> {
  final void Function(T message) entryPoint;
  final T message;

  const IsolateFunctionReturnBuild(
    this.entryPoint,
    this.message,
  );
}

mixin PortsProvider<E> {
  bool get isInitialized => _isInitialized ?? false;

  Completer<SendPort>? _portCompleter;
  SendPort? _portCompleterResult;
  ReceivePort? _recievePort;
  StreamSubscription? _streamSub;
  Isolate? _isolate;

  bool? _isInitialized;
  Completer<void>? _initializingCompleter;

  Future<void> sendPort(Object? message) async {
    (_portCompleterResult ?? await _portCompleter?.future)?.send(message);
  }

  static bool isDisposeMessage(dynamic message) => message == _PortsProviderDisposeMessage;

  @protected
  Future<void> disposePort({bool resetCompleter = true}) async {
    _recievePort?.close();
    _streamSub?.cancel();
    await sendPort(_PortsProviderDisposeMessage);
    _isolate?.kill();
    _isInitialized = false;
    onPreparing(false);
    if (resetCompleter) _initializingCompleter = null;
    _portCompleter = null;
    _portCompleterResult = null;
    _recievePort = null;
    _streamSub = null;
    _isolate = null;
  }

  Future<SendPort> preparePortRaw({
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
  }) async {
    if (_portCompleter != null) return await _portCompleter!.future;

    _initializingCompleter = Completer<void>(); // set early to prevent double init
    await disposePort(resetCompleter: false);
    final portCompleter = _portCompleter = Completer<SendPort>();
    _recievePort = ReceivePort();
    _streamSub = _recievePort?.listen((result) {
      if (result is SendPort) {
        portCompleter.completeIfWasnt(result);
        _portCompleterResult = result;
      } else {
        onResult(result);
      }
    });
    await isolateFunction(_recievePort!.sendPort);
    return await portCompleter.future;
  }

  @protected
  void onResult(dynamic result);

  @protected
  IsolateFunctionReturnBuild<E> isolateFunction(SendPort port);

  void onPreparing(bool prepared) {}

  Future<void> initialize() async {
    if (_isInitialized == true || _initializingCompleter?.isCompleted == true) return;
    if (_initializingCompleter != null) return _initializingCompleter?.future;

    _isInitialized = false;
    onPreparing(false);

    await preparePortRaw(
      onResult: (result) async {
        if (result == null) {
          _initializingCompleter?.completeIfWasnt();
        } else {
          onResult(result);
        }
      },
      isolateFunction: (itemsSendPort) async {
        final isolateFn = isolateFunction(itemsSendPort);
        _isolate = await Isolate.spawn(isolateFn.entryPoint, isolateFn.message);
      },
    );
    await _initializingCompleter?.future;
    _isInitialized = true;
    onPreparing(true);
  }
}

mixin PortsProviderBase {
  StreamSubscription? _streamSub;

  @protected
  Future<void> disposePort(PortsComm port) async {
    port.items.close();
    _streamSub?.cancel();
    (await port.search.future).send(_PortsProviderDisposeMessage);
  }

  Future<SendPort> preparePortBase({
    required PortsComm? portN,
    required Future<PortsComm> Function() onPortNull,
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
    bool force = false,
  }) async {
    if (portN != null && !force) return await portN.search.future;

    final port = await onPortNull();
    _streamSub = port.items.listen((result) {
      if (result is SendPort) {
        port.search.completeIfWasnt(result);
      } else {
        onResult(result);
      }
    });
    await isolateFunction(port.items.sendPort);
    return await port.search.future;
  }
}
