class DownloadTaskFilename {
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
    for (int i = 0; i < name.length; i++) {
      var c = name[i];
      if (c == '.') {
        charsToRemove++;
      } else {
        break;
      }
    }
    if (charsToRemove > 0) {
      if (charsToRemove >= name.length) {
        return '';
      } else {
        return name.substring(charsToRemove);
      }
    }
    return name;
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
