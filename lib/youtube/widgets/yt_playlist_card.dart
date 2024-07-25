import 'dart:async';

import 'package:flutter/material.dart';

import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/result_wrapper/playlist_result_base.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/widgets/yt_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

/// Playlist info is fetched automatically after 3 seconds of being displayed, or after attempting an action.
class YoutubePlaylistCard extends StatefulWidget {
  final PlaylistBasicInfo playlist;
  final String? subtitle;
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final bool playOnTap;
  final String? firstVideoID;
  final String Function()? playingId;
  final bool isMixPlaylist;

  const YoutubePlaylistCard({
    super.key,
    required this.playlist,
    required this.subtitle,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.playOnTap = false,
    required this.firstVideoID,
    required this.playingId,
    required this.isMixPlaylist,
  });

  @override
  State<YoutubePlaylistCard> createState() => _YoutubePlaylistCardState();
}

class _YoutubePlaylistCardState extends State<YoutubePlaylistCard> {
  YoutiPiePlaylistResultBase? playlistToFetch;
  Timer? _fetchTimer;
  final _isFetching = Rxn<bool>();

  Future<YoutiPiePlaylistResultBase?> _fetchFunction({required bool forceRequest}) async {
    final executeDetails = forceRequest ? ExecuteDetails.forceRequest() : ExecuteDetails.cache(CacheDecision.cacheOnly);
    if (widget.isMixPlaylist) {
      final videoId = widget.firstVideoID ?? widget.playingId?.call();
      if (videoId == null) return null;
      return YoutubeInfoController.playlist.getMixPlaylist(
        videoId: videoId,
        details: executeDetails,
      );
    } else {
      if (widget.playlist.videosCountText == 'No videos') return null; // empty user playlists
      return YoutubeInfoController.playlist.fetchPlaylist(
        playlistId: widget.playlist.id,
        details: executeDetails,
      );
    }
  }

  Future<void> _forceFetch() async {
    if (!ConnectivityController.inst.hasConnection) return;
    _fetchTimer?.cancel();
    _isFetching.value = true;
    final value = await _fetchFunction(forceRequest: true);
    playlistToFetch = value;
    _isFetching.value = false;
  }

  Future<void> _fetchInitial() async {
    _fetchTimer?.cancel();
    final value = await _fetchFunction(forceRequest: false);

    if (value != null) {
      playlistToFetch = value;
    } else {
      _fetchTimer = Timer(const Duration(seconds: 3), _forceFetch);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchInitial();
  }

  @override
  void dispose() {
    _fetchTimer?.cancel();
    super.dispose();
  }

  List<NamidaPopupItem> getMenuItems() {
    if (_fetchTimer?.isActive == true || this.playlistToFetch == null) _forceFetch();

    final playlistToFetch = this.playlistToFetch;
    if (playlistToFetch == null) return [];
    return widget.playlist.getPopupMenuItems(
      playlistToFetch: playlistToFetch,
      showProgressSheet: true,
      displayPlay: !widget.playOnTap,
      displayOpenPlaylist: widget.playOnTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    String countText;
    if (widget.isMixPlaylist) {
      countText = '+25';
    } else {
      countText = playlist.videosCount?.formatDecimalShort() ?? '?';
    }
    final thumbnailUrl = playlist.thumbnails.pick()?.url;
    final firstVideoID = widget.firstVideoID;
    final goodVideoID = firstVideoID != null && firstVideoID.isNotEmpty;
    return NamidaPopupWrapper(
      openOnTap: false,
      openOnLongPress: true,
      childrenDefault: getMenuItems,
      child: YoutubeCard(
        thumbnailHeight: widget.thumbnailHeight,
        thumbnailWidth: widget.thumbnailWidth,
        thumbnailType: ThumbnailType.playlist,
        isImageImportantInCache: false,
        extractColor: true,
        borderRadius: 12.0,
        videoId: goodVideoID ? firstVideoID : null,
        thumbnailUrl: goodVideoID ? null : thumbnailUrl,
        shimmerEnabled: false,
        title: playlist.title,
        subtitle: widget.subtitle ?? '',
        thirdLineText: '',
        onTap: () async {
          if (_fetchTimer?.isActive == true || this.playlistToFetch == null) _forceFetch();

          final playlistToFetch = this.playlistToFetch;
          if (playlistToFetch == null) return;
          if (widget.playOnTap) {
            final videos = await playlist.fetchAllPlaylistAsYTIDs(showProgressSheet: true, playlistToFetch: playlistToFetch);
            if (videos.isEmpty) return;
            Player.inst.playOrPause(0, videos, QueueSource.others);
          } else {
            YTHostedPlaylistSubpage(playlist: playlistToFetch).navigate();
          }
        },
        displayChannelThumbnail: false,
        displaythirdLineText: false,
        smallBoxText: countText,
        smallBoxIcon: Broken.play_cricle,
        bottomRightWidgets: [
          ObxO(
            rx: _isFetching,
            builder: (value) {
              if (value == true) {
                return ThreeArchedCircle(
                  color: Colors.red.withOpacity(0.4),
                  size: 12.0,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
        menuChildrenDefault: getMenuItems,
      ),
    );
  }
}
