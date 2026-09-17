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
  late final _showPatreonManualUrl = false.obs;

  static const _kMaxWidth = 560.0;

  @override
  void initState() {
    super.initState();
    _prefillCouponEmail();
    _refreshPatreonIfStale();
  }

  Future<void> _prefillCouponEmail() async {
    final info = await NamicoSubscriptionManager.supabase.getUserSubInCache();
    final email = info?.email;
    if (email != null && email.isNotEmpty && _emailController.text.isEmpty) {
      _emailController.text = email;
    }
  }

  void _refreshPatreonIfStale() {
    final tier = YoutubeAccountController.membership.userPatreonTier.value;
    if (tier == null) return;
    final lastChecked = tier.lastChecked;
    if (lastChecked != null && DateTime.now().difference(lastChecked) < const Duration(days: 1)) return;
    YoutubeAccountController.membership.checkPatreon(showError: false).catchError((_) {});
  }

  @override
  void dispose() {
    if (_isSigningInPatreon.value) YoutubeAccountController.membership.cancelPatreonSignIn();
    _codeController.dispose();
    _emailController.dispose();
    _patreonResultUrlController.dispose();
    _isChecking.close();
    _isClaiming.close();
    _isSigningInPatreon.close();
    _showPatreonManualUrl.close();
    super.dispose();
  }

  void _showError(String msg, {Object? exception, StackTrace? stackTrace}) {
    logger.error('YoutubeManageSubscriptionPage: $msg', e: exception, st: stackTrace);
    snackyy(message: exception.toString(), isError: true, displayDuration: SnackDisplayDuration.long);
  }

  void _showMembershipChangeSnack(MembershipType? oldMS) {
    final newMS = YoutubeAccountController.membership.userMembershipTypeGlobal.value;
    if (newMS == null) {
      if (oldMS != null) snackyy(message: lang.membershipUnknown, isError: true, top: false);
    } else if (oldMS == newMS) {
      final name = YoutubeAccountController.membership.getUsernameGlobal;
      String trailing = '';
      if (name != null && name.isNotEmpty) trailing += '$name ';
      snackyy(message: '${lang.membershipDidntChange}, `${newMS.name}` $trailing', top: false);
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
        message: '${lang.membershipEnjoyNew}, `${newMS.name}` $trailing',
        borderColor: Colors.green.withOpacityExt(0.8),
        top: false,
      );
    }
  }

  Future<void> _onPossibleMemebershipChange(Future<void> Function() fn) async {
    final oldMS = YoutubeAccountController.membership.userMembershipTypeGlobal.value;
    try {
      await fn();
      _showMembershipChangeSnack(oldMS);
    } catch (e, st) {
      _showError('membership change failed', exception: e, stackTrace: st);
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
    _patreonResultUrlController.clear();

    final textTheme = context.textTheme;
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.membershipSignInToPatreonAccount,
          style: textTheme.displayMedium,
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

    final oldMS = YoutubeAccountController.membership.userMembershipTypeGlobal.value;
    try {
      final didSignIn = await YoutubeAccountController.membership.claimPatreon(
        pageConfig: pageConfig,
        signIn: signInDecision,
      );
      if (didSignIn) _showMembershipChangeSnack(oldMS);
    } catch (e, st) {
      _showError('patreon sign in failed', exception: e, stackTrace: st);
    }
    if (!mounted) return;
    _showPatreonManualUrl.value = false;
    _isSigningInPatreon.value = false;
  }

  void _onPatreonManualUrlChanged(String value) {
    try {
      final uri = Uri.parse(value);
      if (!uri.host.startsWith('patreonauth.msob7y.namida')) return;
    } catch (_) {
      return;
    }
    YoutubeAccountController.membership.redirectUrlCompleter?.completeIfWasnt(value);
  }

  Future<void> _pasteClipboardToPatreonUrl() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = clipboardData?.text;
    if (clipboardText != null) {
      _patreonResultUrlController.text = clipboardText;
      _onPatreonManualUrlChanged(clipboardText);
    }
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

  void _onSupabaseClearTap() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        isWarning: true,
        bodyText: '${lang.clear}: ${lang.coupon}?',
        actions: [
          const CancelButton(),
          NamidaButton(
            colorScheme: Colors.red,
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              _onPossibleMemebershipChange(
                () => Future.sync(YoutubeAccountController.membership.signOutSupabase),
              );
            },
            text: lang.clear.toUpperCase(),
          ),
        ],
      ),
    );
  }

  Future<void> _onPatreonSignOut() async {
    _onPossibleMemebershipChange(
      () => Future.sync(YoutubeAccountController.membership.signOutPatreon),
    );
  }

  static bool _hasMembership(MembershipType? ms) => ms != null && ms.index >= MembershipType.cutie.index;

  static _MembershipSource? _effectiveSource(MembershipType? global, MembershipType? patreon, MembershipType? supabase) {
    if (!_hasMembership(global)) return null;
    if (patreon == global) return _MembershipSource.patreon;
    if (supabase == global) return _MembershipSource.coupon;
    return null;
  }

  static const _kExpiryWarningDays = 7;

  static bool _isExpiringSoon(SupabaseSub? sub) {
    final availableTill = sub?.availableTill;
    if (availableTill == null) return false;
    return availableTill.difference(DateTime.now()).inDays < _kExpiryWarningDays;
  }

  static String _expiryText(SupabaseSub? sub) {
    if (sub == null) return '';
    final availableTill = sub.availableTill;
    if (availableTill == null) return ' - ?';
    if (availableTill.isAfter(DateTime(9000))) return '';
    return ' - ${TimeAgoController.dateFromNow(availableTill, long: false)}';
  }

  static String _patreonAmountText(SupportTier? tier) {
    if (tier == null) return '';
    String text = '';
    final amount = tier.ammountUSD;
    if (amount != null) text += amount > 1000 ? ' - ∞/month' : ' - \$$amount/month';
    if (tier.declinedSince != null) text += ' (declined)';
    return text;
  }

  static String? _patreonSinceText(SupportTier? tier) {
    final createdAt = tier?.createdAt;
    if (createdAt == null) return null;
    return 'since ${createdAt.dateFormatted}';
  }

  static Color _warningColor(BuildContext context) => Colors.orange.withOpacityExt(context.isDarkMode ? 0.4 : 0.5);

  Widget _buildHero(BuildContext context, MembershipType? membershipType) {
    final textTheme = context.textTheme;
    final hasMembership = _hasMembership(membershipType);
    return Column(
      children: [
        const MembershipCard(displayName: true),
        const SizedBox(height: 8.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: hasMembership
              ? ObxO(
                  rx: YoutubeAccountController.membership.userMembershipTypePatreon,
                  builder: (context, patreonMS) => ObxO(
                    rx: YoutubeAccountController.membership.userMembershipTypeSupabase,
                    builder: (context, supabaseMS) => ObxO(
                      rx: YoutubeAccountController.membership.userSupabaseSub,
                      builder: (context, userSupabaseSub) => ObxO(
                        rx: YoutubeAccountController.membership.userPatreonTier,
                        builder: (context, userPatreonTier) {
                          final source = _effectiveSource(membershipType, patreonMS, supabaseMS);
                          String text = switch (source) {
                            _MembershipSource.patreon => 'Patreon${_patreonAmountText(userPatreonTier)}',
                            _MembershipSource.coupon => '${lang.coupon}${_expiryText(userSupabaseSub)}',
                            null => lang.active,
                          };
                          if (source == _MembershipSource.patreon) {
                            final since = _patreonSinceText(userPatreonTier);
                            if (since != null) text += '\n$since';
                          }
                          final warn = source == _MembershipSource.coupon && _isExpiringSoon(userSupabaseSub);
                          return Text(
                            text,
                            style: warn
                                ? textTheme.displaySmall?.copyWith(
                                    color: Color.alphaBlend(_warningColor(context), textTheme.displaySmall?.color ?? Colors.transparent),
                                  )
                                : textTheme.displaySmall,
                            textAlign: TextAlign.center,
                          );
                        },
                      ),
                    ),
                  ),
                )
              : Text(
                  lang.signingInAllowsBasicUsageSubtitle,
                  style: textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
        ),
        const SizedBox(height: 12.0),
        _BenefitsList(membershipType: membershipType),
      ],
    );
  }

  Widget _buildOrDivider(BuildContext context) {
    final textTheme = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      child: Row(
        children: [
          const Expanded(child: NamidaContainerDivider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              lang.or.toUpperCase(),
              style: textTheme.displaySmall,
            ),
          ),
          const Expanded(child: NamidaContainerDivider()),
        ],
      ),
    );
  }

  Widget _buildPatreonWaiting(BuildContext context) {
    final textTheme = context.textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 4.0),
            const LoadingIndicator(),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                lang.membershipSignInToPatreonAccount,
                style: textTheme.displayMedium,
              ),
            ),
            const SizedBox(width: 8.0),
            NamidaButton(
              colors: NamidaButtonColors.dimmed,
              text: lang.cancel,
              onTap: YoutubeAccountController.membership.cancelPatreonSignIn,
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Align(
          alignment: Alignment.centerLeft,
          child: ObxO(
            rx: _showPatreonManualUrl,
            builder: (context, show) => NamidaInkWellButton(
              bgColor: Colors.transparent,
              sizeMultiplier: 0.85,
              icon: show ? Broken.arrow_up_2 : Broken.arrow_down_2,
              text: '${lang.issues}?',
              onTap: _showPatreonManualUrl.toggle,
            ),
          ),
        ),
        ObxO(
          rx: _showPatreonManualUrl,
          builder: (context, show) => show
              ? Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomTagTextField(
                          controller: _patreonResultUrlController,
                          onChanged: _onPatreonManualUrlChanged,
                          hintText: 'app://patreonauth.msob7y.namida?code=...',
                          labelText: lang.link,
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      IconButton(
                        onPressed: _pasteClipboardToPatreonUrl,
                        icon: const Icon(Broken.clipboard_import),
                      ),
                    ],
                  ),
                )
              : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildPatreonCard(BuildContext context, MembershipType? membershipType) {
    final textTheme = context.textTheme;
    return ObxO(
      rx: YoutubeAccountController.membership.userPatreonTier,
      builder: (context, userPatreonTier) => ObxO(
        rx: YoutubeAccountController.membership.userMembershipTypePatreon,
        builder: (context, patreonMS) {
          final signedIn = userPatreonTier != null;
          final isStale = !signedIn && patreonMS != null && patreonMS != MembershipType.unknown && patreonMS != MembershipType.none;
          final isEffective = _effectiveSource(membershipType, patreonMS, null) == _MembershipSource.patreon;
          final children = <Widget>[];
          if (signedIn) {
            final username = userPatreonTier.userName;
            final imageUrl = userPatreonTier.imageUrl;
            final sinceText = _patreonSinceText(userPatreonTier);
            children.addAll([
              const SizedBox(height: 12.0),
              Row(
                children: [
                  const SizedBox(width: 4.0),
                  YoutubeThumbnail(
                    key: ValueKey(imageUrl),
                    width: 36.0,
                    height: 36.0,
                    borderRadius: 18.0,
                    customUrl: imageUrl,
                    isImportantInCache: false,
                    type: ThumbnailType.channel,
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username ?? '?',
                          style: textTheme.displayMedium,
                        ),
                        if (sinceText != null)
                          Text(
                            sinceText,
                            style: textTheme.displaySmall,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: lang.refresh,
                    onPressed: _refreshPatreon,
                    icon: const Icon(Broken.refresh, size: 20.0),
                  ),
                  IconButton(
                    tooltip: lang.signOut,
                    onPressed: _onPatreonSignOut,
                    icon: const Icon(Broken.logout, size: 20.0),
                  ),
                ],
              ),
            ]);
          } else {
            children.addAll([
              const SizedBox(height: 16.0),
              ObxO(
                rx: _isSigningInPatreon,
                builder: (context, isSigningIn) => isSigningIn
                    ? _buildPatreonWaiting(context)
                    : NamidaInkWellButton(
                        sizeMultiplier: 1.1,
                        paddingMultiplier: 1.5,
                        icon: Broken.login_1,
                        text: lang.signIn,
                        onTap: () => _onPatreonLoginTap(context, signInDecision: SignInDecision.forceSignIn),
                      ),
              ),
              const SizedBox(height: 4.0),
            ]);
          }
          return _SourceCard(
            icon: Broken.wallet_2,
            title: 'Patreon',
            status: '${patreonMS?.name.capitalizeFirst() ?? lang.none}${_patreonAmountText(userPatreonTier)}',
            isEffective: isEffective,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NamidaInkWellButton(
                  bgColor: Colors.transparent,
                  sizeMultiplier: 0.85,
                  icon: Broken.export_1,
                  text: 'patreon.com',
                  onTap: () => NamidaLinkUtils.openLink(AppSocial.DONATE_PATREON),
                ),
                if (isStale)
                  IconButton(
                    tooltip: lang.clear,
                    onPressed: _onPatreonSignOut,
                    icon: const Icon(Broken.broom, size: 20.0),
                  ),
              ],
            ),
            children: children,
          );
        },
      ),
    );
  }

  Widget _buildCouponCard(BuildContext context, MembershipType? membershipType) {
    return ObxO(
      rx: YoutubeAccountController.membership.userMembershipTypeSupabase,
      builder: (context, supabaseMS) => ObxO(
        rx: YoutubeAccountController.membership.userSupabaseSub,
        builder: (context, userSupabaseSub) {
          final isEffective = _effectiveSource(membershipType, null, supabaseMS) == _MembershipSource.coupon;
          return Form(
            key: _formKey,
            child: _SourceCard(
              icon: Broken.ticket_star,
              title: lang.coupon,
              status: '${supabaseMS?.name.capitalizeFirst() ?? lang.none}${_expiryText(userSupabaseSub)}',
              statusColor: _isExpiringSoon(userSupabaseSub) ? _warningColor(context) : null,
              isEffective: isEffective,
              trailing: userSupabaseSub != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: lang.refresh,
                          onPressed: _refreshSupabase,
                          icon: const Icon(Broken.refresh, size: 20.0),
                        ),
                        IconButton(
                          tooltip: lang.clear,
                          onPressed: _onSupabaseClearTap,
                          icon: const Icon(Broken.broom, size: 20.0),
                        ),
                      ],
                    )
                  : null,
              children: [
                const SizedBox(height: 12.0),
                CustomTagTextField(
                  controller: _codeController,
                  hintText: lang.membershipCode,
                  labelText: lang.membershipCodeSentToEmail,
                  validatorMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.isEmpty == true) return lang.emptyValue;
                    return null;
                  },
                ),
                const SizedBox(height: 12.0),
                CustomTagTextField(
                  controller: _emailController,
                  hintText: lang.email,
                  labelText: lang.email,
                  validatorMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.isEmpty == true) return lang.emptyValue;
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                ObxO(
                  rx: _isChecking,
                  builder: (context, isChecking) => ObxO(
                    rx: _isClaiming,
                    builder: (context, isClaiming) {
                      final enabled = !isChecking && !isClaiming;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          NamidaButton(
                            enabled: enabled,
                            isLoading: isChecking,
                            colors: NamidaButtonColors.dimmed,
                            icon: Broken.cloud_change,
                            onTap: () async {
                              _isChecking.value = true;
                              await _onFreeCouponSubmit(YoutubeAccountController.membership.checkSupabase);
                              _isChecking.value = false;
                            },
                            text: lang.check,
                          ),
                          const SizedBox(width: 8.0),
                          NamidaButton(
                            enabled: enabled,
                            isLoading: isClaiming,
                            colors: NamidaButtonColors.saturated,
                            icon: Broken.ticket_star,
                            onTap: () async {
                              _isClaiming.value = true;
                              await _onFreeCouponSubmit(YoutubeAccountController.membership.claimSupabase);
                              _isClaiming.value = false;
                            },
                            text: lang.claim,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return BackgroundWrapper(
      child: ObxO(
        rx: YoutubeAccountController.membership.userMembershipTypeGlobal,
        builder: (context, membershipType) => SuperSmoothListView(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          children: [
            const SizedBox(height: 16.0),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxWidth),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                  decoration: BoxDecoration(
                    color: theme.cardColor.withOpacityExt(0.2),
                    borderRadius: BorderRadius.circular(22.0.multipliedRadius),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHero(context, membershipType),
                      const SizedBox(height: 16.0),
                      _buildPatreonCard(context, membershipType),
                      _buildOrDivider(context),
                      _buildCouponCard(context, membershipType),
                    ],
                  ),
                ),
              ),
            ),
            Builder(
              builder: (context) {
                return SizedBox(
                  height: Dimensions.globalBottomPaddingTotal + context.viewInsets.bottom,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final Color? statusColor;
  final bool isEffective;
  final Widget? trailing;
  final List<Widget> children;

  const _SourceCard({
    required this.icon,
    required this.title,
    required this.status,
    this.statusColor,
    required this.isEffective,
    required this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final containerColor = theme.colorScheme.secondaryContainer;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuart,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: containerColor.withOpacityExt(isEffective ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(18.0.multipliedRadius),
        border: Border.all(color: isEffective ? containerColor : Colors.transparent),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 24.0,
                color: context.defaultIconColor(),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: textTheme.displayMedium,
                        ),
                        if (isEffective) ...[
                          const SizedBox(width: 6.0),
                          const NamidaCheckMark(
                            size: 11.0,
                            active: true,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      status,
                      style: statusColor == null
                          ? textTheme.displaySmall
                          : textTheme.displaySmall?.copyWith(color: Color.alphaBlend(statusColor!, textTheme.displaySmall?.color ?? Colors.transparent)),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Benefit {
  final IconData icon;
  final String text;
  final MembershipType minTier;

  const _Benefit(this.icon, this.text, this.minTier);

  bool get isFree => minTier.index <= MembershipType.none.index;
}

class _BenefitsList extends StatelessWidget {
  final MembershipType? membershipType;

  const _BenefitsList({required this.membershipType});

  static const _benefits = <_Benefit>[
    _Benefit(Broken.like_1, 'Likes, playlists, subscriptions list & notifications', MembershipType.none),
    _Benefit(Broken.home_2, 'Home feed & watch history', MembershipType.cutie),
    _Benefit(Broken.message_text, 'Comment, subscribe & interact with channels', MembershipType.cutie),
    _Benefit(Broken.music_filter, 'Party mode & crossfade (or find the easter egg)', MembershipType.cutie),
    _Benefit(Broken.profile_2user, 'Multiple accounts', MembershipType.pookie),
  ];

  static String _tierLabel(_Benefit benefit) {
    if (benefit.isFree) return 'Free';
    final usd = switch (benefit.minTier) {
      MembershipType.cutie => 5,
      MembershipType.pookie => 10,
      MembershipType.patootie => 25,
      _ => null,
    };
    final name = benefit.minTier.name.capitalizeFirst();
    return usd == null ? name : '$name+ · \$$usd';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final currentIndex = membershipType?.index ?? -1;
    final iconColor = context.defaultIconColor();
    final dimmedColor = iconColor.withOpacityExt(0.4);
    return NamidaCoolBox(
      colorScheme: theme.colorScheme.secondary,
      reducedColors: true,
      hPadding: 12.0,
      vPadding: 8.0,
      builder: (context) => Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 2.0),
              Expanded(
                child: Text(
                  lang.features,
                  style: textTheme.displayMedium,
                ),
              ),
              NamidaInkWellButton(
                bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(0.25),
                sizeMultiplier: 0.8,
                icon: Broken.export_1,
                text: lang.learnMore,
                onTap: () => NamidaLinkUtils.openLink(AppSocial.PATREON_BENEFITS_POST),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          ..._benefits.map(
            (benefit) {
              final unlocked = benefit.isFree || currentIndex >= benefit.minTier.index;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(
                      benefit.icon,
                      size: 18.0,
                      color: unlocked ? iconColor : dimmedColor,
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        benefit.text,
                        style: textTheme.displaySmall,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withOpacityExt(unlocked ? 0.6 : 0.2),
                        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                      ),
                      child: Text(
                        _tierLabel(benefit),
                        style: textTheme.displaySmall?.copyWith(fontSize: 10.0),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    NamidaCheckMark(
                      size: 11.0,
                      active: unlocked,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _MembershipSource { patreon, coupon }
