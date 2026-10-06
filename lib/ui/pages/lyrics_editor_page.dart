// lyrics editor by claude: line & word sync, drafts, undo, text mode, timeline
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';

import 'package:lrc/lrc.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_base.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/shortcuts_manager/shortcuts_manager.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/spectrum_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/lyrics_lrc_parsed_view.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';

part 'lyrics_editor_page.dialogs.dart';
part 'lyrics_editor_page.document.dart';
part 'lyrics_editor_page.timeline.dart';
part 'lyrics_editor_page.widgets.dart';

class LyricsEditorPage extends StatefulWidget {
  final Playable item;
  final LrcSearchUtils lrcUtils;
  final String sourceLyrics;

  const LyricsEditorPage._({
    required this.item,
    required this.lrcUtils,
    required this.sourceLyrics,
  });

  /// [sourceLyrics] can be synced, plain or empty, a draft left for [item] is restored instead.
  static Future<void> open(Playable item, {required String sourceLyrics}) async {
    final lrcUtils = await LrcSearchUtils.fromPlayable(item);
    if (lrcUtils == null) return;
    final page = LyricsEditorPage._(
      item: item,
      lrcUtils: lrcUtils,
      sourceLyrics: sourceLyrics,
    );
    await NamidaNavigator.inst.navigateToRoot(page);
  }

  @override
  State<LyricsEditorPage> createState() => _LyricsEditorPageState();
}

class _LyricsEditorPageState extends State<LyricsEditorPage> with SingleTickerProviderStateMixin {
  static const _kRowExtent = 50.0;
  static const _kWideLayoutMinWidth = 820.0;
  static const _kSeekStepMS = 2000;
  static const _kNudgeStepMS = 50;
  static const _kPlayLineFallbackMS = 5000;

  /// a seek to a line start can land a ms before it, the lyrics view uses the same.
  static const _kLineMatchToleranceMS = 5;
  static const _kFollowAfterUserScrollMS = 3000;
  static const _kMaxHistory = 200;
  static const _kDraftSaveDelay = Duration(seconds: 1);
  static const _kSpeeds = [1.0, 0.75, 0.5];

  final _doc = _LyricsDocument();

  /// bumped on every document change.
  final _revision = 0.obs;
  final _selectedIndex = 0.obs;
  final _wordIndex = 0.obs;
  final _playingIndex = (-1).obs;
  final _positionMS = 0.obs;
  final _isWordMode = false.obs;
  final _isCurrentItem = false.obs;
  final _hasDraft = false.obs;
  final _isSaving = false.obs;
  final _canUndo = false.obs;
  final _canRedo = false.obs;
  final _isLoading = true.obs;

  late final _rowStateListenable = Listenable.merge([_selectedIndex, _playingIndex]);
  late final _selectionListenable = Listenable.merge([_selectedIndex, _wordIndex, _revision]);

  final _undoStack = <List<_EditorLine>>[];
  final _redoStack = <List<_EditorLine>>[];
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  late final _ticker = createTicker(_onTick);

  late final Track? _embeddableTrack = _getEmbeddableTrack();
  late final File _draftFile = _getDraftFile();

  Timer? _draftTimer;
  Timer? _nudgeRepeatTimer;
  bool _hasUnsavedChanges = false;
  bool _didPreview = false;
  bool _didChangeSpeed = false;
  int _durationMS = 0;
  int? _playLineEndMS;
  int _lastUserScrollMS = 0;

  ({int line, int word})? _pressedWord;

  static String _formatMS(int ms) => LrcLine.formatTimestamp(Duration(milliseconds: ms));

  static String _singerLabel(int person) => person == 0 ? 'bg' : 'v$person';

  Track? _getEmbeddableTrack() {
    final item = widget.item;
    return item is Selectable ? item.track.asPhysical() : null;
  }

  /// one draft per item and starting lyrics, so editing other lyrics or adding new ones starts clean.
  File _getDraftFile() {
    final cacheName = widget.lrcUtils.cachedLRCFile.path.getFilenameWOExt;
    final sourceKey = widget.sourceLyrics.toFastHashKey();
    return FileParts.join(AppDirs.LYRICS_DRAFTS, '${cacheName}_$sourceKey.json');
  }

  @override
  void initState() {
    super.initState();
    _onCurrentItemChanged();
    Player.inst.currentItem.addListener(_onCurrentItemChanged);
    Player.inst.isPlaying.addListener(_onPlayingChanged);
    Player.inst.nowPlayingPosition.addListener(_onPlayerPositionChanged);
    FocusManager.instance.addListener(_onPrimaryFocusChanged);
    _load();
  }

  @override
  void dispose() {
    Player.inst.currentItem.removeListener(_onCurrentItemChanged);
    Player.inst.isPlaying.removeListener(_onPlayingChanged);
    Player.inst.nowPlayingPosition.removeListener(_onPlayerPositionChanged);
    FocusManager.instance.removeListener(_onPrimaryFocusChanged);
    _ticker.dispose();
    _nudgeRepeatTimer?.cancel();
    if (_draftTimer != null) _writeDraft();
    if (_didChangeSpeed) Player.inst.restoreUserSpeed();
    if (_didPreview && _isCurrentItem.value) Lyrics.inst.updateLyrics(widget.item);
    _scrollController.dispose();
    _focusNode.dispose();
    _revision.close();
    _selectedIndex.close();
    _wordIndex.close();
    _playingIndex.close();
    _positionMS.close();
    _isWordMode.close();
    _isCurrentItem.close();
    _hasDraft.close();
    _isSaving.close();
    _canUndo.close();
    _canRedo.close();
    _isLoading.close();
    super.dispose();
  }

  Future<void> _load() async {
    _durationMS = await _resolveDurationMS();
    final draftJson = await _draftFile.readAsJson();
    if (!mounted) return;
    if (draftJson is Map) {
      _doc.loadJson(draftJson.cast<String, dynamic>());
      _hasDraft.value = true;
    } else {
      _doc.loadSource(widget.sourceLyrics, durationMS: _durationMS);
    }
    _isWordMode.value = _doc.hasTimedWords();
    _refreshDerived();
    _isLoading.value = false;
    if (_doc.lines.isEmpty) _showTextDialog();
  }

  /// the player duration is what playback compares the `[length:]` tag to.
  Future<int> _resolveDurationMS() async {
    if (_isCurrentItem.value) {
      final playerDurationMS = Player.inst.currentItemDuration.value?.inMilliseconds ?? 0;
      if (playerDurationMS > 0) return playerDurationMS;
    }
    return widget.lrcUtils.getItemDurationMS();
  }

  // ==================== playback ====================

  bool _isSameItem(Playable? current) {
    final item = widget.item;
    if (item is Selectable && current is Selectable) return item.track == current.track;
    if (item is YoutubeID && current is YoutubeID) return item.id == current.id;
    return false;
  }

  void _onCurrentItemChanged() {
    final isCurrent = _isSameItem(Player.inst.currentItem.value);
    _isCurrentItem.value = isCurrent;
    _onPlayingChanged();
  }

  bool _isPlayingItem() => _isCurrentItem.value && Player.inst.isPlaying.value;

  void _onPlayingChanged() {
    final isPlaying = _isPlayingItem();
    if (isPlaying) {
      if (!_ticker.isActive) _ticker.start();
      return;
    }
    if (_ticker.isActive) _ticker.stop();
    if (_isCurrentItem.value) _updatePosition(Player.inst.getExactPositionMS());
  }

  void _onTick(Duration _) => _updatePosition(Player.inst.getExactPositionMS());

  /// covers seeks while paused, the ticker covers playback.
  void _onPlayerPositionChanged() {
    if (_ticker.isActive || !_isCurrentItem.value) return;
    _updatePosition(Player.inst.nowPlayingPosition.value);
  }

  /// while playing, what is heard runs [settings.visualDelayMS] behind the player (bluetooth), same as the lyrics view.
  int _toHeardPositionMS(int playerPositionMS) {
    if (!_isPlayingItem()) return playerPositionMS;
    return playerPositionMS - settings.visualDelayMS.value;
  }

  /// the play line end is checked against the player position, the delayed audio is still on its way when pausing.
  void _updatePosition(int playerPositionMS) {
    final heardPositionMS = _toHeardPositionMS(playerPositionMS);
    _positionMS.value = heardPositionMS;
    final playingIndex = _doc.lineIndexAt(heardPositionMS + _kLineMatchToleranceMS);
    if (playingIndex != _playingIndex.value) {
      _playingIndex.value = playingIndex;
      if (playingIndex >= 0 && _isPlayingItem()) _followPlayingLine(playingIndex);
    }
    final playLineEndMS = _playLineEndMS;
    if (playLineEndMS != null && playerPositionMS >= playLineEndMS) {
      _playLineEndMS = null;
      Player.inst.pause(fadeMillis: 0);
    }
  }

  void _playItem() {
    Player.inst.playOrPause(0, [widget.item], QueueSource.others(null), gentlePlay: true);
  }

  void _togglePlay() {
    if (!_isCurrentItem.value) {
      _playItem();
      return;
    }
    _playLineEndMS = null;
    if (Player.inst.playWhenReady.value) {
      Player.inst.pause(fadeMillis: 0);
    } else {
      Player.inst.play();
    }
  }

  void _seekBy(int deltaMS) {
    if (!_isCurrentItem.value) return;
    final positionMS = Player.inst.getExactPositionMS() + deltaMS;
    _seekTo(positionMS);
  }

  Future<void> _seekTo(int positionMS) async {
    if (!_isCurrentItem.value) return;
    final finalPositionMS = positionMS.withMinimum(0);
    await Player.inst.seek(Duration(milliseconds: finalPositionMS));
    if (mounted && !_ticker.isActive) _updatePosition(Player.inst.getExactPositionMS());
  }

  void _playLine(int index) {
    if (!_isCurrentItem.value) return;
    final startMS = _doc.lines[index].startMS;
    if (startMS == null) return;
    _playLineEndMS = _doc.nextStartAfter(startMS) ?? startMS + _kPlayLineFallbackMS;
    _seekTo(startMS);
    Player.inst.play();
  }

  void _cycleSpeed() {
    if (!_isCurrentItem.value) return;
    final currentSpeed = Player.inst.currentSpeed.value;
    final currentIndex = _kSpeeds.indexOf(currentSpeed);
    final nextIndex = (currentIndex + 1) % _kSpeeds.length;
    _didChangeSpeed = true;
    Player.inst.setSpeed(_kSpeeds[nextIndex]);
  }

  // ==================== document ====================

  void _refreshDerived() {
    _doc.refreshDerived(durationMS: _durationMS);
    _playingIndex.value = _doc.lineIndexAt(_positionMS.value + _kLineMatchToleranceMS);
    final maxIndex = (_doc.lines.length - 1).withMinimum(0);
    if (_selectedIndex.value > maxIndex) _selectedIndex.value = maxIndex;
  }

  void _onDocChanged() {
    _refreshDerived();
    _revision.value++;
    _hasUnsavedChanges = true;
    _draftTimer?.cancel();
    _draftTimer = Timer(_kDraftSaveDelay, _saveDraft);
  }

  void _pushUndo() {
    _undoStack.add(_doc.snapshot());
    if (_undoStack.length > _kMaxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
    _refreshHistoryState();
  }

  void _refreshHistoryState() {
    _canUndo.value = _undoStack.isNotEmpty;
    _canRedo.value = _redoStack.isNotEmpty;
  }

  void _edit(void Function() fn) {
    _pushUndo();
    fn();
    _onDocChanged();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_doc.snapshot());
    _doc.lines = _undoStack.removeLast();
    _refreshHistoryState();
    _onDocChanged();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_doc.snapshot());
    _doc.lines = _redoStack.removeLast();
    _refreshHistoryState();
    _onDocChanged();
  }

  Future<void> _saveDraft() async {
    final didWrite = await _writeDraft();
    if (didWrite && mounted) _hasDraft.value = true;
  }

  Future<bool> _writeDraft() async {
    _draftTimer?.cancel();
    _draftTimer = null;
    if (!_hasUnsavedChanges) return false;
    final file = await _draftFile.writeAsJson(_doc.toJson());
    return file != null;
  }

  Future<void> _discardDraft() async {
    _draftTimer?.cancel();
    _draftTimer = null;
    await _draftFile.tryDeleting();
    _pushUndo();
    _doc.loadSource(widget.sourceLyrics, durationMS: _durationMS);
    _isWordMode.value = _doc.hasTimedWords();
    _refreshDerived();
    _revision.value++;
    _hasUnsavedChanges = false;
    _hasDraft.value = false;
    if (_doc.lines.isEmpty) _showTextDialog();
  }

  // ==================== selection ====================

  void _select(int index) {
    final lines = _doc.lines;
    if (lines.isEmpty) return;
    final finalIndex = index.withMinimum(0).withMaximum(lines.length - 1);
    _selectedIndex.value = finalIndex;
    _wordIndex.value = 0;
    _ensureVisible(finalIndex);
  }

  void _selectAndSeek(int index) {
    _select(index);
    final startMS = _doc.lines[index].startMS;
    if (startMS != null) _seekTo(startMS);
  }

  /// idle is also reported when our own scroll animation starts.
  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.direction != ScrollDirection.idle) _lastUserScrollMS = DateTime.now().millisecondsSinceEpoch;
    return false;
  }

  /// the user's own scrolling wins for a few seconds.
  void _followPlayingLine(int index) {
    final sinceUserScrollMS = DateTime.now().millisecondsSinceEpoch - _lastUserScrollMS;
    if (sinceUserScrollMS < _kFollowAfterUserScrollMS) return;
    _ensureVisible(index);
  }

  void _ensureVisible(int index) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final viewportHeight = position.viewportDimension;
    final rowTop = index * _kRowExtent;
    final comfortTop = position.pixels + viewportHeight * 0.15;
    final comfortBottom = position.pixels + viewportHeight * 0.65 - _kRowExtent;
    if (rowTop >= comfortTop && rowTop <= comfortBottom) return;
    final targetPre = rowTop - viewportHeight * 0.3;
    final target = targetPre.withMinimum(position.minScrollExtent).withMaximum(position.maxScrollExtent);
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  // ==================== stamping ====================

  /// paused means the position was placed by hand, so there is no reaction to make up for.
  int _stampPositionMS() {
    final playerPositionMS = Player.inst.getExactPositionMS();
    if (!_isPlayingItem()) return playerPositionMS;
    final heardPositionMS = _toHeardPositionMS(playerPositionMS);
    final latencyMS = settings.lyricsEditorLatencyMS.value;
    final positionMS = heardPositionMS - latencyMS;
    return positionMS.withMinimum(0);
  }

  void _onStampDown() {
    if (!_isCurrentItem.value) return;
    final lines = _doc.lines;
    final index = _selectedIndex.value;
    if (index >= lines.length) return;
    final positionMS = _stampPositionMS();
    VibratorController.verylight();

    final line = lines[index];
    final isLineStamp = !_isWordMode.value || line.text.isEmpty;
    if (isLineStamp) {
      _edit(() => _doc.stampLine(index, positionMS));
      _select(index + 1);
      return;
    }

    _pushUndo();
    final words = line.ensureWords();
    final wordIndex = _wordIndex.value.withMaximum(words.length - 1);
    _doc.stampWordStart(index, wordIndex, positionMS);
    _pressedWord = (line: index, word: wordIndex);
    _onDocChanged();
  }

  void _onStampUp() {
    final pressed = _pressedWord;
    if (pressed == null) return;
    _pressedWord = null;
    final lines = _doc.lines;
    if (pressed.line >= lines.length) return;
    final wordsCount = lines[pressed.line].words?.length ?? 0;
    if (pressed.word >= wordsCount) return;
    final positionMS = _stampPositionMS();
    _doc.stampWordEnd(pressed.line, pressed.word, positionMS);
    _onDocChanged();

    final nextWordIndex = pressed.word + 1;
    if (nextWordIndex < wordsCount) {
      _wordIndex.value = nextWordIndex;
    } else {
      _select(pressed.line + 1);
    }
  }

  void _nudgeSelected(int deltaMS, {bool saveUndo = true}) {
    final index = _selectedIndex.value;
    if (index >= _doc.lines.length) return;
    if (saveUndo) _pushUndo();
    _doc.shiftLines(index, index, deltaMS);
    _onDocChanged();
  }

  void _startNudgeRepeat(int deltaMS) {
    _nudgeSelected(deltaMS);
    _nudgeRepeatTimer?.cancel();
    _nudgeRepeatTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _nudgeSelected(deltaMS, saveUndo: false),
    );
  }

  void _stopNudgeRepeat() {
    _nudgeRepeatTimer?.cancel();
    _nudgeRepeatTimer = null;
  }

  /// part of the edit that changed the time, no undo step of its own.
  void _placeLineInTimeOrder(int index) {
    final newIndex = _doc.placeInTimeOrder(index);
    if (newIndex == index) return;
    _onDocChanged();
    _selectedIndex.value = newIndex;
    _ensureVisible(newIndex);
  }

  void _moveLineTo(int index, int startMS, {required bool saveUndo}) {
    if (saveUndo) _pushUndo();
    _doc.stampLine(index, startMS.withMinimum(0));
    _onDocChanged();
  }

  // ==================== lines ====================

  void _insertLineAfter(int index) {
    final newIndex = index + 1;
    _edit(() => _doc.lines.insert(newIndex, _EditorLine(text: '')));
    _select(newIndex);
    _showLineEditDialog(newIndex);
  }

  void _deleteLine(int index) {
    _edit(() => _doc.lines.removeAt(index));
  }

  void _clearLineTimestamps(int index) {
    _edit(() => _doc.lines[index].clearTimestamps());
  }

  void _moveLine(int oldIndex, int newIndexPre) {
    final newIndex = newIndexPre > oldIndex ? newIndexPre - 1 : newIndexPre;
    if (newIndex == oldIndex) return;
    _edit(() {
      final line = _doc.lines.removeAt(oldIndex);
      _doc.lines.insert(newIndex, line);
    });
    _selectedIndex.value = newIndex;
  }

  void _toggleWordMode() {
    _isWordMode.value = !_isWordMode.value;
    _wordIndex.value = 0;
  }

  /// pasted lrc replaces everything, plain text keeps the timings of the lines that stayed.
  void _applyText(String newText) {
    final oldText = _doc.toPlainText();
    if (newText == oldText) return;
    final pastedLrc = newText.isValidLRC() ? newText.parseLRC() : null;
    if (pastedLrc == null) {
      _edit(() => _doc.applyPlainText(newText));
      return;
    }
    _edit(() => _doc.loadLrc(pastedLrc, durationMS: _durationMS));
    _isWordMode.value = _doc.hasTimedWords();
  }

  // ==================== saving ====================

  /// the same duration [_resolveDurationMS] picks, re-read since the player might not have had it before.
  Future<int> _lengthTagDurationMS() async {
    final durationMS = await _resolveDurationMS();
    if (durationMS > 0) _durationMS = durationMS;
    return _durationMS;
  }

  Future<void> _save({required bool embed}) async {
    if (_isSaving.value) return;
    final lines = _doc.lines;
    if (lines.isEmpty) return;
    final untimedCount = _doc.untimedCount;
    final isSynced = untimedCount < lines.length;
    if (isSynced && untimedCount > 0) {
      final confirmed = await _confirmUntimedLines();
      if (!confirmed) return;
    }

    _isSaving.value = true;
    final durationMS = await _lengthTagDurationMS();
    final text = isSynced ? _doc.toLrcText(durationMS: durationMS) : _doc.toPlainText();
    final embeddableTrack = _embeddableTrack;
    bool didSave;
    if (embed && embeddableTrack != null) {
      didSave = await Lyrics.inst.embedLyricsByUser(embeddableTrack, text);
    } else {
      await _saveToFile(text, isSynced);
      didSave = true;
    }
    if (!mounted) return;
    _isSaving.value = false;
    if (!didSave) return;

    _hasUnsavedChanges = false;
    _draftTimer?.cancel();
    _draftTimer = null;
    await _draftFile.tryDeleting();
    if (!mounted) return;
    _hasDraft.value = false;
    if (_isCurrentItem.value) Lyrics.inst.updateLyrics(widget.item);
  }

  Future<void> _saveToFile(String text, bool isSynced) async {
    final lrcUtils = widget.lrcUtils;
    await lrcUtils.removeIgnoreMarker();
    final file = await Lyrics.inst.saveLyricsByUser(lrcUtils, text, isSynced);
    final inUse = await Lyrics.inst.pickLocalLyrics(lrcUtils, lrcUtils.embeddedLyrics);
    if (inUse.isEmbedded) {
      snackyy(
        title: lang.note,
        message: lang.embeddedLyricsArePrioritized(setting: lang.prioritizeEmbeddedLyrics),
        icon: Broken.info_circle,
        displayDuration: SnackDisplayDuration.veryLong,
        button: SnackbarButton(
          text: lang.disable,
          function: () {
            settings.embeddedLyricsPriority.save(EmbeddedLyricsPriority.off);
            if (_isSameItem(Player.inst.currentItem.value)) Lyrics.inst.updateLyrics(widget.item);
          },
        ),
      );
      return;
    }
    snackyy(
      title: lang.save,
      message: '${lang.savedIn}: ${file.path}',
      icon: Broken.document_download,
      top: false,
    );
  }

  Future<void> _preview() async {
    if (!_isCurrentItem.value) return;
    final durationMS = await _lengthTagDurationMS();
    final text = _doc.toLrcText(durationMS: durationMS);
    final lrc = text.parseLRC();
    if (lrc == null) return;
    _didPreview = true;
    Lyrics.inst.previewLyrics(lrc);
    NamidaNavigator.inst.navigateToRoot(
      const LyricsLRCParsedView(
        videoOrImage: SizedBox(),
        isFullScreenView: true,
      ),
      transition: Transition.native,
    );
  }

  // ==================== keyboard ====================

  /// dialogs and menus unfocus everything when opening, without this the page shortcuts would stop after the first one.
  void _onPrimaryFocusChanged() {
    final scope = _focusNode.enclosingScope;
    if (scope == null || FocusManager.instance.primaryFocus != scope) return;
    _focusNode.requestFocus();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (ShortcutsManager.isTextFieldFocused()) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isEnter = key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    if (isEnter) {
      if (event is KeyDownEvent) {
        _onStampDown();
      } else if (event is KeyUpEvent) {
        _onStampUp();
      }
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    final keyboard = HardwareKeyboard.instance;
    final isControl = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (isControl) {
      if (key == LogicalKeyboardKey.keyZ) {
        if (keyboard.isShiftPressed) {
          _redo();
        } else {
          _undo();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyY) {
        _redo();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyS) {
        _save(embed: false);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) _togglePlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _seekBy(-_kSeekStepMS);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _seekBy(_kSeekStepMS);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _select(_selectedIndex.value - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _select(_selectedIndex.value + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.bracketLeft) {
      _nudgeSelected(-_kNudgeStepMS);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.bracketRight) {
      _nudgeSelected(_kNudgeStepMS);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ==================== ui ====================

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final syncWidget = LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _kWideLayoutMinWidth;
        final linesWidget = _LinesList(state: this);
        final controlsWidget = _ControlsPanel(state: this);
        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: linesWidget,
              ),
              const SizedBox(
                width: 8.0,
              ),
              SizedBox(
                width: 400.0,
                child: controlsWidget,
              ),
            ],
          );
        }
        return Column(
          children: [
            Expanded(
              child: linesWidget,
            ),
            controlsWidget,
          ],
        );
      },
    );
    return AnimatedThemeOrTheme(
      duration: const Duration(milliseconds: kThemeAnimationDurationMS),
      data: theme,
      child: BackgroundWrapper(
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                  color: theme.cardColor,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6.0, 6.0, 6.0, 8.0),
                  child: Column(
                    children: [
                      _EditorHeader(state: this),
                      const SizedBox(
                        height: 4.0,
                      ),
                      Expanded(
                        child: ObxO(
                          rx: _isLoading,
                          builder: (context, isLoading) => isLoading
                              ? Center(
                                  child: ThreeArchedCircle(
                                    color: theme.colorScheme.secondary,
                                    size: 42.0,
                                  ),
                                )
                              : syncWidget,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
