import 'package:flutter/material.dart';

import 'package:namida/controller/subtitles_controller.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/simple_lyrics_line.dart';

class SubtitleOverlay extends StatelessWidget {
  final TextStyle? style;
  final int maxLines;

  const SubtitleOverlay({
    super.key,
    this.style,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Subtitles.inst.renderMode,
      builder: (context, mode) => switch (mode) {
        // -- mpv/libass renders into the video texture, keeping the original styling & positioning
        SubtitleRenderMode.none || SubtitleRenderMode.playerInternal => const SizedBox(),
        SubtitleRenderMode.lrc => SimpleLyricsLineWidget(
          customSourceRx: Subtitles.inst.currentSubtitle,
          respectEndTimestamps: true,
          maxLines: maxLines,
          softWrap: true,
          style: style,
        ),
        SubtitleRenderMode.playerText => ObxO(
          rx: Subtitles.inst.playerText,
          builder: (context, text) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 80),
            child: text == null || text.isEmpty
                ? const SizedBox.shrink(key: ValueKey('no_text'))
                : Text(
                    text,
                    key: ValueKey('yes_text'),
                    style: style,
                    textAlign: TextAlign.center,
                    maxLines: maxLines,
                    softWrap: true,
                    overflow: TextOverflow.fade,
                  ),
          ),
        ),
      },
    );
  }
}
