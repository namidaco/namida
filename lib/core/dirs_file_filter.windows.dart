part of 'dirs_file_filter.dart';

// by claude
/// lists through `GetFileInformationByHandleEx`, which hands out each entry's size and dates, so files need no stat.
class _WindowsDirsWalker extends _DirsWalker {
  _WindowsDirsWalker(super._parameters);

  static const _kBufferSize = 64 * 1024;
  static const _kInvalidHandle = -1;
  static const _kFileListDirectory = 0x1;
  static const _kFileShareAll = 0x7;
  static const _kOpenExisting = 3;
  static const _kFileFlagBackupSemantics = 0x02000000;
  static const _kFileFullDirectoryInfo = 14;

  static const _kAttributeDirectory = 0x10;
  static const _kAttributeReparsePoint = 0x400;
  static const _kReparseTagSymlink = 0xA000000C;
  static const _kReparseTagMountPoint = 0xA0000003;

  // -- FILE_FULL_DIR_INFO
  static const _kOffsetCreationTime = 8;
  static const _kOffsetLastAccessTime = 16;
  static const _kOffsetLastWriteTime = 24;
  static const _kOffsetEndOfFile = 40;
  static const _kOffsetAttributes = 56;
  static const _kOffsetNameLength = 60;
  static const _kOffsetReparseTag = 64;
  static const _kOffsetName = 68;

  // -- BY_HANDLE_FILE_INFORMATION
  static const _kOffsetVolumeSerial = 28;
  static const _kOffsetFileIndexHigh = 44;
  static const _kOffsetFileIndexLow = 48;

  static const _kFileTimeEpochDifference = 116444736000000000;
  static const _kLongPathThreshold = 248;

  static final _minimumFileDateMS = DateTime(1980).millisecondsSinceEpoch + 1;

  static final _kernel32 = DynamicLibrary.open('kernel32.dll');
  static final _createFile = _kernel32
      .lookupFunction<
        IntPtr Function(Pointer<Utf16> path, Uint32 access, Uint32 share, Pointer<Void> security, Uint32 creation, Uint32 flags, IntPtr template),
        int Function(Pointer<Utf16> path, int access, int share, Pointer<Void> security, int creation, int flags, int template)
      >('CreateFileW');
  static final _getFileInformationByHandleEx = _kernel32
      .lookupFunction<
        Int32 Function(IntPtr handle, Int32 infoClass, Pointer<Uint8> buffer, Uint32 bufferSize),
        int Function(int handle, int infoClass, Pointer<Uint8> buffer, int bufferSize)
      >('GetFileInformationByHandleEx');
  static final _getFileInformationByHandle = _kernel32.lookupFunction<Int32 Function(IntPtr handle, Pointer<Uint8> buffer), int Function(int handle, Pointer<Uint8> buffer)>(
    'GetFileInformationByHandle',
  );
  static final _closeHandle = _kernel32.lookupFunction<Int32 Function(IntPtr handle), int Function(int handle)>('CloseHandle');

  final _dirFilesStats = <int>[];

  late Pointer<Uint8> _buffer;
  late ByteData _data;
  late Uint16List _chars;

  @override
  DirsFileFilterResult walk() {
    final buffer = malloc<Uint8>(_kBufferSize);
    try {
      final bytes = buffer.asTypedList(_kBufferSize);
      _buffer = buffer;
      _data = ByteData.sublistView(bytes);
      _chars = buffer.cast<Uint16>().asTypedList(_kBufferSize ~/ 2);
      return super.walk();
    } finally {
      malloc.free(buffer);
    }
  }

  @override
  void _listDir(_PendingDir dir) {
    final dirFilesStats = _dirFilesStats;
    dirFilesStats.clear();

    final handle = _openDir(dir.path);
    if (handle == _kInvalidHandle) return;

    final buffer = _buffer;
    final data = _data;
    final chars = _chars;
    final dirFilesPaths = _dirFilesPaths;
    final dirSubdirs = _dirSubdirs;
    final respectNoMedia = _parameters._respectNoMedia;
    const noMediaFilename = _DirsWalker._kNoMediaFilename;
    _LinksChain? linksChain = dir.linksChain;

    try {
      if (dir.isLink) {
        final linkTarget = _readDirId(handle);
        if (linkTarget == null) return;
        linksChain = _appendLinkTarget(linkTarget, linksChain);
        if (linksChain == null) return;
      }

      final dirPath = dir.path;
      final endsWithSeparator = dirPath.endsWith(r'\') || dirPath.endsWith('/');
      final pathPrefix = endsWithSeparator ? dirPath : '$dirPath\\';

      while (_getFileInformationByHandleEx(handle, _kFileFullDirectoryInfo, buffer, _kBufferSize) != 0) {
        int offset = 0;
        while (true) {
          final nextEntryOffset = data.getUint32(offset, Endian.little);
          final attributes = data.getUint32(offset + _kOffsetAttributes, Endian.little);
          final nameLength = data.getUint32(offset + _kOffsetNameLength, Endian.little) ~/ 2;
          final nameStart = (offset + _kOffsetName) ~/ 2;
          final name = String.fromCharCodes(chars, nameStart, nameStart + nameLength);

          final isReparsePoint = attributes & _kAttributeReparsePoint != 0;
          final reparseTag = isReparsePoint ? data.getUint32(offset + _kOffsetReparseTag, Endian.little) : 0;
          final isLink = reparseTag == _kReparseTagSymlink || reparseTag == _kReparseTagMountPoint;

          final isDirectory = attributes & _kAttributeDirectory != 0;
          final isSelfOrParent = isDirectory && (name == '.' || name == '..');
          if (!isSelfOrParent) {
            final path = '$pathPrefix$name';
            if (isDirectory) {
              final subdir = _PendingDir(path: path, isLink: isLink, linksChain: linksChain);
              dirSubdirs.add(subdir);
            } else if (isLink) {
              _addLinkedFile(path);
            } else {
              final isNoMediaFile = respectNoMedia && nameLength == noMediaFilename.length && name.toLowerCase() == noMediaFilename;
              if (isNoMediaFile) _dirHasNoMedia = true;
              final size = data.getInt64(offset + _kOffsetEndOfFile, Endian.little);
              final modifiedMS = _readFileTimeMS(data, offset + _kOffsetLastWriteTime);
              final createdMS = _readFileTimeMS(data, offset + _kOffsetCreationTime);
              final accessedMS = _readFileTimeMS(data, offset + _kOffsetLastAccessTime);
              final creationMS = _oldestValidDate(modifiedMS, createdMS, accessedMS);
              dirFilesPaths.add(path);
              dirFilesStats.add(size);
              dirFilesStats.add(modifiedMS);
              dirFilesStats.add(creationMS);
            }
          }

          if (nextEntryOffset == 0) break;
          offset += nextEntryOffset;
        }
      }
    } finally {
      _closeHandle(handle);
    }
  }

  @override
  void _addFileStats(_FilesStatsBuilder statsBuilder, int dirFileIndex) {
    final dirFilesStats = _dirFilesStats;
    final statsOffset = dirFileIndex * FilesStats._kSlots;
    statsBuilder.add(dirFilesStats[statsOffset], dirFilesStats[statsOffset + 1], dirFilesStats[statsOffset + 2]);
  }

  /// the entry of a linked file describes the link itself, the target needs its own stat.
  void _addLinkedFile(String path) {
    final stat = FileStat.statSync(path);
    if (stat.type != FileSystemEntityType.file) return;
    final modifiedMS = stat.modified.millisecondsSinceEpoch;
    final creationMS = stat.creationDate.millisecondsSinceEpoch;
    _dirFilesPaths.add(path);
    _dirFilesStats.add(stat.size);
    _dirFilesStats.add(modifiedMS);
    _dirFilesStats.add(creationMS);
  }

  int _openDir(String path) {
    final pathPrefixed = _toNativePath(path);
    final nativePath = pathPrefixed.toNativeUtf16(allocator: malloc);
    try {
      return _createFile(nativePath, _kFileListDirectory, _kFileShareAll, nullptr, _kOpenExisting, _kFileFlagBackupSemantics, 0);
    } finally {
      malloc.free(nativePath);
    }
  }

  String _toNativePath(String path) {
    if (path.length < _kLongPathThreshold || path.startsWith(r'\\?\')) return path;
    final normalized = path.replaceAll('/', r'\');
    if (!normalized.startsWith(r'\\')) return '\\\\?\\$normalized';
    final serverAndShare = normalized.substring(2);
    return '\\\\?\\UNC\\$serverAndShare';
  }

  (int volume, int index)? _readDirId(int handle) {
    final didGetInfo = _getFileInformationByHandle(handle, _buffer) != 0;
    if (!didGetInfo) return null;
    final data = _data;
    final volume = data.getUint32(_kOffsetVolumeSerial, Endian.little);
    final indexHigh = data.getUint32(_kOffsetFileIndexHigh, Endian.little);
    final indexLow = data.getUint32(_kOffsetFileIndexLow, Endian.little);
    final index = (indexHigh << 32) | indexLow;
    return (volume, index);
  }

  static int _readFileTimeMS(ByteData data, int offset) {
    final fileTime = data.getInt64(offset, Endian.little);
    if (fileTime <= 0) return 0;
    return (fileTime - _kFileTimeEpochDifference) ~/ 10000;
  }

  static int _oldestValidDate(int modifiedMS, int createdMS, int accessedMS) {
    final minimumMS = _minimumFileDateMS;
    int oldestMS = 0;
    if (modifiedMS > minimumMS) oldestMS = modifiedMS;
    if (createdMS > minimumMS && (oldestMS == 0 || createdMS < oldestMS)) oldestMS = createdMS;
    if (accessedMS > minimumMS && (oldestMS == 0 || accessedMS < oldestMS)) oldestMS = accessedMS;
    return oldestMS;
  }
}
