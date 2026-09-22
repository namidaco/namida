import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:flutter_mailer/flutter_mailer.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rhttp/rhttp.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/version_wrapper.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/shortcuts_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/controller/version_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/jellyfish.dart';
import 'package:namida/ui/widgets/namida_markdown.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/ui/widgets/stats.dart';

class AboutPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_about;

  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();

  static void showShortcutsDialog(BuildContext context) {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.flash_1,
        title: lang.shortcuts,
        normalTitleStyle: true,
        actions: [
          const DoneButton(),
        ],
        child: SizedBox(
          height: context.height * 0.6,
          child: ShortcutsInfoWidget(
            manager: ShortcutsController.instance!,
          ),
        ),
      ),
    );
  }
}

class _AboutPageState extends State<AboutPage> {
  late final _loadingChangelog = false.obso;
  final _scrollOffset = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();

    VersionController.inst.ensureInitialized();
  }

  @override
  void dispose() {
    _loadingChangelog.close();
    _scrollOffset.dispose();
    super.dispose();
  }

  String _getDateDifferenceText() {
    final buildDate = VersionWrapper.current?.buildDate;
    if (buildDate == null) return '';
    final differenceText = TimeAgoController.dateFromNow(buildDate, long: true);
    return "($differenceText)";
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final imageSize = Dimensions.inst.availableAppContentWidth * 0.25;
    final topPadding = imageSize / 2;
    const textTopPadding = 28.0 * 2;
    final buildDateDiff = _getDateDifferenceText();
    final currentVersion = VersionWrapper.current;
    final currentVersionText = currentVersion?.prettyVersion ?? '';
    final isBeta = currentVersion?.isBeta ?? false;

    final fallbackAvatar = SizedBox(
      width: 48.0,
      height: 48.0,
      child: Icon(
        Broken.user,
        color: Colors.white.withOpacityExt(0.8),
      ),
    );

    final double horizontalMargin = Dimensions.inst.getSettingsHorizontalMargin(context);
    final jellyBanner = NamidaJellys.enabled
        ? _EnabledAppIconBuilder(
            builder: (enabledIcon) => enabledIcon.isJelly
                ? _UnderwaterAmbience(
                    child: _JellydaBanner(
                      scrollOffset: _scrollOffset,
                      height: context.height * 0.42,
                    ),
                  )
                : const SizedBox(),
          )
        : null;
    final aboutPage = ObxO(
      rx: VersionController.inst.latestVersion,
      builder: (context, latestVersion) => SuperSmoothListView(
        padding: kBottomPaddingInsets.add(EdgeInsets.symmetric(horizontal: horizontalMargin)),
        children: [
          SizedBox(height: topPadding),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacityExt(0.6),
              borderRadius: BorderRadius.circular(20.0.multipliedRadius),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Column(
                  children: [
                    SizedBox(height: topPadding + textTopPadding),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: NamidaAboutListTile(
                        trailing: const Icon(Broken.code_circle),
                        leading: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.fromRGBO(25, 25, 25, 0.8),
                          ),
                          child: _CachedAvatar(
                            asset: _AboutAsset.developerAvatar,
                            size: 48.0,
                            fallback: fallbackAvatar,
                          ),
                        ),
                        title: lang.developer,
                        subtitle: 'MSOB7YY',
                        link: 'https://github.com/MSOB7YY',
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: -topPadding,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.all(4.0),
                        width: imageSize,
                        height: imageSize,
                        clipBehavior: Clip.none,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.fromRGBO(25, 25, 25, 0.1),
                        ),
                        child: _KuruKuruActivator(
                          child: _EnabledAppIconBuilder(
                            builder: (enabledIcon) {
                              return GestureDetector(
                                onLongPress: NamidaJellys.enabled && enabledIcon.isJelly ? JellyFullArt.show : null,
                                child: Image.asset(
                                  enabledIcon.assetPath,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        "Namida",
                        style: textTheme.displayLarge,
                      ),
                      if (currentVersionText != '')
                        latestVersion?.isUpdate() ?? false
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    currentVersionText,
                                    style: textTheme.displaySmall,
                                  ),
                                  const SizedBox(width: 4.0),
                                  const Icon(
                                    Broken.arrow_up_1,
                                    size: 8.0,
                                  ),
                                ],
                              )
                            : Text(
                                currentVersionText,
                                style: textTheme.displaySmall,
                              ),
                      if (buildDateDiff != '')
                        Text(
                          buildDateDiff,
                          style: textTheme.displaySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SettingsCard(
            icon: Broken.link_circle,
            title: lang.socials,
            subtitle: lang.socialsSubtitle,
            child: Column(
              children: [
                const NamidaAboutListTile(
                  icon: Broken.send_2,
                  title: 'Telegram',
                  link: 'https://t.me/namida_official',
                ),
                NamidaAboutListTile(
                  leading: Image.asset(
                    'assets/icons/discord.png',
                    color: context.defaultIconColor(),
                    height: 24.0,
                  ),
                  title: 'Discord',
                  link: 'https://discord.gg/WeY7DTVChT',
                ),
              ],
            ),
          ),
          const StatsSection(),
          SettingsCard(
            icon: Broken.hierarchy,
            title: lang.development,
            subtitle: null,
            child: Column(
              children: [
                NamidaAboutListTile(
                  icon: Broken.message_question,
                  title: lang.guide,
                  subtitle: lang.learnMore,
                  link: AppDocsLinks.BASE.link,
                ),
                NamidaAboutListTile(
                  icon: Broken.message_programming,
                  title: 'GitHub',
                  subtitle: lang.seeProjectCodeOnSite(site: 'Github'),
                  link: AppSocial.GITHUB,
                ),
                NamidaAboutListTile(
                  // icon: Broken.bezier,
                  icon: Broken.command_square,
                  title: '${lang.issues}/${lang.features}',
                  subtitle: lang.suggestionSubtitle(site: 'Github'),
                  link: AppSocial.GITHUB_ISSUES,
                ),
                ObxO(
                  rx: _loadingChangelog,
                  builder: (context, isLoading) => NamidaAboutListTile(
                    icon: Broken.activity,
                    title: lang.changelog,
                    subtitle: lang.changelogSubtitle,
                    trailing: isLoading ? const LoadingIndicator() : null,
                    onTap: () async {
                      _loadingChangelog.value = true;
                      final NamidaMarkdownDocument document;
                      try {
                        final response = await Rhttp.get('https://raw.githubusercontent.com/namidaco/namida/main/CHANGELOG.md');
                        document = await NamidaMarkdownDocument.parseAsync(response.body);
                      } finally {
                        _loadingChangelog.value = false;
                      }
                      NamidaNavigator.inst.showSheet(
                        showDragHandle: true,
                        isScrollControlled: true,
                        heightPercentage: 0.6,
                        builder: (context, bottomPadding, maxWidth, maxHeight) => NamidaMarkdown.document(
                          document: document,
                          selectable: true,
                          scrollable: true,
                        ),
                      );
                    },
                  ),
                ),
                NamidaAboutListTile(
                  icon: Broken.language_circle,
                  title: lang.addLanguage,
                  subtitle: lang.addLanguageSubtitle,
                  link: AppSocial.TRANSLATION_REPO,
                ),
              ],
            ),
          ),
          SettingsCard(
            icon: Broken.heart_circle,
            title: lang.donate,
            subtitle: lang.donateSubtitle,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => NamidaLinkUtils.openLink(AppSocial.DONATE_KOFI),
                      child: CustomAnimatedSwitcher(
                        duration: const Duration(milliseconds: kThemeAnimationDurationMS),
                        child: context.isDarkMode
                            ? Image.asset(
                                'assets/logos/donate_kofi_dark.png',
                                height: 48.0,
                                key: const Key('donate_kofi_dark'),
                              )
                            : Image.asset(
                                'assets/logos/donate_kofi_light.png',
                                height: 48.0,
                                key: const Key('donate_kofi_light'),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.0),
                  Expanded(
                    child: InkWell(
                      onTap: () => NamidaLinkUtils.openLink(AppSocial.DONATE_BUY_ME_A_COFFEE),
                      child: Image.asset(
                        'assets/logos/donate_bmc.webp',
                        height: 48.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SettingsCard(
            title: lang.others,
            icon: Broken.record_circle,
            subtitle: null,
            child: Column(
              children: [
                if (ShortcutsController.instance != null)
                  NamidaAboutListTile(
                    icon: Broken.flash_1,
                    title: lang.shortcuts,
                    onTap: () => AboutPage.showShortcutsDialog(context),
                  ),
                NamidaAboutListTile(
                  icon: Broken.archive_book,
                  title: lang.license,
                  subtitle: lang.licenseSubtitle,
                  onTap: () {
                    showLicensePage(
                      context: context,
                      useRootNavigator: true,
                      applicationVersion: currentVersionText,
                    );
                  },
                ),
                NamidaAboutListTile(
                  icon: Broken.cpu,
                  title: lang.appVersion,
                  subtitle: currentVersionText,
                  link: isBeta ? AppSocial.GITHUB_RELEASES_BETA : AppSocial.GITHUB_RELEASES,
                  trailing: NamidaInkWell(
                    borderRadius: 8.0,
                    bgColor: theme.cardColor,
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: latestVersion == null
                          ? [
                              Text(
                                '?',
                                style: textTheme.displaySmall,
                              ),
                            ]
                          : latestVersion.isUpdate() ?? false
                          ? [
                              Text(
                                latestVersion.prettyVersion,
                                style: textTheme.displaySmall,
                              ),
                              const SizedBox(width: 4.0),
                              const Icon(
                                Broken.arrow_up_1,
                                size: 14.0,
                              ),
                            ]
                          : [
                              const Icon(
                                Broken.tick_circle,
                                size: 14.0,
                              ),
                            ],
                    ),
                  ),
                ),
                NamidaAboutListTile(
                  icon: Broken.clipboard_text,
                  title: lang.shareLogs,
                  trailing: NamidaIconButton(
                    iconColor: context.defaultIconColor(),
                    icon: Broken.direct_send,
                    tooltip: () => AppSocial.EMAIL,
                    onPressed: () async {
                      final attachments = await AppPaths.getAllExistingLogsAndSettingsAsZip();
                      try {
                        final mailOptions = MailOptions(
                          body: 'pls look at this report im beggin u pls solve my issue pls i wa-',
                          subject: 'Namida Logs Report',
                          recipients: [AppSocial.EMAIL],
                          attachments: attachments,
                        );
                        await FlutterMailer.send(mailOptions);
                      } on MissingPluginException catch (_) {
                        NamidaUtils.shareFiles(attachments);
                      }
                    },
                  ),
                  onTap: () async {
                    final filePaths = await AppPaths.getAllExistingLogsAndSettingsAsZip();
                    NamidaUtils.shareFiles(filePaths);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return BackgroundWrapper(
      child: !NamidaJellys.enabled
          ? aboutPage
          : Stack(
              children: [
                ?jellyBanner,
                const Positioned.fill(
                  child: IgnorePointer(
                    child: JellyField(
                      count: 4,
                      opacity: 0.3,
                      minHeight: 90.0,
                      maxHeight: 240.0,
                      seed: 3,
                    ),
                  ),
                ),
                NotificationListener<ScrollUpdateNotification>(
                  onNotification: (notification) {
                    if (jellyBanner != null && notification.depth == 0) _scrollOffset.value = notification.metrics.pixels;
                    return false;
                  },
                  child: aboutPage,
                ),
              ],
            ),
    );
  }
}

class NamidaAboutListTile extends StatelessWidget {
  final Widget? leading;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? link;
  final void Function()? onTap;
  final Widget? trailing;

  const NamidaAboutListTile({
    super.key,
    this.leading,
    this.icon,
    required this.title,
    this.subtitle,
    this.link,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      leading: leading,
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap:
          onTap ??
          () {
            if (link != null) {
              NamidaLinkUtils.openLink(link!);
            }
          },
    );
  }
}

class _EnabledAppIconBuilder extends StatelessWidget {
  final Widget Function(NamidaAppIcons enabledIcon) builder;
  const _EnabledAppIconBuilder({required this.builder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: NamidaChannel.inst.getEnabledAppIcon(),
      builder: (context, snapshot) {
        final enabledIcon = snapshot.data ?? NamidaChannel.defaultAppIconForPlatform;
        return builder(enabledIcon);
      },
    );
  }
}

class _KuruKuruActivator extends StatefulWidget {
  final Widget child;
  const _KuruKuruActivator({required this.child});

  @override
  State<_KuruKuruActivator> createState() => __KuruKuruActivatorState();
}

class __KuruKuruActivatorState extends State<_KuruKuruActivator> with SingleTickerProviderStateMixin {
  static const _kMaxSampleDuration = Duration(seconds: 30);
  static const _kCompletionGrace = Duration(seconds: 2);

  AnimationController? _controller;
  Animation<double>? _animation;
  List<AVPlayer>? _activePlayers;

  int _speedLevel = 0;

  void _initAndAnimate() {
    _controller ??= AnimationController(vsync: this);

    if (mounted) {
      // _controller?.stop();

      final newSpeedLevel = (_speedLevel++) * 2;
      final playLongerVer = _speedLevel == 8;
      if (_speedLevel > 8 && _controller?.isAnimating == true) {
        // -- is long kuru kurin rn
        return;
      }

      final duration = playLongerVer ? 26000 : 1000 + (newSpeedLevel * 200);
      _controller?.duration = Duration(milliseconds: duration);

      final end = playLongerVer ? 200.0 : 4.0 + newSpeedLevel;
      final decelerateCurve =
          Tween<double>(
            begin: 0.0,
            end: end,
          ).animate(
            CurvedAnimation(
              parent: _controller!,
              curve: Curves.decelerate,
            ),
          );

      setState(() => _animation = decelerateCurve);
      _controller?.forward(from: 0).then((_) => _speedLevel = 0);

      _play(longerVer: playLongerVer);

      if (kAllowJellysInvasion && playLongerVer) {
        if (settings.extra.jellysInvasion != true) NamidaJellys.setInvasion(true);
      }
    }
  }

  void _play({bool longerVer = false}) async {
    (_AboutAsset, Duration) randomSample;
    if (longerVer) {
      randomSample = (_AboutAsset.kuruKuruLong, Duration(milliseconds: 0));
    } else {
      const sounds = [
        (_AboutAsset.kuruKuru, Duration(milliseconds: 200)),
        (_AboutAsset.kururin, Duration(milliseconds: 0)),
      ];
      randomSample = sounds.random;
    }
    final file = await randomSample.$1.resolve();
    if (file == null || !mounted) return;
    final pl = Player.createTempPlayer();
    (_activePlayers ??= []).add(pl);
    try {
      final duration = await pl.setSource(
        ItemPrepareConfig(
          AudioVideoSource.file(file.path),
          index: 0,
          initialPosition: randomSample.$2,
          audioTrackId: null,
          videoOptions: null,
        ),
      );
      if (Player.inst.isPlaying.value) {
        await pl.setVolume(0.25);
      } else {
        await pl.setVolume(0.5);
      }
      await pl.play();
      // -- some backends never report completion, the player would never be released
      final remainingMS = (duration ?? _kMaxSampleDuration) - randomSample.$2;
      await Future.any([
        pl.processingStateStream.firstWhere((element) => element == ProcessingState.completed).ignoreError(),
        Future.delayed(remainingMS + _kCompletionGrace),
      ]);
    } catch (_) {
    } finally {
      if (_activePlayers?.remove(pl) == true) {
        await pl.pause().ignoreError();
        pl.dispose();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    final activePlayers = _activePlayers;
    if (activePlayers != null) {
      for (final pl in activePlayers) {
        pl.pause().whenComplete(pl.dispose);
      }
      activePlayers.clear();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;
    final child = widget.child;

    return DoubleTapDetector(
      behavior: .translucent,
      onDoubleTap: () => _initAndAnimate(),
      child: animation == null
          ? child
          : RotationTransition(
              turns: animation,
              child: child,
            ),
    );
  }
}

// by claude
class _UnderwaterAmbience extends StatefulWidget {
  final Widget child;

  const _UnderwaterAmbience({required this.child});

  @override
  State<_UnderwaterAmbience> createState() => _UnderwaterAmbienceState();
}

class _UnderwaterAmbienceState extends State<_UnderwaterAmbience> {
  static const _startDelay = Duration(seconds: 1);
  static const _fadeInMs = 5000;
  static const _fadeOutMs = 3000;
  static const _crossfadeMs = 6000;

  /// The crossfade starts this early, covers the first load of the second voice.
  static const _crossfadeLeadMs = 3000;

  static const _volume = 0.5;
  static const _volumeWhilePlaying = 0.25;

  // -- two voices take turns, the ending one crossfades into the other restarting from zero
  _AmbienceVoice? _active;
  _AmbienceVoice? _idle;

  Timer? _timer;
  String _path = '';
  double _targetVolume = _volume;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    final file = _AboutAsset.underwaterAmbience.resolve();
    _timer = Timer(_startDelay, () => _start(file));
  }

  void _start(Future<File?> fileFuture) async {
    final file = await fileFuture;
    if (file == null || _disposed) return;
    _path = file.path;
    _targetVolume = Player.inst.isPlaying.value ? _volumeWhilePlaying : _volume;
    _bringIn(_active = _AmbienceVoice(), _fadeInMs, null);
  }

  void _crossfade() {
    final ending = _active;
    final next = _idle ?? _AmbienceVoice();
    _active = next;
    _idle = ending;
    _bringIn(next, _crossfadeMs, ending);
  }

  void _bringIn(_AmbienceVoice voice, int fadeMs, _AmbienceVoice? ending) async {
    try {
      final duration = await voice.prepare(_path);
      if (_disposed) return;
      voice.player.play().ignoreError(); // -- on android it only completes once playback ends

      voice.fadeTo(_targetVolume, fadeMs);
      ending?.fadeTo(0.0, fadeMs, onDone: ending.rewind);

      if (duration == null) return;
      final nextCrossfadeMs = duration.inMilliseconds - _crossfadeMs - _crossfadeLeadMs;
      if (nextCrossfadeMs > 0) _timer = Timer(Duration(milliseconds: nextCrossfadeMs), _crossfade);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _active?.release(_fadeOutMs);
    _idle?.release(_fadeOutMs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Owns its fade timer, so it can finish fading out after the page is gone.
class _AmbienceVoice {
  static const _curve = CrossFadeCurve.equalPower();
  static const _tick = Duration(milliseconds: 50);

  final player = Player.createTempPlayer();

  Timer? _fadeTimer;
  Duration? _duration;
  bool _prepared = false;

  Future<Duration?> prepare(String path) async {
    if (_prepared) return _duration;
    await player.setVolume(0.0);
    _duration = await player.setSource(
      ItemPrepareConfig(
        AudioVideoSource.file(path),
        index: 0,
        initialPosition: Duration.zero,
        audioTrackId: null,
        videoOptions: null,
      ),
    );
    _prepared = true;
    return _duration;
  }

  void fadeTo(double target, int durationMs, {void Function()? onDone}) {
    _fadeTimer?.cancel();
    final start = player.volume;
    final stopwatch = Stopwatch()..start();
    _fadeTimer = Timer.periodic(_tick, (timer) {
      final t = (stopwatch.elapsedMilliseconds / durationMs).clampDouble(0.0, 1.0);
      final volume =
          target >
              start //
          ? start + (target - start) * _curve.transform(t)
          : target + (start - target) * _curve.transform(1.0 - t);
      player.setVolume(volume);
      if (t >= 1.0) {
        timer.cancel();
        onDone?.call();
      }
    });
  }

  void rewind() {
    player.pause().whenComplete(() => player.seek(Duration.zero));
  }

  void release(int fadeOutMs) {
    if (player.playing) {
      fadeTo(0.0, fadeOutMs, onDone: _dispose);
    } else {
      _fadeTimer?.cancel();
      _dispose();
    }
  }

  void _dispose() {
    player.pause().whenComplete(player.dispose);
  }
}

class _CachedAvatar extends StatefulWidget {
  final _AboutAsset asset;
  final double size;
  final Widget fallback;

  const _CachedAvatar({required this.asset, required this.size, required this.fallback});

  @override
  State<_CachedAvatar> createState() => _CachedAvatarState();
}

class _CachedAvatarState extends State<_CachedAvatar> {
  File? _file;

  @override
  void initState() {
    super.initState();
    final file = widget.asset.file;
    if (file.existsSync()) {
      _file = file;
    } else {
      widget.asset.resolve().then((file) {
        if (file != null && mounted) setState(() => _file = file);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null) return widget.fallback;
    return Image.file(
      file,
      width: widget.size,
      height: widget.size,
      errorBuilder: (context, error, stackTrace) => widget.fallback,
    );
  }
}

class _AboutAsset {
  final String url;
  final String filename;

  const _AboutAsset(this.url, this.filename);

  static const developerAvatar = _AboutAsset('https://avatars.githubusercontent.com/u/85245079?s=144', 'developer_avatar');
  static const kuruKuru = _AboutAsset('https://www.myinstants.com/media/sounds/kurukuru.mp3', 'kurukuru.mp3');
  static const kururin = _AboutAsset('https://www.myinstants.com/media/sounds/kururinnn.mp3', 'kururinnn.mp3');
  static const kuruKuruLong = _AboutAsset('https://www.myinstants.com/media/sounds/kuru-kuru.mp3', 'kuru-kuru.mp3');

  /// CC0, https://freesound.org/people/Fission9/sounds/504641/
  static const underwaterAmbience = _AboutAsset('https://cdn.freesound.org/previews/504/504641_9395330-hq.mp3', 'underwater_ambience.mp3');

  static final _downloads = <String, Future<File?>>{};

  File get file => File(FileParts.joinPath(AppDirs.ABOUT_CACHE, filename));

  Future<File?> resolve() {
    final file = this.file;
    if (file.existsSync()) return Future.value(file);
    return _downloads[filename] ??= _download(file);
  }

  Future<File?> _download(File file) async {
    try {
      // -- myinstants sits behind cloudflare, which refuses requests without a user agent
      final bytes = (await Rhttp.getBytes(url, headers: const HttpHeaders.rawMap({'User-Agent': 'Namida'}))).body;
      if (bytes.isEmpty) return null;
      // -- renamed once complete, a half written file would be served forever otherwise
      final temp = File('${file.path}.part');
      try {
        await temp.writeAsBytes(bytes);
      } catch (_) {
        await temp.parent.create(recursive: true);
        await temp.writeAsBytes(bytes);
      }
      return await temp.rename(file.path);
    } catch (_) {
      return null;
    } finally {
      _downloads.remove(filename);
    }
  }
}

// by claude
class _JellydaBanner extends StatelessWidget {
  static const _parallaxFactor = 0.35;

  final ValueListenable<double> scrollOffset;
  final double height;

  const _JellydaBanner({required this.scrollOffset, required this.height});

  @override
  Widget build(BuildContext context) {
    final bgColor = context.theme.scaffoldBackgroundColor;
    // -- artwork is oversized & the parallax clamped by the same amount, so its bottom edge never scrolls into view
    final maxParallax = height * 0.5;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            height: height + maxParallax,
            child: ValueListenableBuilder<double>(
              valueListenable: scrollOffset,
              child: const JellyFullArt(
                alignment: Alignment.topCenter,
                opacity: 0.65,
                handOpacity: 0.0,
              ),
              builder: (context, offset, child) => Transform.translate(
                offset: Offset(0, -(offset * _parallaxFactor).clamp(0.0, maxParallax)),
                child: child,
              ),
            ),
          ),
          // -- page background gradient over the bottom half, so the artwork dissolves into the page
          Positioned(
            left: 0.0,
            right: 0.0,
            bottom: 0.0,
            height: height * 0.55,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor.withValues(alpha: 0.0),
                    bgColor.withValues(alpha: 0.75),
                    bgColor,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
