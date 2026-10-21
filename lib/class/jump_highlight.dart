// by claude
import 'dart:async';

import 'package:namida/class/track.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/utils.dart';

/// the highlight of an item that was jumped to, laid over the tile's own background.
abstract final class JumpHighlight {
  static const color = NColors(.onSurface, opacity: 0.16);

  /// queue tiles are see-through over the miniplayer's colors, the normal one reads like the playing tile there.
  static const queueColor = NColors(.onSurface, opacity: 0.06);

  /// track tiles & video cards get it from their properties providers.
  static final briefTarget = Rxn<JumpHighlightTarget>();
  static Timer? _briefClearTimer;

  /// [inQueue] targets the player queue lists, otherwise every other list.
  static void showBriefly(Playable item, int index, {required bool inQueue}) {
    _briefClearTimer?.cancel();
    briefTarget.value = (item: item, index: index, inQueue: inQueue);
    _briefClearTimer = Timer(const Duration(milliseconds: 2500), () => briefTarget.value = null);
  }
}

typedef JumpHighlightTarget = ({Playable item, int index, bool inQueue});
