import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:vibration/vibration.dart';
import 'package:youtipie/class/youtipie_description/youtipie_description.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class YoutubeDescriptionWidget extends StatefulWidget {
  final String? videoId;
  final YoutipieDescription content;
  final Color? linkColor;
  final Widget Function(TextSpan span)? childBuilder;

  const YoutubeDescriptionWidget({
    super.key,
    required this.videoId,
    required this.content,
    this.childBuilder,
    this.linkColor,
  });

  @override
  State<YoutubeDescriptionWidget> createState() => _YoutubeDescriptionWidgetState();
}

class _YoutubeDescriptionWidgetState extends State<YoutubeDescriptionWidget> {
  late final _manager = YoutubeDescriptionWidgetManager();

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linkColor = widget.linkColor ?? context.theme.colorScheme.primary.withAlpha(210);
    final parts = widget.content.parts;
    final TextSpan mainSpan;
    if (parts != null && parts.isNotEmpty) {
      mainSpan = _manager.buildMainSpan(parts, widget.videoId, linkColor);
    } else {
      mainSpan = TextSpan(text: widget.content.rawText);
    }

    final Widget child;

    if (widget.childBuilder != null) {
      child = widget.childBuilder!(mainSpan);
    } else {
      child = Text.rich(
        mainSpan,
        textAlign: TextAlign.start,
      );
    }

    return SelectionArea(child: child);
  }
}

class YoutubeDescriptionWidgetManager {
  YoutubeDescriptionWidgetManager();

  late final _activeRecognizers = <TapGestureRecognizer>[];

  void dispose() {
    _activeRecognizers.loop((item) => item.dispose());
    _activeRecognizers.clear();
  }

  TextSpan buildMainSpan(List<StylesWrapper> styleParts, String? videoId, Color linkColor) {
    return TextSpan(
      children: styleParts.mapped((sw) => _styleWrapperToSpan(sw, videoId, linkColor)),
    );
  }

  Widget? _latestAttachment;
  InlineSpan _styleWrapperToSpan(StylesWrapper sw, String? videoId, Color linkColor) {
    if (sw.attachementUrl != null) {
      _latestAttachment = YoutubeThumbnail(
        type: ThumbnailType.other,
        key: Key(sw.attachementUrl ?? ''),
        width: 16.0,
        isImportantInCache: true,
        customUrl: sw.attachementUrl,
      );
      return const TextSpan(); // we combining attachment with the next piece
    }
    bool addVMargin = false;
    bool surroundWithBG = false;
    if (_latestAttachment != null) {
      surroundWithBG = true;
      addVMargin = true;
    }
    void Function()? onTap;
    if (sw.hashtag != null) {
      // TODO: onTap for hashtags
    } else if (sw.videoId != null) {
      surroundWithBG = true;
      onTap = () {
        if (sw.videoId == videoId && sw.videoStartSeconds != null) {
          Player.inst.seek(Duration(seconds: sw.videoStartSeconds!));
          Vibration.vibrate(duration: 10, amplitude: 20);
        } else {
          Player.inst.playOrPause(0, [YoutubeID(id: sw.videoId!, playlistID: null)], QueueSource.others);
          // TODO: seek after playing?
        }
      };
    } else if (sw.channelId != null) {
      onTap = YTChannelSubpage(channelID: sw.channelId!, channel: null).navigate;
    } else if (sw.playlistId != null) {
      onTap = YTHostedPlaylistSubpage.fromId(playlistId: sw.playlistId!, userPlaylist: null).navigate;
    } else if (sw.link != null) {
      onTap = () => NamidaLinkUtils.openLinkPreferNamida(sw.linkClean ?? sw.link!);
    }

    final colorized = onTap != null || sw.link != null || sw.hashtag != null;
    final textStyle = TextStyle(
      color: colorized ? linkColor : null,
      fontSize: onTap != null ? 13.5 : 14.0,
      fontStyle: sw.italic ? FontStyle.italic : FontStyle.normal,
      fontWeight: sw.bold
          ? FontWeight.w800
          : sw.medium
              ? FontWeight.w700
              : FontWeight.w500,
      decoration: sw.strikethrough ? TextDecoration.lineThrough : null,
    );

    if (surroundWithBG) {
      Widget child = Text(sw.text);

      double hmargin = 0.0;
      double vpadding = 2.0;
      double hpadding = 4.0;
      double br = 4.0;

      if (_latestAttachment != null) {
        hmargin += 4.0;
        vpadding += 2.0;
        hpadding += 2.0;
        br += 4.0;
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _latestAttachment!,
            child,
          ],
        );
        _latestAttachment = null;
      }
      child = ColoredBox(
        color: linkColor.withOpacity(0.1),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hpadding, vertical: vpadding),
          child: child,
        ),
      );
      final radius = br.multipliedRadius;
      if (radius > 0) {
        child = ClipPath(
          clipper: DecorationClipper(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          child: child,
        );
      }
      if (onTap != null) {
        child = TapDetector(
          onTap: onTap,
          child: child,
        );
      }

      if (addVMargin || hmargin > 0) {
        child = Padding(
          padding: EdgeInsets.symmetric(vertical: addVMargin ? 2.0 : 0, horizontal: hmargin),
          child: child,
        );
      }
      return WidgetSpan(
        child: child,
        style: textStyle,
        alignment: PlaceholderAlignment.middle,
      );
    } else {
      TapGestureRecognizer? recognizer;
      if (onTap != null) {
        recognizer = TapGestureRecognizer()..onTap = onTap;
        _activeRecognizers.add(recognizer);
      }
      return TextSpan(
        text: sw.text,
        style: textStyle,
        recognizer: recognizer,
      );
    }
  }
}
