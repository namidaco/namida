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
  late final _patreonResultUrlController = TextEditingController();
  late final _formKey = GlobalKey<FormState>();

  late final _isChecking = false.obs;
  late final _isClaiming = false.obs;
  late final _isSigningInPatreon = false.obs;

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    _patreonResultUrlController.dispose();
    _isChecking.close();
    _isClaiming.close();
    _isSigningInPatreon.close();
    super.dispose();
  }

  void _showError(String msg, {Object? exception}) {
    snackyy(message: exception.toString(), isError: true, displayDuration: SnackDisplayDuration.long);
  }

  void _showMembershipChangeSnack(MembershipType? oldMS) {
    final newMS = YoutubeAccountController.membership.userMembershipTypeGlobal.value;
    if (newMS == null) {
      if (oldMS != null) snackyy(message: lang.MEMBERSHIP_UNKNOWN, isError: true, top: false);
    } else if (oldMS == newMS) {
      final name = YoutubeAccountController.membership.getUsernameGlobal;
      String trailing = '';
      if (name != null && name.isNotEmpty) trailing += '$name ';
      snackyy(message: '${lang.MEMBERSHIP_DIDNT_CHANGE}, `${newMS.name}` $trailing', top: false);
    } else {
      final name = YoutubeAccountController.membership.getUsernameGlobal;
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
        borderColor: Colors.green.withValues(alpha: 0.8),
        top: false,
      );
    }
  }

  Future<void> _onPossibleMemebershipChange(Future<void> Function() fn) async {
    final oldMS = YoutubeAccountController.membership.userMembershipTypeGlobal.value;
    try {
      await fn();
      _showMembershipChangeSnack(oldMS);
    } catch (e) {
      _showError('', exception: e);
    }
  }

  Future<void> _onFreeCouponSubmit(Future<void> Function(String code, String email) fn) async {
    final code = _codeController.text;
    final email = _emailController.text;
    final validated = _formKey.currentState?.validate();
    if (validated ?? (code.isNotEmpty && email.isNotEmpty)) {
      return _onPossibleMemebershipChange(() => fn(code, email));
    }
  }

  Future<void> _onPatreonLoginTap(BuildContext context, {required SignInDecision signInDecision}) async {
    _isSigningInPatreon.value = true;

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

    await _onPossibleMemebershipChange(
      () => YoutubeAccountController.membership.claimPatreon(
        pageConfig: pageConfig,
        signIn: signInDecision,
      ),
    );
    _isSigningInPatreon.value = false;
  }

  Future<void> _refreshPatreon() async {
    return _onPossibleMemebershipChange(
      () => YoutubeAccountController.membership.checkPatreon(
        showError: true,
      ),
    );
  }

  Future<void> _refreshSupabase() async {
    final info = await NamicoSubscriptionManager.supabase.getUserSubInCache();
    if (info != null) {
      final uuid = info.uuid;
      final email = info.email;
      if (uuid != null && email != null) {
        return _onPossibleMemebershipChange(
          () => YoutubeAccountController.membership.checkSupabase(uuid, email),
        );
      }
    }
  }

  Future<void> _onPatreonSignOut() async {
    _onPossibleMemebershipChange(
      () => Future.sync(YoutubeAccountController.membership.signOutPatreon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: ObxO(
            rx: YoutubeAccountController.membership.userMembershipTypeGlobal,
            builder: (context, membershipType) => SuperListView(
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
                          NamidaExpansionTile(
                            initiallyExpanded: true,
                            icon: Broken.wallet_2,
                            titleText: 'Patreon',
                            trailing: ObxO(
                              rx: YoutubeAccountController.membership.userPatreonTier,
                              builder: (context, userPatreonTier) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(width: 8.0),
                                    NamidaIconButton(
                                      verticalPadding: 8.0,
                                      horizontalPadding: 8.0,
                                      onPressed: () => NamidaLinkUtils.openLink(AppSocial.DONATE_PATREON),
                                      icon: Broken.export_1,
                                      iconSize: 20.0,
                                    ),
                                    const SizedBox(width: 4.0),
                                    NamidaIconButton(
                                      verticalPadding: 8.0,
                                      horizontalPadding: 8.0,
                                      onPressed: _refreshPatreon,
                                      icon: Broken.refresh,
                                      iconSize: 20.0,
                                    ),
                                    const SizedBox(width: 4.0),
                                    const Icon(
                                      Broken.arrow_down_2,
                                      size: 20.0,
                                    ),
                                    const SizedBox(width: 8.0),
                                  ],
                                );
                              },
                            ),
                            subtitle: ObxO(
                              rx: YoutubeAccountController.membership.userMembershipTypePatreon,
                              builder: (context, userMembershipTypePatreon) => Text(
                                userMembershipTypePatreon?.name ?? '?',
                                style: context.textTheme.displaySmall,
                              ),
                            ),
                            children: [
                              ObxO(
                                rx: YoutubeAccountController.membership.userPatreonTier,
                                builder: (context, userPatreonTier) {
                                  if (userPatreonTier == null) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CustomListTile(
                                          icon: Broken.login_1,
                                          title: lang.SIGN_IN,
                                          trailing: IconButton(
                                            tooltip: lang.CLEAR,
                                            onPressed: _onPatreonSignOut,
                                            icon: const Icon(
                                              Broken.broom,
                                              size: 20.0,
                                            ),
                                          ),
                                          onTap: () => _onPatreonLoginTap(context, signInDecision: SignInDecision.forceSignIn),
                                        ),
                                        ObxO(
                                          rx: _isSigningInPatreon,
                                          builder: (context, value) => value
                                              ? Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: CustomTagTextField(
                                                          controller: _patreonResultUrlController,
                                                          onChanged: (value) {
                                                            try {
                                                              final uri = Uri.parse(value);
                                                              if (!uri.host.startsWith('patreonauth.msob7y.namida')) {
                                                                return;
                                                              }
                                                            } catch (_) {
                                                              // not a valid url
                                                              return;
                                                            }
                                                            _isSigningInPatreon.value = false;
                                                            YoutubeAccountController.membership.redirectUrlCompleter?.completeIfWasnt(value);
                                                          },
                                                          hintText: 'app://patreonauth.msob7y.namida?code=...',
                                                          labelText: lang.VALUE,
                                                        ),
                                                      ),
                                                      SizedBox(width: 6.0),
                                                      IconButton(
                                                        onPressed: () async {
                                                          final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                                                          final clipboardText = clipboardData?.text;
                                                          if (clipboardText != null) _patreonResultUrlController.text = clipboardText;
                                                        },
                                                        icon: Icon(
                                                          Broken.copy,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : const SizedBox(),
                                        ),
                                      ],
                                    );
                                  }
                                  final username = userPatreonTier.userName;
                                  final imageUrl = userPatreonTier.imageUrl;
                                  return CustomListTile(
                                    leading: SizedBox(
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
                                    trailing: IconButton(
                                      tooltip: lang.SIGN_OUT,
                                      onPressed: _onPatreonSignOut,
                                      icon: const Icon(
                                        Broken.logout,
                                        size: 20.0,
                                      ),
                                    ),
                                    title: username ?? '?',
                                    onTap: () {},
                                  );
                                },
                              ),
                            ],
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
                                builder: (context, isChecking) => ObxO(
                                  rx: _isClaiming,
                                  builder: (context, isClaiming) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      isChecking || isClaiming ? const LoadingIndicator() : const SizedBox(),
                                      NamidaIconButton(
                                        verticalPadding: 8.0,
                                        horizontalPadding: 8.0,
                                        onPressed: _refreshSupabase,
                                        icon: Broken.refresh,
                                        iconSize: 20.0,
                                      ),
                                      const SizedBox(width: 4.0),
                                      const Icon(
                                        Broken.arrow_down_2,
                                        size: 20.0,
                                      ),
                                      const SizedBox(width: 8.0),
                                    ],
                                  ),
                                ),
                              ),
                              subtitle: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ObxO(
                                    rx: YoutubeAccountController.membership.userMembershipTypeSupabase,
                                    builder: (context, userMembershipTypeSupabase) => Text(
                                      userMembershipTypeSupabase?.name ?? '?',
                                      style: context.textTheme.displaySmall,
                                    ),
                                  ),
                                  ObxO(
                                    rx: YoutubeAccountController.membership.userSupabaseSub,
                                    builder: (context, userSupabaseSub) {
                                      if (userSupabaseSub == null) return const SizedBox();
                                      final availableTill = userSupabaseSub.availableTill;
                                      String endTimeLeftText;
                                      if (availableTill == null) {
                                        endTimeLeftText = '?';
                                      } else {
                                        endTimeLeftText = TimeAgoController.dateFromNow(availableTill, long: false);
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
                                  builder: (context, isChecking) => ObxO(
                                    rx: _isClaiming,
                                    builder: (context, isClaiming) => AnimatedEnabled(
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
