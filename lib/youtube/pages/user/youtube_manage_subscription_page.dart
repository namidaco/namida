part of 'youtube_account_manage_page.dart';

class YoutubeManageSubscriptionPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_USER_MANAGE_SUBSCRIPTION_SUBPAGE;

  const YoutubeManageSubscriptionPage({super.key});

  @override
  State<YoutubeManageSubscriptionPage> createState() => _YoutubeManageSubscriptionPageState();
}

class _YoutubeManageSubscriptionPageState extends State<YoutubeManageSubscriptionPage> {
  late final _codeController = TextEditingController();
  late final _emailController = TextEditingController();
  late final _formKey = GlobalKey<FormState>();

  late final _isChecking = false.obs;
  late final _isClaiming = false.obs;

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    _isChecking.close();
    _isClaiming.close();
    super.dispose();
  }

  void _showError(String msg, {Object? exception}) {
    snackyy(message: exception.toString(), isError: true, displaySeconds: 3);
  }

  Future<void> _onFreeCouponSubmit(Future<void> Function(String code, String email) fn) async {
    final code = _codeController.text;
    final email = _emailController.text;
    final validated = _formKey.currentState?.validate();
    if (validated ?? (code.isNotEmpty && email.isNotEmpty)) {
      final old = YoutubeAccountController.membership.userMembershipTypeGlobal.value;
      try {
        await fn(code, email);

        final newMS = YoutubeAccountController.membership.userMembershipTypeGlobal.value;

        if (newMS == null) {
          if (old != null) snackyy(message: lang.MEMBERSHIP_UNKNOWN, isError: true, top: false);
        } else if (old == newMS) {
          final name = YoutubeAccountController.membership.userSupabaseSub.value?.name;
          String trailing = '';
          if (name != null && name.isNotEmpty) trailing += '$name ';
          snackyy(message: '${lang.MEMBERSHIP_DIDNT_CHANGE}, `${newMS.name}` $trailing', top: false);
        } else {
          final name = YoutubeAccountController.membership.userSupabaseSub.value?.name;
          String trailing = '';
          if (name != null && name.isNotEmpty) trailing += '$name ';
          if (newMS.index <= MembershipType.none.index) {
            trailing = ':(';
          } else if (newMS == MembershipType.owner) {
            trailing = 'o7';
          } else {
            trailing = ':D';
          }
          snackyy(
            message: '${lang.MEMBERSHIP_ENJOY_NEW}, `${newMS.name}` $trailing',
            borderColor: Colors.green.withOpacity(0.8),
            top: false,
          );
        }
      } catch (e) {
        _showError('', exception: e);
      }
    }
  }

  void _onPatreonLoginTap(BuildContext context, {required SignInDecision signInDecision}) {
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.MEMBERSHIP_SIGN_IN_TO_PATREON_ACCOUNT,
          style: context.textTheme.displayMedium,
        ),
      ],
    );
    final pageConfig = LoginPageConfiguration(
      header: header,
      popPage: (_) => NamidaNavigator.inst.popRoot(),
      pushPage: (page, opaque) {
        NamidaNavigator.inst.navigateToRoot(page, opaque: opaque);
      },
    );
    YoutubeAccountController.membership.claimPatreon(
      pageConfig: pageConfig,
      signIn: signInDecision,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: ObxO(
            rx: YoutubeAccountController.membership.userMembershipTypeGlobal,
            builder: (membershipType) => ListView(
                  children: [
                    const SizedBox(height: 64.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: context.theme.cardColor,
                        borderRadius: BorderRadius.circular(18.0.multipliedRadius),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12.0),
                          const MembershipCard(displayName: true),
                          const SizedBox(height: 12.0),
                          ObxO(
                            rx: YoutubeAccountController.membership.userPatreonTier,
                            builder: (userPatreonTier) => NamidaExpansionTile(
                              initiallyExpanded: true,
                              icon: Broken.wallet_2,
                              titleText: 'Patreon',
                              trailing: ObxO(
                                rx: YoutubeAccountController.membership.userPatreonTier,
                                builder: (userPatreonTier) {
                                  final imageUrl = userPatreonTier?.imageUrl;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(width: 8.0),
                                      SizedBox(
                                        width: 24.0,
                                        height: 24.0,
                                        child: YoutubeThumbnail(
                                          key: ValueKey(imageUrl),
                                          width: 24.0,
                                          customUrl: imageUrl,
                                          isImportantInCache: false,
                                          type: ThumbnailType.channel,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {},
                                        icon: const Icon(
                                          Broken.arrow_down_2,
                                          size: 20.0,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              subtitle: ObxO(
                                rx: YoutubeAccountController.membership.userMembershipTypePatreon,
                                builder: (userMembershipTypePatreon) => Text(
                                  userMembershipTypePatreon?.name ?? '?',
                                  style: context.textTheme.displaySmall,
                                ),
                              ),
                              children: [
                                CustomListTile(
                                  icon: Broken.login_1,
                                  title: lang.SIGN_IN,
                                  onTap: () => _onPatreonLoginTap(context, signInDecision: SignInDecision.forceSignIn),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          Form(
                            key: _formKey,
                            child: NamidaExpansionTile(
                              initiallyExpanded: true,
                              icon: Broken.ticket_star,
                              titleText: lang.MEMBERSHIP_FREE_COUPON,
                              trailing: ObxO(
                                rx: _isChecking,
                                builder: (isChecking) => ObxO(
                                  rx: _isClaiming,
                                  builder: (isClaiming) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      isChecking || isClaiming ? const LoadingIndicator() : const SizedBox(),
                                      IconButton(
                                        onPressed: () {},
                                        icon: const Icon(
                                          Broken.arrow_down_2,
                                          size: 20.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              subtitle: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ObxO(
                                    rx: YoutubeAccountController.membership.userMembershipTypeSupabase,
                                    builder: (userMembershipTypeSupabase) => Text(
                                      userMembershipTypeSupabase?.name ?? '?',
                                      style: context.textTheme.displaySmall,
                                    ),
                                  ),
                                  ObxO(
                                    rx: YoutubeAccountController.membership.userSupabaseSub,
                                    builder: (userSupabaseSub) {
                                      if (userSupabaseSub == null) return const SizedBox();
                                      final availableTill = userSupabaseSub.availableTill;
                                      String endTimeLeftText;
                                      if (availableTill == null) {
                                        endTimeLeftText = '?';
                                      } else {
                                        endTimeLeftText = Jiffy.parseFromDateTime(availableTill).fromNow(withPrefixAndSuffix: false);
                                      }
                                      return Text(
                                        " - $endTimeLeftText",
                                        style: context.textTheme.displaySmall,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              children: [
                                const SizedBox(height: 12.0),
                                CustomTagTextField(
                                  controller: _codeController,
                                  hintText: lang.MEMBERSHIP_CODE,
                                  labelText: lang.MEMBERSHIP_CODE_SENT_TO_EMAIL,
                                  validatorMode: AutovalidateMode.onUserInteraction,
                                  validator: (value) {
                                    if (value == null || value.isEmpty == true) return lang.EMPTY_VALUE;
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12.0),
                                CustomTagTextField(
                                  controller: _emailController,
                                  hintText: lang.EMAIL,
                                  labelText: lang.EMAIL,
                                  validatorMode: AutovalidateMode.onUserInteraction,
                                  validator: (value) {
                                    if (value == null || value.isEmpty == true) return lang.EMPTY_VALUE;
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12.0),
                                ObxO(
                                  rx: _isChecking,
                                  builder: (isChecking) => ObxO(
                                    rx: _isClaiming,
                                    builder: (isClaiming) => AnimatedEnabled(
                                      enabled: !isChecking && !isClaiming,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          const SizedBox(width: 8.0),
                                          NamidaButton(
                                            icon: Broken.cloud_change,
                                            iconSize: 20.0,
                                            onPressed: () async {
                                              _isChecking.value = true;
                                              await _onFreeCouponSubmit(YoutubeAccountController.membership.checkSupabase);
                                              _isChecking.value = false;
                                            },
                                            text: lang.CHECK,
                                          ),
                                          const SizedBox(width: 8.0),
                                          NamidaButton(
                                            icon: Broken.ticket_expired,
                                            iconSize: 20.0,
                                            onPressed: () async {
                                              _isClaiming.value = true;
                                              await _onFreeCouponSubmit(YoutubeAccountController.membership.claimSupabase);
                                              _isClaiming.value = false;
                                            },
                                            text: lang.CLAIM,
                                          ),
                                          const SizedBox(width: 8.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        return SizedBox(
                          height: Dimensions.inst.globalBottomPaddingTotalR + context.viewInsets.bottom,
                        );
                      },
                    )
                  ],
                )),
      ),
    );
  }
}
