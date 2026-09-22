import 'package:flutter/material.dart';

import 'package:namida/class/subtitle_cue.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/subtitles_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

/// Draws youtube's styled captions, whose colors carry the karaoke highlight.
class StyledSubtitleLineWidget extends StatefulWidget {
  final TextStyle? style;
  final int maxLines;

  const StyledSubtitleLineWidget({
    super.key,
    this.style,
    this.maxLines = 3,
  });

  @override
  State<StyledSubtitleLineWidget> createState() => _StyledSubtitleLineWidgetState();
}

class _StyledSubtitleLineWidgetState extends State<StyledSubtitleLineWidget> {
  final _currentGroup = Rxn<SubtitleCueGroup>();
  var _groups = <SubtitleCueGroup>[];
  int _lastScanIndex = -1;

  @override
  void initState() {
    super.initState();
    _fillGroups();
    Subtitles.inst.currentStyledSubtitle.addListener(_fillGroups);
    Player.inst.nowPlayingPosition.addListener(_updateGroup);
  }

  @override
  void dispose() {
    Subtitles.inst.currentStyledSubtitle.removeListener(_fillGroups);
    Player.inst.nowPlayingPosition.removeListener(_updateGroup);
    _currentGroup.close();
    super.dispose();
  }

  void _fillGroups() {
    _groups = Subtitles.inst.currentStyledSubtitle.value?.groups ?? const [];
    _lastScanIndex = -1;
    _currentGroup.value = null;
    _updateGroup();
  }

  void _updateGroup() {
    final groups = _groups;
    if (groups.isEmpty) return;

    final position = Player.inst.nowPlayingPosition.value - settings.visualDelayMS.value;

    // -- incremental scan, the index only advances by a few steps normally
    int idx = _lastScanIndex;
    if (idx >= groups.length) idx = -1;
    if (idx >= 0 && groups[idx].start > position) idx = -1; // -- seeked backwards
    while (idx + 1 < groups.length && groups[idx + 1].start <= position) {
      idx++;
    }
    _lastScanIndex = idx;

    final group = idx < 0 || groups[idx].end <= position ? null : groups[idx];
    if (!identical(group, _currentGroup.value)) _currentGroup.value = group;
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: _currentGroup,
      builder: (context, group) {
        if (group == null) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: group.lines
              .map(
                (line) => _StyledSubtitleText(
                  line: line,
                  style: widget.style,
                  maxLines: widget.maxLines,
                ),
              )
              .toFixedList(),
        );
      },
    );
  }
}

class _StyledSubtitleText extends StatelessWidget {
  final SubtitleCueLine line;
  final TextStyle? style;
  final int maxLines;

  const _StyledSubtitleText({
    required this.line,
    required this.style,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style;
    return Text.rich(
      TextSpan(
        children: line.spans
            .map(
              (span) => TextSpan(
                text: span.text,
                style: TextStyle(
                  color: span.color,
                  fontWeight: span.bold ? FontWeight.w700 : null,
                  fontStyle: span.italic ? FontStyle.italic : null,
                  decoration: span.underline ? TextDecoration.underline : null,
                ),
              ),
            )
            .toFixedList(),
      ),
      style: baseStyle,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      softWrap: true,
      overflow: TextOverflow.fade,
    );
  }
}
