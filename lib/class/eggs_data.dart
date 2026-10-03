// by claude
import 'package:namida/core/extensions.dart';

/// stored by name, so reordering the enums never shifts what a user collected.
class EggsData {
  final int _collectedMask;
  final int _unlockedMask;
  final int dismissals;
  final int trades;

  const EggsData() : _collectedMask = 0, _unlockedMask = 0, dismissals = 0, trades = 0;

  const EggsData._(this._collectedMask, this._unlockedMask, this.dismissals, this.trades);

  static final _allEggsMask = (1 << NamidaEgg.values.length) - 1;

  bool isCollected(NamidaEgg egg) => _collectedMask & egg._bit != 0;

  bool hasCollectedAllExcept(NamidaEgg egg) => (_collectedMask | egg._bit) == _allEggsMask;

  bool isUnlocked(EggUnlockable item) => _unlockedMask & item._bit != 0;

  int collectedCount() {
    int count = 0;
    for (final egg in NamidaEgg.values) {
      if (isCollected(egg)) count++;
    }
    return count;
  }

  int _earnedEggs() {
    int earned = 0;
    for (final egg in NamidaEgg.values) {
      if (isCollected(egg)) earned += egg.worth;
    }
    return earned;
  }

  int _spentEggs() {
    int spent = 0;
    for (final item in EggUnlockable.values) {
      if (isUnlocked(item)) spent++;
    }
    return spent;
  }

  int balance() => _earnedEggs() - _spentEggs();

  bool didSpendEverything() {
    final spent = _spentEggs();
    return spent > 0 && spent == _earnedEggs();
  }

  EggsData withCollected(NamidaEgg egg) => EggsData._(_collectedMask | egg._bit, _unlockedMask, dismissals, trades);

  EggsData withUnlocked(EggUnlockable item) => EggsData._(_collectedMask, _unlockedMask | item._bit, dismissals, trades);

  EggsData withLocked(EggUnlockable item) => EggsData._(_collectedMask, _unlockedMask & ~item._bit, dismissals, trades);

  EggsData withDismissal() => EggsData._(_collectedMask, _unlockedMask, dismissals + 1, trades);

  EggsData withTrade() => EggsData._(_collectedMask, _unlockedMask, dismissals, trades + 1);

  static EggsData fromJson(Map<String, dynamic> json) {
    final dismissals = json['d'];
    final trades = json['t'];
    return EggsData._(
      _maskOfNames(json['c'], NamidaEgg.values),
      _maskOfNames(json['u'], EggUnlockable.values),
      dismissals is int ? dismissals : 0,
      trades is int ? trades : 0,
    );
  }

  static int _maskOfNames<E extends Enum>(Object? names, List<E> values) {
    if (names is! List) return 0;
    int mask = 0;
    for (final name in names) {
      if (name is! String) continue;
      final value = values.getEnum(name);
      if (value != null) mask |= 1 << value.index;
    }
    return mask;
  }

  Map<String, dynamic> toJson() => {
    'c': [
      for (final egg in NamidaEgg.values)
        if (isCollected(egg)) egg.name,
    ],
    'u': [
      for (final item in EggUnlockable.values)
        if (isUnlocked(item)) item.name,
    ],
    'd': dismissals,
    't': trades,
  };
}

enum NamidaEgg {
  ano(1),
  loyal(2),
  albumPurist(2),
  obsessed(2),
  dizzy(1),
  secretWord(1),
  tsundere(1),
  newYear(1),
  birthday(1),
  anniversary(1),
  economy(1),
  nightOwl(1),
  veteran(2),
  chipmunk(1),
  broke(1),
  hoarder(1),
  tears(1),
  creep(1),
  lucky(1),
  goodnight(1),
  twins(1),
  colorful(1),
  ;

  final int worth;

  const NamidaEgg(this.worth);
}

enum EggUnlockable {
  crossfade,
  partyMode,
  starfield,
  galaxy,
  aurora,
  fireworks,
  deepOcean,
  mirroredBars,
  glow,
  outline,
  edgeLights,
  playerBackgroundImage,
  appWallpaper,
}

extension _NamidaEggBit on NamidaEgg {
  int get _bit => 1 << index;
}

extension _EggUnlockableBit on EggUnlockable {
  int get _bit => 1 << index;
}
