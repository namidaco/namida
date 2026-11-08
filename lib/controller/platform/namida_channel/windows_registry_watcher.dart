// by claude
import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// notifies when a value of a `HKEY_CURRENT_USER` key changes. a thread pool wait on a registry change event,
/// nothing runs until windows signals a change. a watch lasts for the app's lifetime.
abstract final class WindowsRegistryWatcher {
  /// [onChanged] runs on the calling isolate, once per changed value. false when the watch couldn't start.
  static bool watchCurrentUserKey(String path, void Function() onChanged) {
    final keyHandle = _openCurrentUserKey(path);
    if (keyHandle == null) return false;
    final eventHandle = _createEvent(nullptr, 0, 0, nullptr);
    if (eventHandle == 0) return false;

    bool arm() => _regNotifyChangeKeyValue(keyHandle, 0, _kRegNotifyChangeLastSet | _kRegNotifyThreadAgnostic, eventHandle, 1) == 0;
    if (!arm()) return false;

    // -- a notification fires once, re-armed before reading so a change during the read isn't lost
    final callback = NativeCallable<_WaitCallbackNative>.listener((Pointer<Void> _, int _) {
      arm();
      onChanged();
    });
    final waitHandle = calloc<IntPtr>();
    final didRegister = _registerWaitForSingleObject(waitHandle, eventHandle, callback.nativeFunction, nullptr, _kInfinite, _kWtExecuteDefault) != 0;
    calloc.free(waitHandle);
    if (!didRegister) callback.close();
    return didRegister;
  }

  static int? _openCurrentUserKey(String path) {
    final keyHandlePointer = calloc<IntPtr>();
    final subKey = path.toNativeUtf16();
    try {
      final result = _regOpenKeyEx(_kHkeyCurrentUser, subKey, 0, _kKeyNotify, keyHandlePointer);
      if (result != 0) return null;
      return keyHandlePointer.value;
    } finally {
      calloc.free(subKey);
      calloc.free(keyHandlePointer);
    }
  }

  // -- HKEY_CURRENT_USER is ((HKEY)(ULONG_PTR)((LONG)0x80000001)), sign extended on 64-bit
  static const _kHkeyCurrentUser = -0x7FFFFFFF;
  static const _kKeyNotify = 0x0010;
  static const _kRegNotifyChangeLastSet = 0x00000004;
  static const _kRegNotifyThreadAgnostic = 0x10000000;
  static const _kInfinite = 0xFFFFFFFF;
  static const _kWtExecuteDefault = 0x00000000;

  static final _advapi32 = DynamicLibrary.open('advapi32.dll');
  static final _kernel32 = DynamicLibrary.open('kernel32.dll');

  static final _regOpenKeyEx = _advapi32.lookupFunction<
    Int32 Function(IntPtr hKey, Pointer<Utf16> subKey, Uint32 options, Uint32 samDesired, Pointer<IntPtr> result),
    int Function(int hKey, Pointer<Utf16> subKey, int options, int samDesired, Pointer<IntPtr> result)
  >('RegOpenKeyExW');

  static final _regNotifyChangeKeyValue = _advapi32.lookupFunction<
    Int32 Function(IntPtr hKey, Int32 watchSubtree, Uint32 notifyFilter, IntPtr event, Int32 asynchronous),
    int Function(int hKey, int watchSubtree, int notifyFilter, int event, int asynchronous)
  >('RegNotifyChangeKeyValue');

  static final _createEvent = _kernel32.lookupFunction<
    IntPtr Function(Pointer<Void> attributes, Int32 manualReset, Int32 initialState, Pointer<Utf16> name),
    int Function(Pointer<Void> attributes, int manualReset, int initialState, Pointer<Utf16> name)
  >('CreateEventW');

  static final _registerWaitForSingleObject = _kernel32.lookupFunction<
    Int32 Function(Pointer<IntPtr> newWaitObject, IntPtr object, Pointer<NativeFunction<_WaitCallbackNative>> callback, Pointer<Void> context, Uint32 milliseconds, Uint32 flags),
    int Function(Pointer<IntPtr> newWaitObject, int object, Pointer<NativeFunction<_WaitCallbackNative>> callback, Pointer<Void> context, int milliseconds, int flags)
  >('RegisterWaitForSingleObject');
}

typedef _WaitCallbackNative = Void Function(Pointer<Void> context, Uint8 timerOrWaitFired);
