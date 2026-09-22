part of '../party_page.dart';

class _PartyInfoSections extends StatelessWidget {
  const _PartyInfoSections();

  @override
  Widget build(BuildContext context) {
    final double horizontalMargin = Dimensions.inst.showSubpageInfoAtSideContext(context) ? 0.0 : Dimensions.inst.getSettingsHorizontalMargin(context);
    return Stack(
      children: [
        SuperSmoothListView(
          padding: kBottomPaddingInsets.add(EdgeInsets.symmetric(horizontal: horizontalMargin)),
          children: const [
            _HeaderCard(),
            _JoinRequestsCard(),
            _ReactionsCard(),
            _MembersCard(),
            _PartyHistoryLive(),
            _HostSettingsCard(),
          ],
        ),
        const Positioned.fill(
          child: _ReactionOverlay(),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? countText;

  const _SectionTitle({
    required this.title,
    this.countText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final countText = this.countText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          if (countText != null) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                color: theme.colorScheme.secondaryContainer.withOpacityExt(0.4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                child: Text(
                  countText,
                  style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 6.0),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.displayMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const _Chip({
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
        color: color.withOpacityExt(0.12),
        border: Border.all(color: color.withOpacityExt(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12.0,
                color: color,
              ),
              const SizedBox(width: 4.0),
            ],
            Text(
              text,
              style: context.theme.textTheme.displaySmall?.copyWith(fontSize: 11.0),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PartyConnectionStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (status) {
      PartyConnectionStatus.connected => (lang.partyStatusConnected, Colors.green),
      PartyConnectionStatus.pendingApproval => (lang.partyStatusPendingApproval, Colors.orange),
      PartyConnectionStatus.reconnecting => (lang.partyStatusReconnecting, Colors.orange),
      PartyConnectionStatus.connecting || PartyConnectionStatus.closed => (lang.partyStatusConnecting, context.theme.colorScheme.primary),
    };
    return _Chip(
      text: text,
      color: color,
    );
  }
}

class _SyncStateChip extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const _SyncStateChip({this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: PartyController.inst.syncState,
      builder: (context, syncState) {
        final (String text, IconData icon, Color color, void Function()? onTap) = switch (syncState) {
          PartySyncState.catchingUp => (lang.partySyncCatchingUp, Broken.refresh_2, Colors.orange, null),
          PartySyncState.pausedLocally => (lang.partySyncPausedLocally, Broken.play, Colors.orange, Player.inst.play),
          PartySyncState.unavailable => (lang.partySyncUnavailable, Broken.forbidden_2, Colors.red, null),
          PartySyncState.idle || PartySyncState.inSync => ('', Broken.tick_circle, Colors.transparent, null),
        };
        if (text.isEmpty) return const SizedBox();
        return Padding(
          padding: padding,
          child: NamidaInkWell(
            onTap: onTap,
            borderRadius: 6.0,
            bgColor: color.withOpacityExt(0.12),
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 12.0,
                  color: color,
                ),
                const SizedBox(width: 4.0),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140.0),
                  child: Text(
                    text,
                    style: context.theme.textTheme.displaySmall?.copyWith(fontSize: 11.0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReactionsCard extends StatelessWidget {
  const _ReactionsCard();

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      icon: Broken.emoji_happy,
      title: lang.partyReactions,
      subtitle: null,
      trailing: NamidaIconButton(
        icon: Broken.edit_2,
        iconSize: 18.0,
        tooltip: () => lang.edit,
        onPressed: _editReactions,
      ),
      child: ObxO(
        rx: settings.party.reactions,
        builder: (context, _) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Row(
            children: [
              for (final emoji in settings.party.reactionsList())
                NamidaInkWell(
                  onTap: () => PartyController.inst.sendReaction(emoji),
                  borderRadius: 14.0,
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 22.0),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _editReactions() {
  final controller = TextEditingController(text: settings.party.reactions.valueF);
  NamidaNavigator.inst.navigateDialog(
    onDisposing: controller.dispose,
    dialog: CustomBlurryDialog(
      icon: Broken.emoji_happy,
      title: lang.partyReactions,
      normalTitleStyle: true,
      trailingWidgets: [
        NamidaIconButton(
          icon: Broken.refresh_left_square,
          iconSize: 20.0,
          tooltip: () => lang.restoreDefaults,
          onPressed: () {
            settings.party.modify((partySettings) => partySettings.reactions.value = null);
            NamidaNavigator.inst.closeDialog();
          },
        ),
      ],
      actions: [
        const CancelButton(),
        NamidaButton(
          text: lang.save,
          onTap: () {
            settings.party.modify((partySettings) => partySettings.reactions.value = controller.text.trim().nullifyEmpty());
            NamidaNavigator.inst.closeDialog();
          },
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: CustomTagTextField(
          controller: controller,
          hintText: settings.party.defaultReactions,
          labelText: lang.partyReactions,
          maxLines: 1,
        ),
      ),
    ),
  );
}

class _ReactionOverlay extends StatefulWidget {
  const _ReactionOverlay();

  @override
  State<_ReactionOverlay> createState() => _ReactionOverlayState();
}

class _ReactionOverlayState extends State<_ReactionOverlay> with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1.0),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 6.0),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 3.0),
  ]).animate(_animation);
  late final _slide = Tween(begin: Offset.zero, end: const Offset(0.0, -1.4)).animate(_animation);

  String? _emoji;
  String? _name;

  @override
  void initState() {
    super.initState();
    _animation.addStatusListener(_onAnimationStatus);
    PartyController.inst.reactionTick.addListener(_onReaction);
  }

  @override
  void dispose() {
    PartyController.inst.reactionTick.removeListener(_onReaction);
    _animation.dispose();
    super.dispose();
  }

  // -- dropping the emoji keeps the ticker idle while nothing is floating
  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) setState(() => _emoji = null);
  }

  void _onReaction() {
    final reaction = PartyController.inst.lastReaction;
    if (reaction == null) return;
    setState(() {
      _emoji = reaction.$2;
      _name = PartyController.inst.state.members[reaction.$1]?.name;
    });
    _animation.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _emoji;
    if (emoji == null) return const SizedBox();
    final name = _name;
    final theme = context.theme;
    return IgnorePointer(
      child: Obx(
        (context) => Align(
          alignment: AlignmentDirectional.bottomEnd,
          child: Padding(
            padding: EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingEffectiveR + 12.0, right: 12.0, left: 12.0),
            child: RepaintBoundary(
              child: FadeTransition(
                opacity: _opacity,
                child: SlideTransition(
                  position: _slide,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.cardColor.withOpacityExt(0.9),
                      borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            emoji,
                            style: const TextStyle(fontSize: 26.0),
                          ),
                          if (name != null) ...[
                            const SizedBox(width: 8.0),
                            Text(
                              name,
                              style: theme.textTheme.displaySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  void _onLeaveTap() {
    final controller = PartyController.inst;
    if (!controller.isHost) {
      controller.leave();
      return;
    }
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.logout,
        title: lang.partyLeave,
        normalTitleStyle: true,
        actions: const [
          CancelButton(),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomListTile(
              icon: Broken.logout,
              title: lang.partyLeave,
              subtitle: lang.partyLeaveSubtitle,
              onTap: () {
                NamidaNavigator.inst.closeDialog();
                controller.leave();
              },
            ),
            CustomListTile(
              icon: Broken.close_circle,
              title: lang.partyCloseForEveryone,
              onTap: () {
                NamidaNavigator.inst.closeDialog();
                controller.leave(closeRoom: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = PartyController.inst;
    return ObxO(
      rx: controller.infoTick,
      builder: (context, _) {
        final code = controller.code ?? '';
        final inviteLink = controller.inviteLink;
        final roomName = controller.state.roomName;
        return SettingsCard(
          icon: Broken.people,
          title: roomName.isEmpty ? lang.partyListeningParty : roomName,
          subtitle: null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SyncStateChip(
                padding: EdgeInsetsDirectional.only(end: 6.0),
              ),
              ObxO(
                rx: controller.status,
                builder: (context, status) => _StatusChip(status: status),
              ),
            ],
          ),
          child: Column(
            children: [
              ObxO(
                rx: controller.status,
                builder: (context, status) => status == PartyConnectionStatus.connected && !controller.hostOnline
                    ? CustomListTile(
                        icon: Broken.warning_2,
                        passedColor: Colors.orange,
                        title: lang.partyHostOffline,
                      )
                    : const SizedBox(),
              ),
              _InviteSection(code: code, inviteLink: inviteLink),
              ObxO(
                rx: controller.isListening,
                builder: (context, isListening) => CustomSwitchListTile(
                  icon: Broken.headphone,
                  title: lang.partyListenOnThisDevice,
                  subtitle: lang.partyListenOnThisDeviceSubtitle,
                  value: isListening,
                  onChanged: (isTrue) => controller.setListening(!isTrue),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: NamidaButton(
                        icon: Broken.logout,
                        colorScheme: Colors.red,
                        borderRadius: 18.0,
                        text: lang.partyLeave,
                        onTap: _onLeaveTap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _JoinRequestsCard extends StatelessWidget {
  const _JoinRequestsCard();

  @override
  Widget build(BuildContext context) {
    final controller = PartyController.inst;
    return ObxO(
      rx: controller.infoTick,
      builder: (context, _) => ObxO(
        rx: controller.requestsTick,
        builder: (context, _) {
          if (!controller.isHost) return const SizedBox();
          final requests = controller.joinRequests.toList();
          if (requests.isEmpty) return const SizedBox();
          return SettingsCard(
            icon: Broken.user_add,
            title: lang.partyJoinRequests,
            subtitle: null,
            child: Column(
              children: [
                for (final request in requests)
                  CustomListTile(
                    icon: Broken.user,
                    title: request.name,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NamidaIconButton(
                          icon: Broken.close_circle,
                          iconSize: 22.0,
                          tooltip: () => lang.reject,
                          onPressed: () => controller.answerJoinRequest(request.id, false),
                        ),
                        NamidaButton(
                          text: lang.accept,
                          onTap: () => controller.answerJoinRequest(request.id, true),
                        ),
                      ],
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

class _MembersCard extends StatelessWidget {
  const _MembersCard();

  @override
  Widget build(BuildContext context) {
    final controller = PartyController.inst;
    return ObxO(
      rx: controller.infoTick,
      builder: (context, _) => ObxO(
        rx: controller.membersTick,
        builder: (context, _) {
          final members = controller.state.members.values;
          final me = controller.me;
          final isHost = controller.isHost;
          final maxMembers = controller.maxMembers;
          return SettingsCard(
            icon: Broken.profile_2user,
            title: lang.partyMembers,
            subtitle: maxMembers > 0 ? '${members.length}/$maxMembers' : '${members.length}',
            child: Column(
              children: [
                for (final member in members)
                  _MemberTile(
                    member: member,
                    me: me,
                    isHost: isHost,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final PartyMember member;
  final PartyMember? me;
  final bool isHost;

  const _MemberTile({
    required this.member,
    required this.me,
    required this.isHost,
  });

  void _confirmTransferHost() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: lang.partyTransferHostConfirm(name: member.name),
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.confirm.toUpperCase(),
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              PartyController.inst.transferHost(member.n);
            },
          ),
        ],
      ),
    );
  }

  List<NamidaPopupItem> _moderationItems() {
    final controller = PartyController.inst;
    return [
      NamidaPopupItem(
        icon: Broken.user_remove,
        title: lang.partyKick,
        onTap: () => controller.kick(member.n),
      ),
      NamidaPopupItem(
        icon: Broken.forbidden_2,
        title: lang.partyBan,
        onTap: () => controller.kick(member.n, ban: true),
      ),
    ];
  }

  List<NamidaPopupItem> _actionItems() {
    final me = this.me;
    if (me == null || me.n == member.n) return const [];
    if (isHost) {
      final controller = PartyController.inst;
      return [
        member.role == PartyRole.admin
            ? NamidaPopupItem(
                icon: Broken.shield_slash,
                title: lang.partyRemoveAdmin,
                onTap: () => controller.setRole(member.n, PartyRole.guest),
              )
            : NamidaPopupItem(
                icon: Broken.shield_tick,
                title: lang.partyMakeAdmin,
                onTap: () => controller.setRole(member.n, PartyRole.admin),
              ),
        NamidaPopupItem(
          icon: Broken.crown_1,
          title: lang.partyTransferHost,
          onTap: _confirmTransferHost,
        ),
        ..._moderationItems(),
      ];
    }
    if (me.role == PartyRole.admin && member.role == PartyRole.guest) return _moderationItems();
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isMe = me?.n == member.n;
    final (roleText, roleColor, roleIcon) = switch (member.role) {
      PartyRole.host => (lang.host, Colors.orange, Broken.crown_1),
      PartyRole.admin => (lang.partyRoleAdmin, theme.colorScheme.primary, Broken.shield_tick),
      PartyRole.guest => (lang.partyRoleGuest, theme.colorScheme.onSurface.withOpacityExt(0.5), null),
    };
    final actionItems = _actionItems();
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Tooltip(
                  message: member.listening ? lang.partyListenOnThisDevice : lang.partyRemoteControl,
                  child: Icon(
                    member.listening ? Broken.headphone : Broken.mobile,
                    size: 20.0,
                    color: context.defaultIconColor(),
                  ),
                ),
                const SizedBox(width: 12.0),
                Flexible(
                  child: Text(
                    member.name,
                    style: theme.textTheme.displayMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6.0),
                  _Chip(
                    text: lang.partyYou,
                    color: theme.colorScheme.secondary,
                  ),
                ],
                const SizedBox(width: 6.0),
                _Chip(
                  text: roleText,
                  color: roleColor,
                  icon: roleIcon,
                ),
              ],
            ),
          ),
          if (actionItems.isNotEmpty)
            NamidaPopupWrapper(
              childrenDefault: () => actionItems,
              child: Icon(
                Broken.more,
                size: 18.0,
                color: context.defaultIconColor(),
              ),
            ),
        ],
      ),
    );
    if (actionItems.isEmpty) return tile;
    return NamidaPopupWrapper(
      childrenDefault: () => actionItems,
      child: tile,
    );
  }
}

class _HostSettingsCard extends StatelessWidget {
  const _HostSettingsCard();

  void _promptSetPassword() {
    final textController = TextEditingController();
    NamidaNavigator.inst.navigateDialog(
      onDisposing: textController.dispose,
      dialog: CustomBlurryDialog(
        title: lang.partySetPassword,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.save,
            onTap: () {
              final password = textController.text;
              if (password.isEmpty) return;
              PartyController.inst.setRoomOpts(password: password);
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
        child: CustomTagTextField(
          controller: textController,
          hintText: lang.partyRoomPassword,
          labelText: '',
          obscureText: true,
          maxLines: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = PartyController.inst;
    return ObxO(
      rx: controller.infoTick,
      builder: (context, _) {
        if (!controller.isHost) return const SizedBox();
        final perms = controller.state.perms;
        final opts = controller.opts;
        final bans = controller.bans;
        return SettingsCard(
          icon: Broken.setting_2,
          title: lang.partyHostSettings,
          subtitle: null,
          child: Column(
            children: [
              _SectionTitle(title: lang.partyGuestPermissions),
              CustomSwitchListTile(
                icon: Broken.play,
                title: lang.partyPermControl,
                value: perms.control,
                onChanged: (isTrue) => controller.setPermissions(perms.copyWith(control: !isTrue)),
              ),
              CustomSwitchListTile(
                icon: Broken.add_circle,
                title: lang.partyPermAdd,
                value: perms.add,
                onChanged: (isTrue) => controller.setPermissions(perms.copyWith(add: !isTrue)),
              ),
              CustomSwitchListTile(
                icon: Broken.edit_2,
                title: lang.partyPermEdit,
                value: perms.edit,
                onChanged: (isTrue) => controller.setPermissions(perms.copyWith(edit: !isTrue)),
              ),
              CustomSwitchListTile(
                icon: Broken.message,
                title: lang.partyPermChat,
                value: perms.chat,
                onChanged: (isTrue) => controller.setPermissions(perms.copyWith(chat: !isTrue)),
              ),
              if (opts != null) ...[
                const NamidaContainerDivider(
                  margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                ),
                CustomSwitchListTile(
                  icon: Broken.shield_tick,
                  title: lang.partyRequireApproval,
                  value: opts.approval,
                  onChanged: (isTrue) => controller.setRoomOpts(approval: !isTrue),
                ),
                CustomSwitchListTile(
                  icon: Broken.global,
                  title: lang.partyPublicRoom,
                  subtitle: lang.partyPublicRoomSubtitle,
                  value: opts.isPublic,
                  onChanged: (isTrue) => controller.setRoomOpts(isPublic: !isTrue),
                ),
                if (opts.isPublic)
                  ObxO(
                    rx: settings.party.sharePlaying,
                    builder: (context, sharePlaying) => CustomSwitchListTile(
                      icon: Broken.musicnote,
                      title: lang.partySharePlaying,
                      subtitle: lang.partySharePlayingSubtitle,
                      value: sharePlaying ?? false,
                      onChanged: (isTrue) => controller.setSharePlaying(!isTrue),
                    ),
                  ),
                CustomSwitchListTile(
                  icon: Broken.lock_1,
                  title: lang.partyLockRoom,
                  subtitle: lang.partyLockRoomSubtitle,
                  value: opts.locked,
                  onChanged: (isTrue) => controller.setRoomOpts(locked: !isTrue),
                ),
                CustomListTile(
                  icon: Broken.key,
                  title: lang.partySetPassword,
                  onTap: _promptSetPassword,
                  trailing: opts.hasPassword
                      ? NamidaIconButton(
                          icon: Broken.trash,
                          iconSize: 20.0,
                          tooltip: () => lang.partyRemovePassword,
                          onPressed: () => controller.setRoomOpts(clearPassword: true),
                        )
                      : null,
                ),
              ],
              if (bans.isNotEmpty) ...[
                const NamidaContainerDivider(
                  margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                ),
                _SectionTitle(
                  title: lang.partyBannedMembers,
                  countText: '${bans.length}',
                ),
                for (final ban in bans)
                  CustomListTile(
                    icon: Broken.forbidden_2,
                    title: ban.name,
                    trailing: NamidaButton(
                      text: lang.partyUnban,
                      onTap: () => controller.unban(ban.id),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

void _showQrCode(String inviteLink) {
  NamidaNavigator.inst.navigateDialog(
    dialog: CustomBlurryDialog(
      title: lang.partyScanToJoin,
      normalTitleStyle: true,
      actions: [
        NamidaButton(
          text: lang.done,
          onTap: NamidaNavigator.inst.closeDialog,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0.multipliedRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: QrImageView(
                data: inviteLink,
                size: 220.0,
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _InviteSection extends StatelessWidget {
  final String code;
  final String? inviteLink;

  const _InviteSection({required this.code, required this.inviteLink});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final link = inviteLink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    NamidaInkWell(
                      onTap: () => NamidaUtils.copyToClipboard(content: code, title: lang.partyCode),
                      borderRadius: 10.0,
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      bgColor: theme.cardColor.withOpacityExt(0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                lang.partyCode,
                                style: textTheme.displaySmall,
                              ),
                              const SizedBox(width: 6.0),
                              Icon(
                                Broken.copy,
                                size: 14.0,
                                color: textTheme.displaySmall?.color,
                              ),
                            ],
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              code,
                              style: textTheme.displayLarge?.copyWith(fontSize: 26.0, letterSpacing: 4.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        Expanded(
                          child: NamidaInkWellButton(
                            centered: true,
                            sizeMultiplier: 0.95,
                            icon: Broken.link_1,
                            text: lang.partyInviteLink,
                            enabled: link != null,
                            onTap: () => NamidaUtils.copyToClipboard(content: link!, title: lang.partyInviteLink),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: NamidaInkWellButton(
                            centered: true,
                            sizeMultiplier: 0.95,
                            icon: Broken.share,
                            text: lang.share,
                            enabled: link != null,
                            onTap: () => NamidaUtils.shareText(PartyController.inst.inviteText ?? link!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (link != null) ...[
                const SizedBox(width: 14.0),
                NamidaInkWell(
                  onTap: () => _showQrCode(link),
                  bgColor: Colors.white,
                  borderRadius: 10.0,
                  padding: const EdgeInsets.all(6.0),
                  child: RepaintBoundary(
                    child: QrImageView(
                      data: link,
                      size: 64.0 + 12.0,
                      backgroundColor: Colors.white.withOpacityExt(0.8),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
