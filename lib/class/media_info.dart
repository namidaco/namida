class MediaInfo {
  final String path;
  final List<MIStream>? streams;
  final MIFormat? format;

  const MediaInfo({
    required this.path,
    this.streams,
    this.format,
  });

  factory MediaInfo.fromMap(Map<dynamic, dynamic> json) {
    return MediaInfo(
      path: json["PATH"],
      streams: (json["streams"] as List?)?.map((e) => MIStream.fromMap(e)).toList(),
      format: json["format"] == null ? null : MIFormat.fromMap(json["format"]),
    );
  }

  Map<dynamic, dynamic> toMap() => {
        "streams": streams?.map((e) => e.toMap()),
        "format": format?.toMap(),
      };
}

class MIFormat {
  final Duration? duration;
  final String? startTime;
  final String? bitRate;
  final String? filename;
  final int? size;
  final int? probeScore;
  final int? nbPrograms;
  final int? nbStreams;
  final String? formatName;
  final MIFormatTags? tags;

  const MIFormat({
    this.duration,
    this.startTime,
    this.bitRate,
    this.filename,
    this.size,
    this.probeScore,
    this.nbPrograms,
    this.nbStreams,
    this.formatName,
    this.tags,
  });

  factory MIFormat.fromMap(Map<dynamic, dynamic> json) => MIFormat(
        duration: (json["duration"] as String?).getDuration(),
        startTime: json["start_time"],
        bitRate: json["bit_rate"],
        filename: json["filename"],
        size: json["size"] == null ? null : int.tryParse(json["size"]),
        probeScore: json["probe_score"],
        nbPrograms: json["nb_programs"],
        nbStreams: json["nb_streams"],
        formatName: json["format_name"],
        tags: json["tags"] == null ? null : MIFormatTags.fromMap(json["tags"]),
      );

  Map<dynamic, dynamic> toMap() => {
        "duration": duration?.inMilliseconds ?? 0 / 1000,
        "start_time": startTime,
        "bit_rate": bitRate,
        "filename": filename,
        "size": size,
        "probe_score": probeScore,
        "nb_programs": nbPrograms,
        "nb_streams": nbStreams,
        "format_name": formatName,
        "tags": tags?.toMap(),
      };
}

class MIFormatTags {
  final String? date;
  final String? language;
  final String? artist;
  final String? album;
  final String? composer;
  final String? majorBrand;
  final String? description;
  final String? remixer;
  final String? synopsis;
  final String? title;
  final String? encoder;
  final String? minorVersion;
  final String? albumArtist;
  final String? genre;
  final String? country;
  final String? label;
  final String? comment;
  final String? disc;
  final String? track;
  final String? trackTotal;
  final String? discTotal;
  final String? lyrics;
  final String? lyricist;
  final String? compatibleBrands;
  final String? mood;

  const MIFormatTags({
    this.date,
    this.language,
    this.artist,
    this.album,
    this.composer,
    this.majorBrand,
    this.description,
    this.remixer,
    this.synopsis,
    this.title,
    this.encoder,
    this.minorVersion,
    this.albumArtist,
    this.genre,
    this.country,
    this.label,
    this.comment,
    this.disc,
    this.track,
    this.trackTotal,
    this.discTotal,
    this.lyrics,
    this.lyricist,
    this.compatibleBrands,
    this.mood,
  });

  factory MIFormatTags.fromMap(Map<dynamic, dynamic> json) => MIFormatTags(
        date: json["date"],
        language: json["LANGUAGE"],
        artist: json["artist"],
        album: json["album"],
        composer: json["composer"],
        majorBrand: json["major_brand"],
        description: json["description"],
        remixer: json["REMIXER"],
        synopsis: json["synopsis"],
        title: json["title"],
        encoder: json["encoder"],
        minorVersion: json["minor_version"],
        albumArtist: json["album_artist"],
        genre: json["genre"],
        country: json["Country"],
        label: json["LABEL"],
        comment: json["comment"],
        disc: json["disc"],
        track: json["track"],
        trackTotal: json["TRACKTOTAL"],
        discTotal: json["DISCTOTAL"],
        lyrics: json["lyrics"],
        lyricist: json["LYRICIST"],
        compatibleBrands: json["compatible_brands"],
        mood: json["mood"],
      );

  Map<dynamic, dynamic> toMap() => {
        "date": date,
        "LANGUAGE": language,
        "artist": artist,
        "album": album,
        "composer": composer,
        "major_brand": majorBrand,
        "description": description,
        "REMIXER": remixer,
        "synopsis": synopsis,
        "title": title,
        "encoder": encoder,
        "minor_version": minorVersion,
        "album_artist": albumArtist,
        "genre": genre,
        "Country": country,
        "LABEL": label,
        "comment": comment,
        "disc": disc,
        "track": track,
        "TRACKTOTAL": trackTotal,
        "DISCTOTAL": discTotal,
        "lyrics": lyrics,
        "LYRICIST": lyricist,
        "compatible_brands": compatibleBrands,
        "mood": mood,
      };
}

class MIStream {
  final String? rFrameRate;
  final int? startPts;
  final String? channelLayout;
  final int? durationTs;
  final Duration? duration;
  final String? bitRate;
  final String? codecTagString;
  final String? avgFrameRate;
  final String? nbFrames;
  final String? codecLongName;
  final String? timeBase;
  final String? profile;
  final int? index;
  final String? maxBitRate;
  final String? codecName;
  final MIStreamTags? tags;
  final String? startTime;
  final Map<String, int>? disposition;
  final String? codecTag;
  final String? sampleRate;
  final int? channels;
  final String? sampleFmt;
  final String? codecTimeBase;
  final int? bitsPerSample;
  final String? codecType;
  final String? colorRange;
  final String? pixFmt;
  final int? codedHeight;
  final int? level;
  final int? hasBFrames;
  final int? refs;
  final int? width;
  final int? codedWidth;
  final int? height;

  const MIStream({
    this.rFrameRate,
    this.startPts,
    this.channelLayout,
    this.durationTs,
    this.duration,
    this.bitRate,
    this.codecTagString,
    this.avgFrameRate,
    this.nbFrames,
    this.codecLongName,
    this.timeBase,
    this.profile,
    this.index,
    this.maxBitRate,
    this.codecName,
    this.tags,
    this.startTime,
    this.disposition,
    this.codecTag,
    this.sampleRate,
    this.channels,
    this.sampleFmt,
    this.codecTimeBase,
    this.bitsPerSample,
    this.codecType,
    this.colorRange,
    this.pixFmt,
    this.codedHeight,
    this.level,
    this.hasBFrames,
    this.refs,
    this.width,
    this.codedWidth,
    this.height,
  });

  factory MIStream.fromMap(Map<dynamic, dynamic> json) => MIStream(
        rFrameRate: json["r_frame_rate"],
        startPts: json["start_pts"],
        channelLayout: json["channel_layout"],
        durationTs: json["duration_ts"],
        duration: (json["duration"] as String?).getDuration(),
        bitRate: json["bit_rate"],
        codecTagString: json["codec_tag_string"],
        avgFrameRate: json["avg_frame_rate"],
        nbFrames: json["nb_frames"],
        codecLongName: json["codec_long_name"],
        timeBase: json["time_base"],
        profile: json["profile"],
        index: json["index"],
        maxBitRate: json["max_bit_rate"],
        codecName: json["codec_name"],
        tags: json["tags"] == null ? null : MIStreamTags.fromMap(json["tags"]),
        startTime: json["start_time"],
        disposition: (json["disposition"] as Map?)?.map((k, v) => MapEntry<String, int>(k, v)),
        codecTag: json["codec_tag"],
        sampleRate: json["sample_rate"],
        channels: json["channels"],
        sampleFmt: json["sample_fmt"],
        codecTimeBase: json["codec_time_base"],
        bitsPerSample: json["bits_per_sample"],
        codecType: json["codec_type"],
        colorRange: json["color_range"],
        pixFmt: json["pix_fmt"],
        codedHeight: json["coded_height"],
        level: json["level"],
        hasBFrames: json["has_b_frames"],
        refs: json["refs"],
        width: json["width"],
        codedWidth: json["coded_width"],
        height: json["height"],
      );

  Map<dynamic, dynamic> toMap() => {
        "r_frame_rate": rFrameRate,
        "start_pts": startPts,
        "channel_layout": channelLayout,
        "duration_ts": durationTs,
        "duration": duration?.inMilliseconds ?? 0 / 1000,
        "bit_rate": bitRate,
        "codec_tag_string": codecTagString,
        "avg_frame_rate": avgFrameRate,
        "nb_frames": nbFrames,
        "codec_long_name": codecLongName,
        "time_base": timeBase,
        "profile": profile,
        "index": index,
        "max_bit_rate": maxBitRate,
        "codec_name": codecName,
        "tags": tags?.toMap(),
        "start_time": startTime,
        "disposition": disposition?.map((k, v) => MapEntry<dynamic, dynamic>(k, v)),
        "codec_tag": codecTag,
        "sample_rate": sampleRate,
        "channels": channels,
        "sample_fmt": sampleFmt,
        "codec_time_base": codecTimeBase,
        "bits_per_sample": bitsPerSample,
        "codec_type": codecType,
        "color_range": colorRange,
        "pix_fmt": pixFmt,
        "coded_height": codedHeight,
        "level": level,
        "has_b_frames": hasBFrames,
        "refs": refs,
        "width": width,
        "coded_width": codedWidth,
        "height": height,
      };
}

class MIStreamTags {
  final String? handlerName;
  final String? language;

  const MIStreamTags({
    this.handlerName,
    this.language,
  });

  factory MIStreamTags.fromMap(Map<dynamic, dynamic> json) => MIStreamTags(
        handlerName: json["handler_name"],
        language: json["language"],
      );

  Map<dynamic, dynamic> toMap() => {
        "handler_name": handlerName,
        "language": language,
      };
}

extension StringToDuration on String? {
  /// parses '232.432000' text
  Duration? getDuration() {
    Duration? dur;
    if (this != null) {
      final parsed = double.tryParse(this!);
      if (parsed != null) {
        dur = Duration(milliseconds: (parsed * 1000).round());
      }
    }
    return dur;
  }
}

extension SreamTypeDetector on MIStream {
  StreamType? get streamType => _streamTypes[codecType];
}

final _streamTypes = <String, StreamType>{
  "video": StreamType.video,
  "audio": StreamType.audio,
  "subtitle": StreamType.subtitle,
  "attachment": StreamType.attachment,
  "data": StreamType.data,
};

enum StreamType {
  video,
  audio,
  subtitle,
  attachment,
  data,
}
