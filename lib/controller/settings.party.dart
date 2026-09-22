part of 'settings_controller.dart';

class _PartySettings with SettingsFileWriter {
  _PartySettings._internal();

  /// relay the user last created a room on, null means the default one.
  final serverUrl = Rxn<String>();

  final createPublic = RxnF<bool>(fallback: false);

  /// public rooms also show the current title & artist. off keeps the listing to room level info only.
  final sharePlaying = RxnF<bool>(fallback: false);

  /// plain text, every character is one reaction.
  final reactions = RxnF<String>(fallback: _kDefaultReactions);

  static const _kDefaultReactions = '🔥❤️😴🎉👍😮';

  String get defaultReactions => _kDefaultReactions;

  /// grapheme clusters, an emoji is rarely a single code unit.
  List<String> reactionsList() {
    final list = reactions.valueF.characters.where((e) => e.trim().isNotEmpty).toList();
    return list.isEmpty ? _kDefaultReactions.characters.toList() : list;
  }

  final listenOnThisDevice = RxnF<bool>(fallback: true);

  /// `hid` of room owners whose public rooms are hidden while browsing.
  final hiddenOwners = <String>{};

  /// rooms this device created or joined recently, newest first. see [PartyRoomMemory].
  final recentRooms = <Map<String, dynamic>>[];

  void modify(void Function(_PartySettings partySettings) callback) {
    callback(this);
    _writeToStorage();
  }

  /// returns the new hidden state.
  bool toggleHiddenOwner(String hid) {
    final hidden = !hiddenOwners.remove(hid);
    if (hidden) hiddenOwners.add(hid);
    _writeToStorage();
    return hidden;
  }

  @override
  void applyKuruSettings() {}

  Future<void> prepareSettingsFile() async {
    final json = await prepareSettingsFile_();
    if (json is! Map) return;

    try {
      serverUrl.value = json['serverUrl'] as String?;
      createPublic.value = json['createPublic'] as bool?;
      sharePlaying.value = json['sharePlaying'] as bool?;
      reactions.value = json['reactions'] as String?;
      listenOnThisDevice.value = json['listenOnThisDevice'] as bool?;
      hiddenOwners
        ..clear()
        ..addAll((json['hiddenOwners'] as List?)?.cast<String>() ?? const <String>[]);
      recentRooms
        ..clear()
        ..addAll((json['recentRooms'] as List?)?.whereType<Map>().map((e) => e.cast<String, dynamic>()) ?? const <Map<String, dynamic>>[]);
    } catch (e, st) {
      printy(e, isError: true);
      logger.report(e, st);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
    'serverUrl': ?serverUrl.value,
    'createPublic': ?createPublic.value,
    'sharePlaying': ?sharePlaying.value,
    'reactions': ?reactions.value,
    'listenOnThisDevice': ?listenOnThisDevice.value,
    'hiddenOwners': hiddenOwners.toFixedList(),
    'recentRooms': recentRooms,
  };

  Future<void> _writeToStorage() async => await writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_PARTY;
}
