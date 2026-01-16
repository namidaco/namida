part of 'app_single_instance.dart';

// by claude
class AppSingleInstanceLinux extends AppSingleInstanceBase {
  static const String _busName = 'com.msob7y.namida';
  static const String _objectPath = '/com/msob7y/namida';
  static const String _interfaceName = 'com.msob7y.namida.Instance';

  DBusClient? _bus;
  bool _isPrimaryInstance = false;

  @override
  Future<void> acquireSingleInstanceOrExit(List<String> args) async {
    final isPrimaryInstance = await _tryAcquireSingleInstance(args);
    if (!isPrimaryInstance) {
      exit(0);
    }
  }

  Future<bool> _tryAcquireSingleInstance(List<String> args) async {
    try {
      _bus = DBusClient.session();

      // Try to own the bus name
      final result = await _bus!.requestName(_busName, flags: {DBusRequestNameFlag.doNotQueue});

      _isPrimaryInstance = result == DBusRequestNameReply.primaryOwner;

      if (_isPrimaryInstance) {
        // we the primary instance, register the object to receive args
        await _registerObject();
        return true;
      } else {
        // another instance exists, send args
        await _sendArgsToExistingInstance(args);
        return false;
      }
    } catch (_) {
      // fallback to treating as primary instance on error
      _isPrimaryInstance = true;
      return true;
    }
  }

  /// Register D-Bus object to receive arguments from new instances
  Future<void> _registerObject() async {
    final object = _NamidaDBusObject(_onArgsReceived);
    await _bus?.registerObject(object);
  }

  /// Send arguments to the existing primary instance
  Future<void> _sendArgsToExistingInstance(List<String> args) async {
    final bus = _bus;
    if (bus == null) return;
    try {
      final remoteObject = DBusRemoteObject(
        bus,
        name: _busName,
        path: DBusObjectPath(_objectPath),
      );

      await remoteObject.callMethod(
        _interfaceName,
        'HandleArgs',
        [DBusArray.string(args)],
        replySignature: DBusSignature(''),
      );
    } catch (_) {}
  }

  /// Callback when args are received from a new instance
  void _onArgsReceived(List<String> args, {bool bringToFront = true}) {
    NamidaReceiveIntentManager.executeReceivedItems(args, (p) => p, (p) => p);
    if (bringToFront) _bringWindowToFront();
  }

  void _bringWindowToFront() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  Future<void> dispose() async {
    await _bus?.close();
  }
}

/// D-Bus object implementation
class _NamidaDBusObject extends DBusObject {
  final void Function(List<String>) onArgsReceived;

  _NamidaDBusObject(this.onArgsReceived) : super(DBusObjectPath(AppSingleInstanceLinux._objectPath));

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface(
        AppSingleInstanceLinux._interfaceName,
        methods: [
          DBusIntrospectMethod(
            'HandleArgs',
            args: [
              DBusIntrospectArgument(
                DBusSignature('as'),
                DBusArgumentDirection.in_,
                name: 'args',
              ),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface == AppSingleInstanceLinux._interfaceName) {
      if (methodCall.name == 'HandleArgs') {
        final args = (methodCall.values[0] as DBusArray).children.map((e) => (e as DBusString).value).toList();
        onArgsReceived(args);
        return DBusMethodSuccessResponse();
      }
    }

    return DBusMethodErrorResponse.unknownMethod();
  }
}
