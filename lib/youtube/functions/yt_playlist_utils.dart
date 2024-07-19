import 'package:flutter/material.dart';

import 'package:nampack/core/main_utils.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtipie/class/result_wrapper/list_wrapper_base.dart';
import 'package:youtipie/class/result_wrapper/playlist_result.dart';
import 'package:youtipie/class/result_wrapper/playlist_result_base.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/yt_utils.dart';

extension YoutubePlaylistShare on YoutubePlaylist {
  Future<void> shareVideos() async => await tracks.shareVideos();

  Future<bool> promptDelete({required String name, Color? colorScheme}) async {
    bool deleted = false;
    await NamidaNavigator.inst.navigateDialog(
      colorScheme: colorScheme,
      dialogBuilder: (theme) => CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: "${lang.DELETE}: $name?",
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.DELETE.toUpperCase(),
            onPressed: () {
              deleted = true;
              NamidaNavigator.inst.closeDialog();
              YoutubePlaylistController.inst.removePlaylist(this);
            },
          ),
        ],
      ),
    );
    return deleted;
  }

  Future<String?> showRenamePlaylistSheet({
    required BuildContext context,
    required String playlistName,
  }) async {
    return await showNamidaBottomSheetWithTextField(
      context: context,
      initalControllerText: playlistName,
      title: lang.RENAME_PLAYLIST,
      hintText: playlistName,
      labelText: lang.NAME,
      validator: (value) => YoutubePlaylistController.inst.validatePlaylistName(value),
      buttonText: lang.SAVE,
      onButtonTap: (text) async {
        final didRename = await YoutubePlaylistController.inst.renamePlaylist(playlistName, text);
        if (didRename) {
          return true;
        } else {
          snackyy(title: lang.ERROR, message: lang.COULDNT_RENAME_PLAYLIST);
          return false;
        }
      },
    );
  }
}

extension PlaylistBasicInfoExt on PlaylistBasicInfo {
  /// Videos are accessible through [YoutiPiePlaylistResult.items] getter.
  Future<bool> fetchAllPlaylistStreams({
    required bool showProgressSheet,
    required YoutiPiePlaylistResultBase playlist,
    VoidCallback? onStart,
    VoidCallback? onEnd,
    void Function(YoutiPieFetchAllRes fetchAllRes)? controller,
  }) async {
    final currentCount = playlist.items.length.obs;
    final fetchAllRes = playlist.fetchAll(
      onProgress: () {
        currentCount.value = playlist.items.length;
      },
    );
    if (fetchAllRes == null) return true; // no continuation left

    controller?.call(fetchAllRes);

    final totalCount = Rxn<int>(playlist.basicInfo.videosCount);
    const switchAnimationDur = Duration(milliseconds: 600);
    const switchAnimationDurHalf = Duration(milliseconds: 300);

    void Function()? popSheet;

    if (showProgressSheet) {
      WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback(
        (timeStamp) async {
          final rootContext = nampack.rootNavigatorKey.currentContext;
          if (rootContext != null) {
            popSheet = Navigator.of(rootContext, rootNavigator: true).pop;
            await Future.delayed(Duration.zero);
            showModalBottomSheet(
              // ignore: use_build_context_synchronously
              context: rootContext,
              useRootNavigator: true,
              isDismissible: false,
              builder: (context) {
                final iconSize = context.width * 0.5;
                final iconColor = context.theme.colorScheme.onSurface.withOpacity(0.6);
                return _DisposableWidget(
                  onDispose: fetchAllRes.cancel,
                  child: SizedBox(
                    width: context.width,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Obx(
                            () {
                              final totalC = totalCount.valueR;
                              return AnimatedSwitcher(
                                key: const Key('circle_switch'),
                                duration: switchAnimationDurHalf,
                                child: totalC == null || currentCount.valueR < totalC
                                    ? ThreeArchedCircle(
                                        size: iconSize,
                                        color: iconColor,
                                      )
                                    : Icon(
                                        key: const Key('tick_switch'),
                                        Broken.tick_circle,
                                        size: iconSize,
                                        color: iconColor,
                                      ),
                              );
                            },
                          ),
                          const SizedBox(height: 12.0),
                          Text(
                            '${lang.FETCHING}...',
                            style: context.textTheme.displayLarge,
                          ),
                          const SizedBox(height: 8.0),
                          Obx(
                            () {
                              final totalC = totalCount.valueR;
                              return Text(
                                '${currentCount.valueR.formatDecimal()}/${totalC == null ? '?' : totalC.formatDecimal()}',
                                style: context.textTheme.displayLarge,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      );
    }

    onStart?.call();

    await fetchAllRes.result;

    onEnd?.call();

    if (showProgressSheet) {
      await Future.delayed(switchAnimationDur);
      popSheet?.call();
    }
    Future.delayed(
      const Duration(milliseconds: 200),
      () {
        currentCount.close();
        totalCount.close();
      },
    );

    return true;
  }

  Future<List<YoutubeID>> fetchAllPlaylistAsYTIDs({
    required bool showProgressSheet,
    required YoutiPiePlaylistResultBase playlistToFetch,
  }) async {
    final playlist = this;
    final didFetch = await playlist.fetchAllPlaylistStreams(showProgressSheet: showProgressSheet, playlist: playlistToFetch);
    if (!didFetch) snackyy(title: lang.ERROR, message: 'error fetching playlist videos');
    final plId = PlaylistID(id: this.id);
    return playlistToFetch.items
        .map(
          (e) => YoutubeID(
            id: e.id,
            playlistID: plId,
          ),
        )
        .toList();
  }

  Future<void> showPlaylistDownloadSheet({
    required bool showProgressSheet,
    required YoutiPiePlaylistResultBase playlistToFetch,
  }) async {
    final videoIDs = await fetchAllPlaylistAsYTIDs(showProgressSheet: showProgressSheet, playlistToFetch: playlistToFetch);
    if (videoIDs.isEmpty) return;

    final playlist = this;
    final infoLookup = <String, StreamInfoItem>{};
    playlistToFetch.items.loop((e) => infoLookup[e.id] = e);

    YTPlaylistDownloadPage(
      ids: videoIDs.toList(),
      playlistName: playlist.title,
      infoLookup: infoLookup,
    ).navigate();
  }

  List<NamidaPopupItem> getPopupMenuItems({
    required bool showProgressSheet,
    required YoutiPiePlaylistResultBase playlistToFetch,
    bool displayDownloadItem = true,
    bool displayShuffle = true,
    bool displayPlay = true,
    bool displayOpenPlaylist = false,
  }) {
    final playlist = this;
    final videosCount = playlist.videosCount;
    final countText = videosCount == null || videosCount < 0 ? "+25" : videosCount.formatDecimalShort();
    final playAfterVid = YTUtils.getPlayerAfterVideo();

    Future<List<YoutubeID>> fetchAllIDs() async => await fetchAllPlaylistAsYTIDs(showProgressSheet: showProgressSheet, playlistToFetch: playlistToFetch);

    return [
      NamidaPopupItem(
        icon: Broken.music_playlist,
        title: lang.ADD_TO_PLAYLIST,
        onTap: () async {
          final didFetch = await playlist.fetchAllPlaylistStreams(showProgressSheet: showProgressSheet, playlist: playlistToFetch);
          if (!didFetch) {
            snackyy(title: lang.ERROR, message: 'error fetching playlist videos');
            return;
          }

          final ids = <String>[];
          final info = <String, String?>{};
          playlistToFetch.items.loop((e) {
            final id = e.id;
            ids.add(id);
            info[id] = e.title;
          });

          showAddToPlaylistSheet(
            ids: ids,
            idsNamesLookup: info,
          );
        },
      ),
      NamidaPopupItem(
        icon: Broken.share,
        title: lang.SHARE,
        onTap: () {
          final url = this.buildUrl();
          Share.share(url);
        },
      ),
      if (displayDownloadItem)
        NamidaPopupItem(
          icon: Broken.import,
          title: lang.DOWNLOAD,
          onTap: () => showPlaylistDownloadSheet(
            showProgressSheet: showProgressSheet,
            playlistToFetch: playlistToFetch,
          ),
        ),
      if (displayOpenPlaylist)
        NamidaPopupItem(
          icon: Broken.export_2,
          title: lang.OPEN,
          onTap: YTHostedPlaylistSubpage(playlist: playlistToFetch).navigate,
        ),
      if (displayPlay)
        NamidaPopupItem(
          icon: Broken.play,
          title: "${lang.PLAY} ($countText)",
          onTap: () async {
            final videos = await fetchAllIDs();
            if (videos.isEmpty) return;
            Player.inst.playOrPause(0, videos, QueueSource.others);
          },
        ),
      if (displayShuffle)
        NamidaPopupItem(
          icon: Broken.shuffle,
          title: "${lang.SHUFFLE} ($countText)",
          onTap: () async {
            final videos = await fetchAllIDs();
            if (videos.isEmpty) return;
            Player.inst.playOrPause(0, videos, QueueSource.others, shuffle: true);
          },
        ),
      NamidaPopupItem(
        icon: Broken.next,
        title: "${lang.PLAY_NEXT} ($countText)",
        onTap: () async {
          final videos = await fetchAllIDs();
          if (videos.isEmpty) return;
          Player.inst.addToQueue(videos, insertNext: true);
        },
      ),
      if (playAfterVid != null)
        NamidaPopupItem(
          icon: Broken.hierarchy_square,
          title: '${lang.PLAY_AFTER}: ${playAfterVid.diff.displayVideoKeyword}',
          subtitle: playAfterVid.name,
          oneLinedSub: true,
          onTap: () async {
            final videos = await fetchAllIDs();
            if (videos.isEmpty) return;
            Player.inst.addToQueue(videos, insertAfterLatest: true);
          },
        ),
      NamidaPopupItem(
        icon: Broken.play_cricle,
        title: "${lang.PLAY_LAST} ($countText)",
        onTap: () async {
          final videos = await fetchAllIDs();
          if (videos.isEmpty) return;
          Player.inst.addToQueue(videos, insertNext: false);
        },
      ),
    ];
  }
}

class _DisposableWidget extends StatefulWidget {
  final Widget child;
  final void Function() onDispose;
  const _DisposableWidget({super.key, required this.child, required this.onDispose});

  @override
  State<_DisposableWidget> createState() => __DisposableWidgetState();
}

class __DisposableWidgetState extends State<_DisposableWidget> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
