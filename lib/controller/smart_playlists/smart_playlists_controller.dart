import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';
import 'package:intl/intl.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:playlist_manager/class/favourite_playlist.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';

part 'filters/smart_playlists_date_time.dart';
part 'filters/smart_playlists_number.dart';
part 'filters/smart_playlists_text.dart';
part 'filters/smart_playlists_boolean.dart';
part 'smart_playlist.dart';

class SmartPlaylistsController {
  static final inst = SmartPlaylistsController._();
  SmartPlaylistsController._();

  final smartPlaylistsMap = <SmartPlaylistKey, SmartPlaylist>{}.obs;

  SmartPlaylist? getPlaylistForKey(SmartPlaylistKey? key) => key == null ? null : smartPlaylistsMap.value[key];

  late final _dBManager = DBWrapper.openFromInfo(
    fileInfo: AppPaths.SMART_PLAYLISTS,
    config: const DBConfig(createIfNotExist: true),
  );

  Future<void> prepareAll() async {
    final res = await _dBManager.loadEverythingKeyedResult();
    for (final entry in res.entries) {
      try {
        final config = SmartPlaylist.fromMap(entry.value);
        smartPlaylistsMap.value[entry.key] ??= config;
      } catch (_) {}
    }
    smartPlaylistsMap.refresh();
  }

  Future<void> create(SmartPlaylist smartPlaylist) async {
    final key = smartPlaylist.key;
    smartPlaylistsMap[key] = smartPlaylist;
    await saveToStorage(key);
  }

  Future<void> edit(SmartPlaylist oldSmartPlaylist, SmartPlaylist smartPlaylist) async {
    if (oldSmartPlaylist.key != smartPlaylist.key) await delete(oldSmartPlaylist.key);
    await create(smartPlaylist);
  }

  Future<void> delete(SmartPlaylistKey key) async {
    smartPlaylistsMap.remove(key);
    _popPageIfCurrent(key);
    await _dBManager.delete(key);
  }

  void _popPageIfCurrent(SmartPlaylistKey key) {
    final lastPage = NamidaNavigator.inst.currentRoute;
    if (lastPage?.route == RouteType.SUBPAGE_smartPlaylistTracks) {
      if (lastPage?.name == key) {
        NamidaNavigator.inst.popPage();
      }
    }
  }

  Future<void> saveToStorage(SmartPlaylistKey key) async {
    final pl = smartPlaylistsMap.value[key];
    smartPlaylistsMap.refresh();
    await _dBManager.put(key, pl?.toMap());
  }

  String? validatePlaylistName(String? value, {required SmartPlaylistKey? oldKey}) {
    value ??= '';

    if (value.isEmpty) {
      return lang.pleaseEnterAName;
    }

    if (value != oldKey && smartPlaylistsMap.value.containsKey(value)) {
      return lang.pleaseEnterADifferentName;
    }

    return null;
  }

  File getArtworkFileForPlaylist(SmartPlaylist smartPlaylist) => FileParts.join(AppDirs.SMART_PLAYLISTS_ARTWORKS, '${smartPlaylist.key}.png');

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
      imageCache.clear();
      imageCache.clearLiveImages();
      if (artworkFile != null) {
        await destinationFile.create(recursive: true);
        await artworkFile.copy(destinationFile.path);
      } else if (artworkBytes != null) {
        await destinationFile.create(recursive: true);
        await destinationFile.writeAsBytes(artworkBytes);
      } else {
        await destinationFile.delete();
      }
      smartPlaylistsMap.refresh();
      return true;
    } catch (_) {}

    return false;
  }
}
