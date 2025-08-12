class DownloadTaskFilename {
  static final RegExp cleanupFilenameRegex = RegExp(r'[*#\$|/\\!^:"\?%]', caseSensitive: false);
  static String cleanupFilename(String filename) => filename.replaceAll(DownloadTaskFilename.cleanupFilenameRegex, '_');

  static int _numberKey = 0;

  String filename;
  final String key;

  static DownloadTaskFilename create({
    required String initialFilename,
  }) =>
      DownloadTaskFilename._(
        filename: initialFilename,
        key: _createKey(),
      );

  DownloadTaskFilename._({
    required this.filename,
    required String? key,
  }) : this.key = key ?? _createKey();

  static String _createKey() => ((_numberKey++).hashCode ^ DateTime.now().microsecondsSinceEpoch.hashCode).toString();

  @override
  String toString() => filename;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'filename': filename,
      'key': key,
    };
  }

  factory DownloadTaskFilename.fromMap(dynamic value) {
    if (value is Map) {
      return DownloadTaskFilename._(
        filename: value['filename'] as String? ?? 'UNKNOWN_FILENAME',
        key: value['key'] as String?,
      );
    }
    // -- old string only
    return DownloadTaskFilename._(
      filename: value as String,
      key: null,
    );
  }

  @override
  bool operator ==(other) {
    return other is DownloadTaskFilename && filename == other.filename && key == other.key;
  }

  @override
  int get hashCode => filename.hashCode ^ key.hashCode;
}

class DownloadTaskVideoId {
  final String videoId;

  const DownloadTaskVideoId({
    required this.videoId,
  });

  @override
  bool operator ==(covariant DownloadTaskVideoId other) {
    return videoId == other.videoId;
  }

  @override
  int get hashCode => videoId.hashCode;

  @override
  String toString() => videoId;
}

class DownloadTaskGroupName {
  final String groupName;

  DownloadTaskGroupName({
    required String groupName,
  }) : this.groupName = _sanitize(groupName);

  static String _sanitize(String name) {
    int charsToRemove = 0;
    // -- remove all starting dots ..
    for (int i = 0; i < name.length; i++) {
      var c = name[i];
      if (c == '.') {
        charsToRemove++;
      } else {
        break;
      }
    }
    String finalName = name;
    if (charsToRemove > 0) {
      if (charsToRemove >= finalName.length) {
        finalName = '';
      } else {
        finalName = name.substring(charsToRemove);
      }
    }
    finalName = finalName.replaceAll(DownloadTaskFilename.cleanupFilenameRegex, '_');
    return finalName;
  }

  const DownloadTaskGroupName.defaulty() : groupName = '';

  @override
  bool operator ==(covariant DownloadTaskGroupName other) {
    return groupName == other.groupName;
  }

  @override
  int get hashCode => groupName.hashCode;

  @override
  String toString() => groupName;
}
