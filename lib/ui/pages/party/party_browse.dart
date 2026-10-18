part of '../party_page.dart';

enum _BrowseState {
  loading,
  unsupported,
  unreachable,
  empty,
  rooms,
}

class _PartyBrowseCard extends StatefulWidget {
  final void Function(PartyPublicRoom room) onJoin;

  const _PartyBrowseCard({required this.onJoin});

  @override
  State<_PartyBrowseCard> createState() => _PartyBrowseCardState();
}

class _PartyBrowseCardState extends State<_PartyBrowseCard> {
  List<PartyPublicRoom> _serverRooms = const [];
  List<PartyPublicRoom> _lanRooms = const [];

  /// shown while there are no rooms, never [_BrowseState.rooms].
  _BrowseState _serverState = _BrowseState.loading;
  bool _isScanningLan = true;

  bool get _isLoading => _serverState == _BrowseState.loading || _isScanningLan;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!_isLoading) {
      setState(() {
        _serverState = _BrowseState.loading;
        _isScanningLan = true;
      });
    }
    await Future.wait([_refreshServer(), _refreshLan()]);
  }

  Future<void> _refreshServer() async {
    final server = PartyController.preferredServer;
    final supported = await PartyController.supportsDirectory(server);
    final page = supported == true ? await PartyController.listRooms(server: server) : null;
    if (!mounted) return;
    final rooms = page?.rooms ?? const <PartyPublicRoom>[];
    final _BrowseState state;
    if (supported == false) {
      state = _BrowseState.unsupported;
    } else if (supported == null || page == null) {
      state = _BrowseState.unreachable;
    } else {
      state = _BrowseState.empty;
    }
    setState(() {
      _serverRooms = rooms;
      _serverState = state;
    });
  }

  Future<void> _refreshLan() async {
    final rooms = await PartyController.discoverLanRooms();
    if (!mounted) return;
    setState(() {
      _lanRooms = rooms;
      _isScanningLan = false;
    });
  }

  void _hideOwner(PartyPublicRoom room) {
    if (room.ownerId.isEmpty) return;
    settings.party.toggleHiddenOwner(room.ownerId);
    final remainingServerRooms = _serverRooms.where((e) => e.ownerId != room.ownerId).toFixedList();
    final remainingLanRooms = _lanRooms.where((e) => e.ownerId != room.ownerId).toFixedList();
    setState(() {
      _serverRooms = remainingServerRooms;
      _lanRooms = remainingLanRooms;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasRooms = _lanRooms.isNotEmpty || _serverRooms.isNotEmpty;
    final state = hasRooms
        ? _BrowseState.rooms
        : _isScanningLan
        ? _BrowseState.loading
        : _serverState;
    Widget roomTile(PartyPublicRoom room) => _RoomTile(
      room: room,
      onTap: () => widget.onJoin(room),
      onHideOwner: () => _hideOwner(room),
    );
    return SettingsCard(
      icon: Broken.global_search,
      title: lang.partyBrowse,
      subtitle: lang.partyBrowseSubtitle,
      trailing: NamidaIconButton(
        icon: Broken.refresh,
        iconSize: 20.0,
        tooltip: () => lang.refresh,
        onPressed: _isLoading ? null : _refresh,
      ),
      child: switch (state) {
        _BrowseState.loading => _BrowseInfo.loading(text: lang.fetching),
        _BrowseState.unsupported => _BrowseInfo(icon: Broken.global_refresh, text: lang.partyBrowseUnsupported),
        _BrowseState.unreachable => _BrowseInfo(icon: Broken.danger, text: lang.partyUnreachable),
        _BrowseState.empty => _BrowseInfo(icon: Broken.moon, text: lang.partyNoPublicRooms),
        _BrowseState.rooms => Column(
          children: [
            ..._lanRooms.map(roomTile),
            ..._serverRooms.map(roomTile),
          ],
        ),
      },
    );
  }
}

class _BrowseInfo extends StatelessWidget {
  final IconData? icon;
  final String text;

  const _BrowseInfo({required IconData this.icon, required this.text});
  const _BrowseInfo.loading({required this.text}) : icon = null;

  @override
  Widget build(BuildContext context) {
    const color = NColors(.onSurface, opacity: 0.5);
    final icon = this.icon;
    final iconWidget = icon == null
        ? NBuilder(
            builder: (context, colors) => ThreeArchedCircle(
              color: colors.primary.withOpacityExt(0.5),
              size: 28.0,
            ),
          )
        : NIcon(
            icon,
            size: 28.0,
            color: color,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 24.0),
      child: Column(
        children: [
          iconWidget,
          const SizedBox(height: 8.0),
          NamidaText(
            text,
            style: NText.small,
            color: color,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final PartyPublicRoom room;
  final void Function() onTap;
  final void Function() onHideOwner;

  const _RoomTile({
    required this.room,
    required this.onTap,
    required this.onHideOwner,
  });

  @override
  Widget build(BuildContext context) {
    final title = room.title;
    final artist = room.artist;
    final nowPlaying = title == null || title.isEmpty ? null : (artist == null || artist.isEmpty ? title : '$title • $artist');
    final icon = room.hasPassword
        ? Broken.lock_1
        : room.isLocal
        ? Broken.wifi
        : Broken.people;
    return CustomListTile(
      icon: icon,
      title: room.name,
      subtitle: nowPlaying,
      onTap: room.isFull ? null : onTap,
      trailingRaw: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NamidaText(
            room.maxMembers > 0 ? '${room.members}/${room.maxMembers}' : '${room.members}',
            style: NText.small,
          ),
          NamidaIconButton(
            icon: Broken.eye_slash,
            iconSize: 18.0,
            tooltip: () => lang.partyHideOwner,
            onPressed: onHideOwner,
          ),
        ],
      ),
    );
  }
}
