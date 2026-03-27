import 'dart:async';

import 'package:flutter/material.dart';

import 'package:playlist_manager/module/playlist_id.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/result_wrapper/list_wrapper_base.dart';
import 'package:youtipie/class/result_wrapper/playlist_mix_result.dart';
import 'package:youtipie/class/result_wrapper/playlist_result.dart';
import 'package:youtipie/class/result_wrapper/playlist_result_base.dart';
import 'package:youtipie/class/result_wrapper/playlist_user_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item_user.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/yt_utils.dart';

class YtUtilsPlaylist {
  static Rxn<YoutiPieUserPlaylistsResult>? activeUserPlaylistsList;
  static final activePlaylists = <YoutiPiePlaylistEditCallbacks>[];

  Future<void> promptCreatePlaylist({
    required FutureOr<bool> Function(String title, PlaylistPrivacy? privacy) onButtonConfirm,
  }) => _promptCreateOrEditPlaylist(
    isEdit: false,
    playlistId: null,
    initialTitle: null,
    initialDescription: null,
    initialPrivacy: null,
    onButtonConfirm: (text, _, privacy) => onButtonConfirm(text, privacy),
  );

  Future<void> promptEditPlaylist({
    required YoutiPiePlaylistResult playlist,
    required PlaylistInfoItemUser userPlaylist,
    required FutureOr<bool> Function(String title, String? description, PlaylistPrivacy? privacy) onButtonConfirm,
  }) => _promptCreateOrEditPlaylist(
    isEdit: true,
    playlistId: playlist.info.id.isNotEmpty ? playlist.info.id : userPlaylist.id,
    initialTitle: playlist.info.title.isNotEmpty ? playlist.info.title : userPlaylist.title,
    initialDescription: playlist.info.description,
    initialPrivacy: playlist.info.privacy ?? userPlaylist.privacy,
    onButtonConfirm: onButtonConfirm,
  );

  Future<void> _promptCreateOrEditPlaylist({
    required bool isEdit,
    required String? playlistId,
    required String? initialTitle,
    required String? initialDescription,
    required PlaylistPrivacy? initialPrivacy,
    required FutureOr<bool> Function(String title, String? description, PlaylistPrivacy? privacy) onButtonConfirm,
  }) async {
    final privacyIconsLookup = {
      PlaylistPrivacy.public: Broken.global,
      PlaylistPrivacy.unlisted: Broken.link,
      PlaylistPrivacy.private: Broken.lock_1,
    };
    final privacyRx = (isEdit ? initialPrivacy : PlaylistPrivacy.private).obs;
    final titleController = TextEditingController(text: initialTitle);
    final descriptionController = isEdit ? TextEditingController(text: initialDescription) : null;

    Rx<bool>? isInitiallyLoading;
    // final shouldLoadEditInfo = isEdit && playlistId != null && (initialTitle == null || initialTitle.isEmpty || initialPrivacy == null);
    final shouldLoadEditInfo = isEdit && playlistId != null; // we prefer always loading live info for better cross-device sync

    if (shouldLoadEditInfo) {
      isInitiallyLoading = true.obs;
      isInitiallyLoading.value = true;
      Future<void> fillEditInfo() async {
        try {
          final plEditInfo = await YoutubeInfoController.userplaylist.getPlaylistEditInfo(playlistId);
          if (plEditInfo != null) {
            try {
              titleController.text = plEditInfo.title;
            } catch (_) {}
            try {
              if (plEditInfo.description != null) descriptionController?.text = plEditInfo.description!;
            } catch (_) {}
            if (plEditInfo.privacy != null) privacyRx.value = plEditInfo.privacy!;
          }
        } catch (_) {}

        isInitiallyLoading?.value = false;
      }

      fillEditInfo();
    }

    await showNamidaBottomSheetWithTextField(
      title: lang.configure,
      isInitiallyLoading: isInitiallyLoading,
      textfieldConfig: BottomSheetTextFieldConfigWC(
        controller: titleController,
        hintText: initialTitle ?? '',
        maxLength: YoutubeInfoController.userplaylist.MAX_PLAYLIST_NAME,
        labelText: lang.name,
        validator: (value) {
          if (value == null || value.isEmpty) return lang.pleaseEnterAName;
          return YoutubeInfoController.userplaylist.validatePlaylistTitle(value);
        },
      ),
      extraTextfieldsConfig: descriptionController == null
          ? null
          : [
              BottomSheetTextFieldConfigWC(
                controller: descriptionController,
                hintText: initialDescription ?? '',
                maxLength: YoutubeInfoController.userplaylist.MAX_PLAYLIST_DESCRIPTION,
                labelText: lang.description,
                validator: (value) => null,
              ),
            ],
      extraItemsBuilder: (formState) => Column(
        children: [
          const SizedBox(height: 12.0),
          SmoothSingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ObxO(
              rx: privacyRx,
              builder: (context, privacy) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: PlaylistPrivacy.values.map(
                  (e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: NamidaInkWellButton(
                        icon: privacyIconsLookup[e],
                        text: e.toText(),
                        bgColor: context.theme.colorScheme.secondaryContainer.withOpacityExt(privacy == e ? 0.5 : 0.2),
                        onTap: () => privacyRx.value = e,
                        trailing:
                            const SizedBox(
                              width: 16.0,
                              height: 16.0,
                              child: Checkbox.adaptive(
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(6.0)),
                                ),
                                value: true,
                                onChanged: null,
                              ),
                            ).animateEntrance(
                              showWhen: privacy == e,
                              allCurves: Curves.fastLinearToSlowEaseIn,
                              durationMS: 300,
                            ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
          ),
        ],
      ),
      buttonText: isEdit ? lang.save : lang.add,
      onButtonTap: (title) async {
        if (title.isEmpty) return false;
        final description = descriptionController?.text;
        return onButtonConfirm(title, description, privacyRx.value);
      },
    );
    Future.delayed(const Duration(milliseconds: 2000), () {
      privacyRx.close();
      try {
        titleController.dispose();
      } catch (_) {}
      try {
        descriptionController?.dispose();
      } catch (_) {}
    });
  }
}

extension YoutubePlaylistShare on YoutubePlaylist {
  Future<void> shareVideos() async => await tracks.shareVideos();

  Future<bool> promptDelete({required String name, Color? colorScheme}) async {
    bool deleted = false;
    await NamidaNavigator.inst.navigateDialog(
      colorScheme: colorScheme,
      dialogBuilder: (theme) => CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: "${lang.delete}: $name?",
        actions: [
          const CancelButton(),
          NamidaButton(
            colorScheme: Colors.red,
            text: lang.delete.toUpperCase(),
            onTap: () {
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
    required String playlistName,
  }) async {
    return await showNamidaBottomSheetWithTextField(
      title: lang.renamePlaylist,
      textfieldConfig: BottomSheetTextFieldConfig(
        initalControllerText: playlistName,
        hintText: playlistName,
        labelText: lang.name,
        validator: (value) => YoutubePlaylistController.inst.validatePlaylistName(value),
      ),
      buttonText: lang.save,
      onButtonTap: (text) async {
        final didRename = await YoutubePlaylistController.inst.renamePlaylist(playlistName, text);
        if (didRename) {
          return true;
        } else {
          snackyy(title: lang.error, message: lang.couldntRenamePlaylist);
          return false;
        }
      },
    );
  }
}

extension PlaylistBasicInfoExt on PlaylistBasicInfo {
  /// Videos are accessible through [YoutiPiePlaylistResult.items] getter.
  Future<YoutiPieFetchAllResType> fetchAllPlaylistStreams({
    required bool showProgressSheet,
    required YoutiPiePlaylistResultBase playlist,
    VoidCallback? onStart,
    VoidCallback? onEnd,
    void Function(YoutiPieFetchAllRes fetchAllRes)? controller,
    ExecuteDetails? executeDetails,
  }) async {
    final currentCount = playlist.items.length.obs;
    final fetchAllRes = playlist.fetchAll(
      onProgress: () {
        currentCount.value = playlist.items.length;
      },
      details: executeDetails,
    );
    if (fetchAllRes == null) return YoutiPieFetchAllResType.alreadyDone; // no continuation left

    controller?.call(fetchAllRes);

    final totalCount = Rxn<int>(playlist.basicInfo.videosCount);
    const switchAnimationDur = Duration(milliseconds: 600);
    const switchAnimationDurHalf = Duration(milliseconds: 300);

    void Function()? popSheet;

    if (showProgressSheet) {
      WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback(
        (timeStamp) async {
          final rootContext = namida.rootNavigatorKey.currentContext;
          if (rootContext != null) {
            popSheet = Navigator.of(rootContext, rootNavigator: true).maybePop;
            void onSheetClose() {
              popSheet = null;
              if (fetchAllRes.isExecuting) {
                // cancel if closed manually
                fetchAllRes.cancel();
              }
            }

            NamidaNavigator.inst
                .showSheet(
                  isDismissible: false,
                  builder: (context, bottomPadding, maxWidth, maxHeight) {
                    final theme = context.theme;
                    final textTheme = theme.textTheme;
                    final iconSize = maxWidth * 0.5;
                    final iconColor = theme.colorScheme.onSurface.withOpacityExt(0.6);
                    return Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Obx(
                            (context) {
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
                            '${lang.fetching}...',
                            style: textTheme.displayLarge,
                          ),
                          const SizedBox(height: 8.0),
                          Obx(
                            (context) {
                              final totalC = totalCount.valueR;
                              return Text(
                                '${currentCount.valueR.formatDecimal()}/${totalC == null ? '?' : totalC.formatDecimal()}',
                                style: textTheme.displayLarge,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                )
                .whenComplete(onSheetClose);
          }
        },
      );
    }

    onStart?.call();

    final fetchRes = await fetchAllRes.result;

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

    return fetchRes;
  }

  Future<List<YoutubeID>> fetchAllPlaylistAsYTIDs({
    required bool showProgressSheet,
    required YoutiPiePlaylistResultBase playlistToFetch,
  }) async {
    final playlist = this;
    final fetchRes = await playlist.fetchAllPlaylistStreams(showProgressSheet: showProgressSheet, playlist: playlistToFetch, executeDetails: ExecuteDetails.forceRequest());

    switch (fetchRes) {
      case YoutiPieFetchAllResType.success || YoutiPieFetchAllResType.alreadyDone:
        break;
      case YoutiPieFetchAllResType.fail || YoutiPieFetchAllResType.inProgress:
        snackyy(title: lang.error, message: '${lang.errorFetchingVideoList}: $fetchRes');
        break; // still show the page
      case YoutiPieFetchAllResType.alreadyCanceled:
        return [];
    }

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
      playlistInfo: this,
    ).navigate();
  }

  FutureOr<List<NamidaPopupItem>> getPopupMenuItems({
    required QueueSourceYoutubeID queueSource,
    required bool showProgressSheet,
    required YoutiPiePlaylistResultBase playlistToFetch,
    required PlaylistInfoItemUser? userPlaylist,
    bool displayDownloadItem = true,
    bool displayShuffle = true,
    bool displayPlay = true,
    bool displayOpenPlaylist = false,
    bool isInFullScreen = false,
  }) async {
    final playlist = this;
    final videosCount = playlist.videosCount;
    String? countText;
    if (playlistToFetch is YoutiPieMixPlaylistResult) {
      countText = videosCount?.formatDecimalShort() ?? '+25';
    } else if (playlistToFetch is YoutiPiePlaylistResult) {
      countText = videosCount?.formatDecimalShort();
    }
    countText ??= '?';

    final playAfterVid = await YTUtils.getPlayerAfterVideo();

    Future<List<YoutubeID>> fetchAllIDs() async => await fetchAllPlaylistAsYTIDs(showProgressSheet: showProgressSheet, playlistToFetch: playlistToFetch);

    String playlistNameToAddAs = playlistToFetch.basicInfo.title;
    String suffix = '';
    int suffixIndex = 1;
    while (YoutubePlaylistController.inst.playlistsMap.value["$playlistNameToAddAs$suffix"] != null) {
      suffixIndex++;
      suffix = ' ($suffixIndex)';
    }
    playlistNameToAddAs += suffix;

    final isInYTOnlineLibrary = playlistToFetch is YoutiPiePlaylistResult ? playlistToFetch.info.isInLibrary.value : null;
    return [
      if (playlistToFetch is YoutiPiePlaylistResult && isInYTOnlineLibrary != null)
        NamidaPopupItem(
          icon: Broken.archive,
          title: isInYTOnlineLibrary ? lang.removeFromLibrary : lang.saveToLibrary,
          trailing: const Icon(Broken.global, size: 14.0),
          onTap: () async {
            bool? didSuccess;
            if (isInYTOnlineLibrary) {
              didSuccess = await YoutubeInfoController.userplaylist.removeHostedPlaylistFromLibrary(
                playlist: playlistToFetch,
              );
            } else {
              didSuccess = await YoutubeInfoController.userplaylist.addHostedPlaylistToLibrary(
                playlist: playlistToFetch,
              );
            }
            if (didSuccess == true) {
              snackyy(title: lang.succeeded, message: (isInYTOnlineLibrary ? lang.removed : lang.added).capitalizeFirst(), borderColor: Colors.green.withOpacityExt(0.5));
            } else {
              snackyy(title: lang.error, message: lang.failed, isError: true);
            }
          },
        ),
      if (playlistNameToAddAs != '')
        NamidaPopupItem(
          icon: Broken.add_square,
          title: lang.addAsANewPlaylist,
          subtitle: playlistNameToAddAs,
          onTap: () async {
            final fetchRes = await playlist.fetchAllPlaylistStreams(showProgressSheet: showProgressSheet, playlist: playlistToFetch);
            switch (fetchRes) {
              case YoutiPieFetchAllResType.success || YoutiPieFetchAllResType.alreadyDone:
                break;
              case YoutiPieFetchAllResType.fail || YoutiPieFetchAllResType.inProgress:
                snackyy(title: lang.error, message: '${lang.errorFetchingVideoList}: $fetchRes');
                return;
              case YoutiPieFetchAllResType.alreadyCanceled:
                return;
            }
            YoutubePlaylistController.inst.addNewPlaylist(
              playlistNameToAddAs,
              videoIds: playlistToFetch.items.map((e) => e.id),
            );
          },
        ),
      NamidaPopupItem(
        icon: Broken.music_playlist,
        title: lang.addToPlaylist,
        onTap: () async {
          final fetchRes = await playlist.fetchAllPlaylistStreams(showProgressSheet: showProgressSheet, playlist: playlistToFetch);
          switch (fetchRes) {
            case YoutiPieFetchAllResType.success || YoutiPieFetchAllResType.alreadyDone:
              break;
            case YoutiPieFetchAllResType.fail || YoutiPieFetchAllResType.inProgress:
              snackyy(title: lang.error, message: '${lang.errorFetchingVideoList}: $fetchRes');
              return;
            case YoutiPieFetchAllResType.alreadyCanceled:
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
      if (userPlaylist != null &&
          playlistToFetch is YoutiPiePlaylistResult &&
          (playlistToFetch.info.id.length == 34 || playlistToFetch.info.id.length == 36) && // exludes mixes & defaults (WL & LL)
          playlistToFetch.info.uploader?.id == YoutubeAccountController.current.activeAccountChannel.value?.id)
        NamidaPopupItem(
          icon: Broken.edit_2,
          title: lang.edit,
          onTap: () async {
            YtUtilsPlaylist().promptEditPlaylist(
              playlist: playlistToFetch,
              userPlaylist: userPlaylist,
              onButtonConfirm: (playlistTitle, description, privacy) async {
                final didEdit = await YoutubeInfoController.userplaylist.editPlaylist(
                  mainList: YtUtilsPlaylist.activeUserPlaylistsList,
                  playlists: YtUtilsPlaylist.activePlaylists,
                  playlistId: playlistToFetch.info.id,
                  title: playlistTitle,
                  description: description,
                  privacy: privacy,
                );
                return didEdit == true;
              },
            );
          },
        ),
      NamidaPopupItem(
        icon: Broken.share,
        title: lang.share,
        onTap: () {
          final url = this.buildUrl();
          NamidaUtils.shareUri(url);
        },
      ),
      if (displayDownloadItem)
        NamidaPopupItem(
          icon: Broken.import,
          title: lang.download,
          onTap: () {
            if (isInFullScreen) NamidaNavigator.inst.exitFullScreen();
            showPlaylistDownloadSheet(
              showProgressSheet: showProgressSheet,
              playlistToFetch: playlistToFetch,
            );
          },
        ),
      if (displayOpenPlaylist)
        NamidaPopupItem(
          icon: Broken.export_2,
          title: lang.open,
          onTap: () {
            if (isInFullScreen) NamidaNavigator.inst.exitFullScreen();
            YTHostedPlaylistSubpage(
              playlist: playlistToFetch,
              userPlaylist: userPlaylist,
            ).navigate();
          },
        ),
      if (displayPlay)
        NamidaPopupItem(
          icon: Broken.play,
          title: "${lang.play} ($countText)",
          onTap: () async {
            final videos = await fetchAllIDs();
            if (videos.isEmpty) return;
            Player.inst.playOrPause(0, videos, queueSource);
          },
        ),
      if (displayShuffle)
        NamidaPopupItem(
          icon: Broken.shuffle,
          title: "${lang.shuffle} ($countText)",
          onTap: () async {
            final videos = await fetchAllIDs();
            if (videos.isEmpty) return;
            Player.inst.playOrPause(0, videos, queueSource, shuffle: true);
          },
        ),
      NamidaPopupItem(
        icon: Broken.next,
        title: "${lang.playNext} ($countText)",
        onTap: () async {
          final videos = await fetchAllIDs();
          if (videos.isEmpty) return;
          Player.inst.addToQueue(videos, insertNext: true);
        },
      ),
      if (playAfterVid != null)
        NamidaPopupItem(
          icon: Broken.hierarchy_square,
          title: '${lang.playAfter}: ${playAfterVid.diff.displayVideoKeyword}',
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
        title: "${lang.playLast} ($countText)",
        onTap: () async {
          final videos = await fetchAllIDs();
          if (videos.isEmpty) return;
          Player.inst.addToQueue(videos, insertNext: false);
        },
      ),
    ];
  }
}
