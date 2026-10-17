// by claude

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:history_manager/history_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/file_parts.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/bookmarks_controller.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/party/party_connection.dart';
import 'package:namida/controller/party/party_controller.dart';
import 'package:namida/controller/party/party_player_binder.dart';
import 'package:namida/controller/party/party_protocol.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/window_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/main_page_wrapper.dart';
import 'package:namida/packages/miniplayer.dart';
import 'package:namida/ui/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/dialogs/bookmarks_sheet.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/create_smart_playlist_dialog.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/dialogs/playlist_tags_manager_dialog.dart';
import 'package:namida/ui/dialogs/queue_insertion_dialogs.dart';
import 'package:namida/ui/dialogs/set_lrc_dialog.dart';
import 'package:namida/ui/dialogs/setting_dialog_with_text_field.dart';
import 'package:namida/ui/dialogs/track_advanced_dialog.dart';
import 'package:namida/ui/dialogs/track_clear_dialog.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';
import 'package:namida/ui/dialogs/track_listens_dialog.dart';
import 'package:namida/ui/dialogs/track_stats_dialog.dart';
import 'package:namida/ui/pages/about_page.dart';
import 'package:namida/ui/pages/artists_map_page.dart';
import 'package:namida/ui/pages/discover_page.dart';
import 'package:namida/ui/pages/lyrics_editor_page.dart';
import 'package:namida/ui/pages/party_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/pages/subpages/indexer_missing_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/smart_playlist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/your_year_page.dart';
import 'package:namida/ui/pages/sync_manager_page.dart';
import 'package:namida/ui/pages/wide_screen_player_page.dart';
import 'package:namida/ui/widgets/settings/indexer_settings.dart';
import 'package:namida/ui/widgets/settings/youtube_settings.dart';
import 'package:namida/ui/widgets/settings_search_bar.dart';
import 'package:namida/ui/widgets/stats.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/pages/user/youtube_account_manage_page.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/pages/yt_history_page.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/pages/youtube_home_view.dart';
import 'package:namida/youtube/yt_utils.dart';

part 'screenshots_driver.party.dart';

/// runs the scenes in `<user data>/screenshots/scenes.json` once per theme, captures each into `out/<theme>/<id>.png` then exits.
/// only active in builds made with `--dart-define=NAMIDA_SCREENSHOTS=true`.
class ScreenshotsDriver {
  static final inst = ScreenshotsDriver._();
  ScreenshotsDriver._();

  final boundaryKey = GlobalKey();

  /// set while a full page is captured, the app then lays out this tall and the whole list fits one capture.
  final _tallLayoutHeight = ValueNotifier<double?>(null);

  /// the window shows and nothing runs, F12 captures the current screen into `out/manual`.
  late final isInteractive = Platform.environment['NAMIDA_SCREENSHOTS_INTERACTIVE'] == '1';

  static const _kSceneMinSettleMS = 900;
  static const _kInteractivePixelRatio = 2.0;

  late final _rootDir = FileParts.joinPath(AppDirs.USER_DATA, 'screenshots');
  late final _logFile = File(FileParts.joinPath(_rootDir, 'out', 'log.txt'));

  /// settings a scene changed with `set`, restored once it is captured.
  final _sceneSettingsToRestore = <_SettingsValues>[];

  final _party = _ScreenshotsParty();

  /// `deviceCapture` also asks the host for a capture of the whole screen (status bar included, through adb).
  bool _isDeviceCapture = false;

  /// android shots go without system bars, the designs draw a slim status bar of their own.
  bool get hidesSystemBars => _hidesSystemBars;
  bool _hidesSystemBars = false;

  Future<void> run() async {
    if (isInteractive) {
      HardwareKeyboard.instance.addHandler(_onInteractiveKey);
      return;
    }
    // -- online fetches would replace the seeded youtube caches, scenes that need network ask for it
    ConnectivityController.inst.setForcedOffline(true);
    final errors = <String>[];
    final shots = <String>[];
    try {
      final scenesFile = File(FileParts.joinPath(_rootDir, 'scenes.json'));
      final config = await scenesFile.readAsJson() as Map<String, dynamic>;
      final platformOverrides = (config['platformOverrides'] as Map<String, dynamic>?)?[Platform.operatingSystem] as Map<String, dynamic>?;
      if (platformOverrides != null) config.addAll(platformOverrides);
      await _logFile.create(recursive: true);
      await _waitForLibrary();

      final pixelRatio = (config['pixelRatio'] as num?)?.toDouble() ?? 2.0;
      final themes = (config['themes'] as List?)?.cast<String>() ?? const ['light'];
      // -- scenes without their own `themes` skip the passes left out here, like a pitch black one for a few scenes
      final defaultSceneThemes = (config['sceneThemes'] as List?)?.cast<String>() ?? themes;
      final defaultWindow = config['window'] as Map<String, dynamic>?;
      final setupSteps = (config['setup'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final scenes = (config['scenes'] as List).cast<Map<String, dynamic>>();
      _isDeviceCapture = config['deviceCapture'] as bool? ?? false;
      _hidesSystemBars = Platform.isAndroid && !_isDeviceCapture;
      if (_hidesSystemBars) await NamidaNavigator.setSystemUIImmersiveMode(true);

      for (final step in setupSteps) {
        await _runStep(step);
      }
      _sceneSettingsToRestore.clear();
      await _resetUi();

      for (final themeName in themes) {
        _applyTheme(themeName);
        await _settle(_kSceneMinSettleMS);

        for (final scene in scenes) {
          final id = scene['id'] as String;
          final sceneThemes = (scene['themes'] as List?)?.cast<String>() ?? defaultSceneThemes;
          if (!sceneThemes.contains(themeName)) continue;
          final scenePlatforms = (scene['platforms'] as List?)?.cast<String>();
          if (scenePlatforms != null && !scenePlatforms.contains(Platform.operatingSystem)) continue;
          try {
            final window = scene['window'] as Map<String, dynamic>? ?? defaultWindow;
            await _applyWindow(window);
            await _resetUi();
            final steps = (scene['steps'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
            for (final step in steps) {
              await _runStep(step);
            }
            final settleMS = scene['settleMS'] as int? ?? _kSceneMinSettleMS;
            await _settle(settleMS);
            // -- true for the whole page, a number for that many screens of it
            final fullPage = scene['fullPage'];
            if (fullPage == true || fullPage is num) {
              final maxScreens = fullPage is num ? fullPage.toDouble() : double.infinity;
              await _captureFullPage(FileParts.joinPath(_rootDir, 'out', themeName, id), pixelRatio, maxScreens);
            } else {
              final outPathWithoutExtension = FileParts.joinPath(_rootDir, 'out', themeName, id);
              await _capture('$outPathWithoutExtension.png', pixelRatio);
              await _saveCaptureRegions(outPathWithoutExtension, _collectCaptureRegions(pixelRatio));
              if (_isDeviceCapture) await _requestDeviceCapture('$themeName/$id.device.png');
            }
            shots.add('$themeName/$id');
            await _log('shot $themeName/$id');
          } catch (e, st) {
            errors.add('$themeName/$id: $e');
            await _log('error $themeName/$id: $e\n$st');
          } finally {
            await _party.leave();
            _restoreSceneSettings();
          }
        }
      }
    } catch (e, st) {
      errors.add('$e');
      await _log('fatal: $e\n$st');
    }

    final doneFile = File(FileParts.joinPath(_rootDir, 'out', 'done.json'));
    await doneFile.writeAsJson({'shots': shots, 'errors': errors});
    await Namida.disposeAllResourcesAndExit();
  }

  /// `black` is the dark theme with pitch black on.
  void _applyTheme(String themeName) {
    final isPitchBlack = themeName == 'black';
    final namedThemeMode = ThemeMode.values.getEnum(themeName) ?? ThemeMode.light;
    final themeMode = isPitchBlack ? ThemeMode.dark : namedThemeMode;
    settings.transaction(() {
      settings.themeMode.save(themeMode);
      settings.pitchBlack.save(isPitchBlack);
    });
  }

  bool _onInteractiveKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.f12) return false;
    _captureManually();
    return true;
  }

  Future<void> _captureManually() async {
    final isPitchBlack = settings.pitchBlack.value;
    final themeName = isPitchBlack ? 'black' : settings.themeMode.value.name;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outPath = FileParts.joinPath(_rootDir, 'out', 'manual', '${themeName}_$timestamp.png');
    await _capture(outPath, _kInteractivePixelRatio);
  }

  static const _kDeviceCaptureTimeoutMS = 30000;
  static const _kDeviceCapturePollMS = 100;

  /// the host polls for the request file, captures the screen into [relativePath] and deletes it.
  Future<void> _requestDeviceCapture(String relativePath) async {
    final requestFile = File(FileParts.joinPath(_rootDir, 'out', 'request.txt'));
    await requestFile.writeAsString(relativePath);
    var waitedMS = 0;
    while (await requestFile.exists()) {
      if (waitedMS >= _kDeviceCaptureTimeoutMS) throw StateError('device capture timed out: $relativePath');
      await Future.delayed(const Duration(milliseconds: _kDeviceCapturePollMS));
      waitedMS += _kDeviceCapturePollMS;
    }
  }

  Future<void> _log(String message) async {
    final line = '${DateTime.now().toIso8601String()} $message\n';
    await _logFile.writeAsString(line, mode: FileMode.append);
  }

  Future<void> _waitForLibrary() async {
    await HistoryController.inst.waitForHistoryAndMostPlayedLoad;
    while (Indexer.inst.isIndexing.value || allTracksInLibrary.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 250));
    }
    // -- artworks and colors are extracted lazily right after indexing
    await Future.delayed(const Duration(seconds: 3));
    await _log('library ready: ${allTracksInLibrary.length} tracks');
  }

  Future<void> _applyWindow(Map<String, dynamic>? window) async {
    if (window == null || WindowController.instance == null) return;
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;
    final width = (window['width'] as num).toDouble();
    final height = (window['height'] as num).toDouble();
    final contentSize = Size(width, height);
    if (_getViewSize(view) == contentSize) return;
    await windowManager.setSize(contentSize);
    await _settle(_kSceneMinSettleMS);
    // -- the window size includes its invisible resize borders, the content is what gets captured
    final viewSize = _getViewSize(view);
    final framesWidth = width - viewSize.width;
    final framesHeight = height - viewSize.height;
    if (framesWidth == 0 && framesHeight == 0) return;
    final windowSize = Size(width + framesWidth, height + framesHeight);
    await windowManager.setSize(windowSize);
    await _settle(_kSceneMinSettleMS);
  }

  Size _getViewSize(ui.FlutterView view) => view.physicalSize / view.devicePixelRatio;

  static const _kMaxPopsPerReset = 12;
  static const _kPopWaitMS = 350;

  Future<void> _resetUi() async {
    final navigator = NamidaNavigator.inst;
    if (navigator.isInFullScreen) await navigator.exitFullScreen();
    await navigator.closeAllDialogs();
    navigator.popAllMenus();
    // -- these root layers keep a flag that only `back` resets
    var layerPops = 0;
    while ((navigator.isInSoundControlSubpage || navigator.isInWideScreenPlayerPage) && layerPops < _kMaxPopsPerReset) {
      await navigator.back(waitForAnimation: true);
      layerPops++;
    }
    var rootPops = 0;
    while (navigator.rootNavHasOpenedPages && rootPops < _kMaxPopsPerReset) {
      await navigator.popRoot();
      await Future.delayed(const Duration(milliseconds: _kPopWaitMS));
      rootPops++;
    }
    navigator.innerDrawerKey.currentState?.close();
    final search = ScrollSearchController.inst;
    if (search.isGlobalSearchMenuShown.value) search.toggleSearch(instant: true);
    if (search.searchTextEditingController.text.isNotEmpty) search.resetSearch();
    SettingsSearchController.inst.closeSearch();
    SelectedTracksController.inst.clearEverything();
    MiniPlayerController.inst.snapToMini(haptic: false);
    MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(false);
    ConnectivityController.inst.setForcedOffline(true);
    var pops = 0;
    while (navigator.currentWidgetStack.length > 1 && pops < _kMaxPopsPerReset) {
      await navigator.popPage(fromMainPage: true, waitForAnimation: true);
      pops++;
    }
  }

  static const _kSettleIdlePolls = 3;
  static const _kSettlePollMS = 100;
  static const _kSettleTimeoutMS = 4000;

  Future<void> _settle(int minMS) async {
    await Future.delayed(Duration(milliseconds: minMS));
    var idlePolls = 0;
    var elapsedMS = 0;
    while (idlePolls < _kSettleIdlePolls && elapsedMS < _kSettleTimeoutMS) {
      await Future.delayed(const Duration(milliseconds: _kSettlePollMS));
      elapsedMS += _kSettlePollMS;
      // -- a playing track keeps scheduling frames, so only images are awaited
      final hasPendingImages = PaintingBinding.instance.imageCache.pendingImageCount > 0;
      idlePolls = hasPendingImages ? 0 : idlePolls + 1;
    }
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _capture(String outPath, double pixelRatio) async {
    final renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) throw StateError('capture boundary is not mounted');
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) throw StateError('png encoding failed');
    final file = await File(outPath).create(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List());
  }

  /// the search fields focus themselves, the keyboard never shows in a capture yet it still lifts what floats over it.
  Future<void> _hideKeyboard() async {
    await _settle(_kSceneMinSettleMS);
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  static const _kFullPageSettleMS = 400;
  static const _kTallLayoutMaxPasses = 6;

  /// the app laid out as tall as the list, so the page shows the way it scrolls (one background, overlays once).
  /// lazy lists find more of their content with every taller pass.
  Future<void> _captureFullPage(String outPathWithoutExtension, double pixelRatio, double maxScreens) async {
    final screenHeight = (boundaryKey.currentContext!.findRenderObject() as RenderBox).size.height;
    final maxHeight = screenHeight * maxScreens;
    _findScrollPosition().jumpTo(0);
    var height = screenHeight;
    for (var pass = 0; pass < _kTallLayoutMaxPasses && height < maxHeight; pass++) {
      final scrollExtent = _findScrollPosition().maxScrollExtent;
      if (scrollExtent <= 0) break;
      height = (height + scrollExtent).withMaximum(maxHeight);
      _tallLayoutHeight.value = height;
      await _settle(_kFullPageSettleMS);
    }
    try {
      final tallPage = (windowHeight: screenHeight, page: _findPageScrollable().box);
      await _capture('$outPathWithoutExtension.png', pixelRatio);
      await _saveCaptureRegions(outPathWithoutExtension, _collectCaptureRegions(pixelRatio, tallPage: tallPage));
    } finally {
      _tallLayoutHeight.value = null;
      await _settle(_kFullPageSettleMS);
    }
  }

  /// what's on screen in the capture's pixels, from one walk: the settings tiles (the docs put hotspots and previews on
  /// them) and every text (the translations match their strings to the shot with them).
  /// below the window of a [tallPage] nothing can hit test, there only what's inside the grown page counts, the pages
  /// kept alive under it grew too.
  _CaptureRegions _collectCaptureRegions(double pixelRatio, {_TallPage? tallPage}) {
    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderBox) return (tiles: const [], texts: const []);
    final screenRect = Offset.zero & boundary.size;
    final tiles = <_CaptureRegion>[];
    final texts = <_CaptureRegion>{};
    final elements = _collectVisibleElements(
      (element) => element.widget is SettingEntryTile || (element is RenderObjectElement && element.renderObject is RenderParagraph),
    );
    for (final element in elements) {
      final renderObject = element.renderObject;
      if (renderObject is! RenderBox || renderObject.size.isEmpty) continue;
      final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (!screenRect.overlaps(rect)) continue;
      final isBeyondWindow = tallPage != null && rect.center.dy > tallPage.windowHeight;
      // -- a dialog or the miniplayer over a tile or text would take it
      final isShown = isBeyondWindow ? _isWithin(renderObject, tallPage.page) : _isHittable(element);
      if (!isShown) continue;
      final pixelRect = Rect.fromLTRB(rect.left * pixelRatio, rect.top * pixelRatio, rect.right * pixelRatio, rect.bottom * pixelRatio);
      if (renderObject is RenderParagraph) {
        // -- the whole text, an ellipsis only cuts what is painted
        final text = renderObject.text.toPlainText(includeSemanticsLabels: false, includePlaceholders: false);
        if (_isReadableText(text)) texts.add(_CaptureRegion.of(text, pixelRect));
      } else {
        tiles.add(_CaptureRegion.of((element.widget as SettingEntryTile).entry.title(), pixelRect));
      }
    }
    return (tiles: tiles, texts: texts.toList());
  }

  static bool _isWithin(RenderObject renderObject, RenderObject ancestor) {
    RenderObject? current = renderObject;
    while (current != null) {
      if (identical(current, ancestor)) return true;
      current = current.parent;
    }
    return false;
  }

  static const _kPrivateUseStart = 0xE000;
  static const _kPrivateUseEnd = 0xF8FF;

  /// icons are texts too, of icon font glyphs in the private use area.
  static bool _isReadableText(String text) {
    for (final rune in text.runes) {
      final isGlyph = rune >= _kPrivateUseStart && rune <= _kPrivateUseEnd;
      if (!isGlyph && String.fromCharCode(rune).trim().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _saveCaptureRegions(String outPathWithoutExtension, _CaptureRegions regions) async {
    if (regions.tiles.isNotEmpty) {
      final tilesJson = regions.tiles.map((tile) => tile.toJson(labelKey: 'title')).toList();
      await File('$outPathWithoutExtension.tiles.json').writeAsJson({'tiles': tilesJson});
    }
    if (regions.texts.isNotEmpty) {
      final textsJson = regions.texts.map((text) => text.toJson(labelKey: 'text')).toList();
      await File('$outPathWithoutExtension.texts.json').writeAsJson({'texts': textsJson});
    }
  }

  Future<void> _runStep(Map<String, dynamic> step) async {
    final action = step['do'] as String;
    final name = step['name'] as String?;
    switch (action) {
      case 'tab':
        final tab = LibraryTab.values.getEnum(name) ?? LibraryTab.home;
        ScrollSearchController.inst.animatePageController(tab);
      case 'album':
        final albumIdentifier = _resolveAlbum(name, step['track'] as String?) ?? _findBiggestAlbum();
        final albumTracks = Indexer.inst.mainMapAlbums.value[albumIdentifier];
        final albumName = albumIdentifier?.album;
        await _playFromPage(step, albumTracks, QueueSource.album(albumIdentifier, albumName));
        NamidaOnTaps.inst.onAlbumTap(albumIdentifier);
      case 'artist':
        final artistName = name ?? '';
        final artistTracks = Indexer.inst.mainMapArtists.value[artistName];
        await _playFromPage(step, artistTracks, QueueSource.artist(artistName));
        NamidaOnTaps.inst.onArtistTap(artistName, MediaType.artist);
      case 'genre':
        final genreName = _resolveGenre(name);
        final genreTracks = Indexer.inst.mainMapGenres.value[genreName];
        await _playFromPage(step, genreTracks, QueueSource.genre(genreName));
        NamidaOnTaps.inst.onGenreTap(genreName);
      case 'playlist':
        final playlistName = name ?? k_PLAYLIST_NAME_FAV;
        final playlistTracks = PlaylistController.inst.getPlaylist(playlistName)?.tracks.map((e) => e.track).toFixedList();
        await _playFromPage(step, playlistTracks, QueueSource.playlist(playlistName));
        NamidaOnTaps.inst.onNormalPlaylistTap(playlistName);
      case 'history':
        NamidaOnTaps.inst.onHistoryPlaylistTap();
      case 'mostPlayed':
        final range = MostPlayedTimeRange.values.getEnum(step['range'] as String?);
        if (range != null) _rememberSettings(null, const ['mostPlayedTimeRange', 'mostPlayedCustomDateRange_v2']);
        NamidaOnTaps.inst.onMostPlayedPlaylistTap(mptr: range);
      case 'folder':
        final scanDirectory = settings.directoriesToScan.value.first.sourceRaw;
        final folderPath = name == null ? scanDirectory : FileParts.joinPath(scanDirectory, name);
        FoldersController.tracksAndVideos.stepIn(Folder.explicit(folderPath));
      case 'widePlayer':
        NamidaNavigator.inst.navigateToRoot(const WideScreenPlayerPage(), transition: Transition.fade);
      case 'settings':
        final page = SettingSubpageEnum.values.getEnum(name);
        if (page == null) {
          NamidaNavigator.inst.navigateTo(const SettingsPage());
        } else {
          SettingsSearchController.inst.openSubpage(page);
        }
      case 'settingsSearch':
        final query = step['text'] as String? ?? '';
        NamidaNavigator.inst.navigateTo(const SettingsPage());
        await _settle(_kSceneMinSettleMS);
        NamidaSettingSearchBar.open();
        SettingsSearchController.inst.onSearchChanged(query);
        final isModifiedOnly = step['modified'] as bool? ?? false;
        if (isModifiedOnly) SettingsSearchController.inst.toggleModifiedOnly();
        await _hideKeyboard();
      case 'search':
        final query = step['text'] as String? ?? '';
        final search = ScrollSearchController.inst;
        search.showSearchMenu();
        search.searchBarKey.currentState?.openCloseSearchBar(forceOpen: true);
        search.searchLocal(query);
        await _hideKeyboard();
      case 'select':
        final from = step['from'] as int? ?? 0;
        final to = step['to'] as int? ?? 5;
        SelectedTracksController.inst.selectAllTracks(range: (from, to));
        final isExpanded = step['expanded'] as bool? ?? false;
        SelectedTracksController.inst.isMenuMinimized.value = !isExpanded;
      case 'play':
        await _play(step);
      case 'dismissMiniplayer':
        await Player.inst.clearQueue();
      case 'ytSection':
        final section = YTHomePages.values.getEnum(name) ?? YTHomePages.home;
        YouTubeHomeView.openSection(section);
      case 'ytPlay':
        final videoId = step['id'] as String;
        final video = YoutubeID(id: videoId, playlistID: null);
        await Player.inst.playOrPause(0, [video], QueueSourceYoutubeID.ytPlayerQueue, canAskBeforeReplacing: false);
        final isExpanded = step['expanded'] as bool? ?? true;
        if (isExpanded) YTUtils.expandMiniplayer();
        final seekSeconds = step['seek'] as num?;
        if (seekSeconds != null) await _seek(seekSeconds);
      case 'seek':
        final seconds = step['seconds'] as num? ?? 0;
        await _seek(seconds);
      case 'miniplayer':
        switch (name) {
          case 'expanded':
            MiniPlayerController.inst.snapToExpanded(haptic: false);
          case 'queue':
            MiniPlayerController.inst.snapToQueue(haptic: false);
          default:
            MiniPlayerController.inst.snapToMini(haptic: false);
        }
      case 'videoControls':
        VideoController.inst.videoControlsKey.currentState?.showControlsBriefly();
        VideoController.inst.videoControlsKeyFullScreen.currentState?.showControlsBriefly();
      case 'online':
        ConnectivityController.inst.setForcedOffline(false);
      case 'party':
        await _party.host(step, _findTrack);
        const NamidaPartyPage().navigate();
      case 'partyReact':
        await _party.react(step);
      case 'trackDialog':
        final track = _resolveTrack(step);
        NamidaDialogs.inst.showTrackDialog(track, source: QueueSource.allTracks);
      case 'open':
        await _open(step);
      case 'set':
        _setSettings(step);
      case 'tap':
        final holdMS = step['holdMS'] as int? ?? _kTapHoldMS;
        await _tapText(step, holdMS);
      case 'longPress':
        await _tapText(step, _kLongPressHoldMS);
      case 'scrollTo':
        final element = await _scrollUntilTextBuilt(step);
        final alignment = (step['alignment'] as num?)?.toDouble() ?? 0.15;
        await Scrollable.ensureVisible(element, alignment: alignment);
      case 'scrollBy':
        final pixels = (step['pixels'] as num).toDouble();
        final position = _findScrollPosition();
        final target = (position.pixels + pixels).withMaximum(position.maxScrollExtent);
        position.jumpTo(target);
      case 'bookmark':
        await BookmarksController.inst.addAtCurrentPosition();
      case 'wait':
        final waitMS = step['ms'] as int? ?? 500;
        await Future.delayed(Duration(milliseconds: waitMS));
      default:
        throw ArgumentError.value(action, 'do', 'unknown step');
    }
    final settleMS = step['settleMS'] as int? ?? 400;
    await _settle(settleMS);
  }

  /// pages and dialogs reachable through public calls, by `name`.
  Future<void> _open(Map<String, dynamic> step) async {
    final name = step['name'] as String;
    switch (name) {
      case 'stats':
        const StatsPage(isYoutube: false).navigate();
      case 'discover':
        const DiscoverPage().navigate();
      case 'artistsMap':
        final focusArtist = step['artist'] as String?;
        ArtistsMapPage(type: MediaType.artist, focusArtist: focusArtist).navigate();
      case 'syncManager':
        const NamidaSyncManagerPage().navigate();
      case 'about':
        const AboutPage().navigate();
      case 'membership':
        const YoutubeManageSubscriptionPage().navigate();
      case 'yourYear':
        final year = step['year'] as int? ?? DateTime.now().year;
        YourYearPage(year: year).navigate();
      case 'missingTracks':
        const IndexerMissingTracksSubpage().navigate();
      case 'queue':
        final queue = QueueController.inst.queuesMap.value.values.firstOrNull;
        if (queue != null) NamidaOnTaps.inst.onQueueTap(queue);
      case 'smartPlaylist':
        final smartPlaylist = _findSmartPlaylist(step['playlist'] as String?);
        if (smartPlaylist != null) SmartPlaylistTracksPage(smartPlaylistWrapper: smartPlaylist).navigate();
      case 'smartEditor':
        final smartPlaylist = _findSmartPlaylist(step['playlist'] as String?);
        NamidaNavigator.inst.navigateDialog(dialog: CreateSmartPlaylistDialog(initialSmartPlaylistWrapper: smartPlaylist));
      case 'smartPlaylistDialog':
        final smartPlaylist = _findSmartPlaylist(step['playlist'] as String?);
        NamidaDialogs.inst.showSmartPlaylistDialog(smartPlaylist);
      case 'queuesClear':
        NamidaOnTaps.inst.onQueuesClearIconTap();
      case 'playerMenu':
        final track = _resolveTrack(step);
        NamidaMiniPlayerTrack.openMenu(null, track);
      case 'askReplace':
        final tracks = _resolveTracks(step);
        Player.inst.playWithOptions(0, tracks, QueueSource.allTracks);
      case 'trackClear':
        final track = _resolveTrack(step);
        final colorScheme = CurrentColor.inst.color;
        showTrackClearDialog([track], colorScheme);
      case 'addFolder':
        const IndexerSettings().promptAddFolderType();
      case 'fontScale':
        showSettingDialogWithTextField(title: lang.fontScale, fontScaleFactor: true);
      case 'lyricsFullscreen':
        Lyrics.inst.lrcViewKey.currentState?.enterFullScreen();
      case 'soundControl':
        NamidaOnTaps.inst.openSoundControl();
      case 'audioPath':
        NamidaOnTaps.inst.openAudioPath();
      case 'sortTracks':
        NamidaOnTaps.inst.onSubPageTracksSortIconTap(MediaType.track);
      case 'sortAlbums':
        NamidaOnTaps.inst.onGroupSortIconTap(MediaType.album);
      case 'advancedPlay':
        showAdvancedPlayDialog(() => allTracksInLibrary, QueueSource.allTracks);
      case 'queueInsertion':
        showQueueInsertionConfigDialog(QueueInsertionType.moreAlbum, title: lang.addMoreFromThisAlbum);
      case 'addTracks':
        TracksAddOnTap().onAddTracksTap(rootContext);
      case 'sleepTimer':
        NamidaDrawer.openSleepTimerDialog(rootContext);
      case 'shortcuts':
        AboutPage.showShortcutsDialog(rootContext);
      case 'drawer':
        NamidaNavigator.inst.toggleDrawer();
      case 'dataSaver':
        YoutubeSettings.openDataSaverConfigureDialog();
      case 'playlistDialog':
        final playlistName = step['playlist'] as String? ?? k_PLAYLIST_NAME_FAV;
        NamidaDialogs.inst.showPlaylistDialog(playlistName);
      case 'playlistTags':
        showPlaylistTagsManagerDialog(PlaylistController.inst);
      case 'albumDialog':
        final albumIdentifier = _resolveAlbum(step['album'] as String?, step['track'] as String?);
        NamidaDialogs.inst.showAlbumDialog(albumIdentifier);
      case 'queueDialog':
        final newestQueueDate = QueueController.inst.queuesMap.value.keys.first;
        NamidaDialogs.inst.showQueueDialog(newestQueueDate);
      case 'artistDialog':
        final artistName = step['artist'] as String? ?? '';
        NamidaDialogs.inst.showArtistDialog(artistName, MediaType.artist);
      case 'trackInfo':
        final track = _resolveTrack(step);
        showTrackInfoDialog(track, true, heroTag: null);
      case 'trackAdvanced':
        final track = _resolveTrack(step);
        final colorScheme = CurrentColor.inst.color;
        showTrackAdvancedDialog(tracks: [track], networkArtworkInfo: null, colorScheme: colorScheme, source: QueueSource.allTracks);
      case 'trackListens':
        final track = _resolveTrack(step);
        showTrackListensDialog(track);
      case 'trackStats':
        final track = _resolveTrack(step);
        showSetTrackStatsDialog(tracks: [track]);
      case 'addToPlaylist':
        final track = _resolveTrack(step);
        showAddToPlaylistDialog([track]);
      case 'tagEditor':
        final tracks = _resolveTracks(step);
        final physicalTracks = tracks.asPhysicalOrError();
        showEditTracksTagsDialog(physicalTracks, null);
      case 'ytLink':
        final track = _resolveTrack(step);
        final colorScheme = CurrentColor.inst.color;
        showSetYTLinkCommentDialog(track, colorScheme);
      case 'lyricsPicker':
        final item = Player.inst.currentItem.value;
        final colorScheme = CurrentColor.inst.color;
        if (item != null) showLRCSetDialog(item, colorScheme);
      case 'lyricsEditor':
        final item = Player.inst.currentItem.value;
        final track = _resolveTrack(step);
        final lyricsFile = File(FileParts.joinPath(AppDirs.LYRICS, '${track.filename}.lrc'));
        final sourceLyrics = await lyricsFile.readAsString();
        if (item != null) LyricsEditorPage.open(item, sourceLyrics: sourceLyrics);
      case 'bookmarks':
        final item = Player.inst.currentItem.value;
        if (item != null) showBookmarksSheet(item);
      case 'ytHistory':
        const YoutubeHistoryPage().navigate();
      case 'ytChannel':
        final channelId = step['channel'] as String;
        YTChannelSubpage(channelID: channelId).navigate();
      case 'ytLocalPlaylist':
        final playlistName = step['playlist'] as String;
        YTNormalPlaylistSubpage(playlistName: playlistName, queueSource: QueueSourceYoutubeID.ytPlaylist(playlistName)).navigate();
      case 'videoFullscreen':
        VideoController.inst.toggleFullScreenVideoView(isLocal: true);
      default:
        throw ArgumentError.value(name, 'name', 'unknown page or dialog');
    }
  }

  void _setSettings(Map<String, dynamic> step) {
    final file = step['file'] as String?;
    final values = step['values'] as Map<String, dynamic>;
    _rememberSettings(file, values.keys);
    _applySettings(file, values);
  }

  void _rememberSettings(String? file, Iterable<String> keys) {
    final storedJson = _getStoredSettingsJson(file);
    final previousValues = {for (final key in keys) key: storedJson[key]};
    _sceneSettingsToRestore.add((file: file, values: previousValues));
  }

  void _restoreSceneSettings() {
    for (final restore in _sceneSettingsToRestore.reversed) {
      _applySettings(restore.file, restore.values);
    }
    _sceneSettingsToRestore.clear();
  }

  Map<String, dynamic> _getStoredSettingsJson(String? file) => switch (file) {
    'player' => settings.player.buildJson(),
    'youtube' => settings.youtube.buildJson(),
    'sync' => settings.sync.buildJson(),
    'extra' => settings.extra.buildJson(),
    _ => settings.buildJson(),
  };

  /// a null value resets that key to its default.
  void _applySettings(String? file, Map<String, dynamic> values) {
    final json = {'_v': 2, ...values};
    switch (file) {
      case 'player':
        settings.player.applyBackupJson(json);
      case 'youtube':
        settings.youtube.applyBackupJson(json);
      case 'sync':
        settings.sync.applyBackupJson(json);
      case 'extra':
        settings.extra.applyBackupJson(json);
      default:
        settings.applyBackupJson(json);
    }
  }

  static const _kTapHoldMS = 60;
  static const _kLongPressHoldMS = 800;
  int _nextPointer = 1;

  /// taps through the gesture arena directly, no os input is involved.
  Future<void> _tapText(Map<String, dynamic> step, int holdMS) async {
    final isIcon = step.containsKey('icon');
    final element = isIcon ? _findIconElement(step) : _findTextElement(step, onlyHittable: true);
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox) throw StateError('no box for ${step['text']}');
    final center = renderObject.size.center(Offset.zero);
    final position = renderObject.localToGlobal(center);
    final viewId = View.of(element).viewId;
    final label = step['text'] ?? step['icon'];
    await _log('tap $label at ${position.dx.round()},${position.dy.round()}');
    final pointer = _nextPointer++;
    final downEvent = PointerDownEvent(viewId: viewId, pointer: pointer, position: position);
    GestureBinding.instance.handlePointerEvent(downEvent);
    await Future.delayed(Duration(milliseconds: holdMS));
    final upEvent = PointerUpEvent(viewId: viewId, pointer: pointer, position: position);
    GestureBinding.instance.handlePointerEvent(upEvent);
  }

  Element _findTextElement(Map<String, dynamic> step, {required bool onlyHittable}) {
    final matches = _collectTextMatches(step, onlyHittable: onlyHittable);
    return _pickMatch(step, matches, step['text'] as String);
  }

  /// lazy lists only build what is near the viewport, so the topmost list pages down until the text is built.
  Future<Element> _scrollUntilTextBuilt(Map<String, dynamic> step) async {
    var matches = _collectTextMatches(step, onlyHittable: false);
    if (matches.isEmpty) {
      final position = _findScrollPosition();
      while (matches.isEmpty && position.pixels < position.maxScrollExtent) {
        position.jumpTo((position.pixels + position.viewportDimension).withMaximum(position.maxScrollExtent));
        await WidgetsBinding.instance.endOfFrame;
        matches = _collectTextMatches(step, onlyHittable: false);
      }
    }
    return _pickMatch(step, matches, step['text'] as String);
  }

  /// [onlyHittable] skips matches that are covered or invisible, a tap on them would land on something else.
  List<Element> _collectTextMatches(Map<String, dynamic> step, {required bool onlyHittable}) {
    final text = step['text'] as String;
    final isContains = step['contains'] as bool? ?? false;
    return _collectVisibleElements((element) {
      final renderObject = element.renderObject;
      if (element is! RenderObjectElement || renderObject is! RenderParagraph) return false;
      final paragraphText = renderObject.text.toPlainText();
      final isMatch = isContains ? paragraphText.contains(text) : paragraphText == text;
      return isMatch && (!onlyHittable || _isHittable(element));
    });
  }

  /// `icon` is a codepoint like `0xe9a5`, from `Broken` in icon_fonts/broken_icons.dart.
  Element _findIconElement(Map<String, dynamic> step) {
    final iconText = step['icon'] as String;
    final codePoint = int.parse(iconText);
    final matches = _collectVisibleElements((element) {
      final widget = element.widget;
      final isMatch = widget is Icon && widget.icon?.codePoint == codePoint;
      return isMatch && _isHittable(element);
    });
    return _pickMatch(step, matches, iconText);
  }

  static const _kHitAncestorMaxScreenFraction = 0.5;

  /// copies kept alive at zero opacity or behind another route still lay out, only the real one wins a hit test at its center.
  /// a card's own ink layer often covers its texts, so a hit on an ancestor smaller than half the screen counts too,
  /// the page sized ancestors a covered copy shares with whatever is on top don't.
  bool _isHittable(Element element) {
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox) return false;
    final center = renderObject.size.center(Offset.zero);
    final position = renderObject.localToGlobal(center);
    final viewId = View.of(element).viewId;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, position, viewId);
    final hitTargets = result.path.map((entry) => entry.target).toSet();
    final screenSize = View.of(element).physicalSize / View.of(element).devicePixelRatio;
    final maxAncestorArea = screenSize.width * screenSize.height * _kHitAncestorMaxScreenFraction;
    RenderObject? current = renderObject;
    while (current is RenderBox && current.hasSize && current.size.width * current.size.height <= maxAncestorArea) {
      if (hitTargets.contains(current)) return true;
      current = current.parent;
    }
    return false;
  }

  static const _kMinScrollableSide = 100.0;

  /// for lazily built lists, where the text to scroll to doesn't exist yet.
  /// the topmost scrollable big enough to be a page or a dialog's list, small ones are chips rows and text fields.
  ScrollPosition _findScrollPosition() => _findPageScrollable().position;

  _PageScrollable _findPageScrollable() {
    final matches = _collectVisibleElements((element) => element is StatefulElement && element.state is ScrollableState);
    for (final element in matches.reversed) {
      final state = element is StatefulElement ? element.state : null;
      final renderObject = element.renderObject;
      if (state is! ScrollableState || renderObject is! RenderBox) continue;
      final size = renderObject.size;
      if (size.width < _kMinScrollableSide || size.height < _kMinScrollableSide) continue;
      return (position: state.position, box: renderObject);
    }
    throw StateError('no scrollable');
  }

  /// in tree order, overlays and newer routes come last.
  List<Element> _collectVisibleElements(bool Function(Element element) test) {
    final matches = <Element>[];
    void visit(Element element) {
      final renderObject = element.renderObject;
      final isLaidOut = renderObject is RenderBox && renderObject.hasSize;
      if (isLaidOut && test(element) && !_isOffstage(renderObject)) matches.add(element);
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    return matches;
  }

  /// `index` picks among the matches, negative counts from the end. the last one by default, the topmost.
  Element _pickMatch(Map<String, dynamic> step, List<Element> matches, String label) {
    if (matches.isEmpty) throw StateError('not found: $label');
    final index = step['index'] as int? ?? -1;
    final resolvedIndex = index < 0 ? matches.length + index : index;
    if (resolvedIndex < 0 || resolvedIndex >= matches.length) throw StateError('no match #$index for $label, found ${matches.length}');
    return matches[resolvedIndex];
  }

  bool _isOffstage(RenderObject renderObject) {
    RenderObject? current = renderObject;
    while (current != null) {
      if (current is RenderOffstage && current.offstage) return true;
      current = current.parent;
    }
    return false;
  }

  SmartPlaylistWrapper? _findSmartPlaylist(String? name) {
    final smartPlaylists = SmartPlaylistsController.inst.smartPlaylistsList.value;
    return smartPlaylists.firstWhereEff((e) => e.value.name == name) ?? smartPlaylists.firstOrNull;
  }

  Track? _findTrack(String? title) {
    if (title == null) return null;
    return allTracksInLibrary.firstWhereEff((e) => e.title == title);
  }

  Track _resolveTrack(Map<String, dynamic> step) {
    final track = _findTrack(step['track'] as String?);
    if (track != null) return track;
    final currentTrack = Player.inst.currentTrack?.track;
    return currentTrack ?? allTracksInLibrary.first;
  }

  /// the biggest genre when [name] is missing, the seed picks genres randomly.
  String _resolveGenre(String? name) {
    final genres = Indexer.inst.mainMapGenres.value;
    if (name != null && genres.containsKey(name)) return name;
    var biggestGenre = '';
    var biggestCount = -1;
    for (final e in genres.entries) {
      if (e.value.length <= biggestCount) continue;
      biggestCount = e.value.length;
      biggestGenre = e.key;
    }
    return biggestGenre;
  }

  List<Track> _resolveTracks(Map<String, dynamic> step) {
    final isFromAlbum = step['fromAlbum'] as bool? ?? false;
    final albumTrackTitle = isFromAlbum ? step['track'] as String? : null;
    final albumIdentifier = _resolveAlbum(step['album'] as String?, albumTrackTitle);
    final albumTracks = Indexer.inst.mainMapAlbums.value[albumIdentifier];
    if (albumTracks != null) return albumTracks;
    final track = _resolveTrack(step);
    return [track];
  }

  /// by name, or the album holding [trackTitle] so scenes survive the seed regrouping albums.
  AlbumIdentifierWrapper? _resolveAlbum(String? name, String? trackTitle) {
    final albums = Indexer.inst.mainMapAlbums.value;
    if (name != null) return albums.keys.firstWhereEff((e) => e.album == name);
    final track = _findTrack(trackTitle);
    if (track == null) return null;
    return albums.entries.firstWhereEff((e) => e.value.contains(track))?.key;
  }

  AlbumIdentifierWrapper? _findBiggestAlbum() {
    AlbumIdentifierWrapper? biggest;
    var biggestCount = 0;
    for (final e in Indexer.inst.mainMapAlbums.value.entries) {
      if (e.value.length <= biggestCount) continue;
      biggestCount = e.value.length;
      biggest = e.key;
    }
    return biggest;
  }

  Future<void> _play(Map<String, dynamic> step) async {
    final isFromAlbum = step['fromAlbum'] as bool? ?? false;
    final albumName = step['album'] as String?;
    final albumTrackTitle = isFromAlbum ? step['track'] as String? : null;
    final albumIdentifier = albumName == null && albumTrackTitle == null ? null : _resolveAlbum(albumName, albumTrackTitle);
    final albumTracks = albumIdentifier == null ? null : Indexer.inst.mainMapAlbums.value[albumIdentifier];
    final tracks = albumTracks ?? allTracksInLibrary;
    final source = albumIdentifier == null ? QueueSource.allTracks : QueueSource.album(albumIdentifier, albumIdentifier.album);
    await _playTracks(step, tracks, source);
  }

  /// pages play their own tracks unless `"play": false`, so the player colors match the page.
  Future<void> _playFromPage(Map<String, dynamic> step, List<Track>? tracks, QueueSource source) async {
    final shouldPlay = step['play'] as bool? ?? true;
    if (!shouldPlay || tracks == null || tracks.isEmpty) return;
    await _playTracks(step, tracks, source);
  }

  Future<void> _playTracks(Map<String, dynamic> step, List<Track> tracks, QueueSource source) async {
    final track = _findTrack(step['track'] as String?);
    final trackIndex = track == null ? -1 : tracks.indexOf(track);
    final stepIndex = step['index'] as int? ?? 0;
    final index = trackIndex >= 0 ? trackIndex : stepIndex;
    final isPlaying = step['playing'] as bool? ?? true;
    await Player.inst.playOrPause(index, tracks, source, startPlaying: isPlaying, canAskBeforeReplacing: false);
    // -- replaying the current item toggles it, the requested state is applied after
    if (isPlaying) {
      await Player.inst.play();
    } else {
      await Player.inst.pause();
    }
    final shouldWaitForVideo = step['video'] as bool? ?? false;
    if (shouldWaitForVideo) await _waitForVideo();
    final seekSeconds = step['seek'] as num?;
    if (seekSeconds != null) await _seek(seekSeconds);
  }

  Future<void> _seek(num seconds) async {
    final seekMS = (seconds * 1000).round();
    final position = Duration(milliseconds: seekMS);
    await Player.inst.seek(position);
  }

  static const _kVideoTimeoutMS = 60000;
  static const _kVideoPollMS = 250;

  Future<void> _waitForVideo() async {
    var waitedMS = 0;
    while (VideoController.inst.currentVideo.value == null && waitedMS < _kVideoTimeoutMS) {
      await Future.delayed(const Duration(milliseconds: _kVideoPollMS));
      waitedMS += _kVideoPollMS;
    }
    final videoPath = VideoController.inst.currentVideo.value?.path;
    await _log('video after ${waitedMS}ms: $videoPath');
  }
}

/// the app's root in screenshots mode: the capture boundary, and a full page capture's taller layout. the tree stays the
/// same with or without one, a reshaped root would remount the whole app.
class ScreenshotsRoot extends StatelessWidget {
  final Widget child;
  const ScreenshotsRoot({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final driver = ScreenshotsDriver.inst;
    return ValueListenableBuilder(
      valueListenable: driver._tallLayoutHeight,
      child: RepaintBoundary(
        key: driver.boundaryKey,
        child: child,
      ),
      builder: (context, tallHeight, boundary) {
        final mediaQuery = MediaQuery.of(context);
        final size = tallHeight == null ? mediaQuery.size : Size(mediaQuery.size.width, tallHeight);
        return OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: tallHeight,
          maxHeight: tallHeight,
          child: MediaQuery(
            data: mediaQuery.copyWith(size: size),
            child: boundary!,
          ),
        );
      },
    );
  }
}

/// a label and its rect, rounded to whole capture pixels so the same text drawn twice in one spot counts once.
class _CaptureRegion {
  final String label;
  final int x;
  final int y;
  final int w;
  final int h;

  const _CaptureRegion(this.label, this.x, this.y, this.w, this.h);

  factory _CaptureRegion.of(String label, Rect rect) => _CaptureRegion(label, rect.left.round(), rect.top.round(), rect.width.round(), rect.height.round());

  Map<String, Object> toJson({required String labelKey}) => {labelKey: label, 'x': x, 'y': y, 'w': w, 'h': h};

  @override
  bool operator ==(Object other) => other is _CaptureRegion && other.label == label && other.x == x && other.y == y && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(label, x, y, w, h);
}

typedef _SettingsValues = ({String? file, Map<String, dynamic> values});
typedef _CaptureRegions = ({List<_CaptureRegion> tiles, List<_CaptureRegion> texts});
typedef _TallPage = ({double windowHeight, RenderObject page});
typedef _PageScrollable = ({ScrollPosition position, RenderBox box});
