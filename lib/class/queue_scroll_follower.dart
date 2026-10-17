import 'package:flutter/widgets.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class QueueScrollFollower {
  final double Function() currentItemStart;
  final bool Function()? canFollow;

  QueueScrollFollower({required this.currentItemStart, this.canFollow}) {
    scrollController.addListener(_onScrolled);
  }

  final scrollController = NamidaScrollController.create();
  final arrowIcon = Broken.cd.obso;

  static const _kComfortZoneStart = 0.1;
  static const _kComfortZoneEnd = 0.7;

  bool _isFollowing = true;
  bool _isFollowScheduled = false;
  bool _isAutoSkipScheduled = false;
  int _runningAnimations = 0;

  void dispose() {
    scrollController.removeListener(_onScrolled);
    scrollController.dispose();
    arrowIcon.close();
  }

  void onCurrentItemMoved() {
    final canFollow = this.canFollow;
    final shouldFollow = _isFollowing && scrollController.hasClients && !Player.inst.isModifyingQueue && (canFollow == null || canFollow());
    if (!shouldFollow) {
      _updateArrowIcon();
      return;
    }
    if (Player.inst.isAutoSkipping) _isAutoSkipScheduled = true;
    if (_isFollowScheduled) return;
    _isFollowScheduled = true;
    // -- after layout, so a replaced queue has its new extents
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wasAutoSkip = _isAutoSkipScheduled;
      _isFollowScheduled = false;
      _isAutoSkipScheduled = false;
      if (wasAutoSkip || !_isCurrentItemInComfortZone()) {
        animateToCurrentItem();
      } else {
        _updateArrowIcon();
      }
    });
  }

  bool _isCurrentItemInComfortZone() {
    final position = scrollController.positions.lastOrNull;
    if (position == null || !position.hasContentDimensions) return false;
    final viewport = position.viewportDimension;
    final itemOffsetInViewport = currentItemStart() - position.pixels;
    return itemOffsetInViewport >= viewport * _kComfortZoneStart && itemOffsetInViewport <= viewport * _kComfortZoneEnd;
  }

  void jumpToCurrentItem() {
    final position = scrollController.positions.lastOrNull;
    if (position == null || !position.hasContentDimensions) return;
    _isFollowing = true;
    final target = _currentItemScrollOffset(position);
    position.jumpTo(target);
    _updateArrowIcon();
  }

  Future<void> animateToCurrentItem() async {
    final position = scrollController.positions.lastOrNull;
    if (position == null || !position.hasContentDimensions) return;
    _isFollowing = true;
    final target = _currentItemScrollOffset(position);
    if (position.pixels == target) {
      _updateArrowIcon();
      return;
    }
    _runningAnimations++;
    await position.animateToEff(
      target,
      duration: const Duration(milliseconds: 600),
      curve: Curves.fastEaseInToSlowEaseOut,
    );
    _runningAnimations--;
  }

  void _onScrolled() {
    _updateArrowIcon();
    if (_runningAnimations == 0) _isFollowing = arrowIcon.value == Broken.cd;
  }

  /// clamped, otherwise the icon never settles on [Broken.cd] for items near the edges.
  double _currentItemScrollOffset(ScrollPosition position) {
    final offset = currentItemStart() - position.viewportDimension * 0.2;
    return offset.clampDouble(position.minScrollExtent, position.maxScrollExtent);
  }

  void _updateArrowIcon() {
    final position = scrollController.positions.lastOrNull;
    if (position == null || !position.hasContentDimensions) return;
    final target = _currentItemScrollOffset(position);
    final pixels = position.pixels;
    arrowIcon.value = pixels > target
        ? Broken.arrow_up_1
        : pixels < target
        ? Broken.arrow_down
        : Broken.cd;
  }
}
