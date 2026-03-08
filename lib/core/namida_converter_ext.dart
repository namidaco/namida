import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';
import 'package:path/path.dart' as p;
import 'package:playlist_manager/playlist_manager.dart';
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/core/extensions.dart';
import 'package:youtipie/core/url_utils.dart';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/class/count_per_row.dart';
import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/media_info.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/queue_insertion.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/version_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/dialogs/general_popup_dialog.dart';
import 'package:namida/ui/dialogs/track_advanced_dialog.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';
import 'package:namida/ui/dialogs/track_listens_dialog.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/pages/artists_page.dart';
import 'package:namida/ui/pages/folders_page.dart';
import 'package:namida/ui/pages/genres_page.dart';
import 'package:namida/ui/pages/home_page.dart';
import 'package:namida/ui/pages/playlists_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/pages/tracks_page.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/network_artwork.dart';
import 'package:namida/ui/widgets/settings_search_bar.dart';
import 'package:namida/youtube/class/sponsorblock.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart' as ytplc;
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/functions/video_listens_dialog.dart';
import 'package:namida/youtube/pages/youtube_home_view.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';
import 'package:namida/youtube/widgets/video_info_dialog.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

extension MediaTypeUtils on MediaType {
  LibraryTab toLibraryTab() {
    return switch (this) {
      MediaType.track => LibraryTab.tracks,
      MediaType.album => LibraryTab.albums,
      MediaType.artist || MediaType.albumArtist || MediaType.composer => LibraryTab.artists,
      MediaType.genre => LibraryTab.genres,
      MediaType.folder => LibraryTab.folders,
      MediaType.folderMusic => LibraryTab.foldersMusic,
      MediaType.folderVideo => LibraryTab.foldersVideos,
      MediaType.playlist => LibraryTab.playlists,
    };
  }
}

extension LibraryTabUtils on LibraryTab {
  MediaType? toMediaType() {
    return switch (this) {
      LibraryTab.tracks => MediaType.track,
      LibraryTab.albums => MediaType.album,
      LibraryTab.artists => MediaType.artist,
      LibraryTab.genres => MediaType.genre,
      LibraryTab.playlists => MediaType.playlist,
      LibraryTab.folders => MediaType.folder,
      LibraryTab.foldersMusic => MediaType.folderMusic,
      LibraryTab.foldersVideos => MediaType.folderVideo,
      LibraryTab.home => null,
      LibraryTab.search => null,
      LibraryTab.youtube => null,
    };
  }

  int toInt() => settings.libraryTabs.value.indexOf(this);

  NamidaRouteWidget toWidget([CountPerRow? gridCount, bool animateTiles = true, bool enableHero = true]) {
    gridCount ??= settings.mediaGridCounts.value.get(this);
    return switch (this) {
      LibraryTab.tracks => TracksPage(animateTiles: animateTiles),
      LibraryTab.albums => AlbumsPage(
        countPerRow: gridCount,
        animateTiles: animateTiles,
        enableHero: enableHero,
      ),
      LibraryTab.artists => ArtistsPage(
        countPerRow: gridCount,
        animateTiles: animateTiles,
        enableHero: enableHero,
      ),
      LibraryTab.genres => GenresPage(
        countPerRow: gridCount,
        animateTiles: animateTiles,
        enableHero: enableHero,
      ),
      LibraryTab.playlists => PlaylistsPage(
        countPerRow: gridCount,
        animateTiles: animateTiles,
        enableHero: enableHero,
      ),
      LibraryTab.folders => FoldersPage.tracksAndVideos(),
      LibraryTab.foldersMusic => FoldersPage.tracks(),
      LibraryTab.foldersVideos => FoldersPage.videos(),
      LibraryTab.home => HomePage.tracks(),
      LibraryTab.youtube => const YouTubeHomeView(),
      LibraryTab.search => const NamidaDummyPage(),
    };
  }
}

extension YTVideoQuality on String {
  String settingLabeltoVideoLabel() {
    final val = split('p').first;
    return const <String, String>{
          '144': '144',
          '240': '240',
          '360': '360',
          '480': '480',
          '720': '720',
          '1080': '1080',
          '2k': '1440',
          '4k': '2160',
          '8k': '4320',
        }[val] ??
        '144';
  }

  String videoLabelToSettingLabel() {
    final val = split('p').first;
    return const <String, String>{
          '144': '144p',
          '240': '240p',
          '360': '360p',
          '480': '480p',
          '720': '720p',
          '1080': '1080p',
          '1440': '2k',
          '2160': '4k',
          '4320': '8k',
        }[val] ??
        '144';
  }
}

extension CacheGetterAudio on AudioStream {
  String cacheKey(String id) {
    final audio = this;
    // -- wont save english track, only saves non-english ones.
    String languageText = '';

    final audioTrack = audio.audioTrack;
    if (audioTrack != null) {
      final langCode = audioTrack.langCode?.toLowerCase();
      final langName = audioTrack.displayName?.toLowerCase();

      if (langCode == 'en' && audioTrack.isDefault == true) {
        // -- is original english
        // -- isDefault check is required cuz there can be more than 1 english audio
      } else {
        languageText = '_${langCode}_$langName';
      }
    }

    return "$id${languageText}_${audio.bitrate}.${audio.codecInfo.container}";
  }

  String cachePath(String id) {
    return p.join(AppDirs.AUDIOS_CACHE, cacheKey(id));
  }

  File? getCachedFileSync(String? id) {
    if (id == null) return null;
    final path = cachePath(id);
    return File(path).existsSync() ? File(path) : null;
  }

  Future<File?> getCachedFile(String? id) async {
    if (id == null) return null;
    final path = cachePath(id);
    return await File(path).exists() ? File(path) : null;
  }
}

extension CacheGetterVideo on VideoStream {
  String cacheKey(String id) {
    final video = this;
    var codecIdentifier = codecInfo.codecIdentifierIfCustom();
    var suffix = codecIdentifier != null ? '-$codecIdentifier' : '';
    return "${id}_${video.qualityLabel}$suffix.${video.codecInfo.container}";
  }

  String cachePath(String id) {
    return p.join(AppDirs.VIDEOS_CACHE, cacheKey(id));
  }

  String cachePathTemp(String id) {
    return p.join(AppDirs.VIDEOS_CACHE_TEMP, cacheKey(id));
  }

  File? getCachedFileSync(String? id) {
    if (id == null) return null;
    final path = cachePath(id);
    return File(path).existsSync() ? File(path) : null;
  }

  Future<File?> getCachedFile(String? id) async {
    if (id == null) return null;
    final path = cachePath(id);
    return await File(path).exists() ? File(path) : null;
  }
}

extension FAudioModelExtensions on FAudioModel {
  FAudioModel merge(FAudioModel? original) {
    if (original == null) return this;
    return FAudioModel(
      tags: FTags(
        path: original.tags.path.isNotEmpty ? original.tags.path : this.tags.path,
        artwork: original.tags.artwork.hasArtwork ? original.tags.artwork : this.tags.artwork,
        title: original.tags.title ?? this.tags.title,
        album: original.tags.album ?? this.tags.album,
        albumArtist: original.tags.albumArtist ?? this.tags.albumArtist,
        artist: original.tags.artist ?? this.tags.artist,
        composer: original.tags.composer ?? this.tags.composer,
        genre: original.tags.genre ?? this.tags.genre,
        trackNumber: original.tags.trackNumber ?? this.tags.trackNumber,
        trackTotal: original.tags.trackTotal ?? this.tags.trackTotal,
        discNumber: original.tags.discNumber ?? this.tags.discNumber,
        discTotal: original.tags.discTotal ?? this.tags.discTotal,
        lyrics: original.tags.lyrics ?? this.tags.lyrics,
        comment: original.tags.comment ?? this.tags.comment,
        description: original.tags.description ?? this.tags.description,
        synopsis: original.tags.synopsis ?? this.tags.synopsis,
        year: original.tags.year ?? this.tags.year,
        language: original.tags.language ?? this.tags.language,
        lyricist: original.tags.lyricist ?? this.tags.lyricist,
        djmixer: original.tags.djmixer ?? this.tags.djmixer,
        mixer: original.tags.mixer ?? this.tags.mixer,
        mood: original.tags.mood ?? this.tags.mood,
        rating: original.tags.rating ?? this.tags.rating,
        remixer: original.tags.remixer ?? this.tags.remixer,
        tags: original.tags.tags ?? this.tags.tags,
        tempo: original.tags.tempo ?? this.tags.tempo,
        country: original.tags.country ?? this.tags.country,
        recordLabel: original.tags.recordLabel ?? this.tags.recordLabel,
        ratingPercentage: original.tags.ratingPercentage ?? this.tags.ratingPercentage,
        gainData: original.tags.gainData ?? this.tags.gainData,
        sortInfo: original.tags.sortInfo ?? this.tags.sortInfo,
      ),
      durationMS: original.durationMS ?? this.durationMS,
      bitRate: original.bitRate ?? this.bitRate,
      channels: original.channels ?? this.channels,
      encodingType: original.encodingType ?? this.encodingType,
      format: original.format ?? this.format,
      sampleRate: original.sampleRate ?? this.sampleRate,
      bits: original.bits ?? this.bits,
      isVariableBitRate: original.isVariableBitRate ?? this.isVariableBitRate,
      isLossless: original.isLossless ?? this.isLossless,
      hasError: this.hasError,
      errorsMap: this.errorsMap,
    );
  }
}

extension MediaInfoToFAudioModel on MediaInfo {
  FAudioModel toFAudioModel({required FArtwork? artwork}) {
    final infoFull = this;
    final info = infoFull.format?.tags;
    final trackNumberTotal = info?.track?.split('/');
    final discNumberTotal = info?.disc?.split('/');
    final audioStream = infoFull.getAudioStream();
    int? parsy(String? v) => v == null ? null : int.tryParse(v);
    final bitrate = parsy(infoFull.format?.bitRate); // 234292
    final bitrateThousands = bitrate == null ? null : bitrate / 1000; // 234
    String? format = audioStream?.codecName ?? infoFull.format?.formatName;
    if (format != null && format.isNotEmpty) format = format.replaceFirst(RegExp('flac', caseSensitive: false), 'FLAC');
    return FAudioModel(
      tags: FTags(
        path: infoFull.path,
        artwork: artwork ?? FArtwork(),
        title: info?.title ?? audioStream?.tags?.title,
        album: info?.album ?? audioStream?.tags?.album,
        albumArtist: info?.albumArtist ?? audioStream?.tags?.albumArtist,
        artist: info?.artist ?? audioStream?.tags?.artist,
        composer: info?.composer,
        genre: info?.genre,
        trackNumber: trackNumberTotal?.first ?? info?.track ?? audioStream?.tags?.track,
        trackTotal: info?.trackTotal ?? (trackNumberTotal?.length == 2 ? trackNumberTotal?.last : null),
        discNumber: discNumberTotal?.first ?? info?.disc,
        discTotal: info?.discTotal ?? (discNumberTotal?.length == 2 ? discNumberTotal?.last : null),
        lyrics: info?.lyrics,
        comment: info?.comment,
        description: info?.description,
        synopsis: info?.synopsis,
        year: info?.date,
        language: info?.language,
        lyricist: info?.lyricist,
        remixer: info?.remixer,
        mood: info?.mood,
        country: info?.country,
        recordLabel: info?.label,
        gainData: info?.gainData,
        sortInfo: info?.sortInfo,
      ),
      durationMS: infoFull.format?.duration?.inMilliseconds,
      bitRate: bitrateThousands?.round(),
      channels: audioStream?.channels == null
          ? null
          : switch (audioStream?.channels) {
              0 => null,
              1 => 'mono',
              2 => 'stereo',
              _ => null,
            },
      format: format,
      sampleRate: parsy(audioStream?.sampleRate),
      bits: audioStream?.bitsPerSample,
      isLossless: infoFull.isLossless(),
    );
  }
}

extension QueueNameGetter on Queue {
  String toText() =>
      homePageItem?.toText() ??
      switch (source) {
        final QueueSource s => s.toText(),
        final QueueSourceYoutubeID s => s.toText(),
      };
}

// extension QUEUESOURCEtoTRACKS on QueueSource {

//   List<Selectable> toTracksObso([int? limit, int? dayOfHistory]) {
//     final trs = <Selectable>[];
//     void addThese(Iterable<Selectable> tracks) => trs.addAll(tracks.withLimit(limit));
//     switch (this) {
//       case QueueSource.allTracks:
//         addThese(SearchSortController.inst.trackSearchList.value);
//         break;
//       case QueueSource.search:
//         addThese(SearchSortController.inst.trackSearchTemp.value);
//         break;
//       case QueueSource.mostPlayed:
//         addThese(HistoryController.inst.currentMostPlayedTracks);
//         break;
//       case QueueSource.history:
//         dayOfHistory != null ? addThese(HistoryController.inst.historyMap.value[dayOfHistory] ?? []) : addThese(HistoryController.inst.historyTracks);
//         break;
//       case QueueSource.favourites:
//         addThese(PlaylistController.inst.favouritesPlaylist.value.tracks);
//         break;
//       case QueueSource.queuePage:
//         addThese(SelectedTracksController.inst.getCurrentAllTracks());
//         break;
//       case QueueSource.selectedTracks:
//         addThese(SelectedTracksController.inst.selectedTracks.value);
//         break;
//       case QueueSource.playerQueue:
//         addThese(Player.inst.currentQueue.value.whereType<Selectable>());
//         break;
//       case QueueSource.recentlyAdded:
//         addThese(Indexer.inst.recentlyAddedTracksSorted());
//         break;
//       default:
//         addThese(SelectedTracksController.inst.getCurrentAllTracks());
//     }

//     return trs;
//   }
// }

extension PlaylistToQueueSource on LocalPlaylist {
  QueueSource toQueueSource() {
    // if (name == k_PLAYLIST_NAME_MOST_PLAYED) {
    //   return QueueSource.mostPlayed;
    // }
    // if (name == k_PLAYLIST_NAME_HISTORY) {
    //   return QueueSource.history;
    // }
    if (name == k_PLAYLIST_NAME_FAV) {
      return QueueSource.favourites;
    }
    return QueueSource.playlist;
  }
}

extension FFMPEGTagFieldUtilsC on FFMPEGTagField {
  String ffmpegTagToText() => switch (this) {
    FFMPEGTagField.title => lang.title,
    FFMPEGTagField.album => lang.album,
    FFMPEGTagField.artist => lang.artist,
    FFMPEGTagField.albumArtist => lang.albumArtist,
    FFMPEGTagField.genre => lang.genre,
    FFMPEGTagField.mood => lang.mood,
    FFMPEGTagField.composer => lang.composer,
    FFMPEGTagField.comment => lang.comment,
    FFMPEGTagField.description => lang.description,
    FFMPEGTagField.synopsis => lang.synopsis,
    FFMPEGTagField.lyrics => lang.lyrics,
    FFMPEGTagField.trackNumber => lang.trackNumber,
    FFMPEGTagField.discNumber => lang.discNumber,
    FFMPEGTagField.trackTotal => lang.trackNumberTotal,
    FFMPEGTagField.discTotal => lang.discNumberTotal,
    FFMPEGTagField.year => lang.year,
    FFMPEGTagField.remixer => lang.remixer,
    FFMPEGTagField.lyricist => lang.lyricist,
    FFMPEGTagField.language => lang.language,
    FFMPEGTagField.recordLabel => lang.recordLabel,
    FFMPEGTagField.country => lang.country,
    FFMPEGTagField.rating => lang.rating,
    FFMPEGTagField.tags => lang.tags,
    FFMPEGTagField.titleSort => '${lang.title} (${lang.sortBy})',
    FFMPEGTagField.albumSort => '${lang.album} (${lang.sortBy})',
    FFMPEGTagField.albumArtistSort => '${lang.albumArtist} (${lang.sortBy})',
    FFMPEGTagField.artistSort => '${lang.artist} (${lang.sortBy})',
    FFMPEGTagField.composerSort => '${lang.composer} (${lang.sortBy})',
  };

  IconData ffmpegTagToIcon() => switch (this) {
    FFMPEGTagField.title => Broken.music,
    FFMPEGTagField.album => Broken.music_dashboard,
    FFMPEGTagField.artist => Broken.microphone,
    FFMPEGTagField.albumArtist => Broken.user,
    FFMPEGTagField.genre => Broken.smileys,
    FFMPEGTagField.mood => Broken.happyemoji,
    FFMPEGTagField.composer => Broken.profile_2user,
    FFMPEGTagField.comment => Broken.text_block,
    FFMPEGTagField.description => Broken.note_text,
    FFMPEGTagField.synopsis => Broken.text,
    FFMPEGTagField.lyrics => Broken.message_text,
    FFMPEGTagField.trackNumber => Broken.hashtag,
    FFMPEGTagField.discNumber => Broken.hashtag,
    FFMPEGTagField.trackTotal => Broken.hashtag,
    FFMPEGTagField.discTotal => Broken.hashtag,
    FFMPEGTagField.year => Broken.calendar,
    FFMPEGTagField.remixer => Broken.radio,
    FFMPEGTagField.lyricist => Broken.pen_add,
    FFMPEGTagField.language => Broken.language_circle,
    FFMPEGTagField.recordLabel => Broken.ticket,
    FFMPEGTagField.country => Broken.house,
    FFMPEGTagField.rating => Broken.grammerly,
    FFMPEGTagField.tags => Broken.ticket_discount,
    FFMPEGTagField.titleSort => Broken.music,
    FFMPEGTagField.albumSort => Broken.music_dashboard,
    FFMPEGTagField.albumArtistSort => Broken.user,
    FFMPEGTagField.artistSort => Broken.microphone,
    FFMPEGTagField.composerSort => Broken.profile_2user,
  };
}

extension PlayerRepeatModeUtils on PlayerRepeatMode {
  String buildText() => switch (this) {
    PlayerRepeatMode.none => lang.repeatModeNone,
    PlayerRepeatMode.one => lang.repeatModeOne,
    PlayerRepeatMode.all => lang.repeatModeAll,
    PlayerRepeatMode.allShuffle => lang.shuffleAll,
    PlayerRepeatMode.forNtimes => lang.repeatForNTimes(number: Player.inst.numberOfRepeats.value),
  };
}

extension DataSaverModeUtils on DataSaverMode {
  String toText() => switch (this) {
    DataSaverMode.off => lang.disable,
    DataSaverMode.medium => lang.medium,
    DataSaverMode.extreme => lang.extreme,
  };
}

extension TrackExecuteActionsUtils on TrackExecuteActions {
  String toText() => switch (this) {
    TrackExecuteActions.none => lang.none,
    TrackExecuteActions.playnext => lang.playNext,
    TrackExecuteActions.playlast => lang.playLast,
    TrackExecuteActions.playafter => lang.playAfter,
    TrackExecuteActions.addtoplaylist => lang.addToPlaylist,
    TrackExecuteActions.openinfo => lang.info,
    TrackExecuteActions.openArtwork => "${lang.artwork} (${lang.open})",
    TrackExecuteActions.editArtwork => lang.editArtwork,
    TrackExecuteActions.saveArtwork => "${lang.artwork} (${lang.save})",
    TrackExecuteActions.editTags => lang.editTags,
    TrackExecuteActions.setRating => lang.setRating,
    TrackExecuteActions.openListens => lang.totalListens,
    TrackExecuteActions.goToAlbum => lang.goToAlbum,
    TrackExecuteActions.goToArtist => lang.goToArtist,
    TrackExecuteActions.goToFolder => lang.goToFolder,
    TrackExecuteActions.copyTitle => "${lang.copy} (${lang.title})",
    TrackExecuteActions.copyArtist => "${lang.copy} (${lang.artist})",
    TrackExecuteActions.copyArtistAndTitle => "${lang.copy} (${lang.artist} + ${lang.title})",
    TrackExecuteActions.copyYTLink => "${lang.copy} (${lang.link})",
    TrackExecuteActions.searchYTSimilar => lang.searchYoutube,
    TrackExecuteActions.delete => lang.delete,
  };

  IconData toIcon() {
    return switch (this) {
      TrackExecuteActions.none => Broken.cd,
      TrackExecuteActions.playnext => Broken.next,
      TrackExecuteActions.playlast => Broken.play_cricle,
      TrackExecuteActions.playafter => Broken.hierarchy_square,
      TrackExecuteActions.addtoplaylist => Broken.music_library_2,
      TrackExecuteActions.openinfo => Broken.info_circle,
      TrackExecuteActions.openArtwork => Broken.gallery,
      TrackExecuteActions.editArtwork => Broken.gallery_edit,
      TrackExecuteActions.saveArtwork => Broken.gallery_import,
      TrackExecuteActions.editTags => Broken.edit,
      TrackExecuteActions.setRating => Broken.grammerly,
      TrackExecuteActions.openListens => Broken.math,
      TrackExecuteActions.goToAlbum => Broken.music_dashboard,
      TrackExecuteActions.goToArtist => Broken.profile_2user,
      TrackExecuteActions.goToFolder => Broken.folder,
      TrackExecuteActions.copyTitle => Broken.copy,
      TrackExecuteActions.copyArtist => Broken.copy,
      TrackExecuteActions.copyArtistAndTitle => Broken.copy,
      TrackExecuteActions.copyYTLink => Broken.copy,
      TrackExecuteActions.searchYTSimilar => Broken.search_normal_1,
      TrackExecuteActions.delete => Broken.danger,
    };
  }

  void executePlayingItem(Playable currentItem) {
    final queueSource =
        currentItem.execute(
              selectable: (_) => QueueSource.playerQueue,
              youtubeID: (_) => QueueSourceYoutubeID.playerQueue,
            )
            as QueueSourceBase;
    this.execute(
      currentItem,
      info: SwipeQueueAddTileInfo(
        queueSource: queueSource,
        heroTag: null,
      ),
    );
  }

  void execute(Playable item, {required SwipeQueueAddTileInfo info}) async {
    switch (this) {
      case TrackExecuteActions.none:
        return;
      case TrackExecuteActions.playnext:
        Player.inst.addToQueue([item], insertNext: true);
      case TrackExecuteActions.playlast:
        Player.inst.addToQueue([item], insertNext: false);
      case TrackExecuteActions.playafter:
        Player.inst.addToQueue([item], insertAfterLatest: true);
      case TrackExecuteActions.addtoplaylist:
        item.execute(
          selectable: (finalItem) {
            showAddToPlaylistDialog([finalItem.track]);
          },
          youtubeID: (finalItem) {
            showAddToPlaylistSheet(ids: [finalItem.id], idsNamesLookup: {finalItem.id: info.videoTitle});
          },
        );
      case TrackExecuteActions.openinfo:
        item.execute(
          selectable: (finalItem) {
            showTrackInfoDialog(
              finalItem.track,
              true,
              heroTag: info.heroTag,
            );
          },
          youtubeID: (finalItem) {
            NamidaNavigator.inst.navigateDialog(
              dialog: VideoInfoDialog(
                videoId: finalItem.id,
              ),
            );
          },
        );

      case TrackExecuteActions.openArtwork:
        item.execute(
          selectable: (finalItem) {
            final track = finalItem.track;
            final details = NamidaArtworkExpandableToFullscreen(
              artwork: const SizedBox(),
              heroTag: info.heroTag,
              imageFile: () => File(track.pathToImage),
              fetchImage: () => Indexer.inst.getArtwork(
                imagePath: track.pathToImage,
                track: track,
                compressed: false,
              ),
              onSave: (_, _) => EditDeleteController.inst.saveTrackArtworkToStorage(track),
              themeColor: null,
            );
            details.openInFullscreen();
          },
          youtubeID: (finalItem) {
            final videoId = finalItem.id;
            final details = NamidaArtworkExpandableToFullscreen(
              artwork: const SizedBox(),
              heroTag: null,
              imageFile: () => ThumbnailManager.inst.getYoutubeThumbnailFromCache(
                id: videoId,
                type: ThumbnailType.video,
                isTemp: null,
              ),
              fetchImage: () async => FArtwork(
                file: await ThumbnailManager.inst.getYoutubeThumbnailAndCache(
                  id: videoId,
                  type: ThumbnailType.video,
                ),
              ),
              onSave: (_, _) => YTUtils.copyThumbnailToStorage(videoId),
              themeColor: null,
            );
            details.openInFullscreen();
          },
        );

      case TrackExecuteActions.saveArtwork:
        item.execute(
          selectable: (finalItem) async {
            final saveDirPath = await EditDeleteController.inst.saveTrackArtworkToStorage(finalItem.track);
            NamidaOnTaps.inst.showSavedImageInSnack(saveDirPath, null);
          },
          youtubeID: (finalItem) async {
            final saveDirPath = await YTUtils.copyThumbnailToStorage(finalItem.id);
            NamidaOnTaps.inst.showSavedImageInSnack(saveDirPath, null);
          },
        );
      case TrackExecuteActions.editTags:
        item.execute(
          selectable: (finalItem) {
            final tr = finalItem.track.asPhysicalOrError();
            if (tr == null) return;
            showEditTracksTagsDialog([tr], null);
          },
          youtubeID: (finalItem) {},
        );
      case TrackExecuteActions.editArtwork:
        item.execute(
          selectable: (finalItem) {
            final tr = finalItem.track.asPhysicalOrError();
            if (tr == null) return;
            showEditTracksTagsDialog([tr], null, instantEditArtwork: true);
          },
          youtubeID: (finalItem) {},
        );

      case TrackExecuteActions.setRating:
        item.execute(
          selectable: (finalItem) {
            showSetTrackStatsDialog(
              firstTrack: finalItem.track,
              stats: TrackStats.buildEffective(finalItem.track),
            );
          },
          youtubeID: (finalItem) {},
        );
      case TrackExecuteActions.openListens:
        item.execute(
          selectable: (finalItem) {
            showTrackListensDialog(finalItem.track);
          },
          youtubeID: (finalItem) {
            showVideoListensDialog(finalItem.id);
          },
        );

      case TrackExecuteActions.goToAlbum:
        item.execute(
          selectable: (finalItem) {
            NamidaOnTaps.inst.onAlbumTap(finalItem.track.albumIdentifier);
          },
          youtubeID: (finalItem) {},
        );

      case TrackExecuteActions.goToArtist:
        item.execute(
          selectable: (finalItem) {
            final artist = finalItem.track.artistsList.firstOrNull;
            if (artist != null) {
              NamidaOnTaps.inst.onArtistTap(artist, MediaType.artist);
            }
          },
          youtubeID: (finalItem) async {
            final channelId = await YoutubeInfoController.utils.getVideoChannelID(finalItem.id);
            if (channelId != null) {
              YTChannelSubpage(channelID: channelId).navigate();
            }
          },
        );

      case TrackExecuteActions.goToFolder:
        item.execute(
          selectable: (finalItem) {
            final track = finalItem.track;
            final folder = track.folder;
            NamidaOnTaps.inst.onFolderTapNavigate(folder, null, trackToScrollTo: track);
          },
          youtubeID: (finalItem) {},
        );

      case TrackExecuteActions.copyTitle:
        item.execute(
          selectable: (finalItem) {
            final title = finalItem.track.title;
            info.copyToClipboard(title);
          },
          youtubeID: (finalItem) async {
            final title = await YoutubeInfoController.utils.getVideoName(finalItem.id);
            if (title != null) {
              info.copyToClipboard(title);
            }
          },
        );
      case TrackExecuteActions.copyArtist:
        item.execute(
          selectable: (finalItem) {
            final artist = finalItem.track.originalArtist;
            info.copyToClipboard(artist);
          },
          youtubeID: (finalItem) async {
            final artist = await YoutubeInfoController.utils.getVideoChannelName(finalItem.id);
            if (artist != null) {
              info.copyToClipboard(artist);
            }
          },
        );
      case TrackExecuteActions.copyArtistAndTitle:
        item.execute(
          selectable: (finalItem) {
            final title = finalItem.track.title;
            final artist = finalItem.track.originalArtist;
            info.copyToClipboard("$artist - $title");
          },
          youtubeID: (finalItem) async {
            final title = await YoutubeInfoController.utils.getVideoName(finalItem.id);
            final artist = await YoutubeInfoController.utils.getVideoChannelName(finalItem.id);
            if (title?.isNotEmpty == true || artist?.isNotEmpty == true) {
              info.copyToClipboard("${artist ?? ''} - ${title ?? ''}");
            }
          },
        );
      case TrackExecuteActions.copyYTLink:
        item.execute(
          selectable: (finalItem) {
            final link = finalItem.track.youtubeLink;
            if (link.isNotEmpty) {
              info.copyToClipboard(link);
            } else {
              snackyy(title: lang.error, message: lang.couldntOpenYtLink, top: false);
            }
          },
          youtubeID: (finalItem) async {
            final videoLink = YTUrlUtils.buildVideoUrl(finalItem.id);
            info.copyToClipboard(videoLink);
          },
        );
      case TrackExecuteActions.searchYTSimilar:
        final text = await item.execute<FutureOr<String>>(
          selectable: (finalItem) {
            final title = finalItem.track.title;
            final artist = finalItem.track.originalArtist;
            return "$artist - $title";
          },
          youtubeID: (finalItem) async {
            final title = await YoutubeInfoController.utils.getVideoName(finalItem.id);
            final artist = await YoutubeInfoController.utils.getVideoChannelName(finalItem.id);
            if (title?.isNotEmpty == true || artist?.isNotEmpty == true) {
              return "${artist ?? ''} - ${title ?? ''}";
            }
            return '';
          },
        );
        if (text != null && text.isNotEmpty) {
          MiniPlayerController.inst.snapToMini();
          MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(false); // -- useless really
          // -- all these steps are important..
          final searchController = ScrollSearchController.inst;
          searchController.currentSearchType.value = SearchType.youtube;
          searchController.searchTextEditingController.text = text;
          searchController.latestSubmittedYTSearch.value = text;
          SearchSortController.inst.lastSearchText = text;
          searchController.showSearchMenu();
          searchController.tabViewKey.currentState?.jumpToTab(SearchType.youtube.index);
          searchController.searchBarKey.currentState?.openCloseSearchBar(forceOpen: true);
          searchController.ytSearchKey.currentState?.fetchSearch(customText: text);
        }
      case TrackExecuteActions.delete:
        item.execute(
          selectable: (finalItem) {
            showTrackDeletePermanentlyDialog(
              [finalItem],
              null,
              afterConfirm: NamidaNavigator.inst.closeDialog,
            );
          },
          youtubeID: (finalItem) {},
        );
    }
    VibratorController.verylight();
  }
}

extension OnYoutubeLinkOpenActionUtils on OnYoutubeLinkOpenAction {
  Future<bool> execute(Iterable<String> ids, {ThemeData? theme}) async {
    Iterable<YoutubeID> getPlayables() => ids.map((e) => YoutubeID(id: e, playlistID: null));
    switch (this) {
      case OnYoutubeLinkOpenAction.showDownload:
        if (ids.length == 1) {
          showDownloadVideoBottomSheet(videoId: ids.first, originalIndex: null, totalLength: null, playlistId: null, streamInfoItem: null);
        } else {
          final ptitle = 'External - ${DateTime.now().millisecondsSinceEpoch.dateAndClockFormattedOriginal}';
          YTPlaylistDownloadPage(
            ids: ids.map((e) => YoutubeID(id: e, playlistID: null)).toList(),
            playlistName: ptitle,
            infoLookup: const {},
            playlistInfo: PlaylistBasicInfo(
              id: '',
              title: ptitle,
              videosCountText: ids.length.toString(),
              videosCount: ids.length,
              thumbnails: [],
            ),
          ).navigate();
        }
        return true;
      case OnYoutubeLinkOpenAction.addToPlaylist:
        showAddToPlaylistSheet(ids: ids, idsNamesLookup: {});
        return true;
      case OnYoutubeLinkOpenAction.play:
        await Player.inst.playOrPause(0, getPlayables(), QueueSourceYoutubeID.externalLink, gentlePlay: true);
        return true;
      case OnYoutubeLinkOpenAction.playNext:
        return Player.inst.addToQueue(getPlayables(), insertNext: true);
      case OnYoutubeLinkOpenAction.playLast:
        return Player.inst.addToQueue(getPlayables(), insertNext: false);
      case OnYoutubeLinkOpenAction.playAfter:
        return Player.inst.addToQueue(getPlayables(), insertAfterLatest: true);
      case OnYoutubeLinkOpenAction.alwaysAsk:
        final videoNamesSubtitle =
            await ids
                .take(3)
                .mapAsync((id) async => await YoutubeInfoController.utils.getVideoName(id) ?? id) //
                .join(', ') +
            (ids.length > 3 ? '... + ${ids.length - 3}' : '');
        _showAskDialog((action) => action.execute(ids), title: videoNamesSubtitle, theme: theme);
        return true;
    }
  }

  void _showAskDialog(void Function(OnYoutubeLinkOpenAction action) onTap, {String? title, ThemeData? theme}) async {
    final isItemEnabled = <OnYoutubeLinkOpenAction, bool>{
      OnYoutubeLinkOpenAction.playNext: true,
      OnYoutubeLinkOpenAction.playAfter: true,
      OnYoutubeLinkOpenAction.playLast: true,
    }.obs;

    final playAfterVid = await YTUtils.getPlayerAfterVideo();

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        isItemEnabled.close();
      },
      theme: theme,
      dialogBuilder: (theme) => CustomBlurryDialog(
        theme: theme,
        title: lang.choose,
        titleWidgetInPadding: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.choose,
              style: theme.textTheme.displayLarge,
            ),
            if (title != null && title.isNotEmpty)
              Text(
                title,
                style: theme.textTheme.displaySmall,
              ),
          ],
        ),
        normalTitleStyle: true,
        actions: const [
          DoneButton(),
        ],
        child: Column(
          children: [
            ...[
              OnYoutubeLinkOpenAction.showDownload,
              OnYoutubeLinkOpenAction.play,
              OnYoutubeLinkOpenAction.playNext,
              if (playAfterVid != null) OnYoutubeLinkOpenAction.playAfter,
              OnYoutubeLinkOpenAction.playLast,
              OnYoutubeLinkOpenAction.addToPlaylist,
            ].map(
              (e) {
                final isPlayAfter = e == OnYoutubeLinkOpenAction.playAfter && playAfterVid != null;
                final extraTitle = isPlayAfter ? ": ${playAfterVid.diff.displayVideoKeyword}" : "";
                String? subtitle = isPlayAfter ? playAfterVid.name : null;
                if (subtitle == '') subtitle = null;
                return Obx(
                  (context) => CustomListTile(
                    passedColor: theme.colorScheme.primaryContainer,
                    enabled: isItemEnabled[e] ?? true,
                    icon: e.toIcon(),
                    title: e.toText() + extraTitle,
                    subtitle: subtitle,
                    visualDensity: null,
                    onTap: () {
                      onTap(e);
                      if (isItemEnabled[e] != null) {
                        isItemEnabled[e] = false; // only disable existing item
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

extension PerformanceModeUtils on PerformanceMode {
  Future<void> executeAndSave() async {
    switch (this) {
      case PerformanceMode.highPerformance:
        settings.save(
          performanceMode: PerformanceMode.highPerformance,
          enableBlurEffect: false,
          enableGlowEffect: false,
          enableMiniplayerParallaxEffect: false,
          artworkCacheHeightMultiplier: 0.8,
          autoColor: false,
          animatedTheme: false,
        );
      case PerformanceMode.balanced:
        settings.save(
          performanceMode: PerformanceMode.balanced,
          enableBlurEffect: false,
          enableGlowEffect: false,
          enableMiniplayerParallaxEffect: true,
          artworkCacheHeightMultiplier: 0.9,
          autoColor: true,
          animatedTheme: false,
        );
      case PerformanceMode.goodLooking:
        settings.save(
          performanceMode: PerformanceMode.goodLooking,
          enableBlurEffect: true,
          enableGlowEffect: true,
          enableMiniplayerParallaxEffect: true,
          artworkCacheHeightMultiplier: 1.0,
          autoColor: true,
          animatedTheme: true,
        );
      case PerformanceMode.custom:
        settings.save(
          performanceMode: PerformanceMode.custom,
        );
    }
  }
}

extension QueueInsertionTypeToQI on QueueInsertionType {
  QueueInsertion toQueueInsertion() => settings.queueInsertion.value[this] ?? const QueueInsertion(numberOfTracks: 0, insertNext: true, sortBy: InsertionSortingType.none);

  /// NOTE: Modifies the original list.
  List<Selectable> shuffleOrSort(List<Selectable> tracks) {
    final sortBy = toQueueInsertion().sortBy;

    switch (sortBy) {
      case InsertionSortingType.listenCount:
        if (this == QueueInsertionType.algorithm || this == QueueInsertionType.algorithmDiscoverDate || this == QueueInsertionType.algorithmTimeRange) {
          // already sorted by repeated times inside [NamidaGenerator.generateRecommendedTrack].
        } else {
          tracks.sortByReverse((e) => HistoryController.inst.topTracksMapListens.value[e.track]?.length ?? 0);
        }
      case InsertionSortingType.rating:
        tracks.sortByReverse((e) => e.track.effectiveRating);
      case InsertionSortingType.random:
        tracks.shuffle();
      case InsertionSortingType.none: // do nothing
    }

    return tracks;
  }

  /// NOTE: Modifies the original list.
  List<YoutubeID> shuffleOrSortYT(List<YoutubeID> videos) {
    final sortBy = toQueueInsertion().sortBy;

    switch (sortBy) {
      case InsertionSortingType.listenCount:
        if (this == QueueInsertionType.algorithm) {
          // already sorted by repeated times inside [NamidaGenerator.generateRecommendedTrack].
        } else {
          videos.sortByReverse((e) => YoutubeHistoryController.inst.topTracksMapListens.value[e.id]?.length ?? 0);
        }
      case InsertionSortingType.random:
        videos.shuffle();

      case InsertionSortingType.rating: // no ratings yet
      case InsertionSortingType.none: // do nothing
    }

    return videos;
  }
}

extension SponsorBlockCategoryExt on SponsorBlockCategory {
  String toText() => this.name.sponsorCategoryToText();
}

extension SponsorBlockCategoryNamesExt on String {
  String sponsorCategoryToText() => switch (this) {
    'sponsor' => lang.sponsor,
    'selfpromo' => lang.selfPromotion,
    'interaction' => lang.interactionReminder,
    'poi_highlight' => lang.highlight,
    'intro' => lang.intro,
    'outro' => lang.outro,
    'preview' => lang.preview,
    'hook' => lang.hook,
    'filler' => lang.filler,
    'music_offtopic' => lang.musicOfftopic,
    _ => '',
  };
}

extension SponsorBlockActionExt on SponsorBlockAction {
  String toText() => switch (this) {
    SponsorBlockAction.showInSeekbar => lang.showInSeekbar,
    SponsorBlockAction.showSkipButton => lang.showSkipButton,
    SponsorBlockAction.autoSkip => lang.autoSkip,
    SponsorBlockAction.autoSkipOnce => lang.autoSkipOnce,
    SponsorBlockAction.disabled => lang.disable,
  };

  IconData toIcon() {
    return switch (this) {
      SponsorBlockAction.showInSeekbar => Broken.settings,
      SponsorBlockAction.showSkipButton => Broken.next,
      SponsorBlockAction.autoSkip => Broken.forward,
      SponsorBlockAction.autoSkipOnce => Broken.forward,
      SponsorBlockAction.disabled => Broken.slash,
    };
  }
}

extension RouteUtils on NamidaRoute {
  List<Selectable> tracksListInside() {
    final iter = tracksInside();
    return iter is List ? iter as List<Selectable> : iter.toList();
  }

  bool hasTracksInside() => tracksInside().isNotEmpty;
  bool hasTracksInsideReactive() => tracksInsideReactive().isNotEmpty;

  QueueSource toQueueSource() {
    return switch (route) {
      RouteType.PAGE_allTracks => QueueSource.allTracks,
      RouteType.PAGE_folders => QueueSource.folder,
      RouteType.PAGE_folders_music => QueueSource.folderMusic,
      RouteType.PAGE_folders_videos => QueueSource.folderVideos,
      RouteType.SUBPAGE_albumTracks => QueueSource.album,
      RouteType.SUBPAGE_artistTracks => QueueSource.artist,
      RouteType.SUBPAGE_albumArtistTracks => QueueSource.albumArtist,
      RouteType.SUBPAGE_composerTracks => QueueSource.composer,
      RouteType.SUBPAGE_genreTracks => QueueSource.genre,
      RouteType.SUBPAGE_queueTracks => QueueSource.queuePage,
      RouteType.SUBPAGE_playlistTracks => QueueSource.playlist,
      RouteType.SUBPAGE_favPlaylistTracks => QueueSource.favourites,
      RouteType.SUBPAGE_historyTracks => QueueSource.history,
      RouteType.SUBPAGE_mostPlayedTracks => QueueSource.mostPlayed,
      RouteType.SUBPAGE_recentlyAddedTracks => QueueSource.recentlyAdded,
      _ => QueueSource.others,
    };
  }

  /// NOTE: any modification done to this will be reflected in the original list.
  Iterable<Selectable> tracksInside() {
    return switch (route) {
          RouteType.PAGE_allTracks => SearchSortController.inst.trackSearchList.value,
          RouteType.PAGE_folders => FoldersController.tracksAndVideos.currentFolderTracksList,
          RouteType.PAGE_folders_music => FoldersController.tracks.currentFolderTracksList,
          RouteType.PAGE_folders_videos => FoldersController.videos.currentFolderTracksList,
          RouteType.SUBPAGE_albumTracks => name?.getAlbumTracks(),
          RouteType.SUBPAGE_artistTracks => name?.getArtistTracks(),
          RouteType.SUBPAGE_albumArtistTracks => name?.getAlbumArtistTracks(),
          RouteType.SUBPAGE_composerTracks => name?.getComposerTracks(),
          RouteType.SUBPAGE_genreTracks => name?.getGenresTracks(),
          RouteType.SUBPAGE_queueTracks => name?.getQueue()?.tracks,
          RouteType.SUBPAGE_playlistTracks => name == null ? null : PlaylistController.inst.getPlaylist(name!)?.tracks,
          RouteType.SUBPAGE_favPlaylistTracks => name == null ? null : PlaylistController.inst.favouritesPlaylist.value.tracks,
          RouteType.SUBPAGE_historyTracks => HistoryController.inst.historyTracks,
          // RouteType.SUBPAGE_mostPlayedTracks => HistoryController.inst.currentMostPlayedTracks,
          RouteType.SUBPAGE_recentlyAddedTracks => Indexer.inst.recentlyAddedTracksSorted(),
          _ => null,
        } ??
        [];
  }

  Iterable<Selectable>? _registerAndReturn(Iterable<Selectable>? trs, void Function() fn) {
    fn();
    return trs;
  }

  Iterable<Selectable> tracksInsideReactive() {
    return switch (route) {
          RouteType.PAGE_allTracks => SearchSortController.inst.trackSearchList.valueR,
          RouteType.PAGE_folders => FoldersController.tracksAndVideos.currentFolderTracksList,
          RouteType.PAGE_folders_music => FoldersController.tracks.currentFolderTracksList,
          RouteType.PAGE_folders_videos => FoldersController.videos.currentFolderTracksList,
          RouteType.SUBPAGE_mostPlayedTracks =>
            HistoryController.inst.currentTopTracksMapListensReactive(HistoryController.inst.currentMostPlayedTimeRange.valueR).valueR.keysSortedByValue,
          RouteType.SUBPAGE_albumTracks => _registerAndReturn(name?.getAlbumTracks(), () => Indexer.inst.mainMapAlbums.valueR),
          RouteType.SUBPAGE_artistTracks => _registerAndReturn(name?.getArtistTracks(), () => Indexer.inst.mainMapArtists.valueR),
          RouteType.SUBPAGE_albumArtistTracks => _registerAndReturn(name?.getAlbumArtistTracks(), () => Indexer.inst.mainMapAlbumArtists.valueR),
          RouteType.SUBPAGE_composerTracks => _registerAndReturn(name?.getComposerTracks(), () => Indexer.inst.mainMapComposer.valueR),
          RouteType.SUBPAGE_genreTracks => _registerAndReturn(name?.getGenresTracks(), () => Indexer.inst.mainMapGenres.valueR),
          RouteType.SUBPAGE_queueTracks => _registerAndReturn(name?.getQueue()?.tracks, () => QueueController.inst.queuesMap.valueR),
          RouteType.SUBPAGE_playlistTracks =>
            name == null ? null : _registerAndReturn(PlaylistController.inst.getPlaylist(name!)?.tracks, () => PlaylistController.inst.playlistsMap.valueR),
          RouteType.SUBPAGE_favPlaylistTracks =>
            name == null ? null : _registerAndReturn(PlaylistController.inst.favouritesPlaylist.value.tracks, () => PlaylistController.inst.favouritesPlaylist.valueR),
          RouteType.SUBPAGE_historyTracks => HistoryController.inst.historyTracksR,
          // RouteType.SUBPAGE_mostPlayedTracks => HistoryController.inst.currentMostPlayedTracks,
          RouteType.SUBPAGE_recentlyAddedTracks => _registerAndReturn(Indexer.inst.recentlyAddedTracksSorted(), () => Indexer.inst.tracksInfoList.valueR),
          _ => null,
        } ??
        [];
  }

  /// Currently Supports only [RouteType.SUBPAGE_albumTracks], [RouteType.SUBPAGE_artistTracks],
  /// [RouteType.SUBPAGE_albumArtistTracks] & [RouteType.SUBPAGE_composerTracks].
  Track? get trackOfColor {
    final name = this.name;
    if (name == null) return null;
    if (route == RouteType.SUBPAGE_albumTracks) return name.getAlbumTracks().trackOfImage;
    if (route == RouteType.SUBPAGE_artistTracks) return name.getArtistTracks().trackOfImage;
    if (route == RouteType.SUBPAGE_albumArtistTracks) return name.getAlbumArtistTracks().trackOfImage;
    if (route == RouteType.SUBPAGE_composerTracks) return name.getComposerTracks().trackOfImage;
    return null;
  }

  NetworkArtworkInfo? get getNetworkArtworkInfo {
    final name = this.name;
    if (name == null) return null;
    if (route == RouteType.SUBPAGE_albumTracks) return NetworkArtworkInfo.albumAutoArtist(name);
    if (route == RouteType.SUBPAGE_artistTracks) return NetworkArtworkInfo.artist(name);
    if (route == RouteType.SUBPAGE_albumArtistTracks) return NetworkArtworkInfo.artist(name);
    if (route == RouteType.SUBPAGE_composerTracks) return NetworkArtworkInfo.artist(name);
    return null;
  }

  /// Currently Supports only [RouteType.SUBPAGE_albumTracks], [RouteType.SUBPAGE_artistTracks],
  /// [RouteType.SUBPAGE_albumArtistTracks] & [RouteType.SUBPAGE_composerTracks].
  Future<void> updateColorScheme() async {
    // a delay to prevent navigation glitches
    await Future.delayed(const Duration(milliseconds: 500));

    Color? color;
    final trackToExtractFrom = trackOfColor;
    final networkArtworkInfo = getNetworkArtworkInfo;
    if (trackToExtractFrom != null || networkArtworkInfo != null) {
      color = await CurrentColor.inst.getTrackDelightnedColor(trackToExtractFrom ?? kDummyTrack, networkArtworkInfo, useIsolate: true);
    }
    CurrentColor.inst.updateCurrentColorSchemeOfSubPages(color);
  }

  Widget? toTitle(BuildContext context) {
    final textTheme = context.textTheme;
    Widget getTextWidget(String t) => Text(t, style: textTheme.titleLarge);
    Widget? finalWidget;
    bool displaySettingSearch = false;
    switch (route) {
      case RouteType.SETTINGS_page:
        displaySettingSearch = true;
        finalWidget = getTextWidget(lang.settings);
        break;
      case RouteType.SETTINGS_subpage:
        displaySettingSearch = true;
        finalWidget = getTextWidget(name ?? '');
        break;
      case RouteType.SEARCH_albumResults:
        finalWidget = getTextWidget(lang.albums);
        break;
      case RouteType.SEARCH_artistResults:
        finalWidget = getTextWidget(lang.artists);
        break;
      case RouteType.PAGE_queue:
        finalWidget = ObxO(
          rx: QueueController.inst.queuesMap,
          builder: (context, qmap) => getTextWidget("${lang.queues} • ${qmap.length}"),
        );
        break;
      default:
        null;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child:
          displaySettingSearch //
          ? NamidaSettingSearchBar.keyed(closedChild: finalWidget)
          : finalWidget ?? ScrollSearchController.inst.searchBarWidget,
    );
  }

  Widget _getMoreIcon(void Function()? onPressed) {
    return NamidaAppBarIcon(
      icon: Broken.more_2,
      onPressed: onPressed,
    );
  }

  Widget _getAnimatedCrossFade({required Widget child, required bool shouldShow}) {
    return AnimatedShow(
      show: shouldShow,
      isHorizontal: true,
      curve: Curves.fastEaseInToSlowEaseOut,
      duration: Duration(milliseconds: 400),
      child: child,
    );
  }

  List<Widget> toActions() {
    final shouldShowInitialActions =
        route != RouteType.PAGE_stats &&
        route != RouteType.SETTINGS_page &&
        route != RouteType.SETTINGS_subpage &&
        route != RouteType.YOUTUBE_USER_MANAGE_ACCOUNT_SUBPAGE &&
        route != RouteType.YOUTUBE_USER_MANAGE_SUBSCRIPTION_SUBPAGE;
    final shouldShowProgressPercentage = route != RouteType.SETTINGS_page && route != RouteType.SETTINGS_subpage;
    const shouldShowMissingServerDirAuth = true;

    final name = this.name;

    final queue = route == RouteType.SUBPAGE_queueTracks ? name?.getQueue() : null;

    final showMainMenu =
        route == RouteType.SUBPAGE_albumTracks ||
        route == RouteType.SUBPAGE_artistTracks ||
        route == RouteType.SUBPAGE_albumArtistTracks ||
        route == RouteType.SUBPAGE_composerTracks ||
        route == RouteType.SUBPAGE_genreTracks ||
        route == RouteType.SUBPAGE_queueTracks;

    final showPlaylistMenu =
        route == RouteType.SUBPAGE_playlistTracks ||
        route == RouteType.SUBPAGE_favPlaylistTracks ||
        route == RouteType.SUBPAGE_historyTracks ||
        route == RouteType.SUBPAGE_mostPlayedTracks;

    final shouldShowSettingsIcon = !showMainMenu && !showPlaylistMenu && shouldShowInitialActions;

    return <Widget>[
      const SizedBox(width: 2.0),

      _getAnimatedCrossFade(
        child: NamidaAppBarIcon(
          icon: Broken.trush_square,
          onPressed: () => NamidaOnTaps.inst.onQueuesClearIconTap(),
        ),
        shouldShow: route == RouteType.PAGE_queue,
      ),

      // -- Parsing Json Icon
      _getAnimatedCrossFade(child: const ParsingJsonPercentage(size: 30.0, hero: false), shouldShow: shouldShowProgressPercentage),

      // -- Indexer Icon
      _getAnimatedCrossFade(child: const IndexingPercentage(size: 30.0, hero: false), shouldShow: shouldShowProgressPercentage),

      // -- Videos Icon
      _getAnimatedCrossFade(child: const VideosExtractingPercentage(size: 30.0, hero: false), shouldShow: shouldShowProgressPercentage),

      _getAnimatedCrossFade(
        child: NamidaAppBarIcon(
          icon: Broken.activity,
          onPressed: () => JsonToHistoryParser.inst.showMissingEntriesDialog(),
        ),
        shouldShow: JsonToHistoryParser.inst.shouldShowMissingEntriesDialog,
      ),

      _getAnimatedCrossFade(
        child: ObxO(
          rx: MusicWebServerAuthDetails.manager.hasMissingAuthRx,
          builder: (context, missingAuth) => missingAuth
              ? NamidaAppBarIcon(
                  icon: Broken.danger,
                  onPressed: MusicWebServerAuthDetails.manager.promptFillMissingAuthDialog,
                )
              : const SizedBox(),
        ),
        shouldShow: shouldShowMissingServerDirAuth,
      ),

      ObxO(
        rx: VersionController.inst.latestVersion,
        builder: (context, value) => _getAnimatedCrossFade(
          child: const NamidaUpdateButton(),
          shouldShow: !showMainMenu && (value?.isUpdate() ?? false),
        ),
      ),

      _getAnimatedCrossFade(
        child: NamidaRawLikeButton(
          padding: const EdgeInsets.symmetric(horizontal: 3.0),
          isLiked: queue?.isFav,
          removeConfirmationAction: lang.removeFromFavourites,
          onTap: (isLiked) async => await QueueController.inst.toggleFavButton(queue!),
        ),
        shouldShow: queue != null,
      ),

      _getAnimatedCrossFade(
        child: NamidaAppBarIcon(
          icon: Broken.sort,
          onPressed: () {
            NamidaOnTaps.inst.onPlaylistSubPageTracksSortIconTap(
              name ?? '',
              ytplc.YoutubePlaylistController.inst,
              YTSortType.values,
              (sort) => sort.toText(),
              (sort) => sort.toIcon(),
            );
          },
        ),
        shouldShow: route == RouteType.YOUTUBE_PLAYLIST_SUBPAGE || route == RouteType.YOUTUBE_LIKED_SUBPAGE,
      ),

      _getAnimatedCrossFade(
        child: HistoryJumpToDayIcon(
          considerInfoBoxPadding: true,
          controller: HistoryController.inst,
          itemExtentAndDayHeaderExtent: () => (
            itemExtent: Dimensions.inst.trackTileItemExtent,
            dayHeaderExtent: kHistoryDayHeaderHeightWithPadding,
          ),
        ),
        shouldShow: route == RouteType.SUBPAGE_historyTracks,
      ),

      _getAnimatedCrossFade(
        child: HistoryJumpToDayIcon(
          considerInfoBoxPadding: false,
          controller: YoutubeHistoryController.inst,
          itemExtentAndDayHeaderExtent: () => (
            itemExtent: Dimensions.youtubeCardItemExtent,
            dayHeaderExtent: kYoutubeHistoryDayHeaderHeightWithPadding,
          ),
        ),
        shouldShow: route == RouteType.YOUTUBE_HISTORY_SUBPAGE,
      ),

      // ---- Playlist Tracks ----
      _getAnimatedCrossFade(
        child: EnableDisablePlaylistReordering(
          playlistName: name ?? '',
          playlistManager: PlaylistController.inst,
        ),
        shouldShow: route == RouteType.SUBPAGE_playlistTracks || route == RouteType.SUBPAGE_favPlaylistTracks,
      ),

      _getAnimatedCrossFade(
        child: EnableDisablePlaylistReordering(
          playlistName: name ?? '',
          playlistManager: ytplc.YoutubePlaylistController.inst,
        ),
        shouldShow: route == RouteType.YOUTUBE_PLAYLIST_SUBPAGE || route == RouteType.YOUTUBE_LIKED_SUBPAGE,
      ),

      _getAnimatedCrossFade(
        child: _getMoreIcon(() {
          if (name == null) return;
          switch (route) {
            case RouteType.SUBPAGE_albumTracks:
              NamidaDialogs.inst.showAlbumDialog(name);
              break;
            case RouteType.SUBPAGE_artistTracks:
              NamidaDialogs.inst.showArtistDialog(name, MediaType.artist);
              break;
            case RouteType.SUBPAGE_albumArtistTracks:
              NamidaDialogs.inst.showArtistDialog(name, MediaType.albumArtist);
              break;
            case RouteType.SUBPAGE_composerTracks:
              NamidaDialogs.inst.showArtistDialog(name, MediaType.composer);
              break;
            case RouteType.SUBPAGE_genreTracks:
              NamidaDialogs.inst.showGenreDialog(name);
              break;
            case RouteType.SUBPAGE_queueTracks:
              NamidaDialogs.inst.showQueueDialog(int.parse(name));
              break;

            default:
              null;
          }
        }),
        shouldShow: showMainMenu && name != null,
      ),

      _getAnimatedCrossFade(
        child: _getMoreIcon(() {
          if (name == null) return;
          NamidaDialogs.inst.showPlaylistDialog(name);
        }),
        shouldShow: showPlaylistMenu && name != null,
      ),

      // -- Settings Icon
      _getAnimatedCrossFade(
        child: AnimatedRotation(
          duration: const Duration(milliseconds: 300),
          turns: shouldShowSettingsIcon ? 0.0 : 0.25,
          curve: Curves.easeOutQuart,
          child: NamidaAppBarIcon(
            icon: Broken.setting_2,
            onPressed: const SettingsPage().navigate,
          ),
        ),
        shouldShow: shouldShowSettingsIcon,
      ),

      const SizedBox(width: 8.0),
    ];
  }
}

extension TracksFromMaps on String {
  List<Track> getAlbumTracks() => Indexer.inst.mainMapAlbums.value[this] ?? [];

  List<Track> getArtistTracks() => Indexer.inst.mainMapArtists.value[this] ?? [];

  List<Track> getArtistTracksFor(MediaType type) {
    return Indexer.inst.getArtistMapFor(type).value[this] ?? [];
  }

  List<Track> getAlbumArtistTracks() => Indexer.inst.mainMapAlbumArtists.value[this] ?? [];
  List<Track> getComposerTracks() => Indexer.inst.mainMapComposer.value[this] ?? [];
  List<Track> getGenresTracks() => Indexer.inst.mainMapGenres.value[this] ?? [];

  Queue? getQueue() => QueueController.inst.queuesMap.value[int.tryParse(this)];
}

extension QueueFromMap on int {
  Queue? getQueue() => QueueController.inst.queuesMap.value[this];
}

extension ThemeDefaultColors on BuildContext {
  Color defaultIconColor([Color? mainColor, Color? secondaryColor]) => Color.alphaBlend(
    (mainColor ?? CurrentColor.inst.color).withAlpha(120),
    secondaryColor ?? theme.colorScheme.onSurface,
  );
}

void showMinimumItemsSnack([int minimum = 1]) {
  snackyy(
    title: lang.minimumOneItem,
    message: lang.minimumOneItemSubtitle(number: minimum),
  );
}

extension InterruptionActionL10n on InterruptionAction {
  String toText() => switch (this) {
    InterruptionAction.doNothing => lang.doNothing,
    InterruptionAction.duckAudio => lang.duckAudio,
    InterruptionAction.pause => lang.pausePlayback,
  };

  IconData toIcon() => switch (this) {
    InterruptionAction.doNothing => Broken.minus_cirlce,
    InterruptionAction.duckAudio => Broken.volume_low_1,
    InterruptionAction.pause => Broken.pause_circle,
  };
}

extension InterruptionTypeL10n on InterruptionType {
  String toText() => switch (this) {
    InterruptionType.shouldPause => lang.shouldPause,
    InterruptionType.shouldDuck => lang.shouldDuck,
    InterruptionType.unknown => lang.others,
  };

  String? toSubtitle() => switch (this) {
    InterruptionType.shouldPause => lang.shouldPauseNote,
    InterruptionType.shouldDuck => lang.shouldDuckNote,
    InterruptionType.unknown => null,
  };

  IconData toIcon() => switch (this) {
    InterruptionType.shouldPause => Broken.pause_circle,
    InterruptionType.shouldDuck => Broken.volume_low_1,
    InterruptionType.unknown => Broken.status,
  };
}

extension LibraryTabL10n on LibraryTab {
  String toText() => switch (this) {
    LibraryTab.albums => lang.albums,
    LibraryTab.tracks => lang.tracks,
    LibraryTab.artists => lang.artists,
    LibraryTab.genres => lang.genres,
    LibraryTab.playlists => lang.playlists,
    LibraryTab.folders => lang.folders,
    LibraryTab.foldersMusic => "${lang.folders}: ${lang.tracks}",
    LibraryTab.foldersVideos => "${lang.folders}: ${lang.videos}",
    LibraryTab.home => lang.home,
    LibraryTab.search => lang.search,
    LibraryTab.youtube => lang.youtube,
  };

  IconData toIcon() => switch (this) {
    LibraryTab.albums => Broken.music_dashboard,
    LibraryTab.tracks => Broken.music_circle,
    LibraryTab.artists => Broken.profile_2user,
    LibraryTab.genres => Broken.smileys,
    LibraryTab.playlists => Broken.music_library_2,
    LibraryTab.folders => Broken.folder,
    LibraryTab.foldersMusic => Broken.folder_2,
    LibraryTab.foldersVideos => Broken.video_play,
    LibraryTab.home => Broken.home_2,
    LibraryTab.search => Broken.search_normal_1,
    LibraryTab.youtube => Broken.video_square,
  };
}

extension MediaTypeL10n on MediaType {
  String toText() => switch (this) {
    MediaType.album => lang.albums,
    MediaType.track => lang.tracks,
    MediaType.artist => lang.artists,
    MediaType.albumArtist => lang.albumArtists,
    MediaType.composer => lang.composer,
    MediaType.genre => lang.genres,
    MediaType.playlist => lang.playlists,
    MediaType.folder => lang.folders,
    MediaType.folderMusic => "${lang.folders}: ${lang.tracks}",
    MediaType.folderVideo => "${lang.folders}: ${lang.videos}",
  };
}

extension AlbumIdentifierL10n on AlbumIdentifier {
  String toText() => switch (this) {
    AlbumIdentifier.albumName => lang.name,
    AlbumIdentifier.albumArtist => lang.albumArtist,
    AlbumIdentifier.year => lang.year,
  };
}

extension SortTypeL10n on SortType {
  String toText() => switch (this) {
    SortType.title => lang.title,
    SortType.album => lang.album,
    SortType.albumArtist => lang.albumArtist,
    SortType.artistsList => lang.artists,
    SortType.bitrate => lang.bitrate,
    SortType.composer => lang.composer,
    SortType.dateAdded => lang.dateAdded,
    SortType.dateModified => lang.dateModified,
    SortType.discNo => lang.discNumber,
    SortType.trackNo => lang.trackNumber,
    SortType.filename => lang.fileName,
    SortType.duration => lang.duration,
    SortType.genresList => lang.genres,
    SortType.sampleRate => lang.sampleRate,
    SortType.size => lang.size,
    SortType.year => lang.year,
    SortType.rating => lang.rating,
    SortType.shuffle => lang.shuffle,
    SortType.mostPlayed => lang.mostPlayed,
    SortType.latestPlayed => lang.recentListens,
    SortType.firstListen => lang.firstListen,
    SortType.titleSort => '${lang.title} (${lang.sortBy})',
  };

  IconData toIcon() => switch (this) {
    SortType.title => Broken.music,
    SortType.album => Broken.music_dashboard,
    SortType.artistsList => Broken.microphone,
    SortType.albumArtist => Broken.user,
    SortType.genresList => Broken.smileys,
    SortType.composer => Broken.profile_2user,
    SortType.trackNo => Broken.hashtag,
    SortType.discNo => Broken.hashtag,
    SortType.year => Broken.calendar,
    SortType.duration => Broken.timer_1,
    SortType.dateAdded => Broken.calendar_add,
    SortType.dateModified => Broken.calendar_edit,
    SortType.rating => Broken.grammerly,
    SortType.bitrate => Broken.voice_cricle,
    SortType.filename => Broken.quote_up_circle,
    SortType.sampleRate => Broken.voice_cricle,
    SortType.size => Broken.size,
    SortType.shuffle => Broken.shuffle,
    SortType.mostPlayed => Broken.award,
    SortType.latestPlayed => Broken.clock,
    SortType.firstListen => Broken.calendar_search,
    SortType.titleSort => Broken.music,
  };
}

extension YTSortTypeL10n on YTSortType {
  String toText() => switch (this) {
    YTSortType.title => lang.title,
    YTSortType.channelTitle => lang.channel,
    YTSortType.duration => lang.duration,
    YTSortType.date => lang.date,
    YTSortType.dateAdded => lang.dateAdded,
    YTSortType.shuffle => lang.shuffle,
    YTSortType.mostPlayed => lang.mostPlayed,
    YTSortType.latestPlayed => lang.recentListens,
    YTSortType.firstListen => lang.firstListen,
  };

  IconData toIcon() => switch (this) {
    YTSortType.title => Broken.music,
    YTSortType.channelTitle => Broken.user,
    YTSortType.duration => Broken.timer_1,
    YTSortType.date => Broken.calendar,
    YTSortType.dateAdded => Broken.calendar_add,
    YTSortType.shuffle => Broken.shuffle,
    YTSortType.mostPlayed => Broken.award,
    YTSortType.latestPlayed => Broken.clock,
    YTSortType.firstListen => Broken.calendar_search,
  };
}

extension CacheVideoPriorityL10n on CacheVideoPriority {
  String toText() => switch (this) {
    CacheVideoPriority.VIP => 'VIP',
    CacheVideoPriority.high => 'High',
    CacheVideoPriority.normal => 'Normal',
    CacheVideoPriority.low => 'Low',
    CacheVideoPriority.GETOUT => 'Disable',
  };
}

extension GroupSortTypeL10n on GroupSortType {
  String toText() => switch (this) {
    GroupSortType.title => lang.title,
    GroupSortType.album => lang.album,
    GroupSortType.albumArtist => lang.albumArtist,
    GroupSortType.artistsList => lang.artist,
    GroupSortType.genresList => lang.genres,
    GroupSortType.composer => lang.composer,
    GroupSortType.label => lang.recordLabel,
    GroupSortType.dateModified => lang.dateModified,
    GroupSortType.duration => lang.duration,
    GroupSortType.numberOfTracks => lang.numberOfTracks,
    GroupSortType.playCount => lang.totalListens,
    GroupSortType.firstListen => lang.firstListen,
    GroupSortType.latestPlayed => lang.recentListens,
    GroupSortType.albumsCount => lang.albumsCount,
    GroupSortType.year => lang.year,
    GroupSortType.creationDate => lang.dateCreated,
    GroupSortType.modifiedDate => lang.dateModified,
    GroupSortType.albumSort => '${lang.album} (${lang.sortBy})',
    GroupSortType.albumArtistSort => '${lang.albumArtist} (${lang.sortBy})',
    GroupSortType.artistSort => '${lang.artist} (${lang.sortBy})',
    GroupSortType.composerSort => '${lang.composer} (${lang.sortBy})',
    GroupSortType.shuffle => lang.shuffle,
    GroupSortType.custom => lang.custom,
  };

  IconData toIcon() => switch (this) {
    GroupSortType.title => Broken.music,
    GroupSortType.album => Broken.music_dashboard,
    GroupSortType.artistsList => Broken.microphone,
    GroupSortType.albumArtist => Broken.user,
    GroupSortType.genresList => Broken.smileys,
    GroupSortType.composer => Broken.profile_2user,
    GroupSortType.numberOfTracks => Broken.hashtag,
    GroupSortType.year => Broken.calendar,
    GroupSortType.duration => Broken.timer_1,
    GroupSortType.creationDate => Broken.calendar_add,
    GroupSortType.dateModified => Broken.calendar_edit,
    GroupSortType.modifiedDate => Broken.calendar_edit,
    GroupSortType.label => Broken.ticket,
    GroupSortType.albumsCount => Broken.cards,
    GroupSortType.custom => Broken.format_circle,
    GroupSortType.shuffle => Broken.shuffle,
    GroupSortType.playCount => Broken.award,
    GroupSortType.latestPlayed => Broken.clock,
    GroupSortType.firstListen => Broken.calendar_search,
    GroupSortType.albumSort => Broken.music_dashboard,
    GroupSortType.albumArtistSort => Broken.user,
    GroupSortType.artistSort => Broken.microphone,
    GroupSortType.composerSort => Broken.profile_2user,
  };
}

extension TrackTileItemL10n on TrackTileItem {
  String toText() => switch (this) {
    TrackTileItem.none => lang.none,
    TrackTileItem.title => lang.title,
    TrackTileItem.artists => lang.artists,
    TrackTileItem.album => lang.album,
    TrackTileItem.albumArtist => lang.albumArtist,
    TrackTileItem.genres => lang.genres,
    TrackTileItem.composer => lang.composer,
    TrackTileItem.year => lang.year,
    TrackTileItem.bitrate => lang.bitrate,
    TrackTileItem.channels => lang.channels,
    TrackTileItem.comment => lang.comment,
    TrackTileItem.dateAdded => lang.dateAdded,
    TrackTileItem.dateModified => lang.dateModified,
    TrackTileItem.dateModifiedClock => "${lang.dateModified} (${lang.clock})",
    TrackTileItem.dateModifiedDate => "${lang.dateModified} (${lang.date})",
    TrackTileItem.discNumber => lang.discNumber,
    TrackTileItem.trackNumber => lang.trackNumber,
    TrackTileItem.duration => lang.duration,
    TrackTileItem.fileName => lang.fileName,
    TrackTileItem.fileNameWOExt => lang.fileNameWoExt,
    TrackTileItem.extension => lang.extension,
    TrackTileItem.folder => lang.folderName,
    TrackTileItem.format => lang.format,
    TrackTileItem.path => lang.path,
    TrackTileItem.sampleRate => lang.sampleRate,
    TrackTileItem.size => lang.size,
    TrackTileItem.rating => lang.rating,
    TrackTileItem.moods => lang.moods,
    TrackTileItem.tags => lang.tags,
    TrackTileItem.listenCount => lang.totalListens,
    TrackTileItem.latestListenDate => lang.recentListens,
    TrackTileItem.firstListenDate => lang.firstListen,
  };
}

extension QueueSourceL10n on QueueSource {
  String toText() => switch (this) {
    QueueSource.allTracks => lang.tracks,
    QueueSource.album => lang.album,
    QueueSource.artist => lang.artist,
    QueueSource.albumArtist => lang.albumArtist,
    QueueSource.composer => lang.composer,
    QueueSource.genre => lang.genre,
    QueueSource.playlist => lang.playlist,
    QueueSource.favourites => lang.favourites,
    QueueSource.history => lang.history,
    QueueSource.mostPlayed => lang.mostPlayed,
    QueueSource.folder => lang.folder,
    QueueSource.folderMusic => "${lang.folder} (${lang.tracks})",
    QueueSource.folderVideos => "${lang.folder} (${lang.videos})",
    QueueSource.search => lang.search,
    QueueSource.playerQueue => lang.queue,
    QueueSource.queuePage => lang.queues,
    QueueSource.selectedTracks => lang.selectedTracks,
    QueueSource.externalFile => lang.externalFiles,
    QueueSource.recentlyAdded => lang.recentlyAdded,
    QueueSource.homePageItem => '',
    QueueSource.others => lang.others,
  };
}

extension QueueSourceYoutubeIDL10n on QueueSourceYoutubeID {
  String toText() => switch (this) {
    QueueSourceYoutubeID.channel => lang.channel,
    QueueSourceYoutubeID.playlist => lang.playlist,
    QueueSourceYoutubeID.search => lang.search,
    QueueSourceYoutubeID.playerQueue => lang.queue,
    QueueSourceYoutubeID.mostPlayed => lang.mostPlayed,
    QueueSourceYoutubeID.history => lang.history,
    QueueSourceYoutubeID.historyFiltered => lang.history,
    QueueSourceYoutubeID.favourites => lang.favourites,
    QueueSourceYoutubeID.externalLink => lang.externalFiles,
    QueueSourceYoutubeID.homeFeed => lang.home,
    QueueSourceYoutubeID.relatedVideos => lang.relatedVideos,
    QueueSourceYoutubeID.historyFilteredHosted => lang.history,
    QueueSourceYoutubeID.searchHosted => lang.search,
    QueueSourceYoutubeID.channelHosted => lang.channel,
    QueueSourceYoutubeID.historyHosted => lang.history,
    QueueSourceYoutubeID.playlistHosted => lang.playlist,
    QueueSourceYoutubeID.downloadTask => lang.downloads,
    QueueSourceYoutubeID.videoEndCard => lang.video,
    QueueSourceYoutubeID.videoDescription => lang.description,
    QueueSourceYoutubeID.notificationsHosted => lang.notifications,
  };
}

extension TagFieldL10n on TagField {
  String toText() => switch (this) {
    TagField.title => lang.title,
    TagField.album => lang.album,
    TagField.artist => lang.artist,
    TagField.albumArtist => lang.albumArtist,
    TagField.genre => lang.genre,
    TagField.mood => lang.mood,
    TagField.composer => lang.composer,
    TagField.comment => lang.comment,
    TagField.description => lang.description,
    TagField.synopsis => lang.synopsis,
    TagField.lyrics => lang.lyrics,
    TagField.trackNumber => lang.trackNumber,
    TagField.discNumber => lang.discNumber,
    TagField.year => lang.year,
    TagField.remixer => lang.remixer,
    TagField.trackTotal => lang.trackNumberTotal,
    TagField.discTotal => lang.discNumberTotal,
    TagField.lyricist => lang.lyricist,
    TagField.language => lang.language,
    TagField.recordLabel => lang.recordLabel,
    TagField.country => lang.country,
    TagField.rating => lang.rating,
    TagField.tags => lang.tags,
    TagField.titleSort => '${lang.title} (${lang.sortBy})',
    TagField.albumSort => '${lang.album} (${lang.sortBy})',
    TagField.albumArtistSort => '${lang.albumArtist} (${lang.sortBy})',
    TagField.artistSort => '${lang.artist} (${lang.sortBy})',
    TagField.composerSort => '${lang.composer} (${lang.sortBy})',
  };

  IconData toIcon() => switch (this) {
    TagField.title => Broken.music,
    TagField.album => Broken.music_dashboard,
    TagField.artist => Broken.microphone,
    TagField.albumArtist => Broken.user,
    TagField.genre => Broken.smileys,
    TagField.mood => Broken.happyemoji,
    TagField.composer => Broken.profile_2user,
    TagField.comment => Broken.text_block,
    TagField.description => Broken.note_text,
    TagField.synopsis => Broken.text,
    TagField.lyrics => Broken.message_text,
    TagField.trackNumber => Broken.hashtag,
    TagField.discNumber => Broken.hashtag,
    TagField.year => Broken.calendar,
    TagField.remixer => Broken.radio,
    TagField.trackTotal => Broken.hashtag,
    TagField.discTotal => Broken.hashtag,
    TagField.lyricist => Broken.pen_add,
    TagField.language => Broken.language_circle,
    TagField.recordLabel => Broken.ticket,
    TagField.country => Broken.house,
    TagField.rating => Broken.grammerly,
    TagField.tags => Broken.ticket_discount,
    TagField.titleSort => Broken.music,
    TagField.albumSort => Broken.music_dashboard,
    TagField.albumArtistSort => Broken.user,
    TagField.artistSort => Broken.microphone,
    TagField.composerSort => Broken.profile_2user,
  };
}

extension VideoPlaybackSourceL10n on VideoPlaybackSource {
  String toText() => switch (this) {
    VideoPlaybackSource.auto => lang.auto,
    VideoPlaybackSource.youtube => lang.videoPlaybackSourceYoutube,
    VideoPlaybackSource.local => lang.videoPlaybackSourceLocal,
  };

  String toSubtitle() => switch (this) {
    VideoPlaybackSource.auto => lang.videoPlaybackSourceAutoSubtitle,
    VideoPlaybackSource.youtube => lang.videoPlaybackSourceYoutubeSubtitle,
    VideoPlaybackSource.local => lang.videoPlaybackSourceLocalSubtitle,
  };
}

extension LyricsSourceL10n on LyricsSource {
  String toText() => switch (this) {
    LyricsSource.auto => lang.auto,
    LyricsSource.local => lang.local,
    LyricsSource.internet => lang.database,
  };
}

extension WakelockModeL10n on WakelockMode {
  String toText() => switch (this) {
    WakelockMode.none => lang.keepScreenAwakeNone,
    WakelockMode.expanded => lang.keepScreenAwakeMiniplayerExpanded,
    WakelockMode.expandedAndVideo => lang.keepScreenAwakeMiniplayerExpandedAndVideo,
  };
}

extension LocalVideoMatchingTypeL10n on LocalVideoMatchingType {
  String toText() => switch (this) {
    LocalVideoMatchingType.auto => lang.auto,
    LocalVideoMatchingType.titleAndArtist => "${lang.title} & ${lang.artist}",
    LocalVideoMatchingType.filename => lang.fileName,
    LocalVideoMatchingType.youtubeID => "${lang.fileName} (${lang.youtube})",
  };
}

extension TrackPlayModeL10n on TrackPlayMode {
  String toText() => switch (this) {
    TrackPlayMode.selectedTrack => lang.trackPlayModeSelectedOnly,
    TrackPlayMode.searchResults => lang.trackPlayModeSearchResults,
    TrackPlayMode.trackAlbum => lang.trackPlayModeTrackAlbum,
    TrackPlayMode.trackArtist => lang.trackPlayModeTrackArtist,
    TrackPlayMode.trackGenre => lang.trackPlayModeTrackGenre,
  };
}

extension InsertionSortingTypeL10n on InsertionSortingType {
  String toText() => switch (this) {
    InsertionSortingType.listenCount => lang.totalListens,
    InsertionSortingType.random => lang.random,
    InsertionSortingType.rating => lang.rating,
    InsertionSortingType.none => lang.defaultLabel,
  };

  IconData toIcon() => switch (this) {
    InsertionSortingType.listenCount => Broken.award,
    InsertionSortingType.random => Broken.format_circle,
    InsertionSortingType.rating => Broken.grammerly,
    InsertionSortingType.none => Broken.cd,
  };
}

extension MostPlayedTimeRangeL10n on MostPlayedTimeRange {
  String toText() => switch (this) {
    MostPlayedTimeRange.custom => lang.custom,
    MostPlayedTimeRange.day => lang.day,
    MostPlayedTimeRange.day3 => lang.countDays(count: 3),
    MostPlayedTimeRange.week => lang.week,
    MostPlayedTimeRange.month => lang.month,
    MostPlayedTimeRange.month3 => lang.countMonths(count: 3),
    MostPlayedTimeRange.month6 => lang.countMonths(count: 6),
    MostPlayedTimeRange.year => lang.year,
    MostPlayedTimeRange.allTime => lang.allTime,
  };
}

extension HomePageItemsL10n on HomePageItems {
  String toText() => switch (this) {
    HomePageItems.mixes => lang.mixes,
    HomePageItems.recentListens => lang.recentListens,
    HomePageItems.topRecentListens => lang.topRecents,
    HomePageItems.lostMemories => lang.lostMemories,
    HomePageItems.recentlyAdded => lang.recentlyAdded,
    HomePageItems.recentAlbums => lang.recentAlbums,
    HomePageItems.recentArtists => lang.recentArtists,
    HomePageItems.topRecentAlbums => lang.topRecentAlbums,
    HomePageItems.topRecentArtists => lang.topRecentArtists,
  };
}

extension NotificationTapActionL10n on NotificationTapAction {
  String toText() => switch (this) {
    NotificationTapAction.openApp => lang.openApp,
    NotificationTapAction.openMiniplayer => lang.openMiniplayer,
    NotificationTapAction.openQueue => lang.openQueue,
  };
}

extension OnYoutubeLinkOpenActionL10n on OnYoutubeLinkOpenAction {
  String toText() => switch (this) {
    OnYoutubeLinkOpenAction.showDownload => lang.download,
    OnYoutubeLinkOpenAction.play => lang.play,
    OnYoutubeLinkOpenAction.playNext => lang.playNext,
    OnYoutubeLinkOpenAction.playAfter => lang.playAfter,
    OnYoutubeLinkOpenAction.playLast => lang.playLast,
    OnYoutubeLinkOpenAction.addToPlaylist => lang.addToPlaylist,
    OnYoutubeLinkOpenAction.alwaysAsk => lang.alwaysAsk,
  };

  IconData toIcon() => switch (this) {
    OnYoutubeLinkOpenAction.showDownload => Broken.import,
    OnYoutubeLinkOpenAction.play => Broken.play,
    OnYoutubeLinkOpenAction.playNext => Broken.next,
    OnYoutubeLinkOpenAction.playAfter => Broken.hierarchy_square,
    OnYoutubeLinkOpenAction.playLast => Broken.play_cricle,
    OnYoutubeLinkOpenAction.addToPlaylist => Broken.music_library_2,
    OnYoutubeLinkOpenAction.alwaysAsk => Broken.message_question,
  };
}

extension PerformanceModeL10n on PerformanceMode {
  String toText() => switch (this) {
    PerformanceMode.highPerformance => lang.highPerformance,
    PerformanceMode.balanced => lang.balanced,
    PerformanceMode.goodLooking => lang.goodLooking,
    PerformanceMode.custom => lang.custom,
  };

  IconData toIcon() => switch (this) {
    PerformanceMode.highPerformance => Broken.activity,
    PerformanceMode.balanced => Broken.cd,
    PerformanceMode.goodLooking => Broken.buy_crypto,
    PerformanceMode.custom => Broken.candle,
  };
}

extension KillAppModeL10n on KillAppMode {
  String toText() => switch (this) {
    KillAppMode.never => lang.never,
    KillAppMode.ifNotPlaying => lang.ifNotPlaying,
    KillAppMode.always => lang.always,
  };
}

extension FABTypeL10n on FABType {
  String toText() => switch (this) {
    FABType.none => lang.none,
    FABType.search => lang.search,
    FABType.shuffle => lang.shuffle,
    FABType.play => lang.play,
  };

  IconData toIcon() => switch (this) {
    FABType.none => Broken.status,
    FABType.search => Broken.search_normal,
    FABType.shuffle => Broken.shuffle,
    FABType.play => Broken.play_cricle,
  };
}

extension YTHomePagesL10n on YTHomePages {
  String toText() => switch (this) {
    YTHomePages.home => lang.home,
    YTHomePages.notifications => lang.notifications,
    YTHomePages.channels => lang.channels,
    YTHomePages.playlists => lang.playlists,
    // YTHomePages.userplaylists: '${lang.playlists} (${lang.youtube})',
    YTHomePages.downloads => lang.downloads,
  };

  IconData toIcon() => switch (this) {
    YTHomePages.home => Broken.home_1,
    YTHomePages.notifications => Broken.notification_bing,
    YTHomePages.channels => Broken.profile_2user,
    YTHomePages.playlists => Broken.music_library_2,
    // YTHomePages.userplaylists: Broken.music_dashboard,
    YTHomePages.downloads => Broken.import,
  };
}

extension TrackSearchFilterL10n on TrackSearchFilter {
  String toText() => switch (this) {
    TrackSearchFilter.filename => lang.fileName,
    TrackSearchFilter.folder => lang.folder,
    TrackSearchFilter.title => lang.title,
    TrackSearchFilter.album => lang.album,
    TrackSearchFilter.artist => lang.artist,
    TrackSearchFilter.albumartist => lang.albumArtist,
    TrackSearchFilter.genre => lang.genre,
    TrackSearchFilter.composer => lang.composer,
    TrackSearchFilter.comment => lang.comment,
    TrackSearchFilter.year => lang.year,
    TrackSearchFilter.lyrics => lang.lyrics,
  };
}

extension VibrationTypeL10n on VibrationType {
  String toText() => switch (this) {
    VibrationType.none => lang.none,
    VibrationType.vibration => lang.vibration,
    VibrationType.haptic_feedback => lang.hapticFeedback,
  };

  IconData toIcon() => switch (this) {
    VibrationType.none => Broken.slash,
    VibrationType.vibration => Broken.alarm,
    VibrationType.haptic_feedback => Broken.wind_2,
  };
}

extension ReplayGainTypeL10n on ReplayGainType {
  String toText() => switch (this) {
    ReplayGainType.off => lang.none,
    ReplayGainType.platform_default => lang.defaultLabel,
    ReplayGainType.loudness_enhancer => lang.loudnessEnhancer,
    ReplayGainType.volume => lang.volume,
  };
}

extension LibraryImageSourceL10n on LibraryImageSource {
  String toText() => switch (this) {
    LibraryImageSource.local => lang.local,
    LibraryImageSource.lastfm => 'last.fm',
  };

  IconData toIcon() => switch (this) {
    LibraryImageSource.local => Broken.music_library_2,
    LibraryImageSource.lastfm => Broken.cloud,
  };
}

extension SetMusicAsActionL10n on SetMusicAsAction {
  String toText() => switch (this) {
    SetMusicAsAction.ringtone => lang.ringtone,
    SetMusicAsAction.notification => lang.notification,
    SetMusicAsAction.alarm => lang.alarm,
  };
}

extension PlaylistAddDuplicateActionL10n on PlaylistAddDuplicateAction {
  String toText() => switch (this) {
    PlaylistAddDuplicateAction.justAddEverything => lang.addAll,
    PlaylistAddDuplicateAction.addAllAndRemoveOldOnes => lang.addAllAndRemoveOldOnes,
    PlaylistAddDuplicateAction.addOnlyMissing => lang.addOnlyMissing,
    PlaylistAddDuplicateAction.mergeAndSortByAddedDate => '${lang.merge} + ${lang.sortBy}: ${lang.dateAdded}',
    PlaylistAddDuplicateAction.deleteAndCreateNewPlaylist => '${lang.deletePlaylist} + ${lang.createNewPlaylist}',
  };
}

extension YTSeekActionModeL10n on YTSeekActionMode {
  String toText() => switch (this) {
    YTSeekActionMode.none => lang.none,
    YTSeekActionMode.minimizedMiniplayer => lang.minimizedMiniplayer,
    YTSeekActionMode.expandedMiniplayer => lang.expandedMiniplayer,
    YTSeekActionMode.all => lang.all,
  };
}

extension CommentsSortTypeL10n on CommentsSortType {
  String toText() => switch (this) {
    CommentsSortType.top => lang.top,
    CommentsSortType.newest => lang.newest,
  };
}

extension ChannelNotificationsL10n on ChannelNotifications {
  String toText() => switch (this) {
    ChannelNotifications.all => lang.all,
    ChannelNotifications.personalized => lang.personalized,
    ChannelNotifications.none => lang.none,
  };
}

extension YTVisibleShortPlacesL10n on YTVisibleShortPlaces {
  String toText() => switch (this) {
    YTVisibleShortPlaces.homeFeed => lang.home,
    YTVisibleShortPlaces.relatedVideos => lang.relatedVideos,
    YTVisibleShortPlaces.history => lang.history,
    YTVisibleShortPlaces.search => lang.search,
  };
}

extension YTVisibleMixesPlacesL10n on YTVisibleMixesPlaces {
  String toText() => switch (this) {
    YTVisibleMixesPlaces.homeFeed => lang.home,
    YTVisibleMixesPlaces.relatedVideos => lang.relatedVideos,
    YTVisibleMixesPlaces.search => lang.search,
  };
}

extension PlaylistPrivacyL10n on PlaylistPrivacy {
  String toText() => switch (this) {
    PlaylistPrivacy.public => lang.public,
    PlaylistPrivacy.unlisted => lang.unlisted,
    PlaylistPrivacy.private => lang.private,
  };
}

extension DownloadNotificationsL10n on DownloadNotifications {
  String toText() => switch (this) {
    DownloadNotifications.disableAll => lang.disableAll,
    DownloadNotifications.showAll => lang.showAll,
    DownloadNotifications.showFailedOnly => lang.showFailedOnly,
  };
}

extension PlayerRepeatModeL10n on PlayerRepeatMode {
  IconData toIcon() => switch (this) {
    PlayerRepeatMode.none => Broken.repeate_music,
    PlayerRepeatMode.one => Broken.repeate_one,
    PlayerRepeatMode.all => Broken.repeat,
    PlayerRepeatMode.allShuffle => Broken.shuffle,
    PlayerRepeatMode.forNtimes => Broken.status,
  };
}

extension ThemeModeL10n on ThemeMode {
  IconData toIcon() => switch (this) {
    ThemeMode.light => Broken.sun_1,
    ThemeMode.dark => Broken.moon,
    ThemeMode.system => Broken.autobrightness,
  };
}
