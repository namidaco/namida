// by claude
import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart' show TextTrack;
import 'package:lrc/lrc.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/subtitle_track.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

/// who draws the current subtitle.
enum SubtitleRenderMode {
  /// nothing selected.
  none,

  /// the player draws it itself, mpv with libass keeps the original ass styling & positioning.
  playerInternal,

  /// the player reports the current cue text, see [Subtitles.playerText].
  playerText,

  /// parsed on our side, see [Subtitles.currentSubtitle].
  lrc,
}

/// tracks come from 3 places: the player demuxer (embedded), sidecar files next to local media,
/// and youtube captions. the player owns whatever selection it was given and re-applies it on
/// reloads, so this controller only decides *what* to select and never re-applies on its own.
///
/// the player keeps reporting the previous item's embedded tracks until the new one loads, and
/// those reports can even land after the new item started loading, so nothing embedded is trusted
/// blindly: a selection is dropped as soon as the player reports a list that doesn't carry it.
class Subtitles {
  static Subtitles get inst => _instance;
  static final Subtitles _instance = Subtitles._internal();
  Subtitles._internal();

  /// lyrics-style parsed subtitle, only used when [renderMode] is [SubtitleRenderMode.lrc].
  final currentSubtitle = Rxn<Lrc>();

  /// sidecar files/embedded/youtube in that order, null until the item was looked up.
  final availableTracks = Rxn<List<SubtitleTrack>>();

  final selectedTrack = Rxn<SubtitleTrack>();

  final renderMode = SubtitleRenderMode.none.obs;

  /// cheap heuristic, tells wether the button should be displayed at all.
  final canHaveSubtitles = false.obs;

  /// a selection is being applied.
  final isLoading = false.obs;

  RxBaseCore<String?> get playerText => Player.inst.subtitleText;

  static const _fetchTimeout = Duration(seconds: 20);

  Playable? _currentItem;

  /// invalidates in-flight selections.
  int _operationId = 0;

  /// invalidates in-flight lookups.
  int _discoveryId = 0;

  /// embedded tracks reported by the player for the current item.
  List<TextTrack>? _playerTracks;

  /// sidecar files or youtube captions, null until looked up.
  List<SubtitleTrack>? _itemTracks;

  /// the player was given a selection, it has to be told to drop it on item change.
  bool _playerHoldsSelection = false;

  /// what the player reported for the previous item, telling it to drop its selection makes it
  /// report them once more. cleared once it reports anything else.
  List<TextTrack>? _staleTracks;

  void initialize() {
    YoutubeInfoController.current.currentYTStreams.addListener(_onYTStreamsChanged);
    VideoController.inst.currentVideo.addListener(_onLocalVideoChanged);
    Player.inst.textTracks.addListener(_onPlayerTextTracksChanged);
  }

  Future<void> onItemChange(Playable item) async {
    _reset(item);
    canHaveSubtitles.value = _canItemHaveSubtitles(item);
    if (canHaveSubtitles.value && settings.enableSubtitles.value) await _discoverItemTracks(item);
  }

  /// toggles subtitles globally, auto selecting for the current item when possible.
  Future<void> toggleEnabled() async {
    if (settings.enableSubtitles.value) {
      _deselect();
      return;
    }
    settings.save(enableSubtitles: true);
    final item = _currentItem;
    if (item == null) return;

    if (_itemTracks == null) {
      await _discoverItemTracks(item);
    } else {
      _maybeAutoSelect();
    }

    // if (selectedTrack.value == null && _allTracks().isEmpty) {
    //   snackyy(
    //     message: lang.noSubtitlesFound,
    //     top: false,
    //     icon: Broken.subtitle,
    //   );
    // }
  }

  /// used by the picker, looks up without selecting anything.
  Future<List<SubtitleTrack>> ensureDiscovered() async {
    final existing = availableTracks.value;
    if (existing != null) return existing;
    final item = _currentItem;
    if (item == null) return [];
    await _discoverItemTracks(item);
    return availableTracks.value ?? _allTracks();
  }

  /// image based embedded tracks need a player that draws subtitles itself.
  bool isTrackSupported(SubtitleTrack track) {
    if (track is! SubtitleTrackPlayer) return true;
    if (!track.textTrack.isSupported) return false;
    return !track.isBitmap || Player.inst.rendersSubtitlesInternally;
  }

  Future<void> selectTrack(SubtitleTrack? track) async {
    if (track == null) {
      _deselect();
      return;
    }
    if (!isTrackSupported(track)) {
      snackyy(
        message: "${lang.failed}: ${track.displayName}",
        top: false,
        icon: Broken.subtitle,
      );
      return;
    }
    if (!settings.enableSubtitles.value) settings.save(enableSubtitles: true);
    _promoteLanguage(track.languageCode);
    await _apply(track, ++_operationId, notifyFailure: true);
  }

  // ------------------------ state ------------------------

  void _reset(Playable item) {
    _operationId++;
    _discoveryId++;
    _currentItem = item;
    _staleTracks = _playerTracks;
    _playerTracks = null;
    _itemTracks = null;
    currentSubtitle.value = null;
    availableTracks.value = null;
    selectedTrack.value = null;
    renderMode.value = SubtitleRenderMode.none;
    isLoading.value = false;
    _clearPlayerSelection();
  }

  void _deselect() {
    _operationId++;
    selectedTrack.value = null;
    currentSubtitle.value = null;
    renderMode.value = SubtitleRenderMode.none;
    isLoading.value = false;
    if (settings.enableSubtitles.value) settings.save(enableSubtitles: false);
    _clearPlayerSelection();
  }

  void _clearPlayerSelection() {
    if (!_playerHoldsSelection) return;
    _playerHoldsSelection = false;
    Player.inst.setTextTrack(null).ignoreError();
  }

  /// the embedded selection no longer exists in the player, auto selection will run again once it reports tracks.
  void _dropPlayerSelection() {
    _operationId++;
    selectedTrack.value = null;
    renderMode.value = SubtitleRenderMode.none;
    isLoading.value = false;
    _clearPlayerSelection();
  }

  /// sidecar files first, then embedded, then youtube captions.
  List<SubtitleTrack> _allTracks() {
    final itemTracks = _itemTracks;
    final playerTracks = _playerTracks;
    final tracks = <SubtitleTrack>[];
    final itemTracksFirst = _currentItem is! YoutubeID;
    if (itemTracksFirst && itemTracks != null) tracks.addAll(itemTracks);
    if (playerTracks != null) {
      for (final t in playerTracks) {
        tracks.add(SubtitleTrackPlayer(t));
      }
    }
    if (!itemTracksFirst && itemTracks != null) tracks.addAll(itemTracks);
    return tracks;
  }

  void _rebuildAvailable() {
    availableTracks.value = _itemTracks == null ? null : _allTracks();
  }

  void _maybeAutoSelect() {
    if (!settings.enableSubtitles.value) return;
    if (selectedTrack.value != null) return;
    final best = _pickByLanguagePriority(_allTracks());
    if (best == null) return;
    _apply(best, ++_operationId, notifyFailure: false).ignoreError();
  }

  // ------------------------ listeners ------------------------

  void _onPlayerTextTracksChanged() {
    final tracks = Player.inst.textTracks.value;
    final selected = selectedTrack.value;

    if (tracks == null || tracks.isEmpty) {
      _staleTracks = null;
      _playerTracks = null;
      // -- null is a new source, an empty list is also reported while the same source gets remuxed.
      if (tracks == null && selected is SubtitleTrackPlayer) _dropPlayerSelection();
      _rebuildAvailable();
      return;
    }

    final staleTracks = _staleTracks;
    if (staleTracks != null) {
      if (_sameTrackList(tracks, staleTracks)) return;
      _staleTracks = null;
    }

    _playerTracks = tracks;
    canHaveSubtitles.value = true;
    if (selected is SubtitleTrackPlayer) {
      final fresh = tracks.firstWhereEff((t) => SubtitleTrackPlayer.idOf(t) == selected.playerTrackId);
      if (fresh == null || !_sameTrack(fresh, selected.textTrack)) _dropPlayerSelection();
    }
    _rebuildAvailable();

    final item = _currentItem;
    if (item != null && _itemTracks == null && settings.enableSubtitles.value) {
      _discoverItemTracks(item);
    } else {
      _maybeAutoSelect();
    }
  }

  void _onYTStreamsChanged() {
    final item = _currentItem;
    if (item is! YoutubeID) return;
    final streams = YoutubeInfoController.current.currentYTStreams.value;
    if (streams == null || streams.videoId != item.id) return;

    if (streams.captions.isEmpty) {
      if (_playerTracks == null) canHaveSubtitles.value = false;
      return;
    }
    canHaveSubtitles.value = true;

    final itemTracks = _itemTracks;
    if (itemTracks == null) {
      if (settings.enableSubtitles.value) _discoverItemTracks(item);
    } else if (itemTracks.isEmpty) {
      _discoverItemTracks(item);
    }
  }

  void _onLocalVideoChanged() {
    final item = _currentItem;
    if (item is! Selectable) return;

    if (_localMediaPaths(item.track).isNotEmpty) canHaveSubtitles.value = true;
    if (_itemTracks == null) return;

    // -- sidecar files depend on the media path
    if (settings.enableSubtitles.value) {
      _discoverItemTracks(item);
    } else {
      _discoveryId++;
      _itemTracks = null;
      _rebuildAvailable();
    }
  }

  // ------------------------ applying ------------------------

  Future<void> _apply(SubtitleTrack track, int opId, {required bool notifyFailure}) async {
    selectedTrack.value = track;
    currentSubtitle.value = null;
    renderMode.value = SubtitleRenderMode.none;
    isLoading.value = true;
    try {
      SubtitleRenderMode? mode;
      try {
        mode = await _applyToPlayer(track, opId);
      } catch (_) {}
      if (opId != _operationId) return;
      if (mode == null) {
        selectedTrack.value = null;
        if (notifyFailure) {
          snackyy(
            message: "${lang.failed}: ${track.displayName}",
            top: false,
            isError: true,
            icon: Broken.subtitle,
          );
        }
        return;
      }
      renderMode.value = mode;
    } finally {
      if (opId == _operationId) isLoading.value = false;
    }
  }

  /// null when the track couldn't be loaded.
  Future<SubtitleRenderMode?> _applyToPlayer(SubtitleTrack track, int opId) async {
    if (track is SubtitleTrackPlayer) {
      _playerHoldsSelection = true;
      await Player.inst.setTextTrack(track.playerTrackId);
      return Player.inst.rendersSubtitlesInternally ? SubtitleRenderMode.playerInternal : SubtitleRenderMode.playerText;
    }

    // -- a sidecar file or a fetched youtube caption
    File? file;
    try {
      file = await track.ensureLocalFile().timeout(_fetchTimeout);
    } catch (_) {}
    if (opId != _operationId || file == null) return null;

    if (Player.inst.rendersSubtitlesInternally) {
      _playerHoldsSelection = true;
      final loaded = await Player.inst.setExternalSubtitle(file.path);
      if (opId != _operationId) return null;
      if (loaded) return SubtitleRenderMode.playerInternal;
      // -- the player dropped whatever it had, the file gets drawn by us instead
      _playerHoldsSelection = false;
    }

    // -- drawn by us, the player has no business decoding an embedded one anymore
    _clearPlayerSelection();

    String content = '';
    try {
      content = await file.readAsString();
    } catch (_) {}
    if (opId != _operationId) return null;

    final lrc = content.isEmpty ? null : content.parseLRC();
    if (lrc == null) return null;
    currentSubtitle.value = lrc;
    return SubtitleRenderMode.lrc;
  }

  // ------------------------ lookup ------------------------

  bool _canItemHaveSubtitles(Playable item) {
    if (item is YoutubeID) {
      final streams = YoutubeInfoController.current.currentYTStreams.value;
      if (streams == null || streams.videoId != item.id) return true; // unknown yet -> assume yes
      return streams.captions.isNotEmpty;
    } else if (item is Selectable) {
      return _localMediaPaths(item.track).isNotEmpty;
    }
    return false;
  }

  /// local files that could carry subtitles next to them, the track itself when it is a
  /// video file, and the local video currently matched to it.
  List<String> _localMediaPaths(Track track) {
    final paths = <String>[];

    void addIfValid(String? path) {
      if (path == null || path.isEmpty) return;
      if (path.startsWith('http')) return;
      if (paths.contains(path)) return;
      if (path.startsWith(AppDirs.VIDEOS_CACHE)) return;
      if (!NamidaFileExtensionsWrapper.video.isPathValid(path)) return;
      paths.add(path);
    }

    addIfValid(track.path);
    addIfValid(VideoController.inst.currentVideo.value?.path);
    return paths;
  }

  Future<void> _discoverItemTracks(Playable item) async {
    final discoveryId = ++_discoveryId;
    final tracks = await _discover(item);
    if (discoveryId != _discoveryId) return;

    _itemTracks = tracks;
    if (tracks.isNotEmpty) canHaveSubtitles.value = true;
    _rebuildAvailable();
    _maybeAutoSelect();
  }

  Future<List<SubtitleTrack>> _discover(Playable item) async {
    if (item is YoutubeID) {
      return _discoverYoutube(item.id, YoutubeInfoController.current.currentYTStreams.value);
    } else if (item is Selectable) {
      return _discoverSidecarFiles(item.track);
    }
    return [];
  }

  List<SubtitleTrack> _discoverYoutube(String videoId, VideoStreamsResult? streams) {
    if (streams == null || streams.videoId != videoId) return [];
    final captions = streams.captions;
    if (captions.isEmpty) return [];
    return captions
        .map(
          (e) => SubtitleTrackYoutube(
            videoId: videoId,
            caption: e,
          ),
        )
        .toList();
  }

  static const _sidecarExtensions = ['srt', 'vtt', 'ass', 'ssa', 'sbv'];

  Future<List<SubtitleTrack>> _discoverSidecarFiles(Track track) async {
    final tracks = <SubtitleTrack>[];
    for (final mediaPath in _localMediaPaths(track)) {
      final dirPath = mediaPath.getDirectoryPath;
      final fwoe = mediaPath.getFilenameWOExt;
      for (final ext in _sidecarExtensions) {
        final file = FileParts.join(dirPath, '$fwoe.$ext');
        if (await file.existsAndValid()) tracks.add(SubtitleTrackFile(file));
      }
    }
    return tracks;
  }

  static bool _sameTrack(TextTrack a, TextTrack b) =>
      SubtitleTrackPlayer.idOf(a) == SubtitleTrackPlayer.idOf(b) && a.label == b.label && a.language == b.language && a.mimeType == b.mimeType;

  static bool _sameTrackList(List<TextTrack> a, List<TextTrack> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_sameTrack(a[i], b[i])) return false;
    }
    return true;
  }

  // ------------------------ language ------------------------

  SubtitleTrack? _pickByLanguagePriority(List<SubtitleTrack> tracks) {
    if (tracks.isEmpty) return null;

    for (final code in _languagePriority()) {
      SubtitleTrack? autoGeneratedMatch;
      for (final track in tracks) {
        final trackCode = track.languageCode;
        if (trackCode.isEmpty) continue;
        if (!_codesMatch(trackCode, code)) continue;
        if (!isTrackSupported(track)) continue;
        if (track.isAutoGenerated) {
          autoGeneratedMatch ??= track;
        } else {
          return track;
        }
      }
      if (autoGeneratedMatch != null) return autoGeneratedMatch;
    }

    return null;
  }

  Iterable<String> _languagePriority() sync* {
    final saved = settings.subtitlesLanguages.value;
    if (saved.isNotEmpty) {
      yield* saved;
      return;
    }
    final appLanguageCode = settings.language.value?.codeOnly;
    if (appLanguageCode != null && appLanguageCode.isNotEmpty) yield appLanguageCode;
    yield 'en';
  }

  static bool _codesMatch(String a, String b) {
    if (a == b) return true;
    // -- containers use 3 letter codes (`eng`) while the app & youtube use 2 letter ones (`en`)
    final aBase = SubtitleTrack.normalizeLanguageCode(a);
    return aBase.isNotEmpty && aBase == SubtitleTrack.normalizeLanguageCode(b);
  }

  void _promoteLanguage(String code) {
    if (code.isEmpty) return;
    final current = settings.subtitlesLanguages.value;
    if (current.firstOrNull == code) return;
    final newList = <String>[code, ...current.where((e) => e != code)];
    settings.save(subtitlesLanguages: newList);
  }
}
