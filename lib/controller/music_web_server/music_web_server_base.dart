import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:dio/dio.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:opensubsonic_api/opensubsonic_api.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/file_parts.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/music_web_server/server_auth_model.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/indexer_settings.dart';

part 'subsonic_web_server.dart';
part 'webdav_server.dart';

abstract class MusicWebServer {
  final MusicWebServerAuthDetails authDetails;
  const MusicWebServer(this.authDetails);

  static MusicWebServer? getServerForDir(DirectoryIndex dir) {
    return _MusicWebServerAuthManager.getServerForDir(dir);
  }

  Future<MusicWebServerError?> ping();
  Future<void> fetchAllMusicAndProcess(void Function(TrackExtended trExt) callback);
  FutureOr<WebStreamUriDetails?> getStreamUrl(String id, {void Function(File cachedFile)? onFetchedIfLocal});
  Future<Uint8List?> getImage(String id);
  void dispose();

  Future<List<TrackExtended>> getAllMusic() async {
    final allTracks = <TrackExtended>[];
    await fetchAllMusicAndProcess(
      (trExt) {
        allTracks.add(trExt);
      },
    );
    return allTracks;
  }

  static FutureOr<WebStreamUriDetails?> baseUrlToActualUrl(
    String baseUrl, {
    Uri? uri,
    void Function(File cachedFile)? onFetchedIfLocal,
  }) {
    return _executeIfHasServer(
      baseUrl,
      (s, id) => s.getStreamUrl(id, onFetchedIfLocal: onFetchedIfLocal),
      () => WebStreamUriDetails.fromUri(Uri.file(baseUrl)),
      uri: uri,
    );
  }

  static Future<Uint8List?>? baseUrlToImage(String baseUrl) {
    return _executeIfHasServer(
      baseUrl,
      (s, id) => s.getImage(id),
      () => null,
    );
  }

  static DirectoryIndexType? baseUrlToType(String baseUrl) {
    final baseUri = Uri.parse(baseUrl);
    return DirectoryIndexType.values.getEnum(baseUri.queryParameters['namida_t']);
  }

  static String? baseUrlToId(String baseUrl) {
    final baseUri = Uri.parse(baseUrl);
    return baseUri.queryParameters['d'];
  }

  static T _executeIfHasServer<T>(String baseUrl, T Function(MusicWebServer s, String id) callback, T Function() fallback, {Uri? uri}) {
    String? id;
    final dir = DirectoryIndexServer.parseFromEncodedUrlPath(
      baseUrl,
      uri: uri,
      parseIdCallback: (parsedId) => id = parsedId,
    );
    final server = dir.toWebServer();
    if (server != null && id != null) {
      return callback(server, id!);
    }
    return fallback();
  }
}

class MusicWebServerError {
  final int code;
  final String message;

  const MusicWebServerError({
    required this.code,
    required this.message,
  });
}

class MediaUrlParseResult {
  final DirectoryIndexType type;
  final String username;
  final String? id;

  const MediaUrlParseResult({
    required this.type,
    required this.username,
    required this.id,
  });

  factory MediaUrlParseResult.parse(String url) {
    final uri = Uri.parse(url);
    return MediaUrlParseResult.parseFromUri(uri);
  }

  factory MediaUrlParseResult.parseFromUri(Uri uri) {
    final username = uri.queryParameters['namida_u'] ?? '';
    final type = DirectoryIndexType.values.getEnum(uri.queryParameters['namida_t']);
    final id = uri.queryParameters['d'];
    return MediaUrlParseResult(
      type: type ?? DirectoryIndexType.unknown,
      username: username,
      id: id,
    );
  }
}

class MusicWebServerAuthDetailsDemo {
  final DirectoryIndexType type;
  final String url;
  final String username;
  final String password;

  const MusicWebServerAuthDetailsDemo({
    required this.type,
    required this.url,
    required this.username,
    required this.password,
  });
}

class WebStreamUriDetails {
  final Uri uri;
  final Map<String, String>? headers;
  final bool allowStreamCaching;

  const WebStreamUriDetails({
    required this.uri,
    required this.headers,
    required this.allowStreamCaching,
  });

  static WebStreamUriDetails? fromUri(
    Uri? uri, {
    Map<String, String>? headers,
    bool allowStreamCaching = true,
  }) {
    if (uri == null) return null;
    return WebStreamUriDetails(
      uri: uri,
      headers: headers,
      allowStreamCaching: allowStreamCaching,
    );
  }
}

class MusicWebServerAuthDetails {
  static final manager = _MusicWebServerAuthManager();

  final DirectoryIndex dir;
  final ServerAuthModel auth;

  MusicWebServerAuthDetails.create({
    required this.dir,
    required String password,
    required bool legacyAuth,
  }) : auth = _createAuthModel(dir, password, legacyAuth);

  MusicWebServerAuthDetails._({
    required this.dir,
    required this.auth,
  });

  static ServerAuthModel _createAuthModel(DirectoryIndex dir, String password, bool legacyAuth) {
    return ServerAuthModel.createModel(
      dir.username ?? '',
      password,
      legacyAuth,
      dir.type.legacyAuthEncrypt,
    );
  }

  factory MusicWebServerAuthDetails.fromMap(Map<String, dynamic> map) {
    final authMap = map['auth'];
    final token = authMap['t'] as String?;
    final username = authMap['u'] as String? ?? '';
    final password = authMap['p'] as String?;

    return MusicWebServerAuthDetails._(
      dir: DirectoryIndex.fromMap(map['dir']),
      auth: token != null
          ? ServerAuthModel.token(
              username,
              token,
              authMap['s'], // new salt would result in auth error [40]
            )
          : (password?.startsWith('enc:') ?? false)
              ? ServerAuthModel.encryptedPassword(username, password!)
              : ServerAuthModel.rawPassword(username, password ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dir': dir.toMap(),
      'auth': auth.toUrlParams(),
    };
  }

  // ===========================

  Future<void> saveToDb(DirectoryIndexServer dir) => manager.saveToDb(dir, this);
}

class _MusicWebServerAuthManager {
  bool dirHasAuthInfoR(DirectoryIndexServer dir) => _authInfoRxMap[dir] != null;
  MusicWebServerAuthDetails? forDir(DirectoryIndexServer dir) => _authInfoRxMap.value[dir];
  RxBaseCore<bool> get hasMissingAuthRx => _hasMissingAuthRx;

  static final _hasMissingAuthRx = false.obs;
  static final _authInfoRxMap = <DirectoryIndexServer, MusicWebServerAuthDetails>{}.obs;
  static final _cachedServers = <DirectoryIndex, MusicWebServer?>{};
  late final _webServersDBManager = DBWrapper.open(
    AppDirs.LOGIN,
    'web_servers',
    config: const DBConfig(
      createIfNotExist: true,
      encryptionKey: 'servers',
    ),
  );

  static MusicWebServer? getServerForDir(DirectoryIndex dir) {
    if (_cachedServers.containsKey(dir)) {
      return _cachedServers[dir]; // even if null
    }
    return _cachedServers[dir] = _createServer(dir)?..ping();
  }

  static MusicWebServer? _createServer(DirectoryIndex dir) {
    final authDetails = _authInfoRxMap.value[dir];
    if (authDetails == null) return null;
    return switch (dir.type) {
      DirectoryIndexType.local || DirectoryIndexType.unknown => null,
      DirectoryIndexType.subsonic => _SubsonicWebServer.init(authDetails),
      DirectoryIndexType.webdav => _WebDAVServer.init(authDetails),
    };
  }

  Future<void> initialize(Iterable<DirectoryIndexServer> dirsActive) async {
    final res = await _webServersDBManager.loadEverythingKeyedResult();
    for (final d in dirsActive) {
      final key = d.toDbKey();
      final authMap = res[key];
      if (authMap != null) {
        try {
          final auth = MusicWebServerAuthDetails.fromMap(authMap);
          _authInfoRxMap.value[d] = auth;
        } catch (_) {
          _hasMissingAuthRx.value = true;
        }
      } else {
        _hasMissingAuthRx.value = true;
      }
    }
  }

  void _closeAndRemoveServer(DirectoryIndexServer dir) {
    _cachedServers[dir]?.dispose();
    _cachedServers.remove(dir);
  }

  Future<void> deleteFromDb(DirectoryIndexServer dir) async {
    _closeAndRemoveServer(dir);
    _authInfoRxMap.remove(dir);
    await _webServersDBManager.delete(dir.toDbKey());
    _reEvaluateHasMissingAuth();
  }

  Future<void> saveToDb(DirectoryIndexServer dir, MusicWebServerAuthDetails details) async {
    _authInfoRxMap[dir] = details;
    _closeAndRemoveServer(dir); // will be created when necessary
    await _webServersDBManager.put(dir.toDbKey(), details.toMap());
    _reEvaluateHasMissingAuth();
  }

  void _reEvaluateHasMissingAuth() {
    for (final d in settings.directoriesToScan.value) {
      if (d is DirectoryIndexServer) {
        if (_authInfoRxMap.value[d] == null) {
          _hasMissingAuthRx.value = true;
          return;
        }
      }
    }
    _hasMissingAuthRx.value = false;
  }

  void promptFillMissingAuthDialog() {
    final missingAuthDir = settings.directoriesToScan.value.whereType<DirectoryIndexServer>().where((d) => _authInfoRxMap.value[d] == null);
    final missingAuthDirText = missingAuthDir.toBodyText();
    final warningText = lang.SOME_WEB_SERVERS_REQUIRE_AUTHENTICATION;
    final bodyText = '$warningText\n\n$missingAuthDirText';

    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: bodyText,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.UPDATE.toUpperCase(),
            onPressed: () {
              NamidaNavigator.inst.closeDialog();
              SettingsSearchController.inst
                  .onResultTap(
                    settingPage: SettingSubpageEnum.indexer,
                    key: IndexerSettingsKeysGlobal.foldersToScan,
                    context: namida.context!,
                  )
                  .ignoreError();
            },
          ),
        ],
      ),
    );
  }
}
