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

  void _onPositionChange() {
    final posMS = Player.inst.nowPlayingPosition.value;
    final segments = SponsorBlockController.inst.currentSegments.value;
    SponsorBlockSegment? newSegment;
    if (segments != null) {
      if (segments.segments.isNotEmpty) {
        // -- minor perf boost
        if ((segments.firstMS != null && posMS >= segments.firstMS!) && //
            (segments.lastMS != null && posMS <= segments.lastMS!)) {
          final minDur = settings.youtube.sponsorBlockSettings.value.minimumSegmentDurationMS;
          for (final s in segments.segments) {
            if (minDur > 0 ? s.durationMS > minDur : true) {
              if (posMS >= s.segmentStartMS && posMS <= s.segmentEndMS && (posMS <= s.segmentStartMS + settings.youtube.sponsorBlockSettings.value.hideSkipButtonAfterMS)) {
                newSegment = s;
                break;
              }
            }
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
    if (_currentSegment?.uuid != newSegment?.uuid) {
      if (newSegment == null) {
        setState(() => _currentSegment = null);
      } else {
        final didAutoSkip = SponsorBlockController.inst.autoSkipIfEnabled(newSegment);
        if (!didAutoSkip) {
          if (SponsorBlockController.inst.canShowSkipButton(newSegment)) {
            setState(() => _currentSegment = newSegment);
          }
        }
      }
    }
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
    return AnimatedSwitcher(
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
                color: Colors.black.withValues(alpha: 0.2),
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
                              segment.segmentStartMS == segment.segmentEndMS ? lang.JUMP : lang.SKIP,
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
