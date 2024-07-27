// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

import 'package:jiffy/jiffy.dart';
import 'package:namico_login_manager/namico_login_manager.dart';
import 'package:namico_subscription_manager/core/enum.dart';
import 'package:youtipie/class/youtipie_feed/channel_info_item.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/pages/user/membership_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

part 'youtube_manage_subscription_page.dart';

class YoutubeAccountManagePage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_USER_MANAGE_ACCOUNT_SUBPAGE;

  const YoutubeAccountManagePage({super.key});

  void _onSignInTap(BuildContext context, {required bool forceSignIn}) {
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.SIGN_IN_TO_YOUR_ACCOUNT,
          style: context.textTheme.displayMedium,
        ),
        ObxO(
          rx: YoutubeAccountController.signInProgress,
          builder: (loginProgress) => loginProgress == null
              ? const SizedBox()
              : Text(
                  loginProgress.name,
                  style: context.textTheme.displaySmall,
                ),
        ),
      ],
    );
    YoutubeAccountController.signIn(
      pageConfig: LoginPageConfiguration(
        header: header,
        popPage: (_) => NamidaNavigator.inst.popRoot(),
        pushPage: (page, opaque) {
          NamidaNavigator.inst.navigateToRoot(page, opaque: opaque);
        },
      ),
      forceSignIn: forceSignIn,
    );
  }

  void _onRemoveChannel(ChannelInfoItem channel, bool active) {
    String bodyText;
    void Function() singOutFn;
    if (active) {
      bodyText = '${lang.SIGN_OUT_FROM_NAME.replaceFirst('_NAME_', channel.title.addDQuotation())}?';
      singOutFn = YoutubeAccountController.setAccountAnonymous;
    } else {
      bodyText = '${lang.REMOVE}: "${channel.title}"?';
      singOutFn = () => YoutubeAccountController.signOut(userChannel: channel);
    }
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        isWarning: true,
        bodyText: bodyText,
        actions: [
          const CancelButton(),
          NamidaButton(
            onPressed: () {
              singOutFn();
              NamidaNavigator.inst.closeDialog();
            },
            text: (active ? lang.SIGN_OUT : lang.REMOVE).toUpperCase(),
          )
        ],
      ),
    );
  }

  void _onSetAccount(ChannelInfoItem channel) {
    YoutubeAccountController.setAccountActive(userChannel: channel);
  }

  @override
  Widget build(BuildContext context) {
    final accountColorActive = context.theme.colorScheme.secondaryContainer.withOpacity(0.8);
    final accountColorNonActive = context.theme.cardColor.withOpacity(0.5);
    return BackgroundWrapper(
      child: ObxO(
        rx: YoutubeAccountController.current.signedInAccounts,
        builder: (signedInAccountsSet) {
          final signedInAccounts = signedInAccountsSet.toList();
          return ObxO(
            rx: YoutubeAccountController.current.activeAccountChannel,
            builder: (currentChannel) => Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 24.0),
                      ObxO(
                        rx: YoutubeAccountController.membership.userMembershipTypeGlobal,
                        builder: (userMembershipType) {
                          final hasMembership = userMembershipType != null && userMembershipType.index >= MembershipType.cutie.index;
                          return CustomListTile(
                            borderR: 12.0,
                            onTap: const YoutubeManageSubscriptionPage().navigate,
                            title: hasMembership ? lang.MEMBERSHIP_MANAGE : "${lang.SIGNING_IN_ALLOWS_BASIC_USAGE}.\n${lang.SIGNING_IN_ALLOWS_BASIC_USAGE_SUBTITLE}",
                            icon: Broken.money_3,
                            bgColor: Color.alphaBlend(
                              context.theme.cardTheme.color?.withOpacity(0.3) ?? Colors.transparent,
                              context.theme.colorScheme.secondaryContainer,
                            ).withOpacity(0.5),
                            trailingRaw: const MembershipCard(displayName: false),
                          );
                        },
                      ),
                      const NamidaContainerDivider(
                        margin: EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
                      ),
                      if (signedInAccounts.isNotEmpty)
                        Expanded(
                          child: Material(
                            type: MaterialType.transparency, // cuz it overflow with bg
                            child: ListView.separated(
                              separatorBuilder: (context, index) => const SizedBox(height: 8.0),
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0).add(
                                EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingTotalR + 48.0), // 'Add account' button
                              ),
                              itemCount: signedInAccounts.length,
                              itemBuilder: (context, index) {
                                final acc = signedInAccounts[index];
                                final active = currentChannel?.id == acc.id;
                                return CustomListTile(
                                  verticalPadding: acc.handler.isEmpty ? 6.0 : 0.0,
                                  title: acc.title,
                                  subtitle: acc.handler,
                                  bgColor: active ? accountColorActive : accountColorNonActive,
                                  borderR: 14.0,
                                  visualDensity: VisualDensity.compact,
                                  onTap: () => _onSetAccount(acc),
                                  leading: YoutubeThumbnail(
                                    type: ThumbnailType.channel,
                                    key: Key(acc.id),
                                    width: 64.0,
                                    forceSquared: false,
                                    isImportantInCache: true,
                                    customUrl: acc.thumbnails.pick()?.url,
                                    isCircle: true,
                                  ),
                                  trailing: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (active)
                                        const NamidaCheckMark(
                                          size: 12.0,
                                          active: true,
                                        ),
                                      IconButton(
                                        tooltip: active ? lang.SIGN_OUT : lang.REMOVE,
                                        onPressed: () => _onRemoveChannel(acc, active),
                                        icon: active ? const Icon(Broken.logout) : const Icon(Broken.trash),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            lang.SIGN_IN_YOU_DONT_HAVE_ACCOUNT,
                            style: context.textTheme.displayLarge,
                          ),
                        )
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  left: 0,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: Dimensions.inst.globalBottomPaddingTotalR,
                    ),
                    child: Align(
                      child: ObxO(
                        rx: YoutubeAccountController.signInProgress,
                        builder: (loginProgress) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: loginProgress != null
                              ? [
                                  NamidaInkWellButton(
                                    enabled: false,
                                    text: loginProgress.name.toUpperCase(),
                                    icon: null,
                                    sizeMultiplier: 1.0,
                                  ),
                                ]
                              : [
                                  NamidaInkWellButton(
                                    onTap: () => _onSignInTap(context, forceSignIn: true),
                                    text: lang.ADD_ACCOUNT,
                                    icon: Broken.user_add,
                                    sizeMultiplier: 1.2,
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
