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
  late String pathToImage;
  late String pathToImageComp;
  late String folderPath;
  late String displayName;
  late String displayNameWOExt;
  late String fileExtension;
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
    this.pathToImage,
    this.pathToImageComp,
    this.folderPath,
    this.displayName,
    this.displayNameWOExt,
    this.fileExtension,
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
    // Track(
    //   json['title'],
    //   json['artistsList'],
    //   json['album'],
    //   json['albumArtist'],
    //   json['genresList'],
    //   json['composer'],
    //   json['track'],
    //   json['duration'],
    //   json['year'],
    //   json['size'],
    //   json['dateAdded'],
    //   json['dateModified'],
    //   json['path'],
    //   json['pathToImage'],
    //   json['pathToImageComp'],
    //   json['folderPath'],
    //   json['displayName'],
    //   json['displayNameWOExt'],
    //   json['fileExtension'],
    //   json['comment'],
    //   json['bitrate'],
    //   json['sampleRate'],
    //   json['format'],
    //   json['channels'],
    //   json['discNo'],
    //   json['language'],
    //   json['lyricist'],
    //   json['mood'],
    //   json['tags'],
    // );
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
    pathToImage = json['pathToImage'];
    pathToImageComp = json['pathToImageComp'];
    folderPath = json['folderPath'];
    displayName = json['displayName'];
    displayNameWOExt = json['displayNameWOExt'];
    fileExtension = json['fileExtension'];
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
    data['pathToImage'] = pathToImage;
    data['pathToImageComp'] = pathToImageComp;
    data['folderPath'] = folderPath;
    data['displayName'] = displayName;
    data['displayNameWOExt'] = displayNameWOExt;
    data['fileExtension'] = fileExtension;
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
}
