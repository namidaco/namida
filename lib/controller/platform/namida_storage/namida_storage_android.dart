part of 'namida_storage.dart';

class _NamidaStorageAndroid extends NamidaStorage {
  _NamidaStorageAndroid._init() : super('/storage/emulated/0') {
    _channel = const MethodChannel('namida/storage');
  }

  late final MethodChannel _channel;

  @override
  Future<List<String>> getStorageDirectories() async {
    final res = await _channel.invokeMethod<List<Object?>?>('getStorageDirs');
    return res?.cast() ?? [];
  }

  @override
  Future<List<String>> getStorageDirectoriesAppData() async {
    final res = await _channel.invokeMethod<List<Object?>?>('getStorageDirsData');
    return res?.cast() ?? [];
  }

  @override
  Future<List<String>> getStorageDirectoriesAppCache() async {
    final res = await _channel.invokeMethod<List<Object?>?>('getStorageDirsCache');
    return res?.cast() ?? [];
  }

  @override
  Future<String?> getRealPath(String? contentUri) async {
    if (contentUri == null) return null;
    return await _channel.invokeMethod<String?>('getRealPath', {'contentUri': contentUri});
  }

  @override
  Future<List<String>> pickFiles({
    String? note,
    bool multiple = false,
    List<NamidaFileExtensionsWrapper>? allowedExtensions,
    String? memetype = NamidaStorageFileMemeType.any,
  }) async {
    try {
      List<String>? extensionsList;
      if (allowedExtensions != null) {
        extensionsList = <String>[];
        allowedExtensions.loop((item) => extensionsList!.addAll(item.extensions.toList()));
      }

      final res = await _channel.invokeListMethod<String?>('pickFile', {
        'note': note,
        'type': memetype,
        'multiple': multiple,
        'allowedExtensions': extensionsList,
      });

      final filesPaths = res?.cast<String>() ?? <String>[];

      if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
        for (int i = 0; i < filesPaths.length; i++) {
          var fp = filesPaths[i];
          if (!allowedExtensions.any((wrapper) => wrapper.isPathValid(fp))) {
            snackyy(title: lang.ERROR, message: "${lang.EXTENSION}: $allowedExtensions", isError: true);
            return [];
          }
        }
      }

      return filesPaths;
    } catch (e) {
      snackyy(title: lang.ERROR, message: e.toString(), isError: true);
      return [];
    }
  }

  @override
  Future<String?> pickDirectory({String? note}) async {
    try {
      final res = await _channel.invokeListMethod<String?>('pickDirectory', {'note': note});
      return res?.firstOrNull;
    } catch (e) {
      snackyy(title: lang.ERROR, message: e.toString(), isError: true);
    }
    return null;
  }
}
