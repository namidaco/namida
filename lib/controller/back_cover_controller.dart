// by claude
import 'dart:io';
import 'dart:typed_data';

import 'package:namida/class/taglib_res.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class BackCoverController {
  static final inst = BackCoverController._();
  BackCoverController._();

  static const _kBackCoverPictureType = 'Back Cover';
  static const _kFolderBackCoverNames = {
    'back', 'backcover', 'back_cover', 'back-cover', 'back cover', //
    'coverback', 'cover_back', 'cover-back', 'cover back', //
    'rear', 'rearcover', 'rear_cover', 'rear-cover', 'rear cover', //
  };

  RxBaseCore<BackCover?> get displayed => _displayed;
  final _displayed = Rxn<BackCover>();

  bool _isResolving = false;
  bool _isListeningToItemChanges = false;

  /// false when [track] has no back cover.
  Future<bool> toggle(Track track) async {
    if (_displayed.value?.track == track) {
      _displayed.value = null;
      return true;
    }
    if (_isResolving) return true;

    _isResolving = true;
    final backCover = await _resolve(track);
    _isResolving = false;
    if (backCover == null) return false;
    if (!Player.inst.isCurrentItem(track)) return true;

    if (!_isListeningToItemChanges) {
      _isListeningToItemChanges = true;
      Player.inst.currentItem.addListener(_onCurrentItemChanged);
    }
    _displayed.value = backCover;
    return true;
  }

  void _onCurrentItemChanged() {
    final backCover = _displayed.value;
    if (backCover == null) return;
    if (Player.inst.isCurrentItem(backCover.track)) return;
    _displayed.value = null;
  }

  static Future<BackCover?> _resolve(Track track) async {
    if (track.isNetwork) return null;
    final trackPath = track.path;
    final directoryPath = trackPath.getDirectoryPath;
    final embeddedFuture = _readEmbeddedSync.thready(trackPath);
    final folderFuture = _findInFolder(directoryPath);
    final (embeddedBytes, folderImagePath) = await (embeddedFuture, folderFuture).wait;
    if (embeddedBytes != null && embeddedBytes.isNotEmpty) return BackCover._(track: track, bytes: embeddedBytes, filePath: null);
    if (folderImagePath != null) return BackCover._(track: track, bytes: null, filePath: folderImagePath);
    return null;
  }

  static Uint8List? _readEmbeddedSync(String trackPath) {
    return TagLibRes.readPictureOfTypeSync(trackPath, _kBackCoverPictureType);
  }

  static Future<String?> _findInFolder(String directoryPath) async {
    try {
      await for (final entity in Directory(directoryPath).list()) {
        if (entity is! File) continue;
        final path = entity.path;
        if (!NamidaFileExtensionsWrapper.image.isPathValid(path)) continue;
        final filenameCleaned = path.getFilenameWOExt.toLowerCase();
        if (_kFolderBackCoverNames.contains(filenameCleaned)) return path;
      }
    } catch (_) {}
    return null;
  }
}

class BackCover {
  final Track track;
  final Uint8List? bytes;
  final String? filePath;

  const BackCover._({
    required this.track,
    required this.bytes,
    required this.filePath,
  });
}
