// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:namico_login_manager/namico_login_manager.dart';
import 'package:namico_subscription_manager/class/supabase_sub.dart';
import 'package:namico_subscription_manager/class/support_tier.dart';
import 'package:namico_subscription_manager/core/enum.dart';
import 'package:namico_subscription_manager/namico_subscription_manager.dart';
import 'package:youtipie/class/youtipie_feed/user_channel_info.dart';
import 'package:youtipie/youtipie.dart' hide logger;

import 'package:namida/class/route.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/pages/user/membership_card.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
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
        NamidaText(
          lang.signInToYourAccount,
          style: NText.medium,
        ),
        ObxO(
          rx: YoutubeAccountController.signInProgress,
          builder: (context, loginProgress) => loginProgress == null
              ? const SizedBox()
              : NamidaText(
                  loginProgress.name,
                  style: NText.small,
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

  void _onConfigureTap(BuildContext context) async {
    final initialVisitorData = YoutubeInfoController.potoken.getVisitorData();
    final controllerVisitorData = TextEditingController(text: initialVisitorData);
    final controllerPlayerRequestPoToken = TextEditingController();
    final controllerStreamingPoToken = TextEditingController();
    await NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        controllerVisitorData.dispose();
        controllerPlayerRequestPoToken.dispose();
        controllerStreamingPoToken.dispose();
      },
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: lang.configure,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.save,
            onTap: () {
              YoutubeInfoController.potoken.updateInfo(
                visitorData: controllerVisitorData.text,
                playerRequestPoToken: controllerPlayerRequestPoToken.text,
                streamingPoToken: controllerStreamingPoToken.text,
              );

              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: Dimensions.inst.availableAppContentWidth * 0.7,
            maxWidth: Dimensions.inst.availableAppContentWidth * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12.0),
              CustomTagTextField(
                controller: controllerVisitorData,
                labelText: 'Visitor Data',
                hintText: initialVisitorData ?? '',
                maxLines: 3,
              ),
              const SizedBox(height: 12.0),
              CustomTagTextField(
                controller: controllerPlayerRequestPoToken,
                labelText: 'PoToken (Player Request)',
                hintText: '',
                maxLines: 3,
              ),
              const SizedBox(height: 12.0),
              CustomTagTextField(
                controller: controllerStreamingPoToken,
                labelText: 'PoToken (Streaming)',
                hintText: '',
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onRemoveChannel(UserChannelInfo channel, bool active) {
    String bodyText;
    void Function() singOutFn;
    if (active) {
      bodyText = '${lang.signOutFromName(name: channel.title?.addDQuotation() ?? '')}?';
      singOutFn = YoutubeAccountController.setAccountAnonymous;
    } else {
      bodyText = '${lang.remove}: "${channel.title}"?';
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
            colorScheme: Colors.red,
            onTap: () {
              singOutFn();
              NamidaNavigator.inst.closeDialog();
            },
            text: (active ? lang.signOut : lang.remove).toUpperCase(),
          ),
        ],
      ),
    );
  }

  void _onSetAccount(UserChannelInfo channel) {
    YoutubeAccountController.setAccountActive(userChannel: channel);
  }

  void _onAccountLongPress(UserChannelInfo channel) {
    final handler = channel.handler;
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: channel.title ?? '',
        actions: const [CancelButton()],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (handler.isNotEmpty)
              CustomListTile(
                icon: Broken.copy,
                title: lang.copy,
                subtitle: handler,
                onTap: () {
                  NamidaNavigator.inst.closeDialog();
                  NamidaUtils.copyToClipboard(content: handler);
                },
              ),
            CustomListTile(
              icon: Broken.profile_circle,
              title: lang.goToChannel,
              onTap: () {
                NamidaNavigator.inst.closeDialog();
                YTChannelSubpage(channelID: channel.id).navigate();
              },
            ),
          ],
        ),
      ),
    );
  }

  static bool _canAddMultiAccounts(MembershipType? ms) => ms == MembershipType.pookie || ms == MembershipType.patootie || ms == MembershipType.owner;

  Widget _buildAddAccountButton(BuildContext context, {double sizeMultiplier = 1.2}) {
    return ObxO(
      rx: YoutubeAccountController.signInProgress,
      builder: (context, loginProgress) => loginProgress != null
          ? NamidaInkWellButton(
              enabled: false,
              text: loginProgress.name.toUpperCase(),
              icon: null,
              sizeMultiplier: sizeMultiplier,
            )
          : NamidaInkWellButton(
              onTap: () => _onSignInTap(context, forceSignIn: true),
              text: lang.addAccount,
              icon: Broken.user_add,
              sizeMultiplier: sizeMultiplier,
            ),
    );
  }

  Widget _buildMembershipTile(BuildContext context, {required bool compact}) {
    return ObxO(
      rx: YoutubeAccountController.membership.userMembershipTypeGlobal,
      builder: (context, userMembershipType) {
        final hasMembership = userMembershipType != null && userMembershipType.index >= MembershipType.cutie.index;
        return NBuilder(
          builder: (context, colors) => CustomListTile(
            borderR: 12.0,
            onTap: const YoutubeManageSubscriptionPage().navigate,
            dense: compact,
            title: hasMembership ? lang.membershipManage : lang.signingInAllowsBasicUsage,
            subtitle: hasMembership ? null : lang.signingInAllowsBasicUsageSubtitle,
            icon: Broken.money_3,
            bgColor: Color.alphaBlend(
              colors.cardTheme.withOpacityExt(0.3),
              colors.secondaryContainer,
            ).withOpacityExt(compact ? 0.3 : 0.5),
            trailingRaw: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6.0),
              child: MembershipCard(displayName: false),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NIcon(
              Broken.profile_circle,
              size: 72.0,
              color: NColors.defaultIcon(opacity: 0.7),
            ),
            const SizedBox(height: 20.0),
            NamidaText(
              lang.signInYouDontHaveAccount,
              style: NText.large,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6.0),
            NamidaText(
              lang.signInToYourAccount,
              style: NText.small,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24.0),
            _buildAddAccountButton(context, sizeMultiplier: 1.3),
            const SizedBox(height: 40.0),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480.0),
              child: _buildMembershipTile(context, compact: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTile(BuildContext context, UserChannelInfo acc, {required bool active}) {
    const accountColorActive = NColors(.secondaryContainer, opacity: 0.8);
    const accountColorNonActive = NColors(.card, opacity: 0.5);
    return NamidaInkWell(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      bgColor: active ? accountColorActive : accountColorNonActive,
      borderRadius: 14.0,
      onTap: active ? null : () => _onSetAccount(acc),
      onLongPress: () => _onAccountLongPress(acc),
      child: Row(
        children: [
          const SizedBox(width: 12.0),
          YoutubeThumbnail(
            type: ThumbnailType.channel,
            key: ValueKey(acc),
            width: 52.0,
            forceSquared: false,
            isImportantInCache: true,
            customUrl: acc.thumbnails.pick()?.url,
            isCircle: true,
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: NamidaText(
                        acc.title ?? '',
                        style: NText.medium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 8.0),
                      NContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: (colors) => BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                        ),
                        child: NamidaText(
                          lang.active.toUpperCase(),
                          style: const NText(.small, size: .s10),
                        ),
                      ),
                    ],
                  ],
                ),
                if (acc.handler.isNotEmpty)
                  NamidaText(
                    acc.handler,
                    style: NText.small,
                  ),
              ],
            ),
          ),
          if (active)
            IconButton(
              tooltip: lang.configure,
              onPressed: () => _onConfigureTap(context),
              icon: const Icon(
                Broken.setting_3,
                size: 18.0,
              ),
            ),
          IconButton(
            tooltip: active ? lang.signOut : lang.remove,
            onPressed: () => _onRemoveChannel(acc, active),
            icon: active
                ? const Icon(
                    Broken.logout,
                    size: 20.0,
                  )
                : const Icon(
                    Broken.trash,
                    size: 20.0,
                  ),
          ),
          const SizedBox(width: 8.0),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: ObxO(
        rx: YoutubeAccountController.current.signedInAccounts,
        builder: (context, signedInAccountsSet) {
          final signedInAccounts = signedInAccountsSet.toFixedList();
          if (signedInAccounts.isEmpty) return _buildEmptyState(context);
          return ObxO(
            rx: YoutubeAccountController.current.activeAccountChannel,
            builder: (context, currentChannel) => Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 24.0),
                      _buildMembershipTile(context, compact: false),
                      const NamidaContainerDivider(
                        margin: EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            NIcon(
                              Broken.profile_2user,
                              size: 20.0,
                              color: NColors.defaultIcon(),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: NamidaText(
                                lang.manageYourAccounts,
                                style: NText.medium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Material(
                          type: MaterialType.transparency, // cuz it overflow with bg
                          child: SuperSmoothListView.separated(
                            separatorBuilder: (context, index) => const SizedBox(height: 8.0),
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0).add(
                              const EdgeInsets.only(bottom: Dimensions.globalBottomPaddingTotal + 96.0), // bottom bar
                            ),
                            itemCount: signedInAccounts.length,
                            itemBuilder: (context, index) {
                              final acc = signedInAccounts[index];
                              return _buildAccountTile(context, acc, active: currentChannel == acc);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  left: 0,
                  child: Obx(
                    (context) => Padding(
                      padding: EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingTotalR),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ObxO(
                            rx: YoutubeAccountController.membership.userMembershipTypeGlobal,
                            builder: (context, userMembershipType) => _canAddMultiAccounts(userMembershipType)
                                ? const SizedBox()
                                : Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
                                    child: NamidaText(
                                      lang.membershipYouNeedMembershipOfToAddMultipleAccounts(
                                        name1: MembershipType.pookie.name,
                                        name2: MembershipType.patootie.name,
                                      ),
                                      style: NText.small,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                          ),
                          _buildAddAccountButton(context),
                        ],
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
