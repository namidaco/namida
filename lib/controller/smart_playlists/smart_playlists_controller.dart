import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';
import 'package:intl/intl.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:playlist_manager/class/favourite_playlist.dart';
import 'package:playlist_manager/playlist_manager.dart' show PlaylistTagsFilter;

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/sort_chain.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/youtube/class/download_task_base.dart';

part 'filters/smart_playlists_date_time.dart';
part 'filters/smart_playlists_number.dart';
part 'filters/smart_playlists_text.dart';
part 'filters/smart_playlists_boolean.dart';
part 'smart_playlist.dart';

class SmartPlaylistsController {
  static final inst = SmartPlaylistsController._();
  SmartPlaylistsController._();

  static const _orderRowKey = '_order_index_';

  final smartPlaylistsMap = <SmartPlaylistKey, SmartPlaylistWrapper>{}.obs;
  final smartPlaylistsList = <SmartPlaylistWrapper>[].obs;
  int _orderModifiedDate = 0;

  SmartPlaylistWrapper? getPlaylistForKey(SmartPlaylistKey? key) => key == null ? null : smartPlaylistsMap.value[key];

  late final _dBManager = DBWrapper.openFromInfo(
    fileInfo: AppPaths.SMART_PLAYLISTS,
    config: const DBConfig(createIfNotExist: true),
  );

  Future<void> reloadFromStorage() async {
    await _dBManager.close();
    smartPlaylistsMap.value.clear();
    await prepareAll();
  }

  Future<void> prepareAll() async {
    final res = await _dBManager.loadEverythingKeyedResult();
    final orderRow = res.remove(_orderRowKey);
    final orderedKeys = orderRow?['keys'] as List?;
    _orderModifiedDate = orderRow?['_mt'] as int? ?? 0;
    final map = smartPlaylistsMap.value;
    for (final entry in res.entries) {
      try {
        final config = SmartPlaylist.fromMap(entry.value);
        map[entry.key] ??= SmartPlaylistWrapper(config);
      } catch (_) {}
    }

    smartPlaylistsList.value.clear();
    final isOrderRowValid = orderedKeys != null && _applyOrder(orderedKeys);
    _refresh();
    if (!isOrderRowValid && map.isNotEmpty) await _saveOrder();
  }

  /// returns false if [orderedKeys] didn't match the map exactly.
  bool _applyOrder(List orderedKeys) {
    final map = smartPlaylistsMap.value;
    final list = smartPlaylistsList.value..clear();
    final added = <SmartPlaylistWrapper>{};
    for (final key in orderedKeys) {
      final wrapper = map[key];
      if (wrapper != null && added.add(wrapper)) list.add(wrapper);
    }
    return list.length == map.length && list.length == orderedKeys.length;
  }

  void _ensureListValid() {
    final map = smartPlaylistsMap.value;
    final list = smartPlaylistsList.value;
    if (list.isEmpty) {
      list.addAll(map.values);
      return;
    }
    final seen = <SmartPlaylistWrapper>{};
    bool isValid = list.length == map.length;
    if (isValid) {
      for (final e in list) {
        if (!identical(map[e.value.key], e) || !seen.add(e)) {
          isValid = false;
          break;
        }
      }
    }
    if (isValid) return;
    seen.clear();
    list.retainWhere((e) => identical(map[e.value.key], e) && seen.add(e));
    for (final wrapper in map.values) {
      if (seen.add(wrapper)) list.add(wrapper);
    }
  }

  void _refresh() {
    _ensureListValid();
    smartPlaylistsMap.refresh();
    smartPlaylistsList.refresh();
  }

  void _add(SmartPlaylist smartPlaylist) {
    final wrapper = SmartPlaylistWrapper(smartPlaylist);
    smartPlaylistsMap.value[smartPlaylist.key] = wrapper;
    smartPlaylistsList.value.add(wrapper);
  }

  Map<String, dynamic> _buildOrderRow() => {
    'keys': smartPlaylistsList.value.map((e) => e.value.key).toFixedList(),
    if (_orderModifiedDate > 0) '_mt': _orderModifiedDate,
  };

  Future<void> _saveOrder() async {
    await _dBManager.put(_orderRowKey, _buildOrderRow());
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex == oldIndex) return;
    smartPlaylistsList.value.move(oldIndex, newIndex);
    smartPlaylistsList.refresh();
    _orderModifiedDate = currentTimeMS;
    _saveOrder();
  }

  Future<void> create(SmartPlaylist smartPlaylist) async {
    smartPlaylist = smartPlaylist.copyWith(modifiedDate: currentTimeMS);
    final key = smartPlaylist.key;
    final alreadyExisting = smartPlaylistsMap.value[key];
    if (alreadyExisting != null) {
      alreadyExisting.value = smartPlaylist;
    } else {
      await _deleteArtwork(key); // -- older versions left it on delete/rename
      _add(smartPlaylist);
    }
    await saveToStorage(key);
    if (alreadyExisting == null) await _saveOrder();
  }

  Future<void> edit(SmartPlaylist oldSmartPlaylist, SmartPlaylist smartPlaylist) async {
    final oldKey = oldSmartPlaylist.key;
    final newKey = smartPlaylist.key;
    final alreadyExisting = oldKey == newKey ? null : smartPlaylistsMap.value[oldKey];
    if (alreadyExisting == null) {
      await create(smartPlaylist);
      return;
    }
    await _renameArtwork(oldKey, newKey);
    smartPlaylistsMap.value.remove(oldKey);
    smartPlaylist = smartPlaylist.copyWith(modifiedDate: currentTimeMS);
    alreadyExisting.value = smartPlaylist;
    smartPlaylistsMap.value[newKey] = alreadyExisting;
    await _dBManager.delete(oldKey);
    await saveToStorage(newKey);
    await _saveOrder();
  }

  Future<void> _renameArtwork(SmartPlaylistKey oldKey, SmartPlaylistKey newKey) async {
    final artworkFile = getArtworkFileForKey(oldKey);
    final newArtworkFile = getArtworkFileForKey(newKey);
    try {
      await artworkFile.rename(newArtworkFile.path);
    } catch (_) {
      await _deleteArtwork(newKey); // -- none to move, older versions could leave one at the new name
      return;
    }
    ArtworkWidget.refreshImageFiles([artworkFile.path, newArtworkFile.path]);
  }

  Future<void> _deleteArtwork(SmartPlaylistKey key) async {
    final artworkFile = getArtworkFileForKey(key);
    final didDelete = await artworkFile.deleteIfExists();
    if (didDelete) ArtworkWidget.refreshImageFiles([artworkFile.path]);
  }

  /// pinning alone keeps the modified date, like playlists.
  Future<void> setPinned(SmartPlaylistKey key, {required bool isPinned}) async {
    final wrapper = smartPlaylistsMap.value[key];
    if (wrapper == null) return;
    final smartPlaylist = wrapper.value;
    if (smartPlaylist.isPinned == isPinned) return;
    wrapper.value = smartPlaylist.copyWith(isPinned: isPinned);
    await saveToStorage(key);
  }

  Future<void> delete(SmartPlaylistKey key) async {
    final removed = smartPlaylistsMap.value.remove(key);
    if (removed != null) smartPlaylistsList.value.remove(removed);
    _refresh();
    _popPageIfCurrent(key);
    await _dBManager.delete(key);
    await _deleteArtwork(key);
    if (removed != null) await _saveOrder();
  }

  void _popPageIfCurrent(SmartPlaylistKey key) {
    // -- we currently update playlist in real time
    // final lastPage = NamidaNavigator.inst.currentRoute;
    // if (lastPage?.route == RouteType.SUBPAGE_smartPlaylistTracks) {
    //   if (lastPage?.name == key) {
    //     NamidaNavigator.inst.popPage();
    //   }
    // }
  }

  Future<void> saveToStorage(SmartPlaylistKey key) async {
    final pl = smartPlaylistsMap.value[key];
    _refresh();
    await _dBManager.put(key, pl?.value.toMap());
  }

  Iterable<SmartPlaylist> buildSyncEntries() => smartPlaylistsMap.value.values.map((e) => e.value);

  Map<String, dynamic>? buildSyncOrder() => _orderModifiedDate > 0 ? _buildOrderRow() : null;

  /// [incomingWins] skips the newest wins check, ex: restoring a backup.
  Future<int> import(Iterable<SmartPlaylist> incomingPlaylists, {Map<String, dynamic>? order, bool incomingWins = false}) async {
    int importedCount = 0;
    bool orderChanged = false;
    for (final incoming in incomingPlaylists) {
      final key = incoming.key;
      if (key == _orderRowKey) continue;
      final local = smartPlaylistsMap.value[key];
      if (!incomingWins && local != null && local.value.modifiedDate >= incoming.modifiedDate) continue;
      if (local != null) {
        local.value = incoming;
      } else {
        _add(incoming);
        orderChanged = true;
      }
      importedCount++;
      await _dBManager.put(key, incoming.toMap());
    }
    final incomingOrderKeys = order?['keys'] as List?;
    final incomingOrderModifiedDate = order?['_mt'] as int? ?? 0;
    if (incomingOrderKeys != null && (incomingWins || incomingOrderModifiedDate > _orderModifiedDate)) {
      _orderModifiedDate = incomingOrderModifiedDate;
      _applyOrder(incomingOrderKeys);
      orderChanged = true;
    }
    if (importedCount > 0 || orderChanged) _refresh();
    if (orderChanged) await _saveOrder();
    return importedCount;
  }

  /// rows of a backup's smart playlists db, they win over ours.
  Future<void> importBackupDbRows(Map<String, Map<String, dynamic>> rows) {
    final order = rows.remove(_orderRowKey);
    final playlists = <SmartPlaylist>[];
    for (final row in rows.values) {
      try {
        playlists.add(SmartPlaylist.fromMap(row));
      } catch (_) {}
    }
    return import(playlists, order: order, incomingWins: true);
  }

  String? validatePlaylistName(String? value, {required SmartPlaylistKey? oldKey}) {
    value ??= '';

    if (value.isEmpty) {
      return lang.pleaseEnterAName;
    }

    if (value == oldKey) return null;

    final badCharacters = DownloadTaskFilename.badCharactersIn(value);
    if (badCharacters.isNotEmpty) return '${lang.nameContainsBadCharacter} $badCharacters';

    if (value == _orderRowKey || smartPlaylistsMap.value.containsKey(value)) {
      return lang.pleaseEnterADifferentName;
    }

    return null;
  }

  File getArtworkFileForPlaylist(SmartPlaylist smartPlaylist) => getArtworkFileForKey(smartPlaylist.key);

  File getArtworkFileForKey(SmartPlaylistKey key) => FileParts.join(AppDirs.SMART_PLAYLISTS_ARTWORKS, '$key.png');

  Future<bool> setArtworkForPlaylist(SmartPlaylist smartPlaylist, {required File? artworkFile, required Uint8List? artworkBytes}) async {
    final didSet = await _setArtworkForPlaylist(
      smartPlaylist,
      artworkFile: artworkFile,
      artworkBytes: artworkBytes,
    );
    return didSet;
  }

  /// passing both [artworkFile] and [artworkBytes] with `null` will delete any previously set artwork.
  Future<bool> _setArtworkForPlaylist(SmartPlaylist smartPlaylist, {required File? artworkFile, required Uint8List? artworkBytes}) async {
    try {
      final destinationFile = getArtworkFileForPlaylist(smartPlaylist);
      if (artworkFile != null) {
        await destinationFile.create(recursive: true);
        await artworkFile.copy(destinationFile.path);
      } else if (artworkBytes != null) {
        await destinationFile.create(recursive: true);
        await destinationFile.writeAsBytes(artworkBytes);
      } else {
        await destinationFile.delete();
      }
      ArtworkWidget.refreshImageFiles([destinationFile.path]);
      _refresh();
      return true;
    } catch (_) {}

    return false;
  }
}
