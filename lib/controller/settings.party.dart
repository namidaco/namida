part of 'settings_controller.dart';

class _PartySettings extends _SettingsKeysWriter {
  _PartySettings._internal();

  /// relay the user last created a room on, null means the default one.
  late final serverUrl = _key<String?>('serverUrl', null);
  late final createPublic = _key('createPublic', false);

  /// public rooms also show the current title & artist. off keeps the listing to room level info only.
  late final sharePlaying = _key('sharePlaying', false);
  late final listenOnThisDevice = _key('listenOnThisDevice', true);

  /// plain text, every character is one reaction.
  late final reactions = _key('reactions', _kDefaultReactions);

  /// `hid` of room owners whose public rooms are hidden while browsing.
  late final hiddenOwners = _keySet<String>('hiddenOwners', const {});

  /// rooms this device created or joined recently, newest first. see [PartyRoomMemory].
  late final recentRooms = _keyList<Map<String, dynamic>>('recentRooms', const []);

  static const _kDefaultReactions = '🔥❤️😴🎉👍😮';

  String get defaultReactions => _kDefaultReactions;

  /// grapheme clusters, an emoji is rarely a single code unit.
  List<String> reactionsList() {
    final list = reactions.value.characters.where((e) => e.trim().isNotEmpty).toList();
    return list.isEmpty ? _kDefaultReactions.characters.toList() : list;
  }

  /// returns the new hidden state.
  bool toggleHiddenOwner(String hid) {
    final hidden = !hiddenOwners.value.contains(hid);
    hiddenOwners.update((owners) => hidden ? owners.add(hid) : owners.remove(hid));
    return hidden;
  }

  @override
  Set<String> get sensitiveKeys => const {'hiddenOwners', 'recentRooms'};

  @override
  String get filePath => AppPaths.SETTINGS_PARTY;
}
