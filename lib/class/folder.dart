import 'package:namida/class/track.dart';

class Folder {
  late final int splits;
  late final String folderName;
  late final String path;
  late final List<Track> tracks;
  Folder(
    this.splits,
    this.folderName,
    this.path,
    this.tracks,
  );
}
