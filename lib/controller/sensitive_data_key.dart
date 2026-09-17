import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/platform/namida_channel/windows_data_protection.dart';
import 'package:namida/core/constants.dart';

typedef SensitiveDataKeyResult = ({String key, bool isNew});

enum SensitiveDb { accounts, memberships }

/// Per-install key for the encrypted dbs
///
/// Wrapped by DPAPI on windows (except portable, its data is meant to move between machines),
/// otherwise kept as an owner-only file next to the dbs (already sandboxed on android).
///
/// by claude
class SensitiveDataKey {
  const SensitiveDataKey._();

  static const _markerRaw = 0;
  static const _markerProtected = 1;

  static const _useDataProtection = !isWindowsPortable;

  static final _file = File(FileParts.joinPath(AppDirs.YOUTIPIE_DATA, '.k'));

  /// Available once [obtain] completes.
  static String? current;

  static Future<SensitiveDataKeyResult>? _obtainFuture;

  /// When the key is new, it's only saved after [markMigrated] was called for every [SensitiveDb],
  /// so that an interrupted migration runs again next launch.
  static Future<SensitiveDataKeyResult> obtain() => _obtainFuture ??= _obtain();

  static Future<SensitiveDataKeyResult> _obtain() async {
    final stored = await _read();
    final key = stored ?? _generate();
    current = key;
    return (key: key, isNew: stored == null);
  }

  static final _migrated = <SensitiveDb>{};

  static Future<void> markMigrated(SensitiveDb db) async {
    _migrated.add(db);
    if (_migrated.length < SensitiveDb.values.length) return;
    final key = current;
    if (key != null) await _persist(key);
  }

  static String _generate() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static Future<String?> _read() async {
    try {
      final bytes = await _file.readAsBytes();
      if (bytes.length < 2) return null;
      final payload = Uint8List.sublistView(bytes, 1);
      final raw = bytes[0] == _markerProtected ? WindowsDataProtection.unprotect(payload) : payload;
      if (raw == null || raw.isEmpty) return null;
      return utf8.decode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _persist(String key) async {
    final raw = Uint8List.fromList(utf8.encode(key));
    Uint8List? protected;
    if (_useDataProtection && Platform.isWindows) {
      try {
        protected = WindowsDataProtection.protect(raw);
      } catch (_) {}
    }

    final builder = BytesBuilder(copy: false)
      ..addByte(protected != null ? _markerProtected : _markerRaw)
      ..add(protected ?? raw);

    await _file.create(recursive: true);
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        await Process.run('chmod', ['600', _file.path]);
      } catch (_) {}
    }
    await _file.writeAsBytes(builder.takeBytes(), flush: true);
  }
}
