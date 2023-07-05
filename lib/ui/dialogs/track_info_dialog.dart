import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';
import 'package:namida/class/track.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/track_listens_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

Future<void> showTrackInfoDialog(Track track, bool enableBlur, {bool comingFromQueue = false, int? index}) async {
  // [showTrackDialog] calls [showGeneralPopupDialog] which has a built-check for tracks that are not available.
  final trackExt = track.toTrackExtOrNull();
  if (trackExt == null) {
    NamidaDialogs.inst.showTrackDialog(track);
    return;
  }

  final totalListens = HistoryController.inst.topTracksMapListens[track] ?? [];
  totalListens.sortByReverse((e) => e);
  final firstListenTrack = totalListens.lastOrNull;

  final color = await CurrentColor.inst.getTrackDelightnedColor(track);
  final theme = AppThemes.inst.getAppTheme(color, !Get.isDarkMode);

  bool shouldShowTheField(bool isUnknown) => !isUnknown || (SettingsController.inst.showUnknownFieldsInTrackInfoDialog.value && isUnknown);

  NamidaNavigator.inst.navigateDialog(
    Theme(
      data: theme,
      child: CustomBlurryDialog(
        enableBlur: enableBlur,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 86.0),
        normalTitleStyle: true,
        title: Language.inst.TRACK_INFO,
        trailingWidgets: [
          Obx(
            () => NamidaIconButton(
              tooltip: Language.inst.SHOW_HIDE_UNKNOWN_FIELDS,
              icon: SettingsController.inst.showUnknownFieldsInTrackInfoDialog.value ? Broken.eye : Broken.eye_slash,
              iconColor: theme.colorScheme.primary,
              onPressed: () => SettingsController.inst.save(showUnknownFieldsInTrackInfoDialog: !SettingsController.inst.showUnknownFieldsInTrackInfoDialog.value),
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
                          NamidaInkWell(
                            onTap: () => showTrackListensDialog(track, datesOfListen: totalListens, theme: theme),
                            borderRadius: 12.0,
                            child: Row(
                              children: [
                                const SizedBox(width: 2.0),
                                GestureDetector(
                                  onTap: () => NamidaNavigator.inst.navigateDialog(
                                    Container(
                                      color: Colors.black,
                                      child: InteractiveViewer(
                                        maxScale: 5,
                                        child: Hero(
                                          tag: '$comingFromQueue${index}_sussydialogs_${trackExt.path}',
                                          child: GestureDetector(
                                            onLongPress: () async {
                                              final saveDirPath = await EditDeleteController.inst.saveArtworkToStorage(track);
                                              String title = Language.inst.COPIED_ARTWORK;
                                              String subtitle = '${Language.inst.SAVED_IN} $saveDirPath';
                                              Color snackColor = CurrentColor.inst.color.value;

                                              if (saveDirPath == null) {
                                                title = Language.inst.ERROR;
                                                subtitle = Language.inst.COULDNT_SAVE_IMAGE;
                                                snackColor = Colors.red;
                                              }
                                              Get.snackbar(
                                                title,
                                                subtitle,
                                                snackPosition: SnackPosition.BOTTOM,
                                                snackStyle: SnackStyle.FLOATING,
                                                animationDuration: const Duration(milliseconds: 300),
                                                duration: const Duration(seconds: 2),
                                                leftBarIndicatorColor: snackColor,
                                                margin: const EdgeInsets.all(0.0),
                                                titleText: Text(
                                                  title,
                                                  style: Get.textTheme.displayMedium,
                                                ),
                                                messageText: Text(
                                                  subtitle,
                                                  style: Get.textTheme.displaySmall,
                                                ),
                                                borderRadius: 0,
                                              );
                                            },
                                            child: ArtworkWidget(
                                              track: track,
                                              path: trackExt.pathToImage,
                                              thumbnailSize: Get.width,
                                              compressed: false,
                                              borderRadius: 0,
                                              blur: 0,
                                              useTrackTileCacheHeight: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Hero(
                                    tag: '$comingFromQueue${index}_sussydialogs_${trackExt.path}',
                                    child: ArtworkWidget(
                                      track: track,
                                      path: trackExt.pathToImage,
                                      thumbnailSize: 120,
                                      forceSquared: SettingsController.inst.forceSquaredTrackThumbnail.value,
                                      useTrackTileCacheHeight: true,
                                      compressed: false,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10.0),
                                Expanded(
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
                                              firstListenTrack?.dateAndClockFormattedOriginal ?? Language.inst.MAKE_YOUR_FIRST_LISTEN,
                                              style: Get.textTheme.displaySmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12.0),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          if (shouldShowTheField(trackExt.hasUnknownTitle))
                            TrackInfoListTile(
                              title: Language.inst.TITLE,
                              value: trackExt.title,
                              icon: Broken.text,
                            ),

                          if (shouldShowTheField(trackExt.hasUnknownArtist))
                            TrackInfoListTile(
                              title: Indexer.inst.splitArtist(trackExt.title, trackExt.originalArtist, addArtistsFromTitle: false).length == 1
                                  ? Language.inst.ARTIST
                                  : Language.inst.ARTISTS,
                              value: trackExt.hasUnknownArtist ? k_UNKNOWN_TRACK_ARTIST : trackExt.originalArtist,
                              icon: Broken.microphone,
                            ),

                          if (shouldShowTheField(trackExt.hasUnknownAlbum))
                            TrackInfoListTile(
                              title: Language.inst.ALBUM,
                              value: trackExt.hasUnknownAlbum ? k_UNKNOWN_TRACK_ALBUM : trackExt.album,
                              icon: Broken.music_dashboard,
                            ),

                          if (shouldShowTheField(trackExt.hasUnknownAlbumArtist))
                            TrackInfoListTile(
                              title: Language.inst.ALBUM_ARTIST,
                              value: trackExt.hasUnknownAlbumArtist ? k_UNKNOWN_TRACK_ALBUMARTIST : trackExt.albumArtist,
                              icon: Broken.user,
                            ),

                          if (shouldShowTheField(trackExt.hasUnknownGenre))
                            TrackInfoListTile(
                              title: trackExt.genresList.length == 1 ? Language.inst.GENRE : Language.inst.GENRES,
                              value: trackExt.hasUnknownGenre ? k_UNKNOWN_TRACK_GENRE : trackExt.genresList.join(', '),
                              icon: trackExt.genresList.length == 1 ? Broken.emoji_happy : Broken.smileys,
                            ),

                          if (shouldShowTheField(trackExt.hasUnknownComposer))
                            TrackInfoListTile(
                              title: Language.inst.COMPOSER,
                              value: trackExt.hasUnknownComposer ? k_UNKNOWN_TRACK_COMPOSER : trackExt.composer,
                              icon: Broken.profile_2user,
                            ),

                          if (shouldShowTheField(trackExt.duration == 0))
                            TrackInfoListTile(
                              title: Language.inst.DURATION,
                              value: trackExt.duration.milliseconds.label,
                              icon: Broken.clock,
                            ),

                          if (shouldShowTheField(trackExt.year == 0))
                            TrackInfoListTile(
                              title: Language.inst.YEAR,
                              value: trackExt.year == 0 ? '?' : '${trackExt.year} (${trackExt.year.yearFormatted})',
                              icon: Broken.calendar,
                            ),

                          if (shouldShowTheField(trackExt.dateModified == 0))
                            TrackInfoListTile(
                              title: Language.inst.DATE_MODIFIED,
                              value: trackExt.dateModified.dateAndClockFormattedOriginal,
                              icon: Broken.calendar_1,
                            ),

                          ///
                          if (shouldShowTheField(trackExt.discNo == 0))
                            TrackInfoListTile(
                              title: Language.inst.DISC_NUMBER,
                              value: trackExt.discNo.toString(),
                              icon: Broken.hashtag,
                            ),

                          if (shouldShowTheField(trackExt.trackNo == 0))
                            TrackInfoListTile(
                              title: Language.inst.TRACK_NUMBER,
                              value: trackExt.trackNo.toString(),
                              icon: Broken.hashtag,
                            ),

                          /// bruh moment
                          if (shouldShowTheField(trackExt.filenameWOExt == ''))
                            TrackInfoListTile(
                              title: Language.inst.FILE_NAME,
                              value: trackExt.filenameWOExt,
                              icon: Broken.quote_up_circle,
                            ),

                          if (shouldShowTheField(trackExt.folderName == ''))
                            TrackInfoListTile(
                              title: Language.inst.FOLDER,
                              value: trackExt.folderName,
                              icon: Broken.folder,
                            ),

                          if (shouldShowTheField(trackExt.path == ''))
                            TrackInfoListTile(
                              title: Language.inst.PATH,
                              value: trackExt.path,
                              icon: Broken.location,
                            ),

                          TrackInfoListTile(
                            title: Language.inst.FORMAT,
                            value: '${track.audioInfoFormattedCompact}\n${trackExt.extension} - ${trackExt.size.fileSizeFormatted}',
                            icon: Broken.voice_cricle,
                          ),

                          if (shouldShowTheField(trackExt.lyrics == ''))
                            TrackInfoListTile(
                              title: Language.inst.LYRICS,
                              value: trackExt.lyrics,
                              icon: trackExt.lyrics.isEmpty ? Broken.note_remove : Broken.message_text,
                            ),

                          if (shouldShowTheField(trackExt.comment == ''))
                            TrackInfoListTile(
                              title: Language.inst.COMMENT,
                              value: trackExt.comment,
                              icon: Broken.message_text_1,
                              isComment: true,
                            ),
                          const SizedBox(height: 12.0),
                        ].addSeparators(separator: NamidaContainerDivider(color: color), skipFirst: 3).toList(),
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
      child: NamidaInkWell(
        borderRadius: 16.0,
        onTap: _copyField,
        onLongPress: _copyField,
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 6.0),
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
    );
  }
}
