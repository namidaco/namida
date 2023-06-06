import 'dart:io';

import 'package:namida/class/track.dart';

class Folder {
  final String path;
  final List<Track> tracks;

  Folder(
    this.path,
    this.tracks,
  );
}

extension FolderUtils on Folder {
  String get folderName => path.split(Platform.pathSeparator).last;
  // List<Track> get tracks => allTracksInLibrary.where((element) => path == element.folderPath).toList();
}
