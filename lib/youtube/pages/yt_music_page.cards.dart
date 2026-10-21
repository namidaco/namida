part of 'yt_music_page.dart';

class _MusicItemActions {
  const _MusicItemActions._();

  static void open(YoutubeFeed item, List<YoutubeFeed> siblings, String queueTitle) {
    switch (item) {
      case StreamInfoItem():
        _playFromSiblings(item, siblings, queueTitle);
      case MusicAlbumInfoItem():
        YTHostedPlaylistSubpage.fromId(
          playlistId: item.id,
          userPlaylist: null,
          album: item,
        ).navigate();
      case PlaylistInfoItem():
        YTHostedPlaylistSubpage.fromId(
          playlistId: item.id,
          userPlaylist: null,
        ).navigate();
      case ChannelInfoItem():
        final artistTitle = item.title ?? '';
        YTMusicBrowseSubpage(
          endpoint: YoutiPieMusicBrowseEndpoint(item.id),
          title: artistTitle,
        ).navigate();
      case MusicNavigationItem():
        openEndpoint(item.endpoint, item.title);
    }
  }

  static void openEndpoint(YoutiPieMusicBrowseEndpoint endpoint, String title) {
    final playlistId = endpoint.extractPlaylistId();
    if (playlistId != null) {
      YTHostedPlaylistSubpage.fromId(
        playlistId: playlistId,
        userPlaylist: null,
      ).navigate();
    } else {
      YTMusicBrowseSubpage(
        endpoint: endpoint,
        title: title,
      ).navigate();
    }
  }

  static void _playFromSiblings(StreamInfoItem item, List<YoutubeFeed> siblings, String queueTitle) {
    final streams = siblings.whereType<StreamInfoItem>().toFixedList();
    final index = streams.indexOf(item);
    final queue = streams.map((e) => YoutubeID(id: e.id, playlistID: null));
    final queueSource = QueueSourceYoutubeID.ytMusic(queueTitle);
    YTUtils.expandMiniplayer();
    Player.inst.playOrPause(index, queue, queueSource);
  }

  static Future<void> playPlaylist(String playlistId, String queueTitle, {required bool shuffle}) async {
    final playlist = await YoutubeInfoController.playlist.fetchPlaylist(playlistId: playlistId);
    if (playlist == null) return;
    final videos = await playlist.basicInfo.fetchAllPlaylistAsYTIDs(showProgressSheet: true, playlistToFetch: playlist);
    if (videos.isEmpty) return;
    final queueSource = QueueSourceYoutubeID.ytMusic(queueTitle);
    YTUtils.expandMiniplayer();
    Player.inst.playOrPause(0, videos, queueSource, shuffle: shuffle);
  }

  static Future<List<NamidaPopupItem>> menuItems(YoutubeFeed item, String queueTitle) async {
    final queueSource = QueueSourceYoutubeID.ytMusic(queueTitle);
    if (item is StreamInfoItem) {
      return YTUtils.getVideoCardMenuItems(
        queueSource: queueSource,
        downloadIndex: null,
        totalLength: null,
        streamInfoItem: item,
        videoId: item.id,
        channelID: item.channel?.id,
        playlistID: null,
        idsNamesLookup: {item.id: item.title},
      );
    }
    if (item case final PlaylistBasicInfo playlistInfo) {
      final playlist = await _fetchPlaylist(playlistInfo);
      if (playlist == null) return const [];
      return playlistInfo.getPopupMenuItems(
        queueSource: queueSource,
        showProgressSheet: true,
        playlistToFetch: playlist,
        userPlaylist: null,
      );
    }
    return const [];
  }

  static Future<YoutiPiePlaylistResultBase?> _fetchPlaylist(PlaylistBasicInfo info) {
    if (info is PlaylistInfoItem && info.isMix) {
      final mixVideoId = info.id.substring(2);
      return YoutubeInfoController.playlist.getMixPlaylist(
        videoId: mixVideoId,
        mixId: info.id,
        includeFirstVideo: true,
        userPersonalized: settings.youtube.personalizedMixPlaylists.value,
      );
    }
    return YoutubeInfoController.playlist.fetchPlaylist(playlistId: info.id);
  }
}

class _MusicCard extends StatelessWidget {
  final YoutubeFeed item;
  final List<YoutubeFeed> siblings;
  final String queueTitle;
  final double artWidth;
  final double artHeight;

  const _MusicCard({
    required this.item,
    required this.siblings,
    required this.queueTitle,
    required this.artWidth,
    required this.artHeight,
  });

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    if (item is MusicNavigationItem) {
      return _MusicNavButton(
        item: item,
      );
    }
    final subtitle = item.getMusicSubtitle();
    final isArtist = item is ChannelInfoItem;
    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: () => _MusicItemActions.menuItems(item, queueTitle),
      child: NamidaInkWell(
        width: artWidth,
        borderRadius: 10.0,
        onTap: () => _MusicItemActions.open(item, siblings, queueTitle),
        child: Column(
          crossAxisAlignment: isArtist ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            _MusicItemArt(
              item: item,
              width: artWidth,
              height: artHeight,
            ),
            const SizedBox(height: 6.0),
            NamidaText(
              item.getMusicTitle(),
              style: const NText(.medium, size: .s13),
              maxLines: subtitle.isEmpty ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: isArtist ? TextAlign.center : null,
            ),
            if (subtitle.isNotEmpty)
              NamidaText(
                subtitle,
                style: const NText(.small, size: .s12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _MusicListRow extends StatelessWidget {
  final YoutubeFeed item;
  final List<YoutubeFeed> siblings;
  final String queueTitle;

  const _MusicListRow({required this.item, required this.siblings, required this.queueTitle});

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final subtitle = item.getMusicSubtitle();
    return SizedBox(
      height: _MusicDims.rowHeight,
      child: NamidaPopupWrapper(
        openOnTap: false,
        childrenDefault: () => _MusicItemActions.menuItems(item, queueTitle),
        child: NamidaInkWell(
          borderRadius: 10.0,
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          margin: const EdgeInsets.symmetric(horizontal: 6.0),
          onTap: () => _MusicItemActions.open(item, siblings, queueTitle),
          child: Row(
            children: [
              _MusicItemArt(
                item: item,
                width: _MusicDims.rowArtSize,
                height: _MusicDims.rowArtSize,
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NamidaText(
                      item.getMusicTitle(),
                      style: const NText(.medium, size: .s13p5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      NamidaText(
                        subtitle,
                        style: const NText(.small, size: .s12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicNavButton extends StatelessWidget {
  final MusicNavigationItem item;

  const _MusicNavButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final stripeColor = item.color;
    final bgColor = stripeColor == null ? NColors.card : NColors.custom((c) => Color.alphaBlend(stripeColor.withOpacityExt(0.05), c.card));
    return NamidaInkWell(
      height: _MusicDims.navButtonHeight,
      bgColor: bgColor,
      borderRadius: _MusicDims.navButtonRadius,
      onTap: () => _MusicItemActions.openEndpoint(item.endpoint, item.title),
      child: Row(
        children: [
          if (stripeColor != null)
            Container(
              width: 6.0,
              decoration: BoxDecoration(
                color: stripeColor,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(_MusicDims.navButtonRadius.multipliedRadius),
                ),
              ),
            ),
          const SizedBox(width: 10.0),
          Expanded(
            child: NamidaText(
              item.title,
              style: NText.medium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8.0),
        ],
      ),
    );
  }
}

class _MusicItemArt extends StatelessWidget {
  final YoutubeFeed item;
  final double width;
  final double height;

  const _MusicItemArt({required this.item, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    if (item is StreamInfoItem && item.hasWideThumbnails) {
      return YoutubeThumbnail(
        key: Key(item.id),
        type: ThumbnailType.video,
        videoId: item.id,
        width: width,
        height: height,
        borderRadius: 8.0,
        isImportantInCache: false,
      );
    }
    final url = switch (item) {
      StreamInfoItem() => item.liveThumbs.pick()?.url,
      MusicAlbumInfoItem() => item.thumbnails.pick()?.url,
      PlaylistInfoItem() => item.thumbnails.pick()?.url,
      ChannelInfoItem() => item.thumbnails.pick()?.url,
      _ => null,
    };
    final isArtist = item is ChannelInfoItem;
    final thumbnailType = isArtist ? ThumbnailType.channel : ThumbnailType.playlist;
    return YoutubeThumbnail(
      key: Key('${url}_${item.cacheKey}'),
      type: thumbnailType,
      customUrl: url,
      width: width,
      height: height,
      isCircle: isArtist,
      borderRadius: 8.0,
      isImportantInCache: false,
    );
  }
}

extension _StreamInfoItemMusic on StreamInfoItem {
  /// music videos, songs come with square art instead.
  bool get hasWideThumbnails {
    final thumbnail = liveThumbs.firstOrNull;
    return thumbnail != null && thumbnail.width != thumbnail.height;
  }
}

extension _BidiIsolate on String {
  String isolateBidi() => '\u2068$this\u2069';
}

extension _MusicFeedTexts on YoutubeFeed {
  String getMusicTitle() => switch (this) {
    StreamInfoItem(:final title) => title,
    MusicAlbumInfoItem(:final title) => title,
    PlaylistInfoItem(:final title) => title,
    ChannelInfoItem(:final title) => title ?? '',
    MusicNavigationItem(:final title) => title,
    _ => '',
  };

  /// the channel is isolated so an rtl name doesn't swallow the views digits next to it.
  String getMusicSubtitle() => switch (this) {
    StreamInfoItem(:final channel, :final viewsText, :final durText) => [?channel?.title?.isolateBidi(), ?(viewsText ?? durText)].join(' • '),
    MusicAlbumInfoItem(:final subtitle) => subtitle,
    PlaylistInfoItem(:final subtitle) => subtitle,
    _ => '',
  };
}
