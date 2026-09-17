// by claude
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;

  external Pointer<Uint8> pbData;
}

typedef _CryptDataNative =
    Int32 Function(
      Pointer<_DataBlob> pDataIn,
      Pointer<Void> descr,
      Pointer<_DataBlob> pOptionalEntropy,
      Pointer<Void> pvReserved,
      Pointer<Void> pPromptStruct,
      Uint32 dwFlags,
      Pointer<_DataBlob> pDataOut,
    );
typedef _CryptDataDart =
    int Function(
      Pointer<_DataBlob> pDataIn,
      Pointer<Void> descr,
      Pointer<_DataBlob> pOptionalEntropy,
      Pointer<Void> pvReserved,
      Pointer<Void> pPromptStruct,
      int dwFlags,
      Pointer<_DataBlob> pDataOut,
    );

/// DPAPI, data can only be unwrapped by the same windows user on the same machine.
class WindowsDataProtection {
  const WindowsDataProtection._();

  static const _kUiForbidden = 0x1;

  static Uint8List? protect(Uint8List data) => _run('CryptProtectData', data);
  static Uint8List? unprotect(Uint8List data) => _run('CryptUnprotectData', data);

  static Uint8List? _run(String functionName, Uint8List data) {
    final crypt = DynamicLibrary.open('crypt32.dll').lookupFunction<_CryptDataNative, _CryptDataDart>(functionName);
    final localFree = DynamicLibrary.open('kernel32.dll').lookupFunction<Pointer<Void> Function(Pointer<Void>), Pointer<Void> Function(Pointer<Void>)>('LocalFree');

    final inBytes = calloc<Uint8>(data.length);
    final inBlob = calloc<_DataBlob>();
    final outBlob = calloc<_DataBlob>();
    try {
      inBytes.asTypedList(data.length).setAll(0, data);
      inBlob.ref
        ..cbData = data.length
        ..pbData = inBytes;

      final ok = crypt(inBlob, nullptr, nullptr, nullptr, nullptr, _kUiForbidden, outBlob);
      if (ok == 0) return null;

      final out = Uint8List.fromList(outBlob.ref.pbData.asTypedList(outBlob.ref.cbData));
      localFree(outBlob.ref.pbData.cast());
      return out;
    } finally {
      calloc.free(inBytes);
      calloc.free(inBlob);
      calloc.free(outBlob);
    }
  }
}
