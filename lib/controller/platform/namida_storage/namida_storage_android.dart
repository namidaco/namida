part of 'namida_storage.dart';

class _NamidaStorageAndroid extends NamidaStorage {
  _NamidaStorageAndroid._init() : super('/storage/emulated/0') {
    _channel = const MethodChannel('namida/storage');
  }

  late final MethodChannel _channel;

  @override
  String getUserDataDirectory(List<String> appDataDirectories) {
    return appDataDirectories.firstOrNull ?? '';
  }

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
    NamidaStorageFileMemeType? memetype = NamidaStorageFileMemeType.any,
    String? initialDirectory,
  }) async {
    try {
      List<String>? extensionsList;
      if (allowedExtensions != null) {
        extensionsList = <String>[];
        for (var item in allowedExtensions) {
          extensionsList.addAll(item.extensions);
        }
      }

      final res = await _channel.invokeListMethod<String?>('pickFile', {
        'note': note,
        'type': memetype?.type,
        'multiple': multiple,
        'allowedExtensions': extensionsList,
        'initialDirectory': initialDirectory,
      });

      final filesPaths = res?.cast<String>() ?? <String>[];

      if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
        for (final fp in filesPaths) {
          if (fp.isNotEmpty && !allowedExtensions.any((wrapper) => wrapper.isPathValid(fp))) {
            if (!fp.contains(':')) {
              // : means its content provider type file
              snackyy(title: lang.error, message: '"$fp"\n${lang.extension}: ${extensionsList?.join(', ')}', isError: true);
              return [];
            }
          }
        }
      }

      return filesPaths;
    } catch (e) {
      snackyy(title: lang.error, message: e.toString(), isError: true);
      return [];
    }
  }

  @override
  Future<String?> pickDirectory({String? note, String? initialDirectory}) async {
    try {
      final res = await _channel.invokeListMethod<String?>('pickDirectory', {
        'note': note,
        'initialDirectory': initialDirectory,
      });
      return res?.firstOrNull;
    } catch (e) {
      snackyy(title: lang.error, message: e.toString(), isError: true);
    }
    return null;
  }
}
