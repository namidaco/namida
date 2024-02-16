// ignore_for_file: non_constant_identifier_names, depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

typedef Playlist = GeneralPlaylist<TrackWithDate>;

class PlaylistController extends PlaylistManager<TrackWithDate> {
  static PlaylistController get inst => _instance;
  static final PlaylistController _instance = PlaylistController._internal();
  PlaylistController._internal();

  final RxBool canReorderTracks = false.obs;

  void addNewPlaylist(
    String name, {
    List<Track> tracks = const <Track>[],
    int? creationDate,
    String comment = '',
    List<String> moods = const [],
    String? m3uPath,
  }) async {
    final newTracks = tracks.mapped((e) => TrackWithDate(
          dateAdded: currentTimeMS,
          track: e,
          source: TrackSource.local,
        ));
    super.addNewPlaylistRaw(
      name,
      tracks: (playlistID) => newTracks,
      creationDate: creationDate,
      comment: comment,
      moods: moods,
      m3uPath: m3uPath,
    );
  }

  void addTracksToPlaylist(Playlist playlist, List<Track> tracks, {TrackSource source = TrackSource.local}) async {
    Iterable<TrackWithDate> convertTracks(List<Track> trs) => trs.map((e) => TrackWithDate(
          dateAdded: currentTimeMS,
          track: e,
          source: source,
        ));
    final oldTracksList = List<TrackWithDate>.from(playlist.tracks); // for undo
    int addedTracksLength = tracks.length;

    if (playlist.tracks.any((element) => tracks.contains(element.track))) {
      TrackWithDate convertTrack(Track e) => TrackWithDate(
            dateAdded: currentTimeMS,
            track: e,
            source: source,
          );
      final action = await _showDuplicatedDialogAction();
      switch (action) {
        case PlaylistAddDuplicateAction.justAddEverything:
          playlist.tracks.addAll(convertTracks(tracks));
          break;
        case PlaylistAddDuplicateAction.addAllAndRemoveOldOnes:
          final currentTracks = <Track, List<int>>{};
          playlist.tracks.loop((e, index) => currentTracks.addForce(e.track, index));

          final indicesToRemove = <int>[];
          tracks.loop((e, _) {
            // -- removing same tracks existing in playlist
            final indexesInPlaylist = currentTracks[e];
            if (indexesInPlaylist != null) {
              indicesToRemove.addAll(indexesInPlaylist);
            }
          });
          indicesToRemove.sortByReverse((e) => e);
          indicesToRemove.loop((indexToRemove, _) => playlist.tracks.removeAt(indexToRemove));
          playlist.tracks.addAll(convertTracks(tracks));
          break;
        case PlaylistAddDuplicateAction.addOnlyMissing:
          final currentTracks = <Track, int>{};
          playlist.tracks.loop((e, index) => currentTracks[e.track] = index);
          tracks.loop((e, _) {
            if (currentTracks[e] == null) {
              playlist.tracks.add(convertTrack(e));
            } else {
              addedTracksLength--;
            }
          });

          break;
        default:
          addedTracksLength = 0;
          return;
      }
    } else {
      playlist.tracks.addAll(convertTracks(tracks));
    }

    snackyy(
      message: "${lang.ADDED} ${addedTracksLength.displayTrackKeyword}",
      displaySeconds: 2,
      button: TextButton(
        onPressed: () async {
          updatePropertyInPlaylist(playlist.name, tracks: oldTracksList, modifiedDate: currentTimeMS);
          Get.closeAllSnackbars();
        },
        child: Text(lang.UNDO),
      ),
    );

    super.addTracksToPlaylistRaw(playlist, [] /* added manually */);
  }

  Future<PlaylistAddDuplicateAction?> _showDuplicatedDialogAction() async {
    final action = Rxn<PlaylistAddDuplicateAction>();
    await NamidaNavigator.inst.navigateDialog(
      onDismissing: () {
        action.close();
      },
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: lang.CONFIRM,
        actions: [
          TextButton(
            onPressed: () {
              action.value = null;
              NamidaNavigator.inst.closeDialog();
            },
            child: Text(lang.CANCEL),
          ),
          Obx(
            () => NamidaButton(
              enabled: action.value != null,
              text: lang.CONFIRM,
              onPressed: NamidaNavigator.inst.closeDialog,
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.DUPLICATED_ITEMS_ADDING,
                style: Get.textTheme.displayMedium,
              ),
              const SizedBox(height: 12.0),
              Column(
                children: PlaylistAddDuplicateAction.values
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: Obx(
                          () => ListTileWithCheckMark(
                            active: action.value == e,
                            title: e.toText(),
                            onTap: () => action.value = e,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    return action.value;
  }

  Future<bool> favouriteButtonOnPressed(Track track) async {
    return await super.toggleTrackFavourite(
      newTrack: TrackWithDate(dateAdded: currentTimeMS, track: track, source: TrackSource.local),
      identifyBy: (tr) => tr.track == track,
    );
  }

  Future<void> replaceTracksDirectory(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    String getNewPath(String old) => old.replaceFirst(oldDir, newDir);

    await replaceTheseTracksInPlaylists(
      (e) {
        final trackPath = e.track.path;
        if (ensureNewFileExists) {
          if (!File(getNewPath(trackPath)).existsSync()) return false;
        }
        final firstC = forThesePathsOnly != null ? forThesePathsOnly.contains(e.track.path) : true;
        final secondC = trackPath.startsWith(oldDir);
        return firstC && secondC;
      },
      (old) => TrackWithDate(
        dateAdded: old.dateAdded,
        track: Track(getNewPath(old.track.path)),
        source: old.source,
      ),
    );
  }

  Future<void> replaceTrackInAllPlaylists(Track oldTrack, Track newTrack) async {
    await replaceTheseTracksInPlaylists(
      (e) => e.track == oldTrack,
      (old) => TrackWithDate(
        dateAdded: old.dateAdded,
        track: newTrack,
        source: old.source,
      ),
    );
  }

  /// Returns number of generated tracks.
  int generateRandomPlaylist() {
    final rt = NamidaGenerator.inst.getRandomTracks();
    if (rt.isEmpty) return 0;

    final l = playlistsMap.keys.where((name) => name.startsWith(k_PLAYLIST_NAME_AUTO_GENERATED)).length;
    addNewPlaylist('$k_PLAYLIST_NAME_AUTO_GENERATED ${l + 1}', tracks: rt.toList());

    return rt.length;
  }

  Future<void> exportPlaylistToM3UFile(Playlist playlist, String path) async {
    await _saveM3UPlaylistToFile.thready({
      'path': path,
      'tracks': playlist.tracks,
      'infoMap': _pathsM3ULookup,
    });
  }

  Future<void> prepareAllPlaylists() async {
    await super.prepareAllPlaylistsFile();
    // -- preparing all playlist is awaited, for cases where
    // -- similar name exists, so m3u overrides it
    // -- this can produce in an outdated playlist version in cache
    // -- which will be seen if the m3u file got deleted/renamed
    await prepareM3UPlaylists();
  }

  Future<List<Track>> readM3UFiles(Set<String> filesPaths) async {
    final resBoth = await _parseM3UPlaylistFiles.thready({
      'paths': filesPaths,
      'libraryTracks': allTracksInLibrary,
      'backupDirPath': AppDirs.M3UBackup,
    });
    final infoMap = resBoth['infoMap'] as Map<String, String?>;
    _pathsM3ULookup.addAll(infoMap);

    final paths = resBoth['paths'] as Map<String, (String, List<Track>)>;
    final listy = <Track>[];
    for (final p in paths.entries) {
      listy.addAll(p.value.$2);
    }

    return listy;
  }

  Future<void> prepareM3UPlaylists({Set<String> forPaths = const {}}) async {
    final allAvailableDirectories = await Indexer.inst.getAvailableDirectories(strictNoMedia: false);

    late final Set<String> allPaths;
    if (forPaths.isNotEmpty) {
      allPaths = forPaths;
    } else {
      final parameters = {
        'allAvailableDirectories': allAvailableDirectories,
        'directoriesToExclude': <String>[],
        'extensions': kM3UPlaylistsExtensions,
        'respectNoMedia': false,
      };
      final mapResult = await getFilesTypeIsolate.thready(parameters);
      allPaths = mapResult['allPaths'] as Set<String>;
    }

    final resBoth = await _parseM3UPlaylistFiles.thready({
      'paths': allPaths,
      'libraryTracks': allTracksInLibrary,
      'backupDirPath': AppDirs.M3UBackup,
    });
    final paths = resBoth['paths'] as Map<String, (String, List<Track>)>;
    final infoMap = resBoth['infoMap'] as Map<String, String?>;

    for (final e in paths.entries) {
      final plName = e.key;
      final m3uPath = e.value.$1;
      final trs = e.value.$2;
      final creationDate = File(m3uPath).statSync().creationDate.millisecondsSinceEpoch;
      PlaylistController.inst.addNewPlaylist(plName, tracks: trs, m3uPath: m3uPath, creationDate: creationDate);
    }
    _pathsM3ULookup = infoMap;
  }

  /// saves each track m3u info for writing back
  var _pathsM3ULookup = <String, String?>{}; // {trackPath: EXTINFO}

  static Map _parseM3UPlaylistFiles(Map params) {
    final paths = params['paths'] as Set<String>;
    final allTracksPaths = params['libraryTracks'] as List<Track>; // used as a fallback lookup
    final backupDirPath = params['backupDirPath'] as String; // used as a backup for newly found m3u files.

    final all = <String, (String, List<Track>)>{};
    final infoMap = <String, String?>{};
    for (final path in paths) {
      final file = File(path);
      final filename = file.path.getFilenameWOExt;
      final fullPaths = <String>[];
      String? latestInfo;
      for (final line in file.readAsLinesSync()) {
        if (line.startsWith("#")) {
          latestInfo = line;
        } else {
          String fullPath = line; // maybe is absolute path

          if (!File(fullPath).existsSync()) {
            fullPath = p.join(file.path.getDirectoryPath, line); // maybe was relative
          }

          if (!File(fullPath).existsSync()) {
            final maybeTrack = allTracksPaths.firstWhereEff((e) => e.path.endsWith(line)); // no idea, trying to get from library
            if (maybeTrack != null) fullPath = maybeTrack.path;
          }

          fullPaths.add(fullPath);
          infoMap[fullPath] = latestInfo;
        }
      }
      final tracks = fullPaths.map((e) => e.toTrack()).toList();
      if (all[filename] == null) {
        all[filename] = (path, tracks);
      } else {
        // -- filename already exists
        all[file.path.formatPath()] = (path, tracks);
      }

      latestInfo = null; // resetting info between each file looping
    }
    // -- copying newly found m3u files as a backup
    for (final m3u in all.entries) {
      final backupFile = File("$backupDirPath${m3u.key}.m3u");
      if (!backupFile.existsSync()) {
        File(m3u.value.$1).copySync(backupFile.path);
      }
    }
    return {
      'paths': all,
      'infoMap': infoMap,
    };
  }

  static Future<void> _saveM3UPlaylistToFile(Map params) async {
    final path = params['path'] as String;
    final tracks = params['tracks'] as List<TrackWithDate>;
    final infoMap = params['infoMap'] as Map<String, String?>;
    final relative = params['relative'] as bool? ?? true;

    final file = File(path);
    file.deleteIfExistsSync();
    file.createSync(recursive: true);
    final sink = file.openWrite(mode: FileMode.append);
    sink.write('#EXTM3U\n');
    for (final trwd in tracks) {
      final tr = trwd.track;
      final trext = tr.track.toTrackExt();
      final infoLine = infoMap[tr.path] ?? '#EXTINF:${trext.duration},${trext.originalArtist} - ${trext.title}';
      final pathLine = relative ? tr.path.replaceFirst(path.getDirectoryPath, '') : tr.path;
      sink.write("$infoLine\n$pathLine\n");
    }

    await sink.flush();
    await sink.close();
  }

  Future<bool> _requestM3USyncPermission() async {
    if (settings.enableM3USync.value) return true;

    final didRead = false.obs;

    await NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        didRead.close();
      },
      dialog: CustomBlurryDialog(
        actions: [
          const CancelButton(),
          const SizedBox(width: 8.0),
          Obx(
            () => NamidaButton(
              enabled: didRead.value,
              text: lang.CONFIRM,
              onPressed: () {
                settings.save(enableM3USync: true);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          )
        ],
        title: lang.NOTE,
        child: Column(
          children: [
            Text(
              '${lang.ENABLE_M3U_SYNC}?\n\n${lang.ENABLE_M3U_SYNC_NOTE_1}\n\n${lang.ENABLE_M3U_SYNC_NOTE_2.replaceFirst('_PLAYLISTS_BACKUP_PATH_', AppDirs.M3UBackup)}\n\n${lang.WARNING.toUpperCase()}: ${lang.ENABLE_M3U_SYNC_SUBTITLE}',
              style: Get.textTheme.displayMedium,
            ),
            const SizedBox(height: 12.0),
            Obx(
              () => ListTileWithCheckMark(
                icon: Broken.info_circle,
                active: didRead.value,
                title: lang.I_READ_AND_AGREE,
                onTap: () => didRead.value = !didRead.value,
              ),
            ),
          ],
        ),
      ),
    );
    return settings.enableM3USync.value;
  }

  Timer? writeTimer;

  @override
  FutureOr<void> onPlaylistTracksChanged(Playlist playlist) async {
    final m3uPath = playlist.m3uPath;
    if (m3uPath != null && await File(m3uPath).exists()) {
      final didAgree = await _requestM3USyncPermission();

      if (didAgree) {
        // -- using IOSink sometimes produces errors when succesively opened/closed
        // -- not ideal for cases where u constantly add/remove tracks
        // -- so we save with only 2 seconds limit.
        writeTimer?.cancel();
        writeTimer = null;
        writeTimer = Timer(const Duration(seconds: 2), () async {
          await _saveM3UPlaylistToFile.thready({
            'path': m3uPath,
            'tracks': playlist.tracks,
            'infoMap': _pathsM3ULookup,
          });
        });
      }
    }
  }

  @override
  FutureOr<bool> canSavePlaylist(Playlist playlist) {
    return playlist.m3uPath == null; // dont save m3u-based playlists;
  }

  @override
  void sortPlaylists() => SearchSortController.inst.sortMedia(MediaType.playlist);

  @override
  String get playlistsDirectory => AppDirs.PLAYLISTS;

  @override
  String get favouritePlaylistPath => AppPaths.FAVOURITES_PLAYLIST;

  @override
  String get EMPTY_NAME => lang.PLEASE_ENTER_A_NAME;

  @override
  String get NAME_CONTAINS_BAD_CHARACTER => lang.NAME_CONTAINS_BAD_CHARACTER;

  @override
  String get SAME_NAME_EXISTS => lang.PLEASE_ENTER_A_DIFFERENT_NAME;

  @override
  String get NAME_IS_NOT_ALLOWED => lang.PLEASE_ENTER_A_DIFFERENT_NAME;

  @override
  String get PLAYLIST_NAME_FAV => k_PLAYLIST_NAME_FAV;

  @override
  String get PLAYLIST_NAME_HISTORY => k_PLAYLIST_NAME_HISTORY;

  @override
  String get PLAYLIST_NAME_MOST_PLAYED => k_PLAYLIST_NAME_MOST_PLAYED;

  @override
  Map<String, dynamic> itemToJson(TrackWithDate item) => item.toJson();

  @override
  FutureOr<bool> canRemovePlaylist(GeneralPlaylist<TrackWithDate> playlist) {
    // navigate back in case the current route is this playlist
    final lastPage = NamidaNavigator.inst.currentRoute;
    if (lastPage?.route == RouteType.SUBPAGE_playlistTracks) {
      if (lastPage?.name == playlist.name) {
        NamidaNavigator.inst.popPage();
      }
    }
    return true;
  }

  @override
  Future<Map<String, GeneralPlaylist<TrackWithDate>>> prepareAllPlaylistsFunction() async {
    return await _readPlaylistFilesCompute.thready(playlistsDirectory);
  }

  @override
  Future<GeneralPlaylist<TrackWithDate>?> prepareFavouritePlaylistFunction() async {
    return await _prepareFavouritesFile.thready(favouritePlaylistPath);
  }

  @override
  Future<void> prepareDefaultPlaylistsFile() async {
    HistoryController.inst.prepareHistoryFile();
    await super.prepareDefaultPlaylistsFile();
  }

  static Future<Playlist?> _prepareFavouritesFile(String path) async {
    try {
      final response = File(path).readAsJsonSync();
      return Playlist.fromJson(response, (itemJson) => TrackWithDate.fromJson(itemJson));
    } catch (_) {}
    return null;
  }

  static Future<Map<String, Playlist>> _readPlaylistFilesCompute(String path) async {
    final map = <String, Playlist>{};
    for (final f in Directory(path).listSyncSafe()) {
      if (f is File) {
        try {
          final response = f.readAsJsonSync();
          final pl = Playlist.fromJson(response, (itemJson) => TrackWithDate.fromJson(itemJson));
          map[pl.name] = pl;
        } catch (e) {
          continue;
        }
      }
    }
    return map;
  }
}
