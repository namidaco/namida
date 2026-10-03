part of 'effects.dart';

abstract class NamidaBackdrops {
  static const minUnits = 1;
  static const maxUnits = 10;

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

  static void removeAppWallpaper() {
    final path = settings.appWallpaper.value;
    if (path == null) return;
    settings.appWallpaper.reset();
    removeImage(path);
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
          kind: _BackdropKind.appWallpaper,
          blurUnits: settings.appWallpaperBlur.valueR,
          dimUnits: settings.appWallpaperDim.valueR,
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
                kind: _BackdropKind.player,
                blurUnits: settings.playerBackgroundBlur.valueR,
                dimUnits: settings.playerBackgroundDim.valueR,
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
          kind: _BackdropKind.player,
          blurUnits: settings.playerBackgroundBlur.valueR,
          dimUnits: settings.playerBackgroundDim.valueR,
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
  final _BackdropKind kind;
  final int blurUnits;
  final int dimUnits;
  final bool hasVignette;
  final bool isAnimated;
  final _BackdropImageBuilder imageBuilder;

  const _Backdrop({
    super.key,
    required this.kind,
    required this.blurUnits,
    required this.dimUnits,
    required this.hasVignette,
    required this.isAnimated,
    required this.imageBuilder,
  });

  static const _maxSigma = 40.0;
  static const _maxShrink = 8.0;

  static double _unitsToFraction(int unitsPre, double minFraction) {
    final units = unitsPre.withMinimum(NamidaBackdrops.minUnits).withMaximum(NamidaBackdrops.maxUnits);
    final fractionPerUnit = (1.0 - minFraction) / (NamidaBackdrops.maxUnits - NamidaBackdrops.minUnits);
    return minFraction + (units - NamidaBackdrops.minUnits) * fractionPerUnit;
  }

  static const _vignette = BoxDecoration(
    gradient: RadialGradient(
      radius: 0.95,
      colors: [Color(0x00000000), Color(0x99000000)],
      stops: [0.45, 1.0],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final blurFraction = _unitsToFraction(blurUnits, kind.minBlurFraction);
    final dimFraction = _unitsToFraction(dimUnits, kind.minDimFraction);
    final scrimColor = context.theme.scaffoldBackgroundColor.withOpacityExt(dimFraction);
    return LayoutBuilder(
      builder: (context, constraints) {
        // -- blurred in a box this much smaller then stretched back, so the blur only ever runs over a fraction of the pixels
        final sigma = blurFraction * _maxSigma;
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

enum _BackdropKind {
  appWallpaper(minBlurFraction: 0.25, minDimFraction: 0.4),
  player(minBlurFraction: 0.5, minDimFraction: 0.5),
  ;

  final double minBlurFraction;
  final double minDimFraction;

  const _BackdropKind({required this.minBlurFraction, required this.minDimFraction});
}

typedef _BackdropImageBuilder = Widget Function(double width, double height, bool isCrisp);
