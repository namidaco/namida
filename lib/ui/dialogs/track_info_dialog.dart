import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

Future<void> showTrackInfoDialog(Track track, bool enableBlur, {bool comingFromQueue = false, int? index}) async {
  if (Indexer.inst.allTracksMappedByPath[track.path] == null) {
    // [showTrackDialog] calls [showGeneralPopupDialog] which has a built-check for tracks that are not available.
    NamidaDialogs.inst.showTrackDialog(track);
    return;
  }
  final firstListenTrack = namidaHistoryPlaylist.tracks.lastWhere(
    (element) => element.track == track,
    orElse: () => TrackWithDate(0, track, TrackSource.local),
  );
  final totalListens = namidaHistoryPlaylist.tracks.where((element) => element.track.path == track.path).toList();
  final color = await CurrentColor.inst.generateDelightnedColor(track.pathToImage);
  final theme = AppThemes.inst.getAppTheme(color, !Get.isDarkMode);
  bool shouldShowTheField(bool isUnknown) => !isUnknown || (SettingsController.inst.showUnknownFieldsInTrackInfoDialog.value && isUnknown);

  await Get.to(
    () => Theme(
      data: theme,
      child: CustomBlurryDialog(
        enableBlur: enableBlur,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 86.0),
        normalTitleStyle: true,
        title: Language.inst.TRACK_INFO,
        trailingWidgets: [
          Obx(
            () => Tooltip(
              message: Language.inst.SHOW_HIDE_UNKNOWN_FIELDS,
              child: NamidaIconButton(
                icon: SettingsController.inst.showUnknownFieldsInTrackInfoDialog.value ? Broken.eye : Broken.eye_slash,
                iconColor: theme.colorScheme.primary,
                onPressed: () => SettingsController.inst.save(showUnknownFieldsInTrackInfoDialog: !SettingsController.inst.showUnknownFieldsInTrackInfoDialog.value),
              ),
            ),
          ),
          NamidaLikeButton(
            track: track,
            size: 24,
            color: theme.colorScheme.primary,
          ),
          // TODO(MSOB7YY): preview only not play
          NamidaIconButton(
            icon: Broken.play,
            iconColor: theme.colorScheme.primary,
            onPressed: () => Player.inst.playOrPause(0, [track], QueueSource.playerQueue),
          ),
        ],
        icon: Broken.info_circle,
        child: Theme(
          data: theme,
          child: SizedBox(
            height: Get.height * 0.7,
            width: Get.width,
            child: Obx(
              () {
                SettingsController.inst.showUnknownFieldsInTrackInfoDialog.value;
                return CustomScrollView(
                  slivers: [
                    SliverList(
                      delegate: SliverChildListDelegate(
                        [
                          const SizedBox(height: 12.0),
                          Row(
                            children: [
                              InkWell(
                                onTap: () => Get.to(
                                  () => Container(
                                    color: Colors.black,
                                    child: InteractiveViewer(
                                      maxScale: 5,
                                      child: Hero(
                                        tag: '$comingFromQueue${index}_sussydialogs_${track.path}',
                                        child: ArtworkWidget(
                                          path: track.pathToImage,
                                          thumnailSize: Get.width,
                                          compressed: false,
                                          borderRadius: 0,
                                          blur: 0,
                                          useTrackTileCacheHeight: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  opaque: false,
                                  transition: Transition.fade,
                                  fullscreenDialog: true,
                                ),
                                child: Hero(
                                  tag: '$comingFromQueue${index}_sussydialogs_${track.path}',
                                  child: ArtworkWidget(
                                    path: track.pathToImage,
                                    thumnailSize: 120,
                                    forceSquared: SettingsController.inst.forceSquaredTrackThumbnail.value,
                                    useTrackTileCacheHeight: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    if (totalListens.isEmpty) {
                                      return;
                                    }
                                    Get.dialog(
                                      CustomBlurryDialog(
                                        normalTitleStyle: true,
                                        title: Language.inst.TOTAL_LISTENS,
                                        enableBlur: false,
                                        trailingWidgets: [
                                          Text(
                                            '${totalListens.length}',
                                            style: Get.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                        child: SizedBox(
                                          height: Get.height * 0.7,
                                          width: Get.width,
                                          child: NamidaListView(
                                            padding: EdgeInsets.zero,
                                            itemBuilder: (context, i) {
                                              final t = totalListens[i];
                                              return SmallListTile(
                                                key: ValueKey(i),
                                                borderRadius: 14.0,
                                                title: t.dateAdded.dateAndClockFormattedOriginal,
                                                onTap: () async {
                                                  final i = namidaHistoryPlaylist.tracks.indexWhere((element) => element.dateAdded == t.dateAdded);
                                                  NamidaOnTaps.inst.onPlaylistTap(
                                                    namidaHistoryPlaylist,
                                                    disableAnimation: true,
                                                    indexToHighlight: i,
                                                    scrollController: ScrollController(initialScrollOffset: trackTileItemExtent * i),
                                                  );
                                                },
                                              );
                                            },
                                            itemCount: totalListens.length,
                                            itemExtents: null,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Broken.hashtag_1,
                                            size: 18.0,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                '${Language.inst.TOTAL_LISTENS}: ',
                                                style: Get.textTheme.displaySmall,
                                              ),
                                              Text(
                                                '${totalListens.length}',
                                                style: Get.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8.0),
                                      Row(
                                        children: [
                                          const Icon(
                                            Broken.cake,
                                            size: 18.0,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Expanded(
                                            child: Text(
                                              firstListenTrack.dateAdded == 0 ? Language.inst.MAKE_YOUR_FIRST_LISTEN : firstListenTrack.dateAdded.dateAndClockFormattedOriginal,
                                              style: Get.textTheme.displaySmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                            ],
                          ),
                          const SizedBox(height: 12.0),
                          if (shouldShowTheField(track.hasUnknownTitle)) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.TITLE,
                              value: track.title,
                              icon: Broken.text,
                            ),
                          ],

                          if (shouldShowTheField(track.hasUnknownArtist)) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: track.artistsList.length == 1 ? Language.inst.ARTIST : Language.inst.ARTISTS,
                              value: track.originalArtist,
                              icon: Broken.microphone,
                            ),
                          ],

                          if (shouldShowTheField(track.hasUnknownAlbum)) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.ALBUM,
                              value: track.album,
                              icon: Broken.music_dashboard,
                            ),
                          ],

                          if (shouldShowTheField(track.hasUnknownAlbumArtist)) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.ALBUM_ARTIST,
                              value: track.albumArtist,
                              icon: Broken.user,
                            ),
                          ],

                          if (shouldShowTheField(track.hasUnknownGenre)) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: track.genresList.length == 1 ? Language.inst.GENRE : Language.inst.GENRES,
                              value: track.genresList.join(', '),
                              icon: track.genresList.length == 1 ? Broken.emoji_happy : Broken.smileys,
                            ),
                          ],

                          if (shouldShowTheField(track.hasUnknownComposer)) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.COMPOSER,
                              value: track.composer,
                              icon: Broken.profile_2user,
                            ),
                          ],

                          if (shouldShowTheField(track.duration == 0)) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.DURATION,
                              value: track.duration.milliseconds.label,
                              icon: Broken.clock,
                            ),
                          ],

                          if (shouldShowTheField(track.year == 0)) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.YEAR,
                              value: track.year == 0 ? '?' : '${track.year} (${track.year.yearFormatted})',
                              icon: Broken.calendar,
                            ),
                          ],

                          if (shouldShowTheField(track.dateModified == 0)) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.DATE_MODIFIED,
                              value: track.dateModified.dateAndClockFormattedOriginal,
                              icon: Broken.calendar_1,
                            ),
                          ],

                          ///
                          if (shouldShowTheField(track.discNo == 0)) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.DISC_NUMBER,
                              value: track.discNo.toString(),
                              icon: Broken.hashtag,
                            ),
                          ],

                          if (shouldShowTheField(track.track == 0)) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.TRACK_NUMBER,
                              value: track.track.toString(),
                              icon: Broken.hashtag,
                            ),
                          ],

                          /// bruh moment
                          if (shouldShowTheField(track.filenameWOExt == '')) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.FILE_NAME,
                              value: track.filenameWOExt,
                              icon: Broken.quote_up_circle,
                            ),
                          ],
                          if (shouldShowTheField(track.folderName == '')) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.FOLDER,
                              value: track.folderName,
                              icon: Broken.folder,
                            ),
                          ],
                          if (shouldShowTheField(track.path == '')) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.PATH,
                              value: track.path,
                              icon: Broken.location,
                            ),
                          ],

                          NamidaContainerDivider(color: color),
                          TrackInfoListTile(
                            title: Language.inst.FORMAT,
                            value: '${track.audioInfoFormattedCompact}\n${track.extension} - ${track.size.fileSizeFormatted}',
                            icon: Broken.voice_cricle,
                          ),

                          if (shouldShowTheField(track.lyrics == '')) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.LYRICS,
                              value: track.lyrics,
                              icon: track.lyrics.isEmpty ? Broken.note_remove : Broken.message_text,
                            ),
                          ],

                          if (shouldShowTheField(track.comment == '')) ...[
                            NamidaContainerDivider(color: color),
                            TrackInfoListTile(
                              title: Language.inst.COMMENT,
                              value: track.comment,
                              icon: Broken.message_text_1,
                              isComment: true,
                            ),
                          ],
                          NamidaContainerDivider(color: color),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
    opaque: false,
    transition: Transition.fade,
    fullscreenDialog: true,
  );
}

class TrackInfoListTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isComment;
  const TrackInfoListTile({super.key, required this.title, required this.value, required this.icon, this.isComment = false});
  void _copyField() {
    Clipboard.setData(ClipboardData(text: value));
    Get.snackbar(
      'Copied $title',
      value,
      snackPosition: SnackPosition.BOTTOM,
      snackStyle: SnackStyle.FLOATING,
      animationDuration: const Duration(milliseconds: 300),
      duration: const Duration(seconds: 2),
      leftBarIndicatorColor: CurrentColor.inst.color.value,
      margin: const EdgeInsets.all(0.0),
      titleText: Text(
        'Copied $title',
        style: Get.textTheme.displayMedium,
      ),
      messageText: Text(
        value,
        style: Get.textTheme.displaySmall,
      ),
      borderRadius: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0.multipliedRadius),
          onTap: _copyField,
          onLongPress: _copyField,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 6.0),
            child: Wrap(
              runSpacing: 6.0,
              children: [
                Icon(
                  icon,
                  size: 17.0,
                  color: context.theme.colorScheme.onBackground.withAlpha(220),
                ),
                const SizedBox(width: 6.0),
                Text(
                  '$title:',
                  style: context.theme.textTheme.displaySmall?.copyWith(color: context.theme.colorScheme.onBackground.withAlpha(220)),
                ),
                const SizedBox(width: 4.0),
                isComment
                    ? NamidaSelectableAutoLinkText(text: value == '' ? '?' : value)
                    : Text(
                        value == '' ? '?' : value,
                        style: context.theme.textTheme.displayMedium?.copyWith(
                          color: Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(100), context.theme.colorScheme.primary),
                          fontSize: 13.5.multipliedFontScale,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
