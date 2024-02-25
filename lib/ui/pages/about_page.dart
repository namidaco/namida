// ignore_for_file: depend_on_referenced_packages, implementation_imports

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mailer/flutter_mailer.dart';

import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:markdown/src/ast.dart' as md;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final imageSize = context.width * 0.25;
    final topPadding = imageSize / 2;
    const textTopPadding = 28.0 * 2;
    return BackgroundWrapper(
      child: ListView(
        padding: kBottomPaddingInsets,
        children: [
          SizedBox(height: topPadding),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            decoration: BoxDecoration(
              color: context.theme.cardColor.withOpacity(0.6),
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
                        leading: () {
                          final ic = SizedBox(
                            width: 48.0,
                            height: 48.0,
                            child: Icon(
                              Broken.user,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          );
                          return Container(
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
                                return ic;
                              },
                              errorBuilder: (context, error, stackTrace) => ic,
                            ),
                          );
                        }(),
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
                        padding: const EdgeInsets.all(4.0),
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                        ),
                        child: Container(
                          width: imageSize,
                          height: imageSize,
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.fromRGBO(25, 25, 25, 0.1),
                          ),
                          child: Image.asset(
                            'assets/namida_icon.png',
                          ),
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        "Namida",
                        style: context.textTheme.displayLarge,
                      ),
                      Text(
                        AppSocial.APP_VERSION,
                        style: context.textTheme.displaySmall,
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
                ObxValue<RxBool>(
                  (isLoading) => NamidaAboutListTile(
                    icon: Broken.activity,
                    title: lang.CHANGELOG,
                    subtitle: 'See what\'s newly added/fixed inside Namida',
                    trailing: isLoading.value ? const LoadingIndicator() : null,
                    onTap: () async {
                      isLoading.value = true;
                      final stringy = await http.get(Uri.parse('https://raw.githubusercontent.com/namidaco/namida/main/CHANGELOG.md'));
                      isLoading.value = false;
                      await Future.delayed(Duration.zero); // delay bcz sometimes doesnt show
                      // ignore: use_build_context_synchronously
                      showModalBottomSheet(
                        showDragHandle: true,
                        useRootNavigator: true,
                        isScrollControlled: true,
                        context: context,
                        builder: (context) {
                          return SizedBox(
                            height: context.height * 0.6,
                            width: context.width,
                            child: Markdown(
                              data: stringy.body,
                              selectable: true,
                              styleSheetTheme: MarkdownStyleSheetBaseTheme.cupertino,
                              builders: <String, MarkdownElementBuilder>{
                                'li': _NamidaMarkdownElementBuilderCommitLink(),
                                'h1': _NamidaMarkdownElementBuilderHeader(),
                              },
                              styleSheet: MarkdownStyleSheet(
                                a: context.textTheme.displayLarge,
                                h1: context.textTheme.displayLarge,
                                h2: context.textTheme.displayMedium,
                                h3: context.textTheme.displayMedium,
                                p: context.textTheme.displaySmall,
                                listBullet: context.textTheme.displayMedium,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  false.obs,
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
                  InkWell(
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
                  InkWell(
                    onTap: () => NamidaLinkUtils.openLink(AppSocial.DONATE_BUY_ME_A_COFFEE),
                    child: Image.asset(
                      'assets/logos/donate_bmc.webp',
                      height: 48.0,
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
                NamidaAboutListTile(
                  icon: Broken.archive_book,
                  title: 'License',
                  subtitle: 'Licenses & Agreements Used by Namida',
                  onTap: () {
                    showLicensePage(
                      context: context,
                      useRootNavigator: true,
                      applicationVersion: AppSocial.APP_VERSION,
                    );
                  },
                ),
                const NamidaAboutListTile(
                  icon: Broken.cpu,
                  title: 'App Version',
                  subtitle: AppSocial.APP_VERSION,
                  link: AppSocial.GITHUB_RELEASES,
                ),
                NamidaAboutListTile(
                  icon: Broken.clipboard_text,
                  title: 'Share Logs',
                  trailing: NamidaIconButton(
                    iconColor: context.defaultIconColor(),
                    icon: Broken.direct_send,
                    tooltip: AppSocial.EMAIL,
                    onPressed: () async {
                      final mailOptions = MailOptions(
                        body: 'pls look at this report im beggin u pls solve my issue pls i wa-',
                        subject: 'Namida Logs Report',
                        recipients: [AppSocial.EMAIL],
                        attachments: [AppPaths.LOGS, AppPaths.LOGS_TAGGER],
                      );
                      await FlutterMailer.send(mailOptions);
                    },
                  ),
                  onTap: () => Share.shareXFiles([XFile(AppPaths.LOGS), XFile(AppPaths.LOGS_TAGGER)]),
                )
              ],
            ),
          ),
        ],
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
        bgColor: Get.theme.cardTheme.color?.withOpacity(0.8),
        borderRadius: 18.0,
        decoration: BoxDecoration(
          border: Border.all(
            width: 1.5,
            color: Get.theme.colorScheme.primary.withOpacity(0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Text(
          text.text,
          style: Get.textTheme.displayMedium,
        ),
      ),
    );
  }
}

class _NamidaMarkdownElementBuilderCommitLink extends MarkdownElementBuilder {
  String? shortenLongHash(String? longHash, {int chars = 5}) {
    if (longHash == null || longHash == '') return null;
    return longHash.substring(0, 7);
  }

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    final regex = RegExp(r'([a-fA-F0-9]{40}):', caseSensitive: false);
    final res = regex.firstMatch(text.text);
    final longHash = res?.group(1);
    final url = "${AppSocial.GITHUB}/commit/$longHash";
    final textWithoutCommit = longHash == null ? text.text : text.text.replaceFirst(regex, '');
    final commit = shortenLongHash(longHash);
    return RichText(
      text: TextSpan(
        text: commit == null ? '' : "#$commit:",
        style: Get.textTheme.displayMedium?.copyWith(
          fontSize: 13.5.multipliedFontScale,
          color: Get.theme.colorScheme.secondary,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => NamidaLinkUtils.openLink(url),
        children: [
          TextSpan(
            text: textWithoutCommit,
            style: Get.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: 13.0.multipliedFontScale,
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
