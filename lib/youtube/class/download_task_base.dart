abstract class DownloadTask<T> {
  const DownloadTask();

  @override
  String toString();
}

class DownloadTaskFilename extends DownloadTask {
  String filename;

  String get key => hashCode.toString();

  DownloadTaskFilename.create({
    required String initialFilename,
  }) : filename = initialFilename;

  @override
  String toString() => filename;
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

  const DownloadTaskGroupName({
    required this.groupName,
  });

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
