import 'package:flutter/material.dart';
import 'package:newpipeextractor_dart/models/stream_info_item.dart';
import 'package:share_plus/share_plus.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';
import 'package:namida/youtube/yt_utils.dart';

class YTVideosActionBarOptions {
  final bool shuffle;
  final bool play;
  final bool playNext;
  final bool playAfter;
  final bool playLast;
  final bool download;
  final bool addToPlaylist;

  const YTVideosActionBarOptions({
    this.shuffle = true,
    this.play = false,
    this.playNext = false,
    this.playAfter = false,
    this.playLast = true,
    this.download = true,
    this.addToPlaylist = false,
  });
}

class YTVideosActionBar extends StatelessWidget {
  final String title;
  final String url;
  final List<YoutubeID> Function() videosCallback;
  final Map<String, StreamInfoItem> Function()? infoLookupCallback;
  final YTVideosActionBarOptions barOptions;
  final YTVideosActionBarOptions menuOptions;

  const YTVideosActionBar({
    super.key,
    required this.title,
    required this.url,
    required this.videosCallback,
    this.infoLookupCallback,
    this.barOptions = const YTVideosActionBarOptions(),
    this.menuOptions = const YTVideosActionBarOptions(
      shuffle: false,
      play: true,
      playNext: true,
      playAfter: true,
      playLast: true,
      download: false,
      addToPlaylist: true,
    ),
  });

  List<YoutubeID> get videos => videosCallback();
  Map<String, StreamInfoItem> get infoLookup => infoLookupCallback?.call() ?? {};

  Future<void> _onDownloadTap() async {
    await NamidaNavigator.inst.navigateTo(
      YTPlaylistDownloadPage(
        ids: videos,
        playlistName: title,
        infoLookup: infoLookup,
      ),
    );
  }

  Future<void> _onShuffle() async {
    await Player.inst.playOrPause(0, videos, QueueSource.others, shuffle: true);
  }

  Future<void> _onPlay() async {
    await Player.inst.playOrPause(0, videos, QueueSource.others);
  }

  Future<void> _onPlayNext() async {
    await Player.inst.addToQueue(videos, insertNext: true);
  }

  Future<void> _onPlayAfter() async {
    await Player.inst.addToQueue(videos, insertAfterLatest: true);
  }

  Future<void> _onPlayLast() async {
    await Player.inst.addToQueue(videos, insertNext: false);
  }

  void _onAddToPlaylist() {
    final ids = <String>[];
    final info = <String, String?>{};
    videos.loop((e, index) {
      final id = e.id;
      ids.add(id);
      info[id] = infoLookup[id]?.name;
    });

    showAddToPlaylistSheet(
      ids: ids,
      idsNamesLookup: info,
    );
  }

  List<NamidaPopupItem> getMenuItems() {
    final countText = videos.length;
    final playAfterVid = menuOptions.playAfter ? YTUtils.getPlayerAfterVideo() : null;
    return [
      if (menuOptions.addToPlaylist)
        NamidaPopupItem(
          icon: Broken.music_playlist,
          title: lang.ADD_TO_PLAYLIST,
          onTap: _onAddToPlaylist,
        ),
      if (url != '')
        NamidaPopupItem(
          icon: Broken.share,
          title: lang.SHARE,
          onTap: () => Share.share(url),
        ),
      if (menuOptions.download)
        NamidaPopupItem(
          icon: Broken.import,
          title: lang.DOWNLOAD,
          onTap: _onDownloadTap,
        ),
      if (menuOptions.shuffle)
        NamidaPopupItem(
          icon: Broken.shuffle,
          title: "${lang.SHUFFLE} ($countText)",
          onTap: _onShuffle,
        ),
      if (menuOptions.play)
        NamidaPopupItem(
          icon: Broken.play,
          title: "${lang.PLAY} ($countText)",
          onTap: _onPlay,
        ),
      if (menuOptions.playNext)
        NamidaPopupItem(
          icon: Broken.next,
          title: "${lang.PLAY_NEXT} ($countText)",
          onTap: _onPlayNext,
        ),
      if (playAfterVid != null)
        NamidaPopupItem(
          icon: Broken.hierarchy_square,
          title: "${lang.PLAY_AFTER}: ${playAfterVid.diff.displayVideoKeyword}",
          subtitle: playAfterVid.name,
          oneLinedSub: true,
          onTap: _onPlayAfter,
        ),
      if (menuOptions.playLast)
        NamidaPopupItem(
          icon: Broken.play_cricle,
          title: "${lang.PLAY_LAST} ($countText)",
          onTap: _onPlayLast,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final playAfterVid = barOptions.playAfter ? YTUtils.getPlayerAfterVideo() : null;
    return Row(
      children: [
        if (barOptions.addToPlaylist)
          _ActionItem(
            icon: Broken.music_playlist,
            tooltip: lang.ADD_TO_PLAYLIST,
            onTap: _onAddToPlaylist,
          ),
        if (barOptions.download)
          _ActionItem(
            icon: Broken.import,
            tooltip: lang.DOWNLOAD,
            onTap: _onDownloadTap,
          ),
        if (barOptions.shuffle)
          _ActionItem(
            icon: Broken.shuffle,
            tooltip: lang.SHUFFLE,
            onTap: _onShuffle,
          ),
        if (barOptions.play)
          _ActionItem(
            icon: Broken.play,
            tooltip: lang.PLAY,
            onTap: _onPlay,
          ),
        if (barOptions.playNext)
          _ActionItem(
            icon: Broken.next,
            tooltip: lang.PLAY_NEXT,
            onTap: _onPlayNext,
          ),
        if (playAfterVid != null)
          _ActionItem(
            icon: Broken.hierarchy_square,
            tooltip: "${lang.PLAY_AFTER}: ${playAfterVid.diff.displayVideoKeyword}",
            onTap: _onPlayAfter,
          ),
        if (barOptions.playLast)
          _ActionItem(
            icon: Broken.play_cricle,
            tooltip: lang.PLAY_LAST,
            onTap: _onPlayLast,
          ),
        if (getMenuItems().isNotEmpty)
          NamidaPopupWrapper(
            openOnLongPress: false,
            childrenDefault: getMenuItems,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              child: Icon(
                Broken.more_2,
                size: 24.0,
                color: context.defaultIconColor(),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onTap;
  final IconData icon;

  const _ActionItem({
    required this.tooltip,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaIconButton(
      iconSize: 22.0,
      horizontalPadding: 6.0,
      iconColor: context.defaultIconColor(),
      icon: icon,
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
