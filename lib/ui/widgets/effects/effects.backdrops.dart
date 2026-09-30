part of 'effects.dart';

abstract class NamidaBackdrops {
  static const minDim = 60;
  static const minBlur = 40;

  static Future<String?> importImage({required String? replacing}) async {
    final pickedPaths = await NamidaStorage.inst.pickFiles(memetype: NamidaStorageFileMemeType.image);
    final pickedPath = pickedPaths.firstOrNull;
    if (pickedPath == null) return null;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedPath.getFilename}';
    final storedPath = FileParts.joinPath(AppDirs.WALLPAPERS, fileName);
    try {
      await File(pickedPath).copy(storedPath);
    } catch (e) {
      snackyy(message: e.toString(), isError: true);
      return null;
    }
    if (replacing != null) File(replacing).tryDeleting();
    return storedPath;
  }

  static void removeImage(String path) {
    File(path).tryDeleting();
  }
}

class NamidaAppWallpaper extends StatelessWidget {
  const NamidaAppWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final path = settings.appWallpaper.valueR;
        if (path == null) return const SizedBox();
        return _Backdrop(
          blur: settings.appWallpaperBlur.valueR,
          dim: settings.appWallpaperDim.valueR,
          hasVignette: false,
          isAnimated: false,
          imageBuilder: (width, height, isCrisp) => _BackdropFileImage(
            path: path,
            width: width,
            height: height,
          ),
        );
      },
    );
  }
}

class NamidaPlayerBackground extends StatelessWidget {
  const NamidaPlayerBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.playerBackground,
      builder: (context, source) => switch (source) {
        PlayerBackground.none => const SizedBox(),
        PlayerBackground.artwork => const _PlayerArtworkBackdrop(),
        PlayerBackground.image => const _PlayerImageBackdrop(),
      },
    );
  }
}

class _PlayerArtworkBackdrop extends StatelessWidget {
  const _PlayerArtworkBackdrop();

  static const _switchDuration = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final item = Player.inst.currentItem.valueR;
        final backdrop = item == null
            ? null
            : _Backdrop(
                key: ValueKey(item),
                blur: settings.playerBackgroundBlur.valueR,
                dim: settings.playerBackgroundDim.valueR,
                hasVignette: settings.playerBackgroundVignette.valueR,
                isAnimated: settings.playerBackgroundAnimated.valueR,
                imageBuilder: (width, height, isCrisp) => _BackdropArtwork(
                  item: item,
                  width: width,
                  height: height,
                  isCrisp: isCrisp,
                ),
              );
        return CustomAnimatedSwitcher(
          duration: _switchDuration,
          child: backdrop,
        );
      },
    );
  }
}

class _PlayerImageBackdrop extends StatelessWidget {
  const _PlayerImageBackdrop();

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final path = settings.playerBackgroundImage.valueR;
        if (path == null) return const SizedBox();
        return _Backdrop(
          blur: settings.playerBackgroundBlur.valueR,
          dim: settings.playerBackgroundDim.valueR,
          hasVignette: settings.playerBackgroundVignette.valueR,
          isAnimated: settings.playerBackgroundAnimated.valueR,
          imageBuilder: (width, height, isCrisp) => _BackdropFileImage(
            path: path,
            width: width,
            height: height,
          ),
        );
      },
    );
  }
}

class _Backdrop extends StatelessWidget {
  final int blur;
  final int dim;
  final bool hasVignette;
  final bool isAnimated;
  final _BackdropImageBuilder imageBuilder;

  const _Backdrop({
    super.key,
    required this.blur,
    required this.dim,
    required this.hasVignette,
    required this.isAnimated,
    required this.imageBuilder,
  });

  static const _maxSigma = 40.0;
  static const _maxShrink = 8.0;

  static const _vignette = BoxDecoration(
    gradient: RadialGradient(
      radius: 0.95,
      colors: [Color(0x00000000), Color(0x99000000)],
      stops: [0.45, 1.0],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final blur = this.blur.withMinimum(NamidaBackdrops.minBlur);
    final dim = this.dim.withMinimum(NamidaBackdrops.minDim);
    final scrimColor = context.theme.scaffoldBackgroundColor.withOpacityExt(dim / 100);
    return LayoutBuilder(
      builder: (context, constraints) {
        // -- blurred in a box this much smaller then stretched back, so the blur only ever runs over a fraction of the pixels
        final sigma = blur / 100 * _maxSigma;
        final shrink = (sigma / 4).clampDouble(1.0, _maxShrink);
        final width = constraints.maxWidth / shrink;
        final height = constraints.maxHeight / shrink;
        final image = imageBuilder(width, height, shrink == 1.0);
        Widget picture = RepaintBoundary(
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: width,
              height: height,
              child: NamidaBlur(
                blur: sigma / shrink,
                child: image,
              ),
            ),
          ),
        );
        if (isAnimated) {
          picture = _BackdropPulse(
            child: picture,
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            // -- blur spreads ~3 sigma past the box, pulse scales past it
            ClipRect(
              child: picture,
            ),
            ColoredBox(
              color: scrimColor,
            ),
            if (hasVignette)
              const DecoratedBox(
                decoration: _vignette,
              ),
          ],
        );
      },
    );
  }
}

class _BackdropPulse extends StatefulWidget {
  final Widget child;

  const _BackdropPulse({required this.child});

  @override
  State<_BackdropPulse> createState() => _BackdropPulseState();
}

class _BackdropPulseState extends State<_BackdropPulse> {
  _VisualizerDriver? _driver;

  static const _restScale = 1.04;
  static const _swell = 0.08;

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    _driver?.detach(isSpectrumNeeded: false, hasParticles: false);
    _driver = null;
  }

  @override
  Widget build(BuildContext context) {
    if (namidaAnimationsPaused(context)) {
      _detach();
      return widget.child;
    }
    final driver = _driver ??= _VisualizerDriver.attach(isSpectrumNeeded: false, hasParticles: false);
    return AnimatedBuilder(
      animation: driver,
      child: widget.child,
      builder: (context, child) => Transform.scale(
        scale: _restScale + driver.level * _swell,
        child: child,
      ),
    );
  }
}

class _BackdropFileImage extends StatelessWidget {
  final String path;
  final double width;
  final double height;

  const _BackdropFileImage({
    required this.path,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final file = File(path);
    final cacheHeight = (height * pixelRatio).round();
    return Image.file(
      file,
      width: width,
      height: height,
      cacheHeight: cacheHeight,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const SizedBox(),
    );
  }
}

class _BackdropArtwork extends StatelessWidget {
  final Playable item;
  final double width;
  final double height;
  final bool isCrisp;

  const _BackdropArtwork({
    required this.item,
    required this.width,
    required this.height,
    required this.isCrisp,
  });

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    if (item is YoutubeID) {
      return YoutubeThumbnail(
        key: ValueKey(item.id),
        type: ThumbnailType.video,
        videoId: item.id,
        width: width,
        height: height,
        borderRadius: 0.0,
        blur: 0.0,
        compressed: !isCrisp,
        preferLowerRes: !isCrisp,
        isImportantInCache: true,
        forceSquared: true,
        displayFallbackIcon: false,
        fadeMilliSeconds: 0,
      );
    }
    if (item is Selectable) {
      final track = item.track;
      final imagePath = track.pathToImage;
      return ArtworkWidget(
        key: ValueKey(imagePath),
        track: track,
        path: imagePath,
        thumbnailSize: width,
        width: width,
        height: height,
        borderRadius: 0.0,
        blur: 0.0,
        compressed: !isCrisp,
        forceSquared: true,
        displayIcon: false,
        fadeMilliSeconds: 0,
      );
    }
    return const SizedBox();
  }
}

typedef _BackdropImageBuilder = Widget Function(double width, double height, bool isCrisp);
