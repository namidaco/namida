import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart' as yt;
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';

extension YoutubePlaylistShare on YoutubePlaylist {
  Future<void> shareVideos() async => await tracks.shareVideos();

  void promptDelete({required String name, Color? colorScheme}) {
    NamidaNavigator.inst.navigateDialog(
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
              NamidaNavigator.inst.closeDialog();
              YoutubePlaylistController.inst.removePlaylist(this);
            },
          ),
        ],
      ),
    );
  }

  Future<String> showRenamePlaylistSheet({
    required BuildContext context,
    required String playlistName,
  }) async {
    final controller = TextEditingController(text: playlistName);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final focusNode = FocusNode();
    focusNode.requestFocus();

    await Future.delayed(Duration.zero); // delay bcz sometimes doesnt show
    // ignore: use_build_context_synchronously
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0).add(EdgeInsets.only(bottom: 18.0 + bottomPadding)),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang.RENAME_PLAYLIST,
                  style: context.textTheme.displayLarge,
                ),
                const SizedBox(height: 18.0),
                CustomTagTextField(
                  focusNode: focusNode,
                  controller: controller,
                  hintText: playlistName,
                  labelText: lang.NAME,
                  validator: (value) => YoutubePlaylistController.inst.validatePlaylistName(value),
                ),
                const SizedBox(height: 18.0),
                Row(
                  children: [
                    SizedBox(width: context.width * 0.1),
                    CancelButton(onPressed: Navigator.of(context).pop),
                    SizedBox(width: context.width * 0.1),
                    Expanded(
                      child: NamidaInkWell(
                        borderRadius: 12.0,
                        padding: const EdgeInsets.all(12.0),
                        height: 48.0,
                        bgColor: CurrentColor.inst.color,
                        decoration: const BoxDecoration(),
                        child: Center(
                          child: Text(
                            lang.SAVE,
                            style: context.textTheme.displayMedium?.copyWith(color: Colors.white.withOpacity(0.9)),
                          ),
                        ),
                        onTap: () async {
                          if (formKey.currentState!.validate()) {
                            final didRename = await YoutubePlaylistController.inst.renamePlaylist(playlistName, controller.text);
                            if (didRename) {
                              Navigator.of(context).maybePop();
                            } else {
                              snackyy(title: lang.ERROR, message: lang.COULDNT_RENAME_PLAYLIST);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return controller.text;
  }
}

extension YoutubePlaylistHostedUtils on yt.YoutubePlaylist {
  /// Sending a [context] means showing a bottom sheet with progress.
  ///
  /// Returns wether the fetching process ended successfully, videos are accessible through [streams] getter.
  Future<bool> fetchAllPlaylistStreams({required BuildContext? context}) async {
    final playlist = this;
    if (playlist.streams.length == playlist.streamCount) return true;

    final currentCount = playlist.streams.length.obs;
    final totalCount = playlist.streamCount.obs;
    const switchAnimationDur = Duration(milliseconds: 600);
    const switchAnimationDurHalf = Duration(milliseconds: 300);

    bool isTotalCountNull() => totalCount.value < 0;

    if (context != null) {
      await Future.delayed(Duration.zero);
      // ignore: use_build_context_synchronously
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isDismissible: false,
        builder: (context) {
          final iconSize = context.width * 0.5;
          final iconColor = context.theme.colorScheme.onBackground.withOpacity(0.6);
          return SizedBox(
            width: context.width,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Obx(
                    () => AnimatedSwitcher(
                      key: const Key('circle_switch'),
                      duration: switchAnimationDurHalf,
                      child: currentCount.value < totalCount.value || isTotalCountNull()
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
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    '${lang.FETCHING}...',
                    style: context.textTheme.displayLarge,
                  ),
                  const SizedBox(height: 8.0),
                  Obx(
                    () => Text(
                      '${currentCount.value.formatDecimal()}/${isTotalCountNull() ? '?' : totalCount.value.formatDecimal()}',
                      style: context.textTheme.displayLarge,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (isTotalCountNull() || currentCount.value == 0) {
      await YoutubeController.inst.getPlaylistStreams(playlist, forceInitial: currentCount.value == 0);
      currentCount.value = playlist.streams.length;
      totalCount.value = playlist.streamCount < 0 ? playlist.streams.length : playlist.streamCount;
    }

    // -- if still not fetched
    if (isTotalCountNull()) {
      if (context != null && context.mounted) Navigator.of(context).pop();
      currentCount.close();
      return false;
    }

    while (currentCount.value < totalCount.value) {
      final res = await YoutubeController.inst.getPlaylistStreams(playlist);
      if (res.isEmpty) break;
      currentCount.value = playlist.streams.length;
    }

    if (context != null) {
      await Future.delayed(switchAnimationDur);
      if (context.mounted) Navigator.of(context).pop();
    }

    currentCount.close();
    totalCount.close();
    return true;
  }

  Future<void> showPlaylistDownloadSheet({required BuildContext? context}) async {
    final didFetch = await fetchAllPlaylistStreams(context: context);
    if (!didFetch) return snackyy(title: lang.ERROR, message: 'error fetching playlist videos');
    final playlist = this;
    final plID = playlist.id;
    final videoIDs = playlist.streams.map((e) => YoutubeID(
          id: e.id ?? '',
          playlistID: plID == null ? null : PlaylistID(id: plID),
        ));
    final infoLookup = <String, yt.StreamInfoItem>{};
    playlist.streams.loop((e, index) {
      infoLookup[e.id ?? ''] = e;
    });
    NamidaNavigator.inst.navigateTo(
      YTPlaylistDownloadPage(
        ids: videoIDs.toList(),
        playlistName: playlist.name ?? '',
        infoLookup: infoLookup,
      ),
    );
  }
}
