import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class TrackWithDate {
  late final int dateAdded;
  late final Track track;
  late final TrackSource source;

  TrackWithDate(
    this.dateAdded,
    this.track,
    this.source,
  );

  TrackWithDate.fromJson(Map<String, dynamic> json) {
    dateAdded = json['dateAdded'] ?? DateTime.now().millisecondsSinceEpoch;
    track = (json['track'] as String).toTrack;
    source = TrackSource.values.getEnum(json['source']) ?? TrackSource.local;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['dateAdded'] = dateAdded;
    data['track'] = track.path;
    data['source'] = source.convertToString;

    return data;
  }
}

class Track {
  late final String title;
  late final List<String> artistsList;
  late final String album;
  late final String albumArtist;
  late final List<String> genresList;
  late final String composer;
  late final int track;
  late final int duration;
  late final int year;
  late final int size;
  late final int dateAdded;
  late final int dateModified;
  late final String path;
  late final String comment;
  late final int bitrate;
  late final int sampleRate;
  late final String format;
  late final String channels;
  late final int discNo;
  late final String language;
  late final String lyrics;
  late final String mood;

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
    this.lyrics,
    this.mood,
  );

  Track.fromJson(Map<String, dynamic> json) {
    title = json['title'] ?? '';
    artistsList = List<String>.from(json['artistsList'] ?? []);
    album = json['album'] ?? '';
    albumArtist = json['albumArtist'] ?? '';
    genresList = List<String>.from(json['genresList'] ?? []);
    composer = json['composer'] ?? '';
    track = json['track'] ?? 0;
    duration = json['duration'] ?? 0;
    year = json['year'] ?? 0;
    size = json['size'] ?? 0;
    dateAdded = json['dateAdded'] ?? 0;
    dateModified = json['dateModified'] ?? 0;
    path = json['path'] ?? '';
    comment = json['comment'] ?? '';
    bitrate = json['bitrate'] ?? 0;
    sampleRate = json['sampleRate'] ?? 0;
    format = json['format'] ?? '';
    channels = json['channels'] ?? '';
    discNo = json['discNo'] ?? 0;
    language = json['language'] ?? '';
    lyrics = json['lyrics'] ?? '';
    mood = json['mood'] ?? '';
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
    data['lyrics'] = lyrics;
    data['mood'] = mood;

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
  String get pathToImage => "$k_DIR_ARTWORKS$filename.png";
  String get youtubeLink {
    final match = comment.isEmpty ? null : kYoutubeRegex.firstMatch(comment)?[0];
    final match2 = filename.isEmpty ? null : kYoutubeRegex.firstMatch(filename)?[0];
    return match ?? match2 ?? '';
  }

  String get youtubeID => youtubeLink.getYoutubeID;
  String get audioInfoFormatted => [
        Duration(milliseconds: duration).label,
        size.fileSizeFormatted,
        "$bitrate kps",
        "$sampleRate hz",
      ].join(' • ');
  String get audioInfoFormattedCompact => [
        format,
        "$channels ch",
        "$bitrate kps",
        "${sampleRate / 1000} khz",
      ].join(' • ');
}
