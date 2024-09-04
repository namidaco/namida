part of 'youtube_controller.dart';

class _YtFilenameRebuilder {
  _YtFilenameRebuilder();

  String? _rebuildFilenameWithDecodedParams(
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
    final regex = RegExp(r'%\((\w+)\)s');
    bool didConvertSmth = false;
    var decodedFilename = filenameEncoded.replaceAllMapped(
      regex,
      (match) {
        var keyword = match.group(1)?.toLowerCase();
        if (keyword != null) {
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
        }
        return 'NA';
      },
    );
    return didConvertSmth ? decodedFilename : filenameEncoded;
  }

  bool isBuildingDefaultFilenameSafe(String defaultFilename) {
    return encodedParamsThatShouldExistInFilename.any((element) => defaultFilename.contains(buildParamForFilename(element)));
  }

  final encodedParamsThatShouldExistInFilename = [
    'video_id',
    'id',
    'title',
    'playlist_index',
    'playlist_autonumber',
  ];

  final availableEncodedParams = [
    'video_id', // 'id'
    'title',
    'ext',
    'channel', // 'uploader'
    'channel_id', //'uploader_id'
    'channel_url', // 'uploader_url'
    'timestamp',
    'upload_date',
    'view_count',
    'like_count',
    'playlist_title',
    'playlist_id',
    'playlist',
    'playlist_count',
    'playlist_index',
    'playlist_autonumber',
  ];

  String buildParamForFilename(String e) => '%($e)s';

  String? _keywordToInfo(
    String keyword,
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
    return switch (keyword) {
      'id' || 'video_id' => videoId,
      'title' => pageResult?.videoInfo?.title ?? videoItem?.title ?? streams?.info?.title,
      'ext' => videoStream?.codecInfo.container ?? audioStream?.codecInfo.container ?? 'mp4',
      'uploader' || 'channel' => pageResult?.channelInfo?.title ?? videoItem?.channel.title ?? streams?.info?.channelName,
      'uploader_id' || 'channel_id' => pageResult?.channelInfo?.id ?? videoItem?.channel.id ?? streams?.info?.channelId,
      'uploader_url' || 'channel_url' => () {
          final id = pageResult?.channelInfo?.id ?? videoItem?.channel.id ?? streams?.info?.channelId;
          return id == null ? null : YTUrlUtils.buildChannelUrl(id);
        }(),
      'timestamp' => (streams?.info?.uploadDate.date ?? streams?.info?.publishDate.date ?? pageResult?.videoInfo?.publishedAt.date ?? videoItem?.publishedAt.date)
          ?.millisecondsSinceEpoch
          .toString(),
      'upload_date' => () {
          final date = streams?.info?.uploadDate.date ?? streams?.info?.publishDate.date ?? videoItem?.publishedAt.date;
          return date == null ? null : DateFormat('yyyyMMdd').format(date);
        }(),
      'view_count' =>
        streams?.info?.viewsCount?.toString() ?? pageResult?.videoInfo?.viewsCount?.toString() ?? pageResult?.videoInfo?.viewsText ?? videoItem?.viewsCount?.toString(),
      'like_count' => pageResult?.videoInfo?.engagement?.likesCount?.toString() ?? pageResult?.videoInfo?.engagement?.likesCountText,
      //
      'duration' => (videoStream?.duration?.inSeconds ?? audioStream?.duration?.inSeconds ?? streams?.info?.durSeconds ?? videoItem?.durSeconds)?.toString(),
      'duration_string' => () {
          final durSeconds = videoStream?.duration?.inSeconds ?? audioStream?.duration?.inSeconds ?? streams?.info?.durSeconds ?? videoItem?.durSeconds;
          return durSeconds?.secondsLabel;
        }(),
      //
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
      _ => null,
    };
  }
}
