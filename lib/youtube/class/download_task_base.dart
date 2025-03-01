class DownloadTaskFilename {
  static final RegExp cleanupFilenameRegex = RegExp(r'[*#\$|/\\!^:"\?]', caseSensitive: false);
  static String cleanupFilename(String filename) => filename.replaceAll(DownloadTaskFilename.cleanupFilenameRegex, '_');

  String filename;
  late String key;
  late int _uniqueKey;

  DownloadTaskFilename.create({
    required String initialFilename,
  }) : filename = initialFilename {
    _uniqueKey = hashCode ^ DateTime.now().microsecondsSinceEpoch.hashCode;
    key = _uniqueKey.toString();
  }

  DownloadTaskFilename._({
    required this.filename,
    required String? key,
  }) {
    this._uniqueKey = (key == null ? null : int.tryParse(key)) ?? (hashCode ^ DateTime.now().microsecondsSinceEpoch);
    this.key = _uniqueKey.toString();
  }

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
