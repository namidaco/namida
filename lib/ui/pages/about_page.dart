// ignore_for_file: implementation_imports, depend_on_referenced_packages

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:flutter_mailer/flutter_mailer.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:just_audio/just_audio.dart';
import 'package:markdown/src/ast.dart' as md;
import 'package:rhttp/rhttp.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/version_wrapper.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
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
        title: lang.SHORTCUTS,
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

  @override
  void initState() {
    super.initState();

    VersionController.inst.ensureInitialized();
  }

  @override
  void dispose() {
    _loadingChangelog.close();
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
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );

    final double horizontalMargin = Dimensions.inst.getSettingsHorizontalMargin(context);
    return BackgroundWrapper(
      child: ObxO(
        rx: VersionController.inst.latestVersion,
        builder: (context, latestVersion) => SuperSmoothListView(
          padding: kBottomPaddingInsets.add(EdgeInsets.symmetric(horizontal: horizontalMargin)),
          children: [
            SizedBox(height: topPadding),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.6),
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
                          visualDensity: VisualDensity.compact,
                          trailing: const Icon(Broken.code_circle),
                          leading: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.fromRGBO(25, 25, 25, 0.8),
                            ),
                            child: Image.network(
                              'https://avatars.githubusercontent.com/u/85245079',
                              width: 48.0,
                              height: 48.0,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress?.cumulativeBytesLoaded == loadingProgress?.expectedTotalBytes) {
                                  return child;
                                }
                                return fallbackAvatar;
                              },
                              errorBuilder: (context, error, stackTrace) => fallbackAvatar,
                            ),
                          ),
                          title: 'Developer',
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
                            child: FutureBuilder(
                              future: NamidaChannel.inst.getEnabledAppIcon(),
                              builder: (context, snapshot) {
                                final enabledIcon = snapshot.data ?? NamidaChannel.defaultIconForPlatform;
                                return Image.asset(
                                  enabledIcon.assetPath,
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
              title: 'Social',
              subtitle: 'join us on our platforms for updates, tips, discussion & ideas',
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
              title: 'Developement',
              subtitle: null,
              child: Column(
                children: [
                  const NamidaAboutListTile(
                    icon: Broken.message_programming,
                    title: 'GitHub',
                    subtitle: 'See Project Code on Github',
                    link: AppSocial.GITHUB,
                  ),
                  const NamidaAboutListTile(
                    // icon: Broken.bezier,
                    icon: Broken.command_square,
                    title: 'Issues/Features',
                    subtitle: 'Have an issue or suggestion? open an issue on GitHub',
                    link: AppSocial.GITHUB_ISSUES,
                  ),
                  ObxO(
                    rx: _loadingChangelog,
                    builder: (context, isLoading) => NamidaAboutListTile(
                      icon: Broken.activity,
                      title: lang.CHANGELOG,
                      subtitle: 'See what\'s newly added/fixed inside Namida',
                      trailing: isLoading ? const LoadingIndicator() : null,
                      onTap: () async {
                        _loadingChangelog.value = true;
                        final stringy = await Rhttp.get('https://raw.githubusercontent.com/namidaco/namida/main/CHANGELOG.md');
                        _loadingChangelog.value = false;
                        NamidaNavigator.inst.showSheet(
                          showDragHandle: true,
                          isScrollControlled: true,
                          heightPercentage: 0.6,
                          builder: (context, bottomPadding, maxWidth, maxHeight) => Markdown(
                            data: stringy.body,
                            selectable: true,
                            styleSheetTheme: MarkdownStyleSheetBaseTheme.cupertino,
                            builders: <String, MarkdownElementBuilder>{
                              'li': _NamidaMarkdownElementBuilderCommitLink(),
                              'h1': _NamidaMarkdownElementBuilderHeader(),
                            },
                            styleSheet: MarkdownStyleSheet(
                              a: textTheme.displayLarge,
                              h1: textTheme.displayLarge,
                              h2: textTheme.displayMedium,
                              h3: textTheme.displayMedium,
                              p: textTheme.displaySmall,
                              listBullet: textTheme.displayMedium,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  NamidaAboutListTile(
                    icon: Broken.language_circle,
                    title: lang.ADD_LANGUAGE,
                    subtitle: lang.ADD_LANGUAGE_SUBTITLE,
                    link: AppSocial.TRANSLATION_REPO,
                  ),
                ],
              ),
            ),
            SettingsCard(
              icon: Broken.heart_circle,
              title: 'Donate',
              subtitle: 'If you think it deserves',
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => NamidaLinkUtils.openLink(AppSocial.DONATE_KOFI),
                        child: AnimatedSwitcher(
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
              title: 'Others',
              icon: Broken.record_circle,
              subtitle: null,
              child: Column(
                children: [
                  if (ShortcutsController.instance != null)
                    NamidaAboutListTile(
                      icon: Broken.flash_1,
                      title: lang.SHORTCUTS,
                      onTap: () => AboutPage.showShortcutsDialog(context),
                    ),
                  NamidaAboutListTile(
                    icon: Broken.archive_book,
                    title: 'License',
                    subtitle: 'Licenses & Agreements Used by Namida',
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
                    title: 'App Version',
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
                    title: 'Share Logs',
                    trailing: NamidaIconButton(
                      iconColor: context.defaultIconColor(),
                      icon: Broken.direct_send,
                      tooltip: () => AppSocial.EMAIL,
                      onPressed: () async {
                        final attachments = await AppPaths.getAllExistingLogFiles();
                        final mailOptions = MailOptions(
                          body: 'pls look at this report im beggin u pls solve my issue pls i wa-',
                          subject: 'Namida Logs Report',
                          recipients: [AppSocial.EMAIL],
                          attachments: attachments,
                        );
                        await FlutterMailer.send(mailOptions);
                      },
                    ),
                    onTap: () async {
                      final filePaths = await AppPaths.getAllExistingLogFiles();
                      NamidaUtils.shareFiles(filePaths);
                    },
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NamidaMarkdownElementBuilderHeader extends MarkdownElementBuilder {
  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    return Center(
      child: NamidaInkWell(
        onTap: () {
          final version = text.text.replaceAll(' ', '');
          if (version.startsWith('v') && version.split('.').length > 1) {
            final url = "${AppSocial.GITHUB}/releases/tag/$version";
            NamidaLinkUtils.openLink(url);
          }
        },
        bgColor: namida.theme.cardTheme.color?.withValues(alpha: 0.8),
        borderRadius: 18.0,
        decoration: BoxDecoration(
          border: Border.all(
            width: 1.5,
            color: namida.theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Text(
          text.text,
          style: namida.textTheme.displayMedium,
        ),
      ),
    );
  }
}

class _NamidaMarkdownElementBuilderCommitLink extends MarkdownElementBuilder {
  final regex = RegExp(r'([a-f0-9]{7}):', caseSensitive: false);

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    final res = regex.firstMatch(text.text);
    final shortHash = res?.group(1);
    final url = "${AppSocial.GITHUB}/commit/$shortHash";
    final textWithoutCommit = shortHash == null ? text.text : text.text.substring(shortHash.length + 1);
    return _CommitTapWidget(
      url: url,
      commit: shortHash,
      textWithoutCommit: textWithoutCommit,
    );
  }
}

class _CommitTapWidget extends StatefulWidget {
  final String url;
  final String? commit;
  final String textWithoutCommit;
  const _CommitTapWidget({required this.url, required this.commit, required this.textWithoutCommit});

  @override
  State<_CommitTapWidget> createState() => _CommitTapWidgetState();
}

class _CommitTapWidgetState extends State<_CommitTapWidget> {
  late final TapGestureRecognizer recognizer = TapGestureRecognizer()..onTap = () => NamidaLinkUtils.openLink(widget.url);

  @override
  void dispose() {
    recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: widget.commit == null ? '' : "#${widget.commit}:",
        style: namida.textTheme.displayMedium?.copyWith(
          fontSize: 13.5,
          color: namida.theme.colorScheme.secondary,
        ),
        recognizer: recognizer,
        children: [
          TextSpan(
            text: widget.textWithoutCommit,
            style: namida.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: 13.0,
            ),
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
  final VisualDensity? visualDensity;

  const NamidaAboutListTile({
    super.key,
    this.leading,
    this.icon,
    required this.title,
    this.subtitle,
    this.link,
    this.onTap,
    this.trailing,
    this.visualDensity,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      visualDensity: visualDensity,
      leading: leading,
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap ??
          () {
            if (link != null) {
              NamidaLinkUtils.openLink(link!);
            }
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
  AnimationController? _controller;
  Animation<double>? _animation;

  int _speedLevel = 0;

  void _initAndAnimate() {
    _controller ??= AnimationController(vsync: this);

    if (mounted) {
      // _controller?.stop();

      final newSpeedLevel = (_speedLevel++) * 3;
      final playLongerVer = _speedLevel == 8;
      if (_speedLevel > 8 && _controller?.isAnimating == true) {
        // -- is long kuru kurin rn
        return;
      }

      final duration = playLongerVer ? 26000 : 2000 + (newSpeedLevel * 200);
      _controller?.duration = Duration(milliseconds: duration);

      final end = playLongerVer ? 200.0 : 5.0 + newSpeedLevel;
      final decelerateCurve = Tween<double>(
        begin: 0.0,
        end: end,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.decelerate,
      ));

      setState(() => _animation = decelerateCurve);
      _controller?.forward(from: 0).then((_) => _speedLevel = 0);

      _play(longerVer: playLongerVer);
    }
  }

  void _play({bool longerVer = false}) async {
    (String, Duration) randomSample;
    if (longerVer) {
      randomSample = ('https://www.myinstants.com/media/sounds/kuru-kuru.mp3', Duration(milliseconds: 0));
    } else {
      const sounds = [
        ('https://www.myinstants.com/media/sounds/kurukuru.mp3', Duration(milliseconds: 200)),
        ('https://www.myinstants.com/media/sounds/kururinnn.mp3', Duration(milliseconds: 0)),
      ];
      randomSample = sounds.random;
    }
    final pl = Player.createTempPlayer();
    await pl.setSource(
      ItemPrepareConfig(
        AudioVideoSource.uri(Uri.parse(randomSample.$1)),
        index: 0,
        initialPosition: randomSample.$2,
        videoOptions: null,
      ),
    );
    if (Player.inst.isPlaying.value) {
      await pl.setVolume(0.25);
    } else {
      await pl.setVolume(0.5);
    }
    await pl.play();
    pl.dispose();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;
    final child = widget.child;

    return DoubleTapDetector(
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
