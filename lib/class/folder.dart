import 'package:namida/class/track.dart';

class Folder {
  late final String path;
  late final List<Track> tracks;

  Folder(
    this.path,
    this.tracks,
  );
}

extension FolderUtils on Folder {
  String get folderName => path.split('/').last;
  // List<Track> get tracks => allTracksInLibrary.where((element) => path == element.folderPath).toList();
}
