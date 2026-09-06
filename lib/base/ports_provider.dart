import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:namida/core/extensions.dart';

/// A [ReceivePort] paired with the [SendPort] its isolate reports back on startup.
// by claude
class PortsComm {
  final items = ReceivePort();

  final _sendPortCompleter = Completer<SendPort?>();
  StreamSubscription? _subscription;
  bool _closed = false;

  /// Resolves to null if [close] was called before the isolate reported back.
  Future<SendPort?> get sendPort => _sendPortCompleter.future;

  void listen(void Function(dynamic result) onResult) {
    _subscription = items.listen((result) {
      if (result is SendPort) {
        if (_closed) {
          // -- closed while the isolate was still starting up, it can finally be disposed
          _disposeWith(result);
        } else {
          _sendPortCompleter.completeIfWasnt(result);
        }
      } else if (!_closed) {
        onResult(result);
      }
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    if (_sendPortCompleter.isCompleted) return _disposeWith(await sendPort);

    // -- the isolate hasn't reported back yet, so keep listening to be able to dispose it later,
    // -- but release whoever is waiting on it right away instead of leaving them hanging forever.
    _sendPortCompleter.complete(null);
  }

  /// The isolate failed to start, so nothing will ever report back on this port.
  void abort() {
    _closed = true;
    _sendPortCompleter.completeIfWasnt(null);
    _disposeWith(null);
  }

  void _disposeWith(SendPort? sendPort) {
    _subscription?.cancel();
    _subscription = null;
    items.close();
    if (sendPort != null) PortsProvider.sendDisposeMessage(sendPort);
  }
}

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
  static final _activePortsProviders = <PortsProvider, bool>{};
  static Future<void> disposeAll() async {
    final providers = _activePortsProviders.keys.toFixedList();
    _activePortsProviders.clear();
    await providers.map((e) => e.disposePort()).executeAllAndSilentReportErrors();
  }

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
  static void sendDisposeMessage(SendPort port) => port.send(_PortsProviderDisposeMessage);

  @protected
  Future<void> disposePort({bool resetCompleter = true}) async {
    _activePortsProviders.remove(this);
    _recievePort?.close();
    _streamSub?.cancel();
    // -- no longer wait, if the port was never assigned, this would wait forever
    unawaited(sendPort(_PortsProviderDisposeMessage));
    _isolate?.kill(priority: Isolate.immediate);
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
    _activePortsProviders[this] = true;
    final portCompleter = _portCompleter = Completer<SendPort>();
    _recievePort = ReceivePort();
    void Function(dynamic) onResultVarFn;
    onResultVarFn = (result) {
      if (result is SendPort) {
        portCompleter.completeIfWasnt(result);
        _portCompleterResult = result;
        onResultVarFn = onResult; // -- just small optimization
      } else {
        onResult(result);
      }
    };
    _streamSub = _recievePort?.listen((result) => onResultVarFn(result));
    await isolateFunction(_recievePort!.sendPort);
    return await portCompleter.future;
  }

  @protected
  void onResult(dynamic result);

  @protected
  FutureOr<IsolateFunctionReturnBuild<E>> isolateFunction(SendPort port);

  void onPreparing(bool prepared) {}

  Future<void> initialize() async {
    if (_isInitialized == true || _initializingCompleter?.isCompleted == true) return;
    if (_initializingCompleter != null) return _initializingCompleter?.future;

    _isInitialized = false;
    onPreparing(false);

    void Function(dynamic) onResultVarFn;
    onResultVarFn = (result) {
      if (result == null) {
        _initializingCompleter?.completeIfWasnt();
        onResultVarFn = onResult; // -- just small optimization
      } else {
        onResult(result);
      }
    };
    await preparePortRaw(
      onResult: (result) => onResultVarFn(result), // don't assign fn directly
      isolateFunction: (itemsSendPort) async {
        final isolateFn = await isolateFunction(itemsSendPort);
        _isolate = await Isolate.spawn(isolateFn.entryPoint, isolateFn.message);
      },
    );
    await _initializingCompleter?.future;
    _isInitialized = true;
    onPreparing(true);
  }
}
