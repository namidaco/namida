import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/pip_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/simple_lyrics_line.dart';
import 'package:namida/ui/widgets/video_widget.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

// by claude
class NamidaPipView extends StatelessWidget {
  const NamidaPipView({super.key});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: PipController.inst.content,
      builder: (context, content) => switch (content ?? PipContent.artwork) {
        PipContent.video => const NamidaVideoControls(
          key: Key('pip_widget_child'),
          isFullScreen: true,
          showControls: false,
          forceEnableSponsorBlock: false,
          onMinimizeTap: null,
          isLocal: true,
        ),
        PipContent.lyrics => const _PipThemed(
          child: _PipLyrics(),
        ),
        PipContent.artwork => const _PipThemed(
          child: _PipArtwork(),
        ),
      },
    );
  }
}

class _PipThemed extends StatelessWidget {
  final Widget child;

  const _PipThemed({required this.child});

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final theme = AppThemes.inst.getAppTheme(CurrentColor.inst.miniplayerColor, false);
        return NTheme(
          data: theme,
          child: child,
        );
      },
    );
  }
}

class _PipLyrics extends StatelessWidget {
  const _PipLyrics();

  static const _kTextShadows = [
    Shadow(color: Color(0x66000000), blurRadius: 6.0),
  ];

  @override
  Widget build(BuildContext context) {
    final style = NText.medium
        .of(context)
        .copyWith(
          fontSize: 20.0,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadows: _kTextShadows,
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        const _PipBlurredArtwork(),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Center(
            child: SimpleLyricsLineWidget(
              textAlign: TextAlign.center,
              maxLines: 3,
              softWrap: true,
              fitToWidth: true,
              maxSecondaryLines: 2,
              wrapSecondaryLines: true,
              style: style,
            ),
          ),
        ),
      ],
    );
  }
}

/// blurred once per track at a tiny size, then drawn as a plain image so frames never run a blur pass.
class _PipBlurredArtwork extends StatefulWidget {
  const _PipBlurredArtwork();

  @override
  State<_PipBlurredArtwork> createState() => _PipBlurredArtworkState();
}

class _PipBlurredArtworkState extends State<_PipBlurredArtwork> {
  static const _kBlurredShortestSide = 64;
  static const _kBlurSigma = 8.0;
  static const _kDimColor = Color(0x73000000);

  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    Player.inst.currentItem.addListener(_onItemChanged);
    _onItemChanged();
  }

  @override
  void dispose() {
    Player.inst.currentItem.removeListener(_onItemChanged);
    _image?.dispose();
    super.dispose();
  }

  Future<void> _onItemChanged() async {
    final item = Player.inst.currentItem.value;
    final image = item == null ? null : await _createBlurredImage(item);
    if (!mounted || item != Player.inst.currentItem.value) {
      image?.dispose();
      return;
    }
    final oldImage = _image;
    setState(() => _image = image);
    oldImage?.dispose();
  }

  static Future<ui.Image?> _createBlurredImage(Playable item) async {
    final buffer = await PipController.getArtworkBuffer(item);
    if (buffer == null) return null;
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final isWide = descriptor.width >= descriptor.height;
      final codec = await descriptor.instantiateCodec(
        targetWidth: isWide ? null : _kBlurredShortestSide,
        targetHeight: isWide ? _kBlurredShortestSide : null,
      );
      final frame = await codec.getNextFrame();
      final smallImage = frame.image;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final blurFilter = ui.ImageFilter.blur(sigmaX: _kBlurSigma, sigmaY: _kBlurSigma, tileMode: TileMode.clamp);
      final paint = Paint()..imageFilter = blurFilter;
      canvas.drawImage(smallImage, Offset.zero, paint);
      final picture = recorder.endRecording();
      final blurredImage = await picture.toImage(smallImage.width, smallImage.height);
      picture.dispose();
      smallImage.dispose();
      codec.dispose();
      descriptor.dispose();
      return blurredImage;
    } catch (_) {
      return null;
    } finally {
      buffer.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RawImage(
            image: _image,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
          const ColoredBox(
            color: _kDimColor,
          ),
        ],
      ),
    );
  }
}

class _PipArtwork extends StatelessWidget {
  const _PipArtwork();

  @override
  Widget build(BuildContext context) {
    final width = context.width;
    final height = context.height;
    return ObxO(
      rx: Player.inst.currentItem,
      builder: (context, item) {
        if (item is YoutubeID) {
          final videoId = item.id;
          return YoutubeThumbnail(
            type: ThumbnailType.video,
            key: Key(videoId),
            isImportantInCache: true,
            width: width,
            height: height,
            borderRadius: 0,
            blur: 0,
            videoId: videoId,
            displayFallbackIcon: false,
            compressed: false,
            preferLowerRes: false,
            forceSquared: false,
            fit: BoxFit.cover,
          );
        }
        final track = item is Selectable ? item.track : null;
        return ArtworkWidget(
          key: ValueKey(track?.path),
          track: track,
          path: track?.pathToImage,
          thumbnailSize: width,
          width: width,
          height: height,
          borderRadius: 0,
          blur: 0,
          compressed: false,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
