import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

Future<void> showTrackInfoDialog(Track track, {bool comingFromQueue = false, int? index}) async {
  final firstListenTrack = namidaHistoryPlaylist.tracks.lastWhere(
    (element) => element.track == track,
    orElse: () => TrackWithDate(0, track, TrackSource.local),
  );
  final color = await CurrentColor.inst.generateDelightnedColor(track.pathToImage);
  final theme = AppThemes.inst.getAppTheme(color, !Get.isDarkMode);
  await Get.to(
    () => Theme(
      data: theme,
      child: CustomBlurryDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 86.0),
        normalTitleStyle: true,
        title: Language.inst.TRACK_INFO,
        trailing: NamidaLikeButton(
          track: track,
          size: 24,
          color: theme.colorScheme.primary,
        ),
        icon: Broken.info_circle,
        child: Theme(
          data: theme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12.0),
              Row(
                children: [
                  InkWell(
                    onTap: () => Get.to(
                      () => Container(
                        color: Colors.black,
                        child: Hero(
                          tag: '$comingFromQueue${index}_sussydialogs_${track.path}',
                          child: ArtworkWidget(
                            track: track,
                            thumnailSize: Get.width,
                            useTrackTileCacheHeight: true,
                            compressed: false,
                            borderRadius: 0,
                            blur: 0,
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
                        track: track,
                        thumnailSize: 120,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
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
                                  '${namidaHistoryPlaylist.tracks.where((element) => element.track == track).length}',
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

                            ///TODO: what to write
                            Expanded(
                              child: Text(
                                firstListenTrack.dateAdded == 0 ? 'Make your first listen!' : firstListenTrack.dateAdded.dateAndClockFormattedOriginal,
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
              const SizedBox(height: 12.0),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: Language.inst.TITLE,
                value: track.title,
                icon: Broken.text,
              ),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: track.artistsList.length == 1 ? Language.inst.ARTIST : Language.inst.ARTISTS,
                value: track.artistsList.join(', '),
                icon: Broken.microphone,
              ),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: Language.inst.ALBUM,
                value: track.album,
                icon: Broken.music_dashboard,
              ),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: Language.inst.ALBUM_ARTIST,
                value: track.albumArtist,
                icon: Broken.user,
              ),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: track.genresList.length == 1 ? Language.inst.GENRE : Language.inst.GENRES,
                value: track.genresList.join(', '),
                icon: track.genresList.length == 1 ? Broken.emoji_happy : Broken.smileys,
              ),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: Language.inst.COMPOSER,
                value: track.composer,
                icon: Broken.profile_2user,
              ),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: Language.inst.DURATION,
                value: track.duration.milliseconds.label,
                icon: Broken.clock,
              ),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: Language.inst.YEAR,
                value: track.year == 0 ? '?' : '${track.year} (${track.year.yearFormatted})',
                icon: Broken.calendar,
              ),
              NamidaContainerDivider(color: color),

              TrackInfoListTile(
                title: Language.inst.DATE_MODIFIED,
                value: track.dateModified.dateAndClockFormattedOriginal,
                icon: Broken.calendar_1,
              ),
              NamidaContainerDivider(color: color),

              ///
              TrackInfoListTile(
                title: Language.inst.DISC_NUMBER,
                value: track.discNo.toString(),
                icon: Broken.hashtag,
              ),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: Language.inst.TRACK_NUMBER,
                value: track.track.toString(),
                icon: Broken.hashtag,
              ),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: Language.inst.FILE_NAME,
                value: track.filenameWOExt,
                icon: Broken.quote_up_circle,
              ),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: Language.inst.FOLDER,
                value: track.folderName,
                icon: Broken.folder,
              ),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: Language.inst.PATH,
                value: track.path,
                icon: Broken.location,
              ),

              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: Language.inst.FORMAT,
                value: '${track.audioInfoFormattedCompact}\n${track.extension} - ${track.size.fileSizeFormatted}',
                icon: Broken.voice_cricle,
              ),
              NamidaContainerDivider(color: color),

              TrackInfoListTile(
                title: Language.inst.LYRICS,
                value: track.lyrics,
                icon: track.lyrics.isEmpty ? Broken.note_remove : Broken.message_text,
              ),
              NamidaContainerDivider(color: color),
              TrackInfoListTile(
                title: Language.inst.COMMENT,
                value: track.comment,
                icon: Broken.message_text_1,
                isComment: true,
              ),
              NamidaContainerDivider(color: color),
            ],
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0.multipliedRadius),
          onTap: () => Clipboard.setData(ClipboardData(text: value)),
          onLongPress: () => Clipboard.setData(ClipboardData(text: value)),
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
                        value == '' ? '?' : value.overflow,
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
