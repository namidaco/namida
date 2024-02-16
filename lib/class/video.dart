import 'dart:io';

import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

/// used for stats.
class YoutubeVideoHistory {
  final String id;
  final String title;
  final String channel;
  final String channelUrl;
  final List<YTWatch> watches;

  const YoutubeVideoHistory({
    required this.id,
    required this.title,
    required this.channel,
    required this.channelUrl,
    required this.watches,
  });

  factory YoutubeVideoHistory.fromJson(Map<String, dynamic> json) {
    return YoutubeVideoHistory(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      channel: json['channel'] ?? '',
      channelUrl: json['channelUrl'] ?? '',
      watches: List<YTWatch>.from((json['watches'] as List? ?? []).map((e) => YTWatch.fromJson(e))),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['channel'] = channel;
    data['channelUrl'] = channelUrl;
    data['watches'] = watches;
    return data;
  }
}

class YTWatch {
  final DateTime? dateNull;
  final bool isYTMusic;

  DateTime get date => _date;
  DateTime get _date => dateNull ?? DateTime.now();

  const YTWatch({
    required this.dateNull,
    required this.isYTMusic,
  });

  factory YTWatch.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return YTWatch(dateNull: DateTime(1970), isYTMusic: false);
    }
    return YTWatch(
      dateNull: DateTime.fromMillisecondsSinceEpoch(json['date'] ?? 0),
      isYTMusic: json['isYTMusic'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': _date.millisecondsSinceEpoch,
      'isYTMusic': isYTMusic,
    };
  }

  @override
  bool operator ==(other) {
    if (other is YTWatch) {
      return _date == other._date && isYTMusic == other.isYTMusic;
    }
    return false;
  }

  @override
  int get hashCode => "${_date}_$isYTMusic".hashCode;
}

class NamidaVideo {
  int get resolution => width < height ? width : height;
  final String path;
  final String? ytID;
  final String? nameInCache;
  final int height;
  final int width;
  final int sizeInBytes;
  final double frameratePrecise;
  final int creationTimeMS;
  final int durationMS;
  final int bitrate;

  const NamidaVideo({
    required this.path,
    this.ytID,
    this.nameInCache,
    required this.height,
    required this.width,
    required this.sizeInBytes,
    required this.frameratePrecise,
    required this.creationTimeMS,
    required this.durationMS,
    required this.bitrate,
  });

  factory NamidaVideo.fromJson(Map<String, dynamic> json) {
    final youtubeId = json['ytID'] as String?;
    final path = json['path'] as String?;
    return NamidaVideo(
      path: path ?? '',
      ytID: youtubeId,
      nameInCache: json['nameInCache'] ?? (youtubeId != null ? path?.getFilenameWOExt : null),
      height: json['height'] ?? 0,
      width: json['width'] ?? 0,
      sizeInBytes: json['sizeInBytes'] ?? 0,
      frameratePrecise: json['frameratePrecise'] ?? 0.0,
      creationTimeMS: json['creationTimeMS'] ?? 0,
      durationMS: json['durationMS'] ?? 0,
      bitrate: json['bitrate'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'ytID': ytID,
      'nameInCache': nameInCache,
      'height': height,
      'width': width,
      'sizeInBytes': sizeInBytes,
      'frameratePrecise': frameratePrecise,
      'creationTimeMS': creationTimeMS,
      'durationMS': durationMS,
      'bitrate': bitrate,
    };
  }

  @override
  bool operator ==(other) {
    if (other is NamidaVideo) {
      return path == other.path &&
          ytID == other.ytID &&
          height == other.height &&
          width == other.width &&
          sizeInBytes == other.sizeInBytes &&
          frameratePrecise == other.frameratePrecise &&
          creationTimeMS == other.creationTimeMS;
    }
    return false;
  }

  @override
  int get hashCode => "$path$ytID$height$width$sizeInBytes$frameratePrecise$creationTimeMS".hashCode;

  @override
  String toString() {
    return toJson().toString();
  }
}

extension NamidaVideoUtils on NamidaVideo {
  String framerateText([int displayAbove = 30]) {
    final videoFramerate = framerate;
    return videoFramerate > displayAbove ? videoFramerate.toString() : '';
  }

  int get framerate => frameratePrecise.round();

  String get pathToImage {
    final isLocal = ytID == null;
    final dir = isLocal ? AppDirs.THUMBNAILS : AppDirs.YT_THUMBNAILS;
    final idOrFileNameWOExt = ytID ?? path.getFilenameWOExt;

    String getPath(String prefix) => "$dir$prefix$idOrFileNameWOExt.png";

    if (!isLocal) {
      final path = getPath('');
      if (File(path).existsSync()) {
        return path;
      }
    }
    return getPath('EXT_');
  }

  String get pathToLocalImage {
    final name = path.getFilenameWOExt;
    const prefix = 'EXT_';
    return "${AppDirs.THUMBNAILS}$prefix$name.png";
  }

  String get pathToYTImage => ThumbnailManager.getPathToYTImage(ytID);
}
