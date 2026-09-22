import 'package:namida/class/track.dart';

enum PartyQueueRewrite {
  shuffleAll,
  shuffleNext,
  removeDuplicates,
  clear,
}

/// set on the audio handler only while the player is bound to a party.
/// `intercept*` return true when the action was taken over and must not run locally.
abstract class PartyPlayerGate {
  bool get forcesMixedQueue;

  /// whether skip commands would be accepted, for ui that animates before acting.
  bool get canSkip;

  bool interceptPlay();
  bool interceptPause({required bool isUserInitiated});
  bool interceptSeek(Duration position);

  /// [index] for a direct jump, otherwise [offset] is 1 or -1.
  bool interceptSkip({int? index, int offset = 0});

  /// [atIndex] for an explicit position, otherwise appended or inserted next.
  bool interceptAdd(Iterable<Playable> items, {required bool insertNext, int? atIndex});

  /// [end] is exclusive.
  bool interceptRemove(int start, int end);

  /// indices follow the reorderable list convention, [newIndex] counts the dragged item.
  bool interceptReorder(int oldIndex, int newIndex);
  bool interceptNewQueue(Iterable<Playable> queue, int index, {required bool startPlaying, required bool shuffle, required bool isPlayerQueue});
  bool interceptQueueRewrite(PartyQueueRewrite rewrite);

  void onLocalIndexChanged(int index);
  void onLocalItemCompleted();
}
