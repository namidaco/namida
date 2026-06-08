import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/replay_gain_data.dart';
import 'package:namida/core/extensions.dart';

class MediaInfo {
  final String path;
  final List<MIStream>? streams;
  final MIFormat? format;

  const MediaInfo({
    required this.path,
    required this.streams,
    required this.format,
  });

  MIStream? getAudioStream() => streams?.firstWhereEff((e) => e.streamType == StreamType.audio) ?? streams?.firstOrNull;
  MIStream? getVideoStream() => streams?.firstWhereEff((e) => e.streamType == StreamType.video) ?? streams?.firstOrNull;
  static const _losslessFormats = {'flac', 'alac', 'wav', 'pcm_s16le', 'pcm_s24le', 'pcm_s32le', 'ape'};

  bool? isLossless([MIStream? audioStream]) {
    String? formatName = (audioStream ?? getAudioStream())?.codecName ?? format?.formatName;

    if (formatName != null && formatName.isNotEmpty) {
      final confirmedLossless = _losslessFormats.contains(formatName.toLowerCase());
      if (confirmedLossless) {
        return true;
      } else {
        // -- we cant tell for sure if its not lossless
        return null;
      }
    }
    return null;
  }

  static int? extractInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static num? extractNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  factory MediaInfo.fromMap(Map<String, dynamic> map) {
    final format = map.getOrUpperCase("format");
    return MediaInfo(
      path: map.getOrLowerCase("PATH"),
      streams: (map.getOrUpperCase("streams") as List?)?.map((e) => MIStream.fromMap(e)).toList(),
      format: format == null ? null : MIFormat.fromMap(format),
    );
  }

  Map<dynamic, dynamic> toMap() => {
    "streams": streams?.map((e) => e.toMap()).toFixedList(),
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
    required this.duration,
    required this.startTime,
    required this.bitRate,
    required this.filename,
    required this.size,
    required this.probeScore,
    required this.nbPrograms,
    required this.nbStreams,
    required this.formatName,
    required this.tags,
  });

  factory MIFormat.fromMap(Map<String, dynamic> map) {
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
  final int? bpm;
  final double? rating;
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
  final FTagsSortInfo? sortInfo;

  const MIFormatTags({
    required this.date,
    required this.bpm,
    required this.rating,
    required this.language,
    required this.artist,
    required this.album,
    required this.composer,
    required this.majorBrand,
    required this.description,
    required this.remixer,
    required this.synopsis,
    required this.title,
    required this.encoder,
    required this.minorVersion,
    required this.albumArtist,
    required this.genre,
    required this.country,
    required this.label,
    required this.comment,
    required this.disc,
    required this.track,
    required this.trackTotal,
    required this.discTotal,
    required this.lyrics,
    required this.lyricist,
    required this.compatibleBrands,
    required this.mood,
    required this.gainData,
    required this.sortInfo,
  });

  factory MIFormatTags.fromMap(Map<String, dynamic> map) {
    final ratingRaw = MediaInfo.extractNum(map.getOrUpperCase("rating")); // 0-5
    return MIFormatTags(
      date: map.getOrUpperCase("date") ?? map["Date"],
      bpm: MediaInfo.extractInt(map.getOrLowerCase("BPM")) ?? MediaInfo.extractInt(map.getOrLowerCase("TBPM")),
      rating: ratingRaw == null ? null : ratingRaw / 5.0,
      language: map.getOrLowerCase("LANGUAGE") ?? map["Language"],
      artist: map.getOrUpperCase("artist") ?? map["Artist"],
      album: map.getOrUpperCase("album") ?? map["Album"],
      composer: map.getOrUpperCase("composer") ?? map["Composer"],
      majorBrand: map.getOrUpperCase("major_brand"),
      description: map.getOrUpperCase("description") ?? map["Description"],
      remixer: map.getOrLowerCase("REMIXER") ?? map["Remixer"],
      synopsis: map.getOrUpperCase("synopsis") ?? map["Synopsis"],
      title: map.getOrUpperCase("title") ?? map["Title"],
      encoder: map.getOrUpperCase("encoder"),
      minorVersion: map.getOrUpperCase("minor_version"),
      albumArtist: map.getOrUpperCase("album_artist") ?? map["Album Artist"],
      genre: map.getOrUpperCase("genre") ?? map["Genre"],
      country: map.getOrUpperCase("country") ?? map["Country"],
      label: map.getOrLowerCase("LABEL") ?? map["Label"],
      comment: map.getOrUpperCase("comment") ?? map["Comment"],
      disc: map.getOrUpperCase("disc") ?? map["Disc"],
      track: map.getOrUpperCase("track") ?? map["Track"],
      trackTotal: map.getOrLowerCase("TRACKTOTAL") ?? map.getOrLowerCase("TRACK_TOTAL"),
      discTotal: map.getOrLowerCase("DISCTOTAL") ?? map.getOrLowerCase("DISC_TOTAL"),
      lyrics: map.getOrUpperCase("lyrics") ?? map.getOrUpperCase("lyrics-XXX") ?? map.filterStartsWith('lyrics') ?? map.filterStartsWith('LYRICS') ?? map["Lyrics"],
      lyricist: map.getOrLowerCase("LYRICIST") ?? map["Lyricist"],
      compatibleBrands: map.getOrUpperCase("compatible_brands"),
      mood: map.getOrUpperCase("mood") ?? map["Mood"],
      gainData: ReplayGainData.fromAndroidMap(map),
      sortInfo: FTagsSortInfo.fromFFmpegMap(map),
    );
  }

  Map<dynamic, dynamic> toMap() => {
    "date": date,
    "BPM": bpm,
    "rating": rating,
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
    "sortInfo": sortInfo?.toMap(),
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
    required this.rFrameRate,
    required this.startPts,
    required this.channelLayout,
    required this.durationTs,
    required this.duration,
    required this.bitRate,
    required this.codecTagString,
    required this.avgFrameRate,
    required this.nbFrames,
    required this.codecLongName,
    required this.timeBase,
    required this.profile,
    required this.index,
    required this.maxBitRate,
    required this.codecName,
    required this.tags,
    required this.startTime,
    required this.disposition,
    required this.codecTag,
    required this.sampleRate,
    required this.channels,
    required this.sampleFmt,
    required this.codecTimeBase,
    required this.bitsPerSample,
    required this.codecType,
    required this.colorRange,
    required this.pixFmt,
    required this.codedHeight,
    required this.level,
    required this.hasBFrames,
    required this.refs,
    required this.width,
    required this.codedWidth,
    required this.height,
  });

  factory MIStream.fromMap(Map<String, dynamic> map) {
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
      bitsPerSample: MediaInfo.extractInt(map.getOrUpperCase("bits_per_raw_sample")) ?? MediaInfo.extractInt(map.getOrUpperCase("bits_per_sample")),
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
    required this.handlerName,
    required this.language,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.track,
  });

  factory MIStreamTags.fromMap(Map<String, dynamic> map) => MIStreamTags(
    handlerName: map.getOrUpperCase("handler_name"),
    language: map["Language"] ?? map.getOrUpperCase("language"),
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

extension _MapValueGetter on Map<String, dynamic> {
  dynamic getOrUpperCase(String lowercase) => this[lowercase] ?? this[lowercase.toUpperCase()];
  dynamic getOrLowerCase(String uppercase) => this[uppercase] ?? this[uppercase.toLowerCase()];

  dynamic filterStartsWith(String lowercase) {
    for (final k in keys) {
      if (k.startsWith(lowercase)) {
        return this[k]!;
      }
    }
    return null;
  }
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
