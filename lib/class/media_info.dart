import 'package:namida/class/replay_gain_data.dart';

class MediaInfo {
  final String path;
  final List<MIStream>? streams;
  final MIFormat? format;

  const MediaInfo({
    required this.path,
    this.streams,
    this.format,
  });

  factory MediaInfo.fromMap(Map<dynamic, dynamic> map) {
    final format = map.getOrUpperCase("format");
    return MediaInfo(
      path: map.getOrLowerCase("PATH"),
      streams: (map.getOrUpperCase("streams") as List?)?.map((e) => MIStream.fromMap(e)).toList(),
      format: format == null ? null : MIFormat.fromMap(format),
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

  factory MIFormat.fromMap(Map<dynamic, dynamic> map) {
    final tags = map.getOrUpperCase("tags");
    final size = map.getOrUpperCase("size");
    return MIFormat(
      duration: (map.getOrUpperCase("duration") as String?).getDuration(),
      startTime: map.getOrUpperCase("start_time"),
      bitRate: map.getOrUpperCase("bit_rate"),
      filename: map.getOrUpperCase("filename"),
      size: size == null ? null : int.tryParse(size),
      probeScore: map.getOrUpperCase("probe_score"),
      nbPrograms: map.getOrUpperCase("nb_programs"),
      nbStreams: map.getOrUpperCase("nb_streams"),
      formatName: map.getOrUpperCase("format_name"),
      tags: tags == null ? null : MIFormatTags.fromMap(tags),
    );
  }

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
  final ReplayGainData? gainData;

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
    this.gainData,
  });

  factory MIFormatTags.fromMap(Map<dynamic, dynamic> map) => MIFormatTags(
        date: map.getOrUpperCase("date"),
        language: map.getOrLowerCase("LANGUAGE"),
        artist: map.getOrUpperCase("artist"),
        album: map.getOrUpperCase("album"),
        composer: map.getOrUpperCase("composer"),
        majorBrand: map.getOrUpperCase("major_brand"),
        description: map.getOrUpperCase("description"),
        remixer: map.getOrLowerCase("REMIXER"),
        synopsis: map.getOrUpperCase("synopsis"),
        title: map.getOrUpperCase("title"),
        encoder: map.getOrUpperCase("encoder"),
        minorVersion: map.getOrUpperCase("minor_version"),
        albumArtist: map.getOrUpperCase("album_artist"),
        genre: map.getOrUpperCase("genre"),
        country: map.getOrUpperCase("Country"),
        label: map.getOrLowerCase("LABEL"),
        comment: map.getOrUpperCase("comment"),
        disc: map.getOrUpperCase("disc"),
        track: map.getOrUpperCase("track"),
        trackTotal: map.getOrLowerCase("TRACKTOTAL"),
        discTotal: map.getOrLowerCase("DISCTOTAL"),
        lyrics: map.getOrUpperCase("lyrics"),
        lyricist: map.getOrLowerCase("LYRICIST"),
        compatibleBrands: map.getOrUpperCase("compatible_brands"),
        mood: map.getOrUpperCase("mood"),
        gainData: ReplayGainData.fromAndroidMap(map),
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
        "gainData": gainData?.toMap(),
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

  factory MIStream.fromMap(Map<dynamic, dynamic> map) {
    final tags = map.getOrUpperCase("tags");
    return MIStream(
      rFrameRate: map.getOrUpperCase("r_frame_rate"),
      startPts: map.getOrUpperCase("start_pts"),
      channelLayout: map.getOrUpperCase("channel_layout"),
      durationTs: map.getOrUpperCase("duration_ts"),
      duration: (map.getOrUpperCase("duration") as String?).getDuration(),
      bitRate: map.getOrUpperCase("bit_rate"),
      codecTagString: map.getOrUpperCase("codec_tag_string"),
      avgFrameRate: map.getOrUpperCase("avg_frame_rate"),
      nbFrames: map.getOrUpperCase("nb_frames"),
      codecLongName: map.getOrUpperCase("codec_long_name"),
      timeBase: map.getOrUpperCase("time_base"),
      profile: map.getOrUpperCase("profile"),
      index: map.getOrUpperCase("index"),
      maxBitRate: map.getOrUpperCase("max_bit_rate"),
      codecName: map.getOrUpperCase("codec_name"),
      tags: tags == null ? null : MIStreamTags.fromMap(tags),
      startTime: map.getOrUpperCase("start_time"),
      disposition: (map.getOrUpperCase("disposition") as Map?)?.map((k, v) => MapEntry<String, int>(k, v)),
      codecTag: map.getOrUpperCase("codec_tag"),
      sampleRate: map.getOrUpperCase("sample_rate"),
      channels: map.getOrUpperCase("channels"),
      sampleFmt: map.getOrUpperCase("sample_fmt"),
      codecTimeBase: map.getOrUpperCase("codec_time_base"),
      bitsPerSample: map.getOrUpperCase("bits_per_sample"),
      codecType: map.getOrUpperCase("codec_type"),
      colorRange: map.getOrUpperCase("color_range"),
      pixFmt: map.getOrUpperCase("pix_fmt"),
      codedHeight: map.getOrUpperCase("coded_height"),
      level: map.getOrUpperCase("level"),
      hasBFrames: map.getOrUpperCase("has_b_frames"),
      refs: map.getOrUpperCase("refs"),
      width: map.getOrUpperCase("width"),
      codedWidth: map.getOrUpperCase("coded_width"),
      height: map.getOrUpperCase("height"),
    );
  }

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
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? track;

  const MIStreamTags({
    this.handlerName,
    this.language,
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.track,
  });

  factory MIStreamTags.fromMap(Map<dynamic, dynamic> map) => MIStreamTags(
        handlerName: map.getOrUpperCase("handler_name"),
        language: map.getOrUpperCase("language"),
        title: map["Title"] ?? map.getOrUpperCase("title"),
        artist: map["Artist"] ?? map.getOrUpperCase("artist"),
        album: map["Album"] ?? map.getOrUpperCase("album"),
        albumArtist: map["AlbumArtist"] ?? map.getOrUpperCase("albumArtist") ?? map.getOrUpperCase("album_artist"),
        track: map["Track"] ?? map.getOrUpperCase("track"),
      );

  Map<dynamic, dynamic> toMap() => {
        "handler_name": handlerName,
        "language": language,
        "title": title,
        "artist": artist,
        "album": album,
        "album_artist": albumArtist,
        "track": track,
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

extension _MapValueGetter on Map {
  dynamic getOrUpperCase(String lowercase) => this[lowercase] ?? this[lowercase.toUpperCase()];
  dynamic getOrLowerCase(String uppercase) => this[uppercase] ?? this[uppercase.toLowerCase()];
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
