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
  List<PartyPublicRoom> _rooms = const [];
  _BrowseState _state = _BrowseState.loading;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_state != _BrowseState.loading) setState(() => _state = _BrowseState.loading);
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
      state = rooms.isEmpty ? _BrowseState.empty : _BrowseState.rooms;
    }
    setState(() {
      _rooms = rooms;
      _state = state;
    });
  }

  void _hideOwner(PartyPublicRoom room) {
    if (room.ownerId.isEmpty) return;
    settings.party.toggleHiddenOwner(room.ownerId);
    final remaining = _rooms.where((e) => e.ownerId != room.ownerId).toList();
    setState(() {
      _rooms = remaining;
      if (remaining.isEmpty) _state = _BrowseState.empty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      icon: Broken.global_search,
      title: lang.partyBrowse,
      subtitle: lang.partyBrowseSubtitle,
      trailing: NamidaIconButton(
        icon: Broken.refresh,
        iconSize: 20.0,
        tooltip: () => lang.refresh,
        onPressed: _state == _BrowseState.loading ? null : _refresh,
      ),
      child: switch (_state) {
        _BrowseState.loading => Padding(
          padding: EdgeInsets.all(32.0),
          child: ThreeArchedCircle(
            color: context.theme.colorScheme.primary.withOpacityExt(0.5),
            size: 38.0,
          ),
        ),
        _BrowseState.unsupported => _BrowseInfo(icon: Broken.global_refresh, text: lang.partyBrowseUnsupported),
        _BrowseState.unreachable => _BrowseInfo(icon: Broken.danger, text: lang.partyUnreachable),
        _BrowseState.empty => _BrowseInfo(icon: Broken.moon, text: lang.partyNoPublicRooms),
        _BrowseState.rooms => Column(
          children: _rooms
              .map(
                (room) => _RoomTile(
                  room: room,
                  onTap: () => widget.onJoin(room),
                  onHideOwner: () => _hideOwner(room),
                ),
              )
              .toList(),
        ),
      },
    );
  }
}

class _BrowseInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BrowseInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = context.theme.colorScheme.onSurface.withOpacityExt(0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 24.0),
      child: Column(
        children: [
          Icon(
            icon,
            size: 28.0,
            color: color,
          ),
          const SizedBox(height: 8.0),
          Text(
            text,
            style: context.theme.textTheme.displaySmall?.copyWith(color: color),
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
    return CustomListTile(
      icon: room.hasPassword ? Broken.lock_1 : Broken.people,
      title: room.name,
      subtitle: nowPlaying,
      onTap: room.isFull ? null : onTap,
      trailingRaw: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            room.maxMembers > 0 ? '${room.members}/${room.maxMembers}' : '${room.members}',
            style: context.theme.textTheme.displaySmall,
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
