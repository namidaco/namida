// by claude
import 'dart:async';
import 'dart:math' as math;

import 'package:namico_subscription_manager/core/enum.dart';

import 'package:namida/class/eggs_data.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/effects/effects.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';

/// eggs earned by listening are only looked for in [collectPending], when the eggs are about to be shown.
class EggsController {
  static final inst = EggsController._();
  EggsController._();

  static const _kLoyalListens = 10000;
  static const _kObsessedListens = 200;
  static const _kTsundereDismissals = 7;
  static const _kEconomyTrades = 5;
  static const _kHoarderBalance = 5;
  static const _kNightOwlHour = 3;
  static const _kVeteranAge = Duration(days: 365);
  static const _kChipmunkSpeed = 2.0;
  static const _kChipmunkPitch = 1.5;
  static const _kLuckyOneIn = 50;
  static const _kSecretWords = {'uwu', 'kechi', 'baka', 'sussy baka'};
  static final _tearsRegex = RegExp('namida|tears|涙|なみだ|ナミダ', caseSensitive: false);
  static final _luckyRandom = math.Random();

  static const _kDateEggs = [
    _DateEggWindow(NamidaEgg.newYear, month: DateTime.december, day: 31, days: 2),
    _DateEggWindow(NamidaEgg.birthday, month: DateTime.january, day: 19, days: 1),
    _DateEggWindow(NamidaEgg.anniversary, month: DateTime.october, day: 5, days: 1),
  ];

  final pendingDateEgg = Rxn<NamidaEgg>();

  var _dateEggRefreshAt = DateTime(0);
  Timer? _dateEggRefreshTimer;

  bool isSupporter() {
    if (settings.didSupportNamida) return true;
    final membership = YoutubeAccountController.membership.userMembershipTypeGlobal.value;
    final isMember = membership != null && membership.index >= MembershipType.cutie.index;
    if (isMember) settings.didSupportNamida = true;
    return isMember;
  }

  bool collect(NamidaEgg egg) {
    final data = settings.eggs.value;
    if (data.isCollected(egg)) return false;
    final updated = data.withCollected(egg);
    settings.eggs.save(updated);
    if (pendingDateEgg.value == egg) pendingDateEgg.value = null;
    return true;
  }

  List<NamidaEgg> collectPending() {
    var data = settings.eggs.value;
    final found = <NamidaEgg>[];
    void check(NamidaEgg egg, bool Function() isEarned) {
      if (data.isCollected(egg)) return;
      if (!isEarned()) return;
      data = data.withCollected(egg);
      found.add(egg);
    }

    check(NamidaEgg.loyal, _isLoyal);
    check(NamidaEgg.obsessed, _isObsessed);
    check(NamidaEgg.albumPurist, _didPlayWholeAlbum);
    check(NamidaEgg.nightOwl, _didListenAtNight);
    check(NamidaEgg.veteran, _isVeteran);
    check(NamidaEgg.chipmunk, _isChipmunk);
    check(NamidaEgg.tears, _hasTearsTrack);
    check(NamidaEgg.lucky, _rollLucky);
    final dateEgg = pendingDateEgg.value;
    if (dateEgg != null) check(dateEgg, () => true);
    check(NamidaEgg.broke, () => data.didSpendEverything());
    check(NamidaEgg.hoarder, () => data.balance() >= _kHoarderBalance);
    check(NamidaEgg.colorful, () => data.hasCollectedAllExcept(NamidaEgg.colorful));

    if (found.isEmpty) return found;
    settings.eggs.save(data);
    if (dateEgg != null) pendingDateEgg.value = null;
    return found;
  }

  /// true when this dismissal is the one that earns the egg.
  bool countDismissal() {
    final data = settings.eggs.value;
    if (data.isCollected(NamidaEgg.tsundere)) return false;
    final counted = data.withDismissal();
    final isEarned = counted.dismissals >= _kTsundereDismissals;
    final updated = isEarned ? counted.withCollected(NamidaEgg.tsundere) : counted;
    settings.eggs.save(updated);
    return isEarned;
  }

  bool isSecretWord(String text) {
    final word = text.trim().toLowerCase();
    return _kSecretWords.contains(word);
  }

  bool unlock(EggUnlockable item) {
    final data = settings.eggs.value;
    if (data.isUnlocked(item)) return true;
    if (data.balance() < item.price) return false;
    final unlocked = data.withUnlocked(item);
    final updated = _withTrade(unlocked);
    settings.eggs.save(updated);
    return true;
  }

  void relock(EggUnlockable item) {
    final data = settings.eggs.value;
    if (!data.isUnlocked(item)) return;
    final locked = data.withLocked(item);
    final updated = _withTrade(locked);
    settings.eggs.save(updated);
    if (!isSupporter()) _disableFeature(item);
  }

  EggsData _withTrade(EggsData data) {
    if (data.isCollected(NamidaEgg.economy)) return data;
    final traded = data.withTrade();
    if (traded.trades < _kEconomyTrades) return traded;
    return traded.withCollected(NamidaEgg.economy);
  }

  void _disableFeature(EggUnlockable item) {
    switch (item) {
      case EggUnlockable.crossfade:
        settings.player.enableCrossFade.save(false);
      case EggUnlockable.partyMode:
        settings.enablePartyModeInMiniplayer.save(false);
      case EggUnlockable.starfield:
        _disableTheme(EffectTheme.starfield);
      case EggUnlockable.galaxy:
        _disableTheme(EffectTheme.galaxy);
      case EggUnlockable.aurora:
        _disableTheme(EffectTheme.aurora);
      case EggUnlockable.fireworks:
        _disableTheme(EffectTheme.fireworks);
      case EggUnlockable.deepOcean:
        _disableTheme(EffectTheme.deepOcean);
      case EggUnlockable.mirroredBars:
        _disableVisualizer(MiniplayerVisualizer.mirroredBars);
      case EggUnlockable.glow:
        _disableVisualizer(MiniplayerVisualizer.glow);
      case EggUnlockable.outline:
        _disableVisualizer(MiniplayerVisualizer.outline);
      case EggUnlockable.edgeLights:
        _disableVisualizer(MiniplayerVisualizer.edgeLights);
      case EggUnlockable.playerBackgroundImage:
        if (settings.playerBackground.value == PlayerBackground.image) settings.playerBackground.save(PlayerBackground.none);
      case EggUnlockable.appWallpaper:
        NamidaBackdrops.removeAppWallpaper();
    }
  }

  void _disableTheme(EffectTheme theme) {
    settings.transaction(() {
      if (settings.effectsBackground.value == theme) settings.effectsBackground.save(EffectTheme.none);
      if (settings.effectsOverlay.value == theme) settings.effectsOverlay.save(EffectTheme.none);
    });
  }

  void _disableVisualizer(MiniplayerVisualizer visualizer) {
    if (!settings.miniplayerVisualizers.value.contains(visualizer)) return;
    settings.miniplayerVisualizers.update((styles) => styles.remove(visualizer));
  }

  void refreshDateEgg() {
    _dateEggRefreshTimer?.cancel();
    final now = DateTime.now();
    final data = settings.eggs.value;
    NamidaEgg? activeEgg;
    DateTime? refreshAt;
    for (final window in _kDateEggs) {
      if (data.isCollected(window.egg)) continue;
      final boundary = window.nextBoundaryAfter(now);
      if (boundary.isOpen) activeEgg = window.egg;
      if (refreshAt == null || boundary.at.isBefore(refreshAt)) refreshAt = boundary.at;
    }
    pendingDateEgg.value = activeEgg;
    if (refreshAt == null) {
      _dateEggRefreshAt = DateTime(9999);
      return;
    }
    _dateEggRefreshAt = refreshAt;
    final refreshDelay = refreshAt.difference(now);
    _dateEggRefreshTimer = Timer(refreshDelay, refreshDateEgg);
  }

  // -- timers don't count deep sleep on android
  void refreshDateEggIfDue() {
    if (DateTime.now().isBefore(_dateEggRefreshAt)) return;
    refreshDateEgg();
  }

  bool _isLoyal() => HistoryController.inst.totalHistoryItemsCount.value >= _kLoyalListens;

  bool _isObsessed() {
    final mostPlayed = HistoryController.inst.topTracksMapListens.value.entriesSortedByValueCount.firstOrNull;
    return mostPlayed != null && mostPlayed.value >= _kObsessedListens;
  }

  bool _isVeteran() {
    final oldest = HistoryController.inst.oldestTrack;
    if (oldest == null) return false;
    final ageMS = currentTimeMS - oldest.dateAdded;
    return ageMS >= _kVeteranAge.inMilliseconds;
  }

  bool _didListenAtNight() {
    const hourMS = 60 * 60 * 1000;
    for (final dayTracks in HistoryController.inst.historyMap.value.values) {
      final firstListen = dayTracks.firstOrNull;
      if (firstListen == null) continue;
      final firstDate = DateTime.fromMillisecondsSinceEpoch(firstListen.dateAdded);
      final dayStartMS = DateTime(firstDate.year, firstDate.month, firstDate.day).millisecondsSinceEpoch;
      for (final twd in dayTracks) {
        final hour = (twd.dateAdded - dayStartMS) ~/ hourMS;
        if (hour == _kNightOwlHour) return true;
      }
    }
    return false;
  }

  bool _isChipmunk() => settings.player.speed.value >= _kChipmunkSpeed || settings.player.pitch.value >= _kChipmunkPitch;

  bool _hasTearsTrack() {
    for (final tr in Indexer.inst.allTracksMappedByPath.values) {
      if (_tearsRegex.hasMatch(tr.title)) return true;
    }
    return false;
  }

  bool _rollLucky() => _luckyRandom.nextInt(_kLuckyOneIn) == 0;

  bool _didPlayWholeAlbum() {
    final tracksInfo = Indexer.inst.allTracksMappedByPath;
    final days = HistoryController.inst.historyMap.value.values.toFixedList();
    List<Track>? albumTracks;
    int playedCount = 0;
    int lastDiscNo = 0;
    int lastTrackNo = 0;
    // -- history is newest first, walked backwards to follow listening order
    for (int i = days.length - 1; i >= 0; i--) {
      final dayTracks = days[i];
      for (int j = dayTracks.length - 1; j >= 0; j--) {
        final tr = dayTracks[j].track;
        final info = tracksInfo[tr.path];
        if (info == null) {
          albumTracks = null;
          continue;
        }
        final discNo = info.discNo;
        final trackNo = info.trackNo;
        final currentAlbumTracks = albumTracks;
        if (currentAlbumTracks != null) {
          final isNextOnDisc = discNo == lastDiscNo && trackNo == lastTrackNo + 1;
          final isNextDisc = discNo == lastDiscNo + 1 && trackNo == 1;
          if ((isNextOnDisc || isNextDisc) && currentAlbumTracks.contains(tr)) {
            playedCount++;
            if (playedCount == currentAlbumTracks.length) return true;
            lastDiscNo = discNo;
            lastTrackNo = trackNo;
            continue;
          }
          albumTracks = null;
        }
        if (trackNo != 1 || discNo > 1) continue;
        final tracks = info.albumsIdentifiersWrappers.firstOrNull?.getAlbumTracks();
        if (tracks == null || tracks.length < 2) continue;
        albumTracks = tracks;
        playedCount = 1;
        lastDiscNo = discNo;
        lastTrackNo = trackNo;
      }
    }
    return false;
  }
}

class _DateEggWindow {
  final NamidaEgg egg;
  final int month;
  final int day;
  final int days;

  const _DateEggWindow(this.egg, {required this.month, required this.day, required this.days});

  ({DateTime at, bool isOpen}) nextBoundaryAfter(DateTime date) {
    int year = date.year - 1;
    while (true) {
      final start = DateTime(year, month, day);
      if (date.isBefore(start)) return (at: start, isOpen: false);
      final end = DateTime(year, month, day + days);
      if (date.isBefore(end)) return (at: end, isOpen: true);
      year++;
    }
  }
}
