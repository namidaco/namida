import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_view/photo_view.dart';

import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/base/audio_handler.dart';
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
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/track_listens_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

Future<void> showTrackInfoDialog(
  Track track,
  bool enableBlur, {
  bool comingFromQueue = false,
  int? index,
  Color? colorScheme,
  required QueueSource queueSource,
  String? additionalHero,
}) async {
  // [showTrackDialog] calls [showGeneralPopupDialog] which has a built-check for tracks that are not available.
  final trackExt = track.toTrackExtOrNull();
  if (trackExt == null) {
    NamidaDialogs.inst.showTrackDialog(
      track,
      source: queueSource,
      additionalHero: additionalHero,
    );
    return;
  }

  final totalListens = HistoryController.inst.topTracksMapListens[track] ?? [];
  totalListens.sortByReverse((e) => e);
  final firstListenTrack = totalListens.lastOrNull;

  final color = (colorScheme ?? CurrentColor.inst.color).obs;

  if (colorScheme == null) {
    CurrentColor.inst.getTrackDelightnedColor(track, useIsolate: true).executeWithMinDelay(delayMS: 100).then((c) {
      if (c == color.value) return;
      color.value = c;
    });
  }

  bool shouldShowTheField(bool isUnknown) => !isUnknown || (settings.showUnknownFieldsInTrackInfoDialog.value && isUnknown);

  void showPreviewTrackDialog() async {
    final wasPlaying = Player.inst.isPlaying;
    if (wasPlaying) {
      Player.inst.pause();
    }

    final ap = AudioPlayer();
    await ap.setAudioSource(track.toAudioSource(0, 0));
    ap.play();

    NamidaNavigator.inst.navigateDialog(
      durationInMs: 400,
      onDismissing: () {
        ap.stop();
        if (wasPlaying) {
          Player.inst.play();
        }
      },
      dialog: StreamBuilder(
        initialData: color.value,
        stream: color.stream,
        builder: (context, snapshot) {
          final theme = AppThemes.inst.getAppTheme(snapshot.data, null, true);
          return AnimatedTheme(
            data: theme,
            child: Builder(builder: (context) {
              return CustomBlurryDialog(
                theme: theme,
                insetPadding: const EdgeInsets.all(24.0),
                title: lang.PREVIEW,
                normalTitleStyle: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StreamBuilder(
                      stream: ap.positionStream,
                      builder: (context, snapshot) {
                        final dur = snapshot.data ?? Duration.zero;
                        return Text(dur.inSeconds.secondsLabel);
                      },
                    ),
                    StreamBuilder(
                      initialData: Duration.zero,
                      stream: ap.positionStream,
                      builder: (context, snapshot) {
                        final dur = snapshot.data ?? Duration.zero;
                        return Slider.adaptive(
                          value: dur.inMilliseconds.toDouble(),
                          min: 0,
                          max: ap.duration?.inMilliseconds.toDouble() ?? 0,
                          onChanged: (value) => ap.seek(Duration(milliseconds: value.toInt())),
                        );
                      },
                    ),
                    Text(((ap.duration?.inSeconds ?? 0).secondsLabel)),
                    StreamBuilder(
                      stream: ap.playingStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data ?? false;
                        return NamidaIconButton(
                          icon: isPlaying ? Broken.pause : Broken.play,
                          onPressed: ap.playing ? ap.pause : ap.play,
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }

  final artwork = NamidaHero(
    tag: '$comingFromQueue${index}_sussydialogs_${trackExt.path}$additionalHero',
    child: ArtworkWidget(
      key: Key(trackExt.pathToImage),
      track: trackExt.toTrack(),
      path: trackExt.pathToImage,
      thumbnailSize: 120,
      forceSquared: settings.forceSquaredTrackThumbnail.value,
      useTrackTileCacheHeight: true,
      compressed: false,
    ),
  );

  String releasedFromNow = '';
  final parsed = DateTime.tryParse(trackExt.year.toString());
  if (parsed != null) {
    final fromNow = Jiffy.parseFromDateTime(parsed);
    releasedFromNow = fromNow.fromNow();
  }

  NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      color.close();
    },
    lighterDialogColor: false,
    dialog: StreamBuilder(
      initialData: color.value,
      stream: color.stream,
      builder: (context, snapshot) {
        final theme = AppThemes.inst.getAppTheme(snapshot.data, null, true);
        return AnimatedTheme(
          data: theme,
          child: CustomBlurryDialog(
            theme: theme,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 86.0),
            normalTitleStyle: true,
            title: lang.TRACK_INFO,
            trailingWidgets: [
              Obx(
                () => NamidaIconButton(
                  tooltip: lang.SHOW_HIDE_UNKNOWN_FIELDS,
                  icon: settings.showUnknownFieldsInTrackInfoDialog.value ? Broken.eye : Broken.eye_slash,
                  iconColor: theme.colorScheme.primary,
                  onPressed: () => settings.save(showUnknownFieldsInTrackInfoDialog: !settings.showUnknownFieldsInTrackInfoDialog.value),
                ),
              ),
              NamidaLikeButton(
                track: track,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              NamidaIconButton(
                tooltip: lang.PREVIEW,
                icon: Broken.play,
                iconColor: theme.colorScheme.primary,
                onPressed: showPreviewTrackDialog,
              ),
            ],
            icon: Broken.info_circle,
            child: SizedBox(
              height: Get.height * 0.7,
              width: Get.width,
              child: Obx(
                () {
                  settings.showUnknownFieldsInTrackInfoDialog.value;
                  return CustomScrollView(
                    slivers: [
                      SliverList(
                        delegate: SliverChildListDelegate(
                          [
                            const SizedBox(height: 12.0),
                            NamidaInkWell(
                              onTap: () => showTrackListensDialog(track, datesOfListen: totalListens, colorScheme: color.value),
                              borderRadius: 12.0,
                              child: Row(
                                children: [
                                  const SizedBox(width: 2.0),
                                  TapDetector(
                                    onTap: () => NamidaNavigator.inst.navigateDialog(
                                      scale: 1.0,
                                      blackBg: true,
                                      dialog: LongPressDetector(
                                        onLongPress: () async {
                                          final saveDirPath = await EditDeleteController.inst.saveArtworkToStorage(track);
                                          String title = lang.COPIED_ARTWORK;
                                          String subtitle = '${lang.SAVED_IN} $saveDirPath';
                                          Color snackColor = color.value;

                                          if (saveDirPath == null) {
                                            title = lang.ERROR;
                                            subtitle = lang.COULDNT_SAVE_IMAGE;
                                            snackColor = Colors.red;
                                          }
                                          snackyy(
                                            title: title,
                                            message: subtitle,
                                            leftBarIndicatorColor: snackColor,
                                            margin: EdgeInsets.zero,
                                            top: false,
                                            borderRadius: 0,
                                          );
                                        },
                                        child: PhotoView(
                                          heroAttributes: PhotoViewHeroAttributes(tag: '$comingFromQueue${index}_sussydialogs_${trackExt.path}$additionalHero'),
                                          gaplessPlayback: true,
                                          tightMode: true,
                                          minScale: PhotoViewComputedScale.contained,
                                          loadingBuilder: (context, event) => artwork,
                                          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                                          filterQuality: FilterQuality.high,
                                          imageProvider: FileImage(File(trackExt.pathToImage)),
                                        ),
                                      ),
                                    ),
                                    child: artwork,
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
                                                  '${lang.TOTAL_LISTENS}: ',
                                                  style: theme.textTheme.displaySmall,
                                                ),
                                                Text(
                                                  '${totalListens.length}',
                                                  style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
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
                                                firstListenTrack?.dateAndClockFormattedOriginal ?? lang.MAKE_YOUR_FIRST_LISTEN,
                                                style: theme.textTheme.displaySmall,
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
                                title: lang.TITLE,
                                value: trackExt.title,
                                icon: Broken.text,
                              ),

                            if (shouldShowTheField(trackExt.hasUnknownArtist))
                              TrackInfoListTile(
                                title: Indexer.splitArtist(
                                          title: trackExt.title,
                                          originalArtist: trackExt.originalArtist,
                                          config: ArtistsSplitConfig.settings(addFeatArtist: false),
                                        ).length ==
                                        1
                                    ? lang.ARTIST
                                    : lang.ARTISTS,
                                value: trackExt.hasUnknownArtist ? UnknownTags.ARTIST : trackExt.originalArtist,
                                icon: Broken.microphone,
                              ),

                            if (shouldShowTheField(trackExt.hasUnknownAlbum))
                              TrackInfoListTile(
                                title: lang.ALBUM,
                                value: trackExt.hasUnknownAlbum ? UnknownTags.ALBUM : trackExt.album,
                                icon: Broken.music_dashboard,
                              ),

                            if (shouldShowTheField(trackExt.hasUnknownAlbumArtist))
                              TrackInfoListTile(
                                title: lang.ALBUM_ARTIST,
                                value: trackExt.hasUnknownAlbumArtist ? UnknownTags.ALBUMARTIST : trackExt.albumArtist,
                                icon: Broken.user,
                              ),

                            if (shouldShowTheField(trackExt.hasUnknownGenre))
                              TrackInfoListTile(
                                title: trackExt.genresList.length == 1 ? lang.GENRE : lang.GENRES,
                                value: trackExt.hasUnknownGenre ? UnknownTags.GENRE : trackExt.genresList.join(', '),
                                icon: trackExt.genresList.length == 1 ? Broken.emoji_happy : Broken.smileys,
                              ),

                            if (shouldShowTheField(trackExt.hasUnknownMood))
                              TrackInfoListTile(
                                title: trackExt.moodList.length == 1 ? lang.MOOD : lang.MOODS,
                                value: trackExt.hasUnknownMood ? UnknownTags.MOOD : trackExt.moodList.join(', '),
                                icon: Broken.happyemoji,
                              ),

                            if (shouldShowTheField(trackExt.hasUnknownComposer))
                              TrackInfoListTile(
                                title: lang.COMPOSER,
                                value: trackExt.hasUnknownComposer ? UnknownTags.COMPOSER : trackExt.composer,
                                icon: Broken.profile_2user,
                              ),

                            if (shouldShowTheField(trackExt.duration == 0))
                              TrackInfoListTile(
                                title: lang.DURATION,
                                value: trackExt.duration.secondsLabel,
                                icon: Broken.clock,
                              ),

                            if (shouldShowTheField(trackExt.year == 0))
                              TrackInfoListTile(
                                title: lang.YEAR,
                                value: trackExt.year == 0 ? '?' : '${trackExt.year} (${trackExt.year.yearFormatted}${releasedFromNow == '' ? '' : ' | $releasedFromNow'})',
                                icon: Broken.calendar,
                              ),

                            if (shouldShowTheField(trackExt.dateModified == 0))
                              TrackInfoListTile(
                                title: lang.DATE_MODIFIED,
                                value: trackExt.dateModified.dateAndClockFormattedOriginal,
                                icon: Broken.calendar_1,
                              ),

                            ///
                            if (shouldShowTheField(trackExt.discNo == 0))
                              TrackInfoListTile(
                                title: lang.DISC_NUMBER,
                                value: trackExt.discNo.toString(),
                                icon: Broken.hashtag,
                              ),

                            if (shouldShowTheField(trackExt.trackNo == 0))
                              TrackInfoListTile(
                                title: lang.TRACK_NUMBER,
                                value: trackExt.trackNo.toString(),
                                icon: Broken.hashtag,
                              ),

                            /// bruh moment
                            if (shouldShowTheField(trackExt.filenameWOExt == ''))
                              TrackInfoListTile(
                                title: lang.FILE_NAME,
                                value: trackExt.filenameWOExt,
                                icon: Broken.quote_up_circle,
                              ),

                            if (shouldShowTheField(trackExt.folderName == ''))
                              TrackInfoListTile(
                                title: lang.FOLDER,
                                value: trackExt.folderName,
                                icon: Broken.folder,
                              ),

                            if (shouldShowTheField(trackExt.path == ''))
                              TrackInfoListTile(
                                title: lang.PATH,
                                value: trackExt.path,
                                icon: Broken.location,
                              ),

                            TrackInfoListTile(
                              title: lang.FORMAT,
                              value: '${track.audioInfoFormattedCompact}\n${trackExt.extension} - ${trackExt.size.fileSizeFormatted}',
                              icon: Broken.voice_cricle,
                            ),

                            if (shouldShowTheField(trackExt.lyrics == ''))
                              TrackInfoListTile(
                                title: lang.LYRICS,
                                value: trackExt.lyrics,
                                icon: trackExt.lyrics.isEmpty ? Broken.note_remove : Broken.message_text,
                              ),

                            if (shouldShowTheField(trackExt.comment == ''))
                              TrackInfoListTile(
                                title: lang.COMMENT,
                                value: trackExt.comment,
                                icon: Broken.message_text_1,
                                isComment: true,
                              ),
                            const SizedBox(height: 12.0),
                          ].addSeparators(separator: NamidaContainerDivider(color: color.value), skipFirst: 3).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}

class TrackInfoListTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isComment;
  final Widget? child;

  const TrackInfoListTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.isComment = false,
    this.child,
  });

  void _copyField(BuildContext context) {
    if (value == '') return;

    Clipboard.setData(ClipboardData(text: value));
    snackyy(
      title: 'Copied $title',
      message: value,
      leftBarIndicatorColor: context.theme.colorScheme.primary,
      margin: EdgeInsets.zero,
      borderRadius: 0,
      top: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: NamidaInkWell(
        borderRadius: 16.0,
        onTap: () => _copyField(context),
        onLongPress: () => _copyField(context),
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
            child ??
                (isComment
                    ? NamidaSelectableAutoLinkText(text: value == '' ? '?' : value)
                    : Text(
                        value == '' ? '?' : value,
                        style: context.theme.textTheme.displayMedium?.copyWith(
                          color: Color.alphaBlend(context.theme.colorScheme.primary.withAlpha(140), context.textTheme.displayMedium!.color!),
                          fontSize: 13.5.multipliedFontScale,
                        ),
                      )),
          ],
        ),
      ),
    );
  }
}
