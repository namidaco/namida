import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class TrackWithDate {
  late int dateAdded;
  late Track track;
  late bool isYT;

  TrackWithDate(
    this.dateAdded,
    this.track,
    this.isYT,
  );

  TrackWithDate.fromJson(Map<String, dynamic> json) {
    dateAdded = json['dateAdded'] ?? DateTime.now().millisecondsSinceEpoch;
    track = (json['track'] as String).toTrack;
    isYT = json['isYT'] ?? false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['dateAdded'] = dateAdded;
    data['track'] = track.path;
    data['isYT'] = isYT;

    return data;
  }
}

class Track {
  late String title;
  late List<String> artistsList;
  late String album;
  late String albumArtist;
  late List<String> genresList;
  late String composer;
  late int track;
  late int duration;
  late int year;
  late int size;
  late int dateAdded;
  late int dateModified;
  late String path;
  late String comment;
  late int bitrate;
  late int sampleRate;
  late String format;
  late String channels;
  late int discNo;
  late String language;
  late String lyricist;
  late String mood;
  late String tags;

  Track(
    this.title,
    this.artistsList,
    this.album,
    this.albumArtist,
    this.genresList,
    this.composer,
    this.track,
    this.duration,
    this.year,
    this.size,
    this.dateAdded,
    this.dateModified,
    this.path,
    this.comment,
    this.bitrate,
    this.sampleRate,
    this.format,
    this.channels,
    this.discNo,
    this.language,
    this.lyricist,
    this.mood,
    this.tags,
  );

  Track.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    artistsList = List<String>.from(json['artistsList']);
    album = json['album'];
    albumArtist = json['albumArtist'];
    genresList = List<String>.from(json['genresList']);
    composer = json['composer'];
    track = json['track'];
    duration = json['duration'];
    year = json['year'];
    size = json['size'];
    dateAdded = json['dateAdded'];
    dateModified = json['dateModified'];
    path = json['path'];
    comment = json['comment'];
    bitrate = json['bitrate'];
    sampleRate = json['sampleRate'];
    format = json['format'];
    channels = json['channels'];
    discNo = json['discNo'];
    language = json['language'];
    lyricist = json['lyricist'];
    mood = json['mood'];
    tags = json['tags'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['title'] = title;
    data['artistsList'] = artistsList;
    data['album'] = album;
    data['albumArtist'] = albumArtist;
    data['genresList'] = genresList;
    data['composer'] = composer;
    data['track'] = track;
    data['duration'] = duration;
    data['year'] = year;
    data['size'] = size;
    data['dateAdded'] = dateAdded;
    data['dateModified'] = dateModified;
    data['path'] = path;
    data['comment'] = comment;
    data['bitrate'] = bitrate;
    data['sampleRate'] = sampleRate;
    data['format'] = format;
    data['channels'] = channels;
    data['discNo'] = discNo;
    data['language'] = language;
    data['lyricist'] = lyricist;
    data['mood'] = mood;
    data['tags'] = tags;

    return data;
  }

  @override
  bool operator ==(other) {
    if (other is! Track) {
      return false;
    }
    return path == other.path && title == other.title && album == other.album && artistsList == other.artistsList;
  }

  @override
  int get hashCode => (path + title + album + artistsList.toString()).hashCode;
}

extension TrackUtils on Track {
  String get filename => path.getFilename;
  String get filenameWOExt => path.getFilenameWOExt;
  String get extension => path.getExtension;
  String get folderPath => path.getDirectoryName;
  String get folderName => folderPath.split('/').last;
  String get pathToImage => "$kArtworksDirPath$filename.png";
  String get youtubeLink {
    final match = comment.isEmpty ? null : kYoutubeRegex.firstMatch(comment)?[0];
    final match2 = filename.isEmpty ? null : kYoutubeRegex.firstMatch(filename)?[0];
    return match ?? match2 ?? '';
  }

  String get youtubeID => youtubeLink.getYoutubeID;
}
