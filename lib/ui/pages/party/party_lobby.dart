part of '../party_page.dart';

void _showPartyError(String message, {String? errorCode, void Function()? onManageReturn}) {
  final isMembership = errorCode != null && PartyController.isMembershipError(errorCode);
  snackyy(
    icon: isMembership ? Broken.money_3 : Broken.warning_2,
    title: lang.partyListeningParty,
    message: message,
    isError: true,
    displayDuration: SnackDisplayDuration.long,
    button: isMembership
        ? SnackbarButton(
            text: lang.manage,
            function: onManageReturn == null
                ? const YoutubeManageSubscriptionPage().navigate
                : () async {
                    await const YoutubeManageSubscriptionPage().navigate();
                    onManageReturn();
                  },
          )
        : null,
  );
}

/// only shown for servers that gate room creation, tapping it manages the membership.
class _MembershipTile extends StatelessWidget {
  final Future<bool?> requiresMembership;

  const _MembershipTile({required this.requiresMembership});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FutureBuilder(
      future: requiresMembership,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox();
        return ObxO(
          rx: YoutubeAccountController.membership.userMembershipTypeGlobal,
          builder: (context, userMembershipType) {
            final hasMembership = userMembershipType != null && userMembershipType.index >= MembershipType.cutie.index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: CustomListTile(
                borderR: 12.0,
                dense: true,
                titleStyle: context.theme.textTheme.displaySmall,
                onTap: const YoutubeManageSubscriptionPage().navigate,
                title: hasMembership ? lang.membershipManage : lang.partyMembershipRequired(name: MembershipType.cutie.name),
                subtitle: hasMembership ? null : lang.signingInAllowsBasicUsageSubtitle,
                icon: Broken.money_3,
                bgColor: Color.alphaBlend(
                  theme.cardTheme.color?.withOpacityExt(0.3) ?? Colors.transparent,
                  theme.colorScheme.secondaryContainer,
                ).withOpacityExt(0.35),
                trailingRaw: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.0),
                  child: MembershipCard(displayName: false),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PartyLobby extends StatelessWidget {
  const _PartyLobby();

  @override
  Widget build(BuildContext context) {
    final double horizontalMargin = Dimensions.inst.getSettingsHorizontalMargin(context);
    return SuperSmoothListView(
      padding: kBottomPaddingInsets.add(EdgeInsets.symmetric(horizontal: horizontalMargin)).add(EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom)),
      children: const [
        _RejoinCard(),
        _JoinCard(),
        _CreateCard(),
        _PartyHistoryLive(),
        _DeviceNameCard(),
        _BrowseSection(),
        NamidaContainerDivider(
          margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        ),
        _PrivacyTile(),
      ],
    );
  }
}

class _DeviceNameCard extends StatefulWidget {
  const _DeviceNameCard();

  @override
  State<_DeviceNameCard> createState() => _DeviceNameCardState();
}

class _DeviceNameCardState extends State<_DeviceNameCard> {
  final _controller = TextEditingController(text: settings.sync.customDeviceName.value?.nullifyEmpty());
  final _focusNode = FocusNode();
  final _isDirty = false.obs;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refreshDirty);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_refreshDirty);
    _focusNode.removeListener(_onFocusChanged);
    _save();
    _isDirty.close();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  String? get _typedName => _controller.text.trim().nullifyEmpty();

  void _refreshDirty() => _isDirty.value = _typedName != settings.sync.customDeviceName.value;

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) _save();
  }

  void _save() {
    final name = _typedName;
    if (name == settings.sync.customDeviceName.value) return;
    settings.sync.modify((syncSettings) => syncSettings.customDeviceName.value = name);
    _isDirty.value = false;
  }

  void _saveAndUnfocus() {
    _save();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      icon: Broken.user_edit,
      title: lang.partyDisplayName,
      subtitle: lang.partyDisplayNameSubtitle,
      child: _FieldPadding(
        // -- the shared field keeps its focus on outside taps, here it has to save instead
        child: TapRegion(
          onTapOutside: (_) => _saveAndUnfocus(),
          child: Row(
            children: [
              Expanded(
                child: FutureBuilder(
                  future: SyncUtils.fallbackDeviceName,
                  builder: (context, snapshot) => CustomTagTextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    hintText: snapshot.data ?? '',
                    labelText: '',
                    icon: Broken.user,
                    maxLines: 1,
                    onFieldSubmitted: (_) => _saveAndUnfocus(),
                  ),
                ),
              ),
              ObxO(
                rx: _isDirty,
                builder: (context, isDirty) => AnimatedShow(
                  isHorizontal: true,
                  show: isDirty,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: NamidaButton(
                      icon: Broken.tick_circle,
                      tooltip: () => lang.save,
                      onTap: _saveAndUnfocus,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldPadding extends StatelessWidget {
  final Widget child;

  const _FieldPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: child,
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isLoading;
  final void Function() onTap;

  const _SubmitButton({
    required this.icon,
    required this.text,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: NamidaButton(
              icon: icon,
              minHeight: NamidaButton.kDefaultMinHeight * 1.25,
              borderRadius: 18.0,
              text: text,
              enabled: !isLoading,
              isLoading: isLoading,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateCard extends StatefulWidget {
  const _CreateCard();

  @override
  State<_CreateCard> createState() => _CreateCardState();
}

class _CreateCardState extends State<_CreateCard> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverController = TextEditingController(text: PartyController.preferredServer.toString());
  final _serverPasswordController = TextEditingController();

  bool _listening = settings.party.listenOnThisDevice.valueF;
  bool _approval = false;
  bool _seedQueue = true;
  bool _hostOnThisDevice = false;
  bool _isPublic = settings.party.createPublic.valueF;
  bool _sharePlaying = settings.party.sharePlaying.valueF;
  bool _isLoading = false;
  bool _canRetryAfterMembership = false;
  bool _awaitingMembership = false;

  late final Future<bool?> _requiresMembership = PartyController.requiresMembership(PartyController.preferredServer);

  @override
  void dispose() {
    _stopAwaitingMembership();
    _nameController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    _serverPasswordController.dispose();
    super.dispose();
  }

  void _startAwaitingMembership() {
    if (_awaitingMembership) return;
    _awaitingMembership = true;
    YoutubeAccountController.membership.userMembershipTypeGlobal.addListener(_onMembershipChanged);
  }

  void _stopAwaitingMembership() {
    if (!_awaitingMembership) return;
    _awaitingMembership = false;
    YoutubeAccountController.membership.userMembershipTypeGlobal.removeListener(_onMembershipChanged);
  }

  void _onMembershipChanged() {
    final membershipType = YoutubeAccountController.membership.userMembershipTypeGlobal.value;
    if (membershipType == null || membershipType.index < MembershipType.cutie.index) return;
    _stopAwaitingMembership();
    _offerRetry();
  }

  void _offerRetry() {
    if (!mounted || _canRetryAfterMembership) return;
    setState(() => _canRetryAfterMembership = true);
  }

  void _retryCreate() {
    setState(() => _canRetryAfterMembership = false);
    _create();
  }

  void _onCreateError(String error) {
    if (error == PartyController.kRoomsLimitError) {
      _showOpenRoomsDialog(onRetry: _create);
      return;
    }
    final message = PartyController.fatalMessage(error);
    if (PartyController.isMembershipError(error)) {
      _startAwaitingMembership();
      _showPartyError(message, errorCode: error, onManageReturn: _offerRetry);
      return;
    }
    _showPartyError(message, errorCode: error);
  }

  Future<void> _createOnThisDevice() async {
    setState(() => _isLoading = true);
    final error = await PartyController.inst.createLanRoom(
      roomName: _nameController.text,
      listening: _listening,
      approval: _approval,
      isPublic: _isPublic,
      password: _passwordController.text.nullifyEmpty(),
      seedWithPlayerQueue: _seedQueue,
    );
    if (error != null) _showPartyError(PartyController.fatalMessage(error), errorCode: error);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _create() async {
    if (_hostOnThisDevice) return _createOnThisDevice();
    final serverText = _serverController.text.trim();
    final server = serverText.isEmpty ? PartyController.defaultServer : Uri.tryParse(serverText);
    if (server == null || !server.hasScheme || server.host.isEmpty) {
      _showPartyError(lang.partyInvalidServerUrl);
      return;
    }
    setState(() => _isLoading = true);
    final error = await PartyController.inst.createRoom(
      server: server,
      roomName: _nameController.text,
      listening: _listening,
      approval: _approval,
      isPublic: _isPublic,
      password: _passwordController.text.nullifyEmpty(),
      serverPassword: _serverPasswordController.text.nullifyEmpty(),
      seedWithPlayerQueue: _seedQueue,
    );
    if (error != null) _onCreateError(error);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      icon: Broken.people,
      title: lang.partyCreate,
      subtitle: lang.partyCreateSubtitle,
      child: Column(
        children: [
          const SizedBox(height: 4.0),
          _FieldPadding(
            child: CustomTagTextField(
              controller: _nameController,
              hintText: lang.partyRoomName,
              labelText: '',
              icon: Broken.edit_2,
              maxLines: 1,
            ),
          ),
          _FieldPadding(
            child: CustomTagTextField(
              controller: _passwordController,
              hintText: lang.partyRoomPassword,
              labelText: '',
              icon: Broken.key,
              obscureText: true,
              maxLines: 1,
            ),
          ),
          CustomSwitchListTile(
            icon: Broken.headphone,
            title: lang.partyListenOnThisDevice,
            subtitle: lang.partyListenOnThisDeviceSubtitle,
            value: _listening,
            onChanged: (isTrue) {
              settings.party.modify((partySettings) => partySettings.listenOnThisDevice.value = !isTrue);
              setState(() => _listening = !isTrue);
            },
          ),
          CustomSwitchListTile(
            icon: Broken.shield_tick,
            title: lang.partyRequireApproval,
            value: _approval,
            onChanged: (isTrue) => setState(() => _approval = !isTrue),
          ),
          CustomSwitchListTile(
            icon: Broken.music_playlist,
            title: lang.partyStartWithCurrentQueue,
            value: _seedQueue,
            onChanged: (isTrue) => setState(() => _seedQueue = !isTrue),
          ),
          CustomSwitchListTile(
            icon: Broken.global,
            title: lang.partyPublicRoom,
            subtitle: lang.partyPublicRoomSubtitle,
            value: _isPublic,
            onChanged: (isTrue) {
              settings.party.modify((partySettings) => partySettings.createPublic.value = !isTrue);
              setState(() => _isPublic = !isTrue);
            },
          ),
          if (_isPublic)
            CustomSwitchListTile(
              icon: Broken.musicnote,
              title: lang.partySharePlaying,
              subtitle: lang.partySharePlayingSubtitle,
              value: _sharePlaying,
              onChanged: (isTrue) {
                settings.party.modify((partySettings) => partySettings.sharePlaying.value = !isTrue);
                setState(() => _sharePlaying = !isTrue);
              },
            ),
          CustomSwitchListTile(
            icon: Broken.wifi,
            title: lang.partyHostOnThisDevice,
            subtitle: lang.partyHostOnThisDeviceSubtitle,
            value: _hostOnThisDevice,
            onChanged: (isTrue) => setState(() => _hostOnThisDevice = !isTrue),
          ),
          NamidaExpansionTile(
            icon: Broken.driver_2,
            titleText: lang.partyCustomServer,
            subtitleText: lang.partyServerPasswordSubtitle,
            borderless: true,
            iconColor: context.defaultIconColor(),
            children: [
              _FieldPadding(
                child: CustomTagTextField(
                  controller: _serverController,
                  hintText: PartyController.defaultServer.toString(),
                  labelText: lang.partyServerUrl,
                  icon: Broken.global,
                  keyboardType: TextInputType.url,
                  maxLines: 1,
                ),
              ),
              _FieldPadding(
                child: CustomTagTextField(
                  controller: _serverPasswordController,
                  hintText: lang.partyServerPassword,
                  labelText: '',
                  icon: Broken.password_check,
                  obscureText: true,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          if (!_hostOnThisDevice)
            _MembershipTile(
              requiresMembership: _requiresMembership,
            ),
          if (_canRetryAfterMembership)
            _SubmitButton(
              icon: Broken.refresh,
              text: lang.partyTryAgain,
              isLoading: false,
              onTap: _retryCreate,
            ),
          _SubmitButton(
            icon: Broken.add_circle,
            text: lang.create,
            isLoading: _isLoading,
            onTap: _create,
          ),
        ],
      ),
    );
  }
}

class _JoinCard extends StatefulWidget {
  const _JoinCard();

  @override
  State<_JoinCard> createState() => _JoinCardState();
}

class _JoinCardState extends State<_JoinCard> {
  final _inviteController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _listening = settings.party.listenOnThisDevice.valueF;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _takePendingInvite();
    PartyController.inst.pendingInvite.addListener(_takePendingInvite);
  }

  void _takePendingInvite() {
    final pending = PartyController.inst.pendingInvite.value;
    if (pending == null) return;
    PartyController.inst.pendingInvite.value = null;
    _inviteController.text = pending;
  }

  @override
  void dispose() {
    PartyController.inst.pendingInvite.removeListener(_takePendingInvite);
    _inviteController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final invite = PartyController.parseInvite(_inviteController.text);
    if (invite == null) {
      _showPartyError(lang.partyInvalidInvite);
      return;
    }
    setState(() => _isLoading = true);
    await PartyController.inst.joinRoom(
      server: invite.server,
      code: invite.code,
      password: _passwordController.text.nullifyEmpty(),
      listening: _listening,
    );
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      icon: Broken.login_1,
      title: lang.partyJoin,
      subtitle: null,
      child: Column(
        children: [
          const SizedBox(height: 4.0),
          _FieldPadding(
            child: CustomTagTextField(
              controller: _inviteController,
              hintText: lang.partyInviteLinkOrCode,
              labelText: '',
              icon: Broken.link_1,
              maxLines: 1,
              onFieldSubmitted: (_) => _join(),
            ),
          ),
          _FieldPadding(
            child: CustomTagTextField(
              controller: _passwordController,
              hintText: lang.password,
              labelText: '',
              icon: Broken.key,
              obscureText: true,
              maxLines: 1,
            ),
          ),
          CustomSwitchListTile(
            icon: Broken.headphone,
            title: lang.partyListenOnThisDevice,
            subtitle: lang.partyListenOnThisDeviceSubtitle,
            value: _listening,
            onChanged: (isTrue) {
              settings.party.modify((partySettings) => partySettings.listenOnThisDevice.value = !isTrue);
              setState(() => _listening = !isTrue);
            },
          ),
          _SubmitButton(
            icon: Broken.login_1,
            text: lang.partyJoin,
            isLoading: _isLoading,
            onTap: _join,
          ),
        ],
      ),
    );
  }
}

class _BrowseSection extends StatefulWidget {
  const _BrowseSection();

  @override
  State<_BrowseSection> createState() => _BrowseSectionState();
}

class _BrowseSectionState extends State<_BrowseSection> {
  bool _isLoading = false;

  Future<void> _join(PartyPublicRoom room) async {
    if (_isLoading) return;
    String? password;
    if (room.hasPassword) {
      password = await _promptPassword(room.name);
      if (password == null) return;
    }
    setState(() => _isLoading = true);
    await PartyController.inst.joinRoom(
      server: PartyController.preferredServer,
      code: room.code,
      password: password,
      listening: settings.party.listenOnThisDevice.valueF,
    );
    if (mounted) setState(() => _isLoading = false);
  }

  Future<String?> _promptPassword(String roomName) {
    final controller = TextEditingController();
    final completer = Completer<String?>();
    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        controller.dispose();
        if (!completer.isCompleted) completer.complete(null);
      },
      dialog: CustomBlurryDialog(
        title: roomName,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.confirm,
            onTap: () {
              completer.complete(controller.text.nullifyEmpty());
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
        child: CustomTagTextField(
          controller: controller,
          hintText: lang.partyRoomPassword,
          labelText: '',
          icon: Broken.key,
          obscureText: true,
          maxLines: 1,
        ),
      ),
    );
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return _PartyBrowseCard(onJoin: _join);
  }
}

class _PrivacyTile extends StatelessWidget {
  const _PrivacyTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: CustomListTile(
        extraDense: true,
        icon: Broken.shield_tick,
        title: lang.partyPrivacy,
        onTap: _showPartyPrivacyNote,
      ),
    );
  }
}

class _RejoinCard extends StatefulWidget {
  const _RejoinCard();

  @override
  State<_RejoinCard> createState() => _RejoinCardState();
}

class _RejoinCardState extends State<_RejoinCard> {
  static const _maxDisplayed = 3;

  List<PartyRoomMemory> _rooms = PartyController.recentRooms();
  bool _isLoading = false;

  Future<void> _rejoin(PartyRoomMemory room) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await PartyController.inst.rejoin(room, listening: settings.party.listenOnThisDevice.valueF);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      // -- a failed rejoin may have dropped the room
      if (!PartyController.inst.isActive.value) _rooms = PartyController.recentRooms();
    });
  }

  void _forget(PartyRoomMemory room) {
    PartyController.forgetRoom(room);
    setState(() => _rooms = PartyController.recentRooms());
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _rooms;
    if (rooms.isEmpty) return const SizedBox();
    final displayed = rooms.length < _maxDisplayed ? rooms.length : _maxDisplayed;
    return SettingsCard(
      icon: Broken.refresh_left_square,
      title: lang.partyRejoin,
      subtitle: null,
      child: Column(
        children: [
          for (int i = 0; i < displayed; i++)
            _RejoinTile(
              room: rooms[i],
              enabled: !_isLoading,
              onTap: () => _rejoin(rooms[i]),
              onForget: () => _forget(rooms[i]),
            ),
        ],
      ),
    );
  }
}

class _RejoinTile extends StatelessWidget {
  final PartyRoomMemory room;
  final bool enabled;
  final void Function() onTap;
  final void Function() onForget;

  const _RejoinTile({
    required this.room,
    required this.enabled,
    required this.onTap,
    required this.onForget,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      icon: room.hosted ? Broken.crown_1 : Broken.login_1,
      title: room.name.isEmpty ? room.code : room.name,
      subtitle: '${room.code}  •  ${TimeAgoController.dateMSSEFromNow(room.atMS, long: false)}',
      enabled: enabled,
      onTap: onTap,
      trailingRaw: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (room.hosted)
            _Chip(
              text: lang.host,
              color: Colors.orange,
              icon: Broken.crown_1,
            ),
          NamidaIconButton(
            icon: Broken.close_circle,
            iconSize: 20.0,
            tooltip: () => lang.remove,
            onPressed: onForget,
          ),
        ],
      ),
    );
  }
}

void _showOpenRoomsDialog({required void Function() onRetry}) {
  NamidaNavigator.inst.navigateDialog(
    dialog: CustomBlurryDialog(
      icon: Broken.people,
      title: lang.partyYourOpenRooms,
      normalTitleStyle: true,
      actions: [
        NamidaButton(
          text: lang.done,
          onTap: NamidaNavigator.inst.closeDialog,
        ),
      ],
      child: _OpenRoomsList(
        onRetry: onRetry,
      ),
    ),
  );
}

class _OpenRoomsList extends StatefulWidget {
  final void Function() onRetry;

  const _OpenRoomsList({required this.onRetry});

  @override
  State<_OpenRoomsList> createState() => _OpenRoomsListState();
}

class _OpenRoomsListState extends State<_OpenRoomsList> {
  late final List<PartyRoomMemory> _rooms = PartyController.recentRooms().where((e) => e.hosted).toList();
  final _closing = <String>{};
  bool _closedAny = false;

  Future<void> _close(PartyRoomMemory room) async {
    if (_closing.contains(room.code)) return;
    setState(() => _closing.add(room.code));
    final closed = await PartyController.closeRemoteRoom(room);
    if (!closed) _showPartyError(lang.partyCloseRoomFailed);
    if (!mounted) return;
    setState(() {
      _closing.remove(room.code);
      if (closed) {
        _rooms.remove(room);
        _closedAny = true;
      }
    });
  }

  void _retry() {
    NamidaNavigator.inst.closeDialog();
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(
            '${lang.partyRoomsLimit}\n${lang.partyOpenRoomsOtherDevices}',
            style: context.theme.textTheme.displaySmall,
          ),
        ),
        for (final room in _rooms)
          CustomListTile(
            icon: Broken.people,
            title: room.name.isEmpty ? room.code : room.name,
            subtitle: room.code,
            trailingRaw: NamidaButton(
              text: lang.partyCloseRoom,
              isLoading: _closing.contains(room.code),
              enabled: !_closing.contains(room.code),
              onTap: () => _close(room),
            ),
          ),
        if (_closedAny)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: NamidaButton(
                    icon: Broken.refresh,
                    text: lang.partyTryAgain,
                    onTap: _retry,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// [PartyController.playedHistory] has no tick of its own, the anchor is what grows it.
class _PartyHistoryLive extends StatefulWidget {
  const _PartyHistoryLive();

  @override
  State<_PartyHistoryLive> createState() => _PartyHistoryLiveState();
}

class _PartyHistoryLiveState extends State<_PartyHistoryLive> {
  int _lastId = PartyController.inst.playedHistory.lastOrNull?.id ?? -1;

  @override
  void initState() {
    super.initState();
    PartyController.inst.anchorTick.addListener(_onAnchorChanged);
  }

  @override
  void dispose() {
    PartyController.inst.anchorTick.removeListener(_onAnchorChanged);
    super.dispose();
  }

  void _onAnchorChanged() {
    final lastId = PartyController.inst.playedHistory.lastOrNull?.id ?? -1;
    if (lastId == _lastId) return;
    setState(() => _lastId = lastId);
  }

  @override
  Widget build(BuildContext context) {
    return _PartyHistoryCard(
      entries: PartyController.inst.playedHistory,
    );
  }
}

class _PartyHistoryCard extends StatelessWidget {
  static const _maxDisplayed = 50;

  final List<PartyEntry> entries;

  const _PartyHistoryCard({required this.entries});

  String _defaultPlaylistName() {
    final roomName = PartyController.inst.state.roomName;
    final base = roomName.isEmpty ? lang.partyListeningParty : roomName;
    return '$base - ${DateTime.now().millisecondsSinceEpoch.dateFormattedOriginal}';
  }

  Future<void> _save(String name) async {
    final count = await PartyController.inst.saveHistoryAsPlaylist(name);
    snackyy(
      icon: Broken.music_playlist,
      title: lang.partySaveAsPlaylist,
      message: lang.partySavedToPlaylist(count: count, name: name),
    );
  }

  void _promptSave() {
    final textController = TextEditingController(text: _defaultPlaylistName());
    NamidaNavigator.inst.navigateDialog(
      onDisposing: textController.dispose,
      dialog: CustomBlurryDialog(
        title: lang.partySaveAsPlaylist,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.save,
            onTap: () {
              final name = textController.text.trim();
              if (name.isEmpty) return;
              NamidaNavigator.inst.closeDialog();
              _save(name);
            },
          ),
        ],
        child: CustomTagTextField(
          controller: textController,
          hintText: lang.name,
          labelText: '',
          icon: Broken.music_playlist,
          maxLines: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = this.entries;
    if (entries.isEmpty) return const SizedBox();
    final lastIndex = entries.length - 1;
    final displayed = entries.length < _maxDisplayed ? entries.length : _maxDisplayed;
    return SettingsCard(
      icon: Broken.clock,
      title: lang.partyHistory,
      subtitle: '${entries.length}',
      child: Column(
        children: [
          for (int i = 0; i < displayed; i++)
            _HistoryTile(
              entry: entries[lastIndex - i],
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: NamidaButton(
                    icon: Broken.music_playlist,
                    borderRadius: 18.0,
                    text: lang.partySaveAsPlaylist,
                    onTap: _promptSave,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final PartyEntry entry;

  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.theme.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Row(
        children: [
          Icon(
            entry.isLocal ? Broken.musicnote : Broken.video_square,
            size: 18.0,
            color: context.defaultIconColor(),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: textTheme.displayMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.artist.isNotEmpty)
                  Text(
                    entry.artist,
                    style: textTheme.displaySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          Text(
            entry.durationMS.milliSecondsLabel,
            style: textTheme.displaySmall,
          ),
        ],
      ),
    );
  }
}
