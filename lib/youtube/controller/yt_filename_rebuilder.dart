part of 'youtube_controller.dart';

class _YtFilenameRebuilder {
  _YtFilenameRebuilder();

  final paramRegex = RegExp(r'%\((\w+)\)s');

  bool get fallbackExtractInfoFromDescription => settings.youtube.fallbackExtractInfoDescription.value;

  String? rebuildFilenameWithDecodedParams(
    String filenameEncoded,
    String videoId,
    VideoStreamInfo? streamInfo,
    YoutiPieVideoPageResult? pageResult,
    StreamInfoItem? videoItem,
    PlaylistBasicInfo? playlistInfo,
    VideoStream? videoStream,
    AudioStream? audioStream,
    int? originalIndex,
    int? totalLength,
  ) {
    bool didConvertSmth = false;
    var decodedFilename = filenameEncoded.replaceAllMapped(
      paramRegex,
      (match) {
        var keyword = match.group(1)?.toLowerCase();
        if (keyword != null) {
          try {
            var converted = _keywordToInfo(
              keyword,
              videoId,
              streamInfo,
              pageResult,
              videoItem,
              playlistInfo,
              videoStream,
              audioStream,
              originalIndex,
              totalLength,
            );
            if (converted != null) {
              didConvertSmth = true;
              return converted;
            }
          } on _NonMatched catch (_) {
            // confusing param, ex: `%(blabla)s`
            // ain't changing it to 'NA' or etc.
            return match.input;
          }
        }

        return 'NA';
      },
    );
    return didConvertSmth ? decodedFilename : null;
  }

  bool isBuildingDefaultFilenameSafe(String defaultFilename) {
    return encodedParamsThatShouldExistInFilename.any((element) => defaultFilename.contains(buildParamForFilename(element)));
  }

  final encodedParamsThatShouldExistInFilename = const [
    'video_id',
    'id',
    'video_url',
    'url',
    'video_title',
    'title',
    'playlist_index',
    'playlist_autonumber',
  ];

  final availableEncodedParams = const [
    'video_id', // 'id'
    'video_url', // 'url'
    'video_title', // 'fulltitle'
    'title',
    'artist',
    'genre',
    'ext',
    'channel_fulltitle',
    'channel', // 'uploader'
    'channel_id', //'uploader_id'
    'channel_url', // 'uploader_url'
    'timestamp',
    'upload_date',
    'view_count',
    'like_count',
    'description',
    'duration',
    'duration_string',
    'playlist_title',
    'playlist_id',
    'playlist',
    'playlist_count',
    'playlist_index',
    'playlist_autonumber',
    'none',
  ];

  String buildParamForFilename(String e) => '%($e)s';

  String? _keywordToInfo(String keyword, String videoId, VideoStreamInfo? streamInfo, YoutiPieVideoPageResult? pageResult, StreamInfoItem? videoItem,
      PlaylistBasicInfo? playlistInfo, VideoStream? videoStream, AudioStream? audioStream, int? originalIndex, int? totalLength) {
    return switch (keyword) {
      'none' => '',
      'id' || 'video_id' => videoId,
      'url' || 'video_url' => YTUrlUtils.buildVideoUrl(videoId),
      'video_title' || 'fulltitle' => pageResult?.videoInfo?.title.nullifyEmpty() ?? videoItem?.title.nullifyEmpty() ?? streamInfo?.title.nullifyEmpty(),
      'title' => () {
          final fulltitle = pageResult?.videoInfo?.title.nullifyEmpty() ?? videoItem?.title.nullifyEmpty() ?? streamInfo?.title.nullifyEmpty();
          final splitted = fulltitle?.splitArtistAndTitle();

          if (fallbackExtractInfoFromDescription) {
            final possibleExtracted = _extractArtistTitleFromDescriptionIfNecessary(splitted, (infos) => infos.$2?.keepFeatKeywordsOnly(), streamInfo, pageResult, videoItem);
            if (possibleExtracted != null) return possibleExtracted;
          }

          return splitted?.$2?.keepFeatKeywordsOnly().nullifyEmpty() ?? streamInfo?.title.nullifyEmpty() ?? fulltitle?.nullifyEmpty();
        }(),
      'artist' => () {
          // tries extracting artist from video title, or else uses channel name
          final fulltitle = pageResult?.videoInfo?.title.nullifyEmpty() ?? videoItem?.title.nullifyEmpty() ?? streamInfo?.title.nullifyEmpty();

          if (fulltitle != null) {
            final splitted = fulltitle.splitArtistAndTitle();
            if (fallbackExtractInfoFromDescription) {
              final possibleExtracted = _extractArtistTitleFromDescriptionIfNecessary(splitted, (infos) => infos.$1, streamInfo, pageResult, videoItem);
              if (possibleExtracted != null) return possibleExtracted;
            }
            final String? artist = splitted.$1;
            if (artist != null) return artist;
          } else {
            final possibleExtracted = _extractArtistTitleFromDescriptionIfNecessary(null, (infos) => infos.$1, streamInfo, pageResult, videoItem);
            if (possibleExtracted != null) return possibleExtracted;
          }

          final fullChannelName = pageResult?.channelInfo?.title?.nullifyEmpty() ?? videoItem?.channel?.title?.nullifyEmpty() ?? streamInfo?.channelName?.nullifyEmpty();
          return fullChannelName == null ? null : _removeTopicKeyword(fullChannelName);
        }(),
      'genre' => () {
          final fulltitle = pageResult?.videoInfo?.title.nullifyEmpty() ?? videoItem?.title.nullifyEmpty() ?? streamInfo?.title.nullifyEmpty();
          if (fulltitle != null && fulltitle.contains(RegExp('nightcore', caseSensitive: false))) {
            return 'Nightcore';
          }
          return null;
        }(),
      'ext' => videoStream?.codecInfo.container.nullifyEmpty() ?? audioStream?.codecInfo.container.nullifyEmpty() ?? 'mp4',
      'channel_fulltitle' => pageResult?.channelInfo?.title?.nullifyEmpty() ?? videoItem?.channel?.title?.nullifyEmpty() ?? streamInfo?.channelName?.nullifyEmpty(),
      'uploader' || 'channel' => () {
          final fullChannelName = pageResult?.channelInfo?.title?.nullifyEmpty() ?? videoItem?.channel?.title?.nullifyEmpty() ?? streamInfo?.channelName?.nullifyEmpty();
          return fullChannelName == null ? null : _removeTopicKeyword(fullChannelName);
        }(),
      'uploader_id' || 'channel_id' => pageResult?.channelInfo?.id.nullifyEmpty() ?? videoItem?.channel?.id.nullifyEmpty() ?? streamInfo?.channelId?.nullifyEmpty(),
      'uploader_url' || 'channel_url' => () {
          final id = pageResult?.channelInfo?.id.nullifyEmpty() ?? videoItem?.channel?.id.nullifyEmpty() ?? streamInfo?.channelId?.nullifyEmpty();
          return id == null ? null : YTUrlUtils.buildChannelUrl(id);
        }(),
      'timestamp' =>
        (streamInfo?.publishDate.accurateDate ?? streamInfo?.uploadDate.accurateDate ?? pageResult?.videoInfo?.publishedAt.accurateDate ?? videoItem?.publishedAt.accurateDate)
            ?.millisecondsSinceEpoch
            .toString(),
      'upload_date' => () {
          final date = streamInfo?.publishDate.accurateDate ?? streamInfo?.uploadDate.accurateDate ?? videoItem?.publishedAt.accurateDate;
          return date == null ? null : DateFormat('yyyyMMdd').format(date.toLocal());
        }(),
      'view_count' => streamInfo?.viewsCount?.toString() ??
          pageResult?.videoInfo?.viewsCount?.toString() ??
          pageResult?.videoInfo?.viewsText?.nullifyEmpty() ??
          videoItem?.viewsCount?.toString(),
      'like_count' => pageResult?.videoInfo?.engagement?.likesCount?.toString() ?? pageResult?.videoInfo?.engagement?.likesCountText?.nullifyEmpty(),
      'description' => _getDescription(streamInfo, pageResult, videoItem),
      'duration' => (videoStream?.duration?.inSeconds ?? audioStream?.duration?.inSeconds ?? streamInfo?.durSeconds ?? videoItem?.durSeconds)?.toString(),
      'duration_string' => () {
          final durSeconds = videoStream?.duration?.inSeconds ?? audioStream?.duration?.inSeconds ?? streamInfo?.durSeconds ?? videoItem?.durSeconds;
          return durSeconds?.secondsLabel;
        }(),
      'playlist_title' => playlistInfo?.title,
      'playlist_id' => playlistInfo?.id,
      'playlist' => () {
          var finalTitle = playlistInfo?.title;
          if (finalTitle == null || finalTitle.isEmpty) finalTitle = playlistInfo?.id;
          return finalTitle;
        }(),
      'playlist_count' => (totalLength ?? playlistInfo?.videosCount)?.toString(),
      'playlist_index' => originalIndex?.toString().padLeft((totalLength ?? playlistInfo?.videosCount)?.toString().length ?? 0, '0'),
      'playlist_autonumber' => originalIndex == null ? null : (originalIndex + 1).toString().padLeft((totalLength ?? playlistInfo?.videosCount)?.toString().length ?? 0, '0'),
      _ => throw const _NonMatched(),
    };
  }

  String? _getDescription(
    VideoStreamInfo? streamInfo,
    YoutiPieVideoPageResult? pageResult,
    StreamInfoItem? videoItem,
  ) {
    final parts = pageResult?.videoInfo?.description?.parts;
    if (parts != null && parts.isNotEmpty) {
      return _formatDescription(parts);
    }
    return pageResult?.videoInfo?.description?.rawText?.nullifyEmpty() ?? streamInfo?.availableDescription?.nullifyEmpty() ?? videoItem?.availableDescription?.nullifyEmpty();
  }

  T? _extractArtistTitleFromDescriptionIfNecessary<T>(
    (String? artist, String? title)? info,
    T? Function((String? artist, String? title) infos) onMatch,
    VideoStreamInfo? streamInfo,
    YoutiPieVideoPageResult? pageResult,
    StreamInfoItem? videoItem,
  ) {
    if ((info?.$1 == null && info?.$2 == null) || info?.$1?.toLowerCase() == 'nightcore') {
      final description = _getDescription(streamInfo, pageResult, videoItem);
      if (description != null) {
        final title = info?.$2?.splitFirst('(').splitFirst('[');
        final regex = title == null ? RegExp('^\\W*(song|info|details)(.*)', caseSensitive: false) : RegExp('^\\W*(song|info|details)?(.*$title.*)', caseSensitive: false);
        final regexArtist = RegExp('artist:(.*)', caseSensitive: false);
        final regexTitle = RegExp('title:(.*)', caseSensitive: false);
        for (String line in description.split('\n')) {
          line = line.replaceFirst(RegExp('Nightcore\\W*', caseSensitive: false), '');
          final m = regex.firstMatch(line);
          try {
            var infosLine = m?.group(2)?.splitArtistAndTitle();
            if (infosLine == null) {
              final fallback = (regexArtist.firstMatch(line)?.group(1)?.trim(), regexTitle.firstMatch(line)?.group(1)?.trim());
              if (fallback.$1 != null || fallback.$2 != null) infosLine = fallback;
            }
            if (infosLine != null) {
              final resolved = onMatch(infosLine);
              if (resolved != null) return resolved;
            }
          } catch (_) {}
        }
      }
    }
    return null;
  }

  String _removeTopicKeyword(String text) {
    const topic = '- Topic';
    final startIndex = (text.length - topic.length).withMinimum(0);
    return text.replaceFirst(topic, '', startIndex).trimAll();
  }

  String _formatDescription(List<StylesWrapper> parts) {
    var buffer = StringBuffer();
    parts.loop(
      (item) {
        String? finalLink;

        if (item.channelId != null) {
          finalLink = YTUrlUtils.buildChannelUrl(item.channelId!);
        } else if (item.playlistId != null) {
          finalLink = YTUrlUtils.buildPlaylistUrl(item.playlistId!);
        } else if (item.videoId != null) {
          finalLink = YTUrlUtils.buildVideoUrl(item.videoId!);
        } else if (item.link != null) {
          finalLink = item.linkClean ?? item.link!;
        }

        if (finalLink != null && finalLink != item.text) {
          buffer.write('[');
          buffer.write(item.text);
          buffer.write('](');
          buffer.write(finalLink);
          buffer.write(')');
        } else {
          buffer.write(item.text);
        }
      },
    );
    return buffer.toString();
  }
}

class _NonMatched implements Exception {
  const _NonMatched();
}
