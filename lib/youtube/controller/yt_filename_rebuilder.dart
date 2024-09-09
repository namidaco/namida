part of 'youtube_controller.dart';

class _YtFilenameRebuilder {
  _YtFilenameRebuilder();

  final paramRegex = RegExp(r'%\((\w+)\)s');

  String? rebuildFilenameWithDecodedParams(
    String filenameEncoded,
    String videoId,
    VideoStreamsResult? streams,
    YoutiPieVideoPageResult? pageResult,
    StreamInfoItem? videoItem,
    PlaylistBasicInfo? playlistInfo,
    VideoStream? videoStream,
    AudioStream? audioStream,
    int? index,
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
              streams,
              pageResult,
              videoItem,
              playlistInfo,
              videoStream,
              audioStream,
              index,
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

  String? _keywordToInfo(String keyword, String videoId, VideoStreamsResult? streams, YoutiPieVideoPageResult? pageResult, StreamInfoItem? videoItem,
      PlaylistBasicInfo? playlistInfo, VideoStream? videoStream, AudioStream? audioStream, int? index, int? totalLength) {
    return switch (keyword) {
      'none' => '',
      'id' || 'video_id' => videoId,
      'url' || 'video_url' => YTUrlUtils.buildVideoUrl(videoId),
      'video_title' || 'fulltitle' => pageResult?.videoInfo?.title ?? videoItem?.title ?? streams?.info?.title,
      'title' => () {
          final fulltitle = pageResult?.videoInfo?.title ?? videoItem?.title ?? streams?.info?.title;
          return fulltitle?.splitArtistAndTitle().$2?.keepFeatKeywordsOnly() ?? streams?.info?.title ?? fulltitle;
        }(),
      'artist' => () {
          // tries extracting artist from video title, or else uses channel name
          final fulltitle = pageResult?.videoInfo?.title ?? videoItem?.title ?? streams?.info?.title;

          if (fulltitle != null) {
            final splitted = fulltitle.splitArtistAndTitle();
            if (splitted.$1 != null) return splitted.$1;
          }

          final fullChannelName = pageResult?.channelInfo?.title ?? videoItem?.channel.title ?? streams?.info?.channelName;
          return fullChannelName == null ? null : _removeTopicKeyword(fullChannelName);
        }(),
      'ext' => videoStream?.codecInfo.container ?? audioStream?.codecInfo.container ?? 'mp4',
      'channel_fulltitle' => pageResult?.channelInfo?.title ?? videoItem?.channel.title ?? streams?.info?.channelName,
      'uploader' || 'channel' => () {
          final fullChannelName = pageResult?.channelInfo?.title ?? videoItem?.channel.title ?? streams?.info?.channelName;
          return fullChannelName == null ? null : _removeTopicKeyword(fullChannelName);
        }(),
      'uploader_id' || 'channel_id' => pageResult?.channelInfo?.id ?? videoItem?.channel.id ?? streams?.info?.channelId,
      'uploader_url' || 'channel_url' => () {
          final id = pageResult?.channelInfo?.id ?? videoItem?.channel.id ?? streams?.info?.channelId;
          return id == null ? null : YTUrlUtils.buildChannelUrl(id);
        }(),
      'timestamp' => (streams?.info?.publishDate.date ?? streams?.info?.uploadDate.date ?? pageResult?.videoInfo?.publishedAt.accurateDate ?? videoItem?.publishedAt.accurateDate)
          ?.millisecondsSinceEpoch
          .toString(),
      'upload_date' => () {
          final date = streams?.info?.publishDate.date ?? streams?.info?.uploadDate.date ?? videoItem?.publishedAt.accurateDate;
          return date == null ? null : DateFormat('yyyyMMdd').format(date.toLocal());
        }(),
      'view_count' =>
        streams?.info?.viewsCount?.toString() ?? pageResult?.videoInfo?.viewsCount?.toString() ?? pageResult?.videoInfo?.viewsText ?? videoItem?.viewsCount?.toString(),
      'like_count' => pageResult?.videoInfo?.engagement?.likesCount?.toString() ?? pageResult?.videoInfo?.engagement?.likesCountText,
      'description' => () {
          final parts = pageResult?.videoInfo?.description?.parts;
          if (parts != null && parts.isNotEmpty) {
            return _formatDescription(parts);
          }
          return pageResult?.videoInfo?.description?.rawText ?? streams?.info?.availableDescription ?? videoItem?.availableDescription;
        }(),
      'duration' => (videoStream?.duration?.inSeconds ?? audioStream?.duration?.inSeconds ?? streams?.info?.durSeconds ?? videoItem?.durSeconds)?.toString(),
      'duration_string' => () {
          final durSeconds = videoStream?.duration?.inSeconds ?? audioStream?.duration?.inSeconds ?? streams?.info?.durSeconds ?? videoItem?.durSeconds;
          return durSeconds?.secondsLabel;
        }(),
      'playlist_title' => playlistInfo?.title,
      'playlist_id' => playlistInfo?.id,
      'playlist' => () {
          var finalTitle = playlistInfo?.title;
          if (finalTitle == null || finalTitle.isEmpty) finalTitle = playlistInfo?.id;
          return finalTitle;
        }(),
      'playlist_count' => (playlistInfo?.videosCount ?? totalLength)?.toString(),
      'playlist_index' => (videoItem?.indexInPlaylist ?? index)?.toString().padLeft((playlistInfo?.videosCount ?? totalLength)?.toString().length ?? 0, '0'),
      'playlist_autonumber' => index == null && videoItem?.indexInPlaylist == null
          ? null
          : ((videoItem?.indexInPlaylist ?? index)! + 1).toString().padLeft((playlistInfo?.videosCount ?? totalLength)?.toString().length ?? 0, '0'),
      _ => throw const _NonMatched(),
    };
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
