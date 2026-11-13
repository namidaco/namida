// by claude
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/class/sort_chain.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/translations/language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final controller = SmartPlaylistsController.inst;
  final artworkBytes = Uint8List.fromList(List.filled(16, 7));
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_smart_playlist_artwork');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
    Directory(AppDirs.SMART_PLAYLISTS_ARTWORKS).createSync(recursive: true);
    Language.inst.update(language: NamidaLanguage.fromCode('en'));
  });

  SmartPlaylist newSmartPlaylist(String name) => SmartPlaylist(
    name: name,
    creationDate: DateTime(2026),
    joiner: SmartJoiner.and,
    sorting: const SortChain([]),
    moods: [],
    ruleGroups: [],
    limit: null,
  );

  File artworkOf(String name) => controller.getArtworkFileForPlaylist(newSmartPlaylist(name));

  Future<SmartPlaylist> createWithArtwork(String name) async {
    final smartPlaylist = newSmartPlaylist(name);
    await controller.create(smartPlaylist);
    final didSet = await controller.setArtworkForPlaylist(smartPlaylist, artworkFile: null, artworkBytes: artworkBytes);
    expect(didSet, isTrue);
    expect(artworkOf(name).readAsBytesSync(), artworkBytes);
    return smartPlaylist;
  }

  test('renaming moves the artwork', () async {
    final smartPlaylist = await createWithArtwork('rename a');
    await controller.edit(smartPlaylist, smartPlaylist.copyWith(name: 'rename b'));
    expect(controller.getPlaylistForKey('rename a'), isNull);
    expect(controller.getPlaylistForKey('rename b'), isNotNull);
    expect(artworkOf('rename a').existsSync(), isFalse);
    expect(artworkOf('rename b').readAsBytesSync(), artworkBytes);
  });

  test('editing without a rename keeps the artwork', () async {
    final smartPlaylist = await createWithArtwork('same');
    await controller.edit(smartPlaylist, smartPlaylist.copyWith(moods: ['x']));
    expect(controller.getPlaylistForKey('same')!.value.moods, ['x']);
    expect(artworkOf('same').readAsBytesSync(), artworkBytes);
  });

  test('deleting removes the artwork, a new one with the same name has none', () async {
    final smartPlaylist = await createWithArtwork('deleted');
    await controller.delete(smartPlaylist.key);
    expect(artworkOf('deleted').existsSync(), isFalse);

    await controller.create(newSmartPlaylist('deleted'));
    expect(artworkOf('deleted').existsSync(), isFalse);
  });

  test('artworks left by older versions never show on a new or renamed playlist', () async {
    artworkOf('stale new').writeAsBytesSync(artworkBytes);
    await controller.create(newSmartPlaylist('stale new'));
    expect(artworkOf('stale new').existsSync(), isFalse);

    final smartPlaylist = newSmartPlaylist('no artwork');
    await controller.create(smartPlaylist);
    artworkOf('stale renamed').writeAsBytesSync(artworkBytes);
    await controller.edit(smartPlaylist, smartPlaylist.copyWith(name: 'stale renamed'));
    expect(artworkOf('stale renamed').existsSync(), isFalse);
  });

  test('names with characters normal playlists reject are rejected, unless unchanged', () async {
    await controller.create(newSmartPlaylist('taken'));
    expect(controller.validatePlaylistName('', oldKey: null), lang.pleaseEnterAName);
    expect(controller.validatePlaylistName('taken', oldKey: null), lang.pleaseEnterADifferentName);
    expect(controller.validatePlaylistName('taken', oldKey: 'taken'), isNull);
    expect(controller.validatePlaylistName('fine name', oldKey: null), isNull);
    for (final name in ['a/b', r'a\b', 'a:b', 'a?b', 'a*b']) {
      expect(controller.validatePlaylistName(name, oldKey: null), startsWith(lang.nameContainsBadCharacter), reason: name);
      expect(controller.validatePlaylistName(name, oldKey: name), isNull, reason: name);
    }
  });
}
