import 'package:flutter/material.dart';

import 'package:window_manager/window_manager.dart';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/window_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/simple_lyrics_line.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

// by claude
class MiniLyricsWindow extends StatefulWidget {
  const MiniLyricsWindow({super.key});

  @override
  State<MiniLyricsWindow> createState() => _MiniLyricsWindowState();
}

class _MiniLyricsWindowState extends State<MiniLyricsWindow> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (_hovering != value && mounted) setState(() => _hovering = value);
  }

  void _exit() => WindowController.instance?.exitMiniLyricsMode();

  static const _borderRadius = BorderRadius.all(Radius.circular(14.0));
  static const _edgeGripWidth = 6.0;

  Widget _resizeGrip(ResizeEdge edge) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startResizing(edge),
        child: const SizedBox(width: _edgeGripWidth, height: double.infinity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final isDark = context.isDarkMode;
    final backgroundColor = theme.scaffoldBackgroundColor.withOpacityExt(0.94);
    final foregroundColor = isDark ? const Color(0xFFDDDDDD) : const Color(0xFF16161A);

    return MouseRegion(
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: _borderRadius,
                border: Border.all(
                  width: 1.0,
                  color: isDark ? const Color.fromARGB(120, 90, 90, 90) : const Color.fromARGB(60, 20, 20, 20),
                ),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: _exit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _MiniLyricsText(
                          color: foregroundColor,
                          textTheme: textTheme,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _hovering
                              ? _MiniLyricsControls(
                                  backgroundColor: backgroundColor,
                                  color: foregroundColor,
                                  borderRadius: _borderRadius,
                                  onExit: _exit,
                                )
                              : const SizedBox(
                                  key: ValueKey('empty'),
                                  height: 32.0,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(left: 0.0, top: 0.0, bottom: 0.0, child: _resizeGrip(ResizeEdge.left)),
          Positioned(right: 0.0, top: 0.0, bottom: 0.0, child: _resizeGrip(ResizeEdge.right)),
        ],
      ),
    );
  }
}

class _MiniLyricsText extends StatelessWidget {
  final Color color;
  final TextTheme textTheme;

  const _MiniLyricsText({required this.color, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Lyrics.inst.currentLyricsLRC,
      builder: (context, lrc) {
        if (lrc == null) return _MiniLyricsNoSyncedText(color: color, textTheme: textTheme);
        return SimpleLyricsLineWidget(
          textAlign: TextAlign.center,
          maxLines: 3,
          softWrap: true,
          style: textTheme.displayMedium?.copyWith(
            fontSize: 17.0,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        );
      },
    );
  }
}

class _MiniLyricsNoSyncedText extends StatelessWidget {
  final Color color;
  final TextTheme textTheme;

  const _MiniLyricsNoSyncedText({required this.color, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Player.inst.currentItem,
      builder: (context, item) {
        final title =
            item?.execute(
              selectable: (finalItem) => finalItem.track.title,
              youtubeID: (finalItem) => YoutubeInfoController.utils.getVideoNameSync(finalItem.id) ?? '',
            ) ??
            '';
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                style: textTheme.displayMedium?.copyWith(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            Text(
              'no synced lyrics',
              style: textTheme.displaySmall?.copyWith(
                fontSize: 12.0,
                color: color.withOpacityExt(0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
            ),
          ],
        );
      },
    );
  }
}

class _MiniLyricsControls extends StatelessWidget {
  final Color color;
  final Color backgroundColor;
  final BorderRadiusGeometry borderRadius;
  final VoidCallback onExit;

  const _MiniLyricsControls({
    required this.color,
    required this.backgroundColor,
    required this.borderRadius,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    const iconSize = 18.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor.withOpacityExt(1.0),
        borderRadius: borderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 6.0),
            NamidaIconButton(
              horizontalPadding: 6.0,
              iconSize: iconSize,
              iconColor: color,
              icon: Broken.previous,
              tooltip: () => lang.previous,
              onPressed: () => Player.inst.previous().ignoreError(),
            ),
            ObxO(
              rx: Player.inst.playWhenReady,
              builder: (context, playWhenReady) => NamidaIconButton(
                horizontalPadding: 6.0,
                iconSize: iconSize,
                iconColor: color,
                icon: playWhenReady ? Broken.pause : Broken.play,
                tooltip: () => playWhenReady ? lang.pause : lang.play,
                onPressed: () => Player.inst.togglePlayPause().ignoreError(),
              ),
            ),
            NamidaIconButton(
              horizontalPadding: 6.0,
              iconSize: iconSize,
              iconColor: color,
              icon: Broken.next,
              tooltip: () => lang.next,
              onPressed: () => Player.inst.next().ignoreError(),
            ),
            const SizedBox(width: 4.0),
            NamidaIconButton(
              horizontalPadding: 8.0,
              iconSize: iconSize,
              iconColor: color,
              icon: Broken.maximize_3,
              tooltip: () => lang.miniLyricsWindow,
              onPressed: onExit,
            ),
          ],
        ),
      ),
    );
  }
}
