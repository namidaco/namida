import 'package:flutter/material.dart';

import 'package:youtipie/class/sponsorblock_segment.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/sponsorblock.dart';
import 'package:namida/youtube/controller/sponsorblock_controller.dart';

class SkipSponsorButton extends StatefulWidget {
  final Color itemsColor;
  const SkipSponsorButton({super.key, required this.itemsColor});

  @override
  State<SkipSponsorButton> createState() => __SkipSponsorButtonState();
}

class __SkipSponsorButtonState extends State<SkipSponsorButton> {
  SponsorBlockSegment? _currentSegment;
  String? _evaluatedSegmentUuid;
  int _seenSeekCount = Player.inst.seekCount;
  int? _seekLandingMS;
  bool _didReachSeekLanding = false;

  /// the position can settle a bit before the requested one, ex: keyframe snapping.
  static const _kSeekLandingToleranceMS = 1000;

  void _onPositionChange() {
    final posMS = Player.inst.nowPlayingPosition.value;
    final seekCount = Player.inst.seekCount;
    if (seekCount != _seenSeekCount) {
      _seenSeekCount = seekCount;
      _seekLandingMS = Player.inst.lastSeekPositionMS;
      _didReachSeekLanding = false;
    }

    final segments = SponsorBlockController.inst.currentSegments.value;
    SponsorBlockSegment? newSegment;
    bool newSegmentSeekedInto = false;
    if (segments != null) {
      if (segments.segments.isNotEmpty) {
        final sponsorBlockSettings = settings.youtube.sponsorBlockSettings.value;
        final hideSkipButtonAfterMS = sponsorBlockSettings.hideSkipButtonAfterMS;

        // -- ticks queued before the seek applied still carry the old position, so a landing is only dropped once reached & left
        final seekLandingMS = _seekLandingMS;
        if (seekLandingMS != null) {
          final isNearLanding = posMS >= seekLandingMS - _kSeekLandingToleranceMS && posMS <= seekLandingMS + hideSkipButtonAfterMS;
          if (isNearLanding) {
            _didReachSeekLanding = true;
          } else if (_didReachSeekLanding) {
            _seekLandingMS = null;
            _didReachSeekLanding = false;
          }
        }

        // -- minor perf boost
        if ((segments.firstMS != null && posMS >= segments.firstMS!) && //
            (segments.lastMS != null && posMS <= segments.lastMS!)) {
          final minDur = sponsorBlockSettings.minimumSegmentDurationMS;
          final validSeekLandingMS = _didReachSeekLanding ? _seekLandingMS : null;
          final list = segments.segments;
          // -- most important is last, same as what the seekbar paints on top
          for (int i = list.length - 1; i >= 0; i--) {
            final s = list[i];
            if (s.durationMS < minDur) continue;
            if (posMS < s.segmentStartMS || posMS > s.segmentEndMS) continue;
            final isInStartWindow = posMS <= s.segmentStartMS + hideSkipButtonAfterMS;
            final seekedInto = !isInStartWindow && validSeekLandingMS != null && validSeekLandingMS > s.segmentStartMS && validSeekLandingMS < s.segmentEndMS;
            if (!isInStartWindow && !seekedInto) continue;
            if (!SponsorBlockController.inst.canActOnSegment(s)) continue;
            newSegment = s;
            newSegmentSeekedInto = seekedInto;
            break;
          }
        }
      }

      if (newSegment == null) {
        final poiHighlight = segments.poi_highlight;
        if (poiHighlight != null) {
          if (posMS <= settings.youtube.sponsorBlockSettings.value.hideSkipButtonAfterMS) {
            // -- only show in start of video
            newSegment = poiHighlight;
          }
        }
      }
    }
    // -- acting once per segment keeps ticks queued before an auto skip's seek from skipping again
    final newSegmentUuid = newSegment?.uuid;
    if (newSegmentUuid == _evaluatedSegmentUuid) return;
    _evaluatedSegmentUuid = newSegmentUuid;

    SponsorBlockSegment? segmentToShow;
    if (newSegment != null) {
      if (newSegmentSeekedInto) {
        // -- seeking in is deliberate, it gets the button rather than being bounced out by an auto skip
        segmentToShow = newSegment;
      } else {
        final didAutoSkip = SponsorBlockController.inst.autoSkipIfEnabled(newSegment);
        final canShowButton = !didAutoSkip && SponsorBlockController.inst.canShowSkipButton(newSegment);
        if (canShowButton) segmentToShow = newSegment;
      }
    }
    if (segmentToShow?.uuid != _currentSegment?.uuid) setState(() => _currentSegment = segmentToShow);
  }

  @override
  void initState() {
    _onPositionChange();
    Player.inst.nowPlayingPosition.addListener(_onPositionChange);
    SponsorBlockController.inst.currentSegments.addListener(_onPositionChange);
    super.initState();
  }

  @override
  void dispose() {
    Player.inst.nowPlayingPosition.removeListener(_onPositionChange);
    SponsorBlockController.inst.currentSegments.removeListener(_onPositionChange);
    super.dispose();
  }

  void _onSkipTap() {
    final segment = _currentSegment;
    if (segment == null) return;
    SponsorBlockController.inst.skipSegment(segment);
  }

  @override
  Widget build(BuildContext context) {
    final segment = _currentSegment;
    final config = segment == null ? null : SponsorBlockController.inst.getConfigForSegment(segment.category);
    final textTheme = context.textTheme;
    final itemsColor = widget.itemsColor;
    return CustomAnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 200),
      child: segment == null || config == null || config.action == SponsorBlockAction.disabled
          ? const SizedBox(
              key: ValueKey('button_hidden'),
            )
          : NamidaBgBlurClipped(
              key: ValueKey('button_shown'),
              blur: 3.0,
              decoration: BoxDecoration(
                color: Colors.black.withOpacityExt(0.2),
                borderRadius: BorderRadius.horizontal(left: Radius.circular(6.0.multipliedRadius)),
                border: Border(
                  right: BorderSide(
                    color: config.color,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: TapDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _onSkipTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 2.0),
                      Icon(
                        Broken.forward,
                        size: 18.0,
                        color: itemsColor,
                      ),
                      const SizedBox(width: 4.0),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: context.width * 0.3),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              segment.segmentStartMS == segment.segmentEndMS ? lang.jump : lang.skip,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.displayMedium?.copyWith(
                                fontSize: 14.0,
                                color: itemsColor,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                segment.category.sponsorCategoryToText(),
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                style: textTheme.displaySmall?.copyWith(
                                  fontSize: 11.0,
                                  color: itemsColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2.0),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
