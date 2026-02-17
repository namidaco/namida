import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';

final class DirectoryIndexLocal extends DirectoryIndex {
  const DirectoryIndexLocal(
    String path,
  ) : super(DirectoryIndexType.local, source: path, username: null);

  @override
  bool existsSync() {
    return Directory(source).existsSync();
  }

  @override
  Future<bool> exists() {
    return Directory(source).exists();
  }

  @override
  bool hasNoMedia() => FileParts.join(source, ".nomedia").existsSync();

  @override
  List<FileSystemEntity> listSyncSafe({bool recursive = false, bool followLinks = true}) {
    return Directory(source).listSyncSafe(recursive: recursive, followLinks: followLinks);
  }

  @override
  Stream<FileSystemEntity>? list({bool recursive = false, bool followLinks = true}) {
    return Directory(source).list(recursive: recursive, followLinks: followLinks);
  }

  @override
  String toSourceInfo() {
    return source;
  }
}

final class DirectoryIndexServer extends DirectoryIndex {
  const DirectoryIndexServer.raw(
    String url,
    super.type,
    String username,
  ) : super(source: url, username: username);

  factory DirectoryIndexServer.fromHost(
    String host,
    String? share,
    String? subdir,
    DirectoryIndexType type,
    String username,
    String? port,
  ) {
    final uri = Uri(
      scheme: 'http',
      host: host,
      queryParameters: {
        '_share': ?share,
        '_subdir': ?subdir,
        if (port != null && port.isNotEmpty) '_p': port,
      },
    );

    return DirectoryIndexServer.raw(uri.toString(), type, username);
  }

  factory DirectoryIndexServer.parseFromEncodedUrlPath(String path, {Uri? uri, void Function(String? id)? parseIdCallback}) {
    uri ??= Uri.parse(path);
    final username = uri.queryParameters['namida_u'];
    final type = DirectoryIndexType.values.getEnum(uri.queryParameters['namida_t']);
    // -- only remove specific params. there can be other useful like share and port, etc.
    final cleanParams = Map<String, String>.from(uri.queryParameters)
      ..remove('namida_u')
      ..remove('namida_t')
      ..remove('d');
    final uriClean = uri.replace(queryParameters: cleanParams.isEmpty ? null : cleanParams);

    String uriCleanText = uriClean.toString();
    if (uriCleanText.endsWith('?')) uriCleanText = uriCleanText.substring(0, uriCleanText.length - 1);

    if (parseIdCallback != null) {
      final id = uri.queryParameters['d'];
      parseIdCallback(id);
    }

    return DirectoryIndexServer.raw(uriCleanText, type ?? DirectoryIndexType.unknown, username ?? '');
  }

  @override
  bool existsSync() => true;

  @override
  Future<bool> exists() async => true;

  @override
  bool hasNoMedia() => false;

  @override
  List<FileSystemEntity> listSyncSafe({bool recursive = false, bool followLinks = true}) => []; // the files would be treated as physical, so no

  @override
  Stream<FileSystemEntity>? list({bool recursive = false, bool followLinks = true}) {
    return null;
  }

  @override
  String toSourceInfo() {
    if (type.check(DirectoryIndexTypeTag.isURLHost)) {
      final uri = Uri.parse(source);
      final port = uri.queryParameters['_p'];

      final sourceInfo = [
        [
          uri.host,
          if (port != null && port.isNotEmpty) port,
        ].join(':'),
        ...uri.pathSegments,
        ...uri.queryParameters.values.where((element) => element != port), // share and subdir
      ].where((s) => s.isNotEmpty).join('/');
      return sourceInfo;
    }
    return source;
  }
}

sealed class DirectoryIndex {
  String get sourceRaw => source;

  @protected
  final String source;
  final DirectoryIndexType type;
  final String? username;

  const DirectoryIndex(
    this.type, {
    required this.source,
    required this.username,
  });

  String toSourceInfo();

  bool get isServer => this is DirectoryIndexServer;

  factory DirectoryIndex.guess(String source, DirectoryIndexType? type) {
    if (source.startsWith('http')) {
      return DirectoryIndexServer.raw(source, type ?? DirectoryIndexType.unknown, '');
    }
    return DirectoryIndexLocal(source);
  }

  bool existsSync();
  Future<bool> exists();
  bool hasNoMedia();
  List<FileSystemEntity> listSyncSafe({bool recursive = false, bool followLinks = true});
  Stream<FileSystemEntity>? list({bool recursive = false, bool followLinks = true});

  MusicWebServer? toWebServer() => MusicWebServer.getServerForDir(this);

  String toDbKey() {
    switch (this) {
      case DirectoryIndexLocal():
        return source;
      case DirectoryIndexServer():
        final uri = Uri.parse(source);
        final newUri = uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            'namida_t': type.name,
            'namida_u': username,
          },
        );
        return newUri.toString();
    }
  }

  factory DirectoryIndex.fromMap(dynamic value) {
    String source;
    if (value is Map) {
      final type = DirectoryIndexType.values.getEnum(value['type'] as String?);
      source = value['source'] as String;
      final username = value['u'] as String? ?? '';
      if (type != null && type != DirectoryIndexType.local) return DirectoryIndexServer.raw(source, type, username);
    } else if (value is String) {
      // -- backward compatibility
      source = value;
    } else {
      source = '';
    }
    return DirectoryIndexLocal(source);
  }

  @override
  String toString() => source;

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      if (type != DirectoryIndexType.local) 'type': type.name,
      if (username?.isNotEmpty == true) 'u': username,
    };
  }

  @override
  bool operator ==(covariant DirectoryIndex other) {
    if (identical(this, other)) return true;
    return source == other.source && type == other.type && username == other.username;
  }

  @override
  int get hashCode => source.hashCode ^ type.hashCode ^ username.hashCode;
}

enum DirectoryIndexTypeTag {
  server,
  legacyAuthOnly,
  legacyAuthEncrypt,
  isURLHost,
  supportsShare,
  supportsSubdir,
  supportsPort,
  isFileBased,
}

enum DirectoryIndexType {
  local({}),
  subsonic({
    DirectoryIndexTypeTag.server,
    DirectoryIndexTypeTag.legacyAuthEncrypt,
  }),
  webdav({
    DirectoryIndexTypeTag.server,
    DirectoryIndexTypeTag.legacyAuthOnly,
    DirectoryIndexTypeTag.isFileBased,
  }),
  smb({
    DirectoryIndexTypeTag.server,
    DirectoryIndexTypeTag.legacyAuthOnly,
    DirectoryIndexTypeTag.isURLHost,
    DirectoryIndexTypeTag.supportsShare,
    DirectoryIndexTypeTag.supportsSubdir,
    DirectoryIndexTypeTag.supportsPort,
    DirectoryIndexTypeTag.isFileBased,
  }),
  unknown({}),
  ;

  final Set<DirectoryIndexTypeTag> tags;
  const DirectoryIndexType(this.tags);

  bool check(DirectoryIndexTypeTag tag) {
    return tags.contains(tag);
  }

  bool checkAny(List<DirectoryIndexTypeTag> tags) {
    return tags.any((t) => this.tags.contains(t));
  }

  String toText() {
    return switch (this) {
      DirectoryIndexType.local => lang.LOCAL,
      DirectoryIndexType.subsonic => '(Open) Subsonic',
      DirectoryIndexType.webdav => 'WebDAV',
      DirectoryIndexType.smb => 'Samba (SMB v2/v3)',
      DirectoryIndexType.unknown => lang.NONE,
    };
  }

  String? toSubtitle() {
    return switch (this) {
      DirectoryIndexType.local => lang.PICK_FROM_STORAGE,
      DirectoryIndexType.subsonic => 'Navidrome, Airsonic, Gonic, etc...',
      DirectoryIndexType.webdav => null,
      DirectoryIndexType.smb => null,
      DirectoryIndexType.unknown => null,
    };
  }

  String? toAssetImage() {
    return switch (this) {
      DirectoryIndexType.local || DirectoryIndexType.unknown => null,
      DirectoryIndexType.subsonic => 'assets/icons/subsonic.png',
      DirectoryIndexType.webdav => null,
      DirectoryIndexType.smb => null,
    };
  }

  IconData toIcon() {
    return switch (this) {
      DirectoryIndexType.local || DirectoryIndexType.unknown => Broken.driver,
      DirectoryIndexType.subsonic => Broken.cloud,
      DirectoryIndexType.webdav => Broken.global,
      DirectoryIndexType.smb => Broken.folder_cloud,
    };
  }

  Color toColor(ThemeData theme) {
    return switch (this) {
      DirectoryIndexType.local || DirectoryIndexType.unknown => theme.colorScheme.primary,
      DirectoryIndexType.subsonic => const Color.fromARGB(255, 235, 211, 0),
      DirectoryIndexType.webdav => theme.colorScheme.primary,
      DirectoryIndexType.smb => theme.colorScheme.primary,
    };
  }

  MusicWebServerAuthDetailsDemo? toDemoInfo() {
    return switch (this) {
      DirectoryIndexType.local || DirectoryIndexType.unknown => null,
      DirectoryIndexType.subsonic => MusicWebServerAuthDetailsDemo(
        type: this,
        url: 'https://demo.navidrome.org',
        username: 'demo',
        password: 'demo',
      ),
      DirectoryIndexType.webdav => MusicWebServerAuthDetailsDemo(
        type: this,
        url: 'http://localhost:8080',
        username: '',
        password: '',
      ),
      DirectoryIndexType.smb => MusicWebServerAuthDetailsDemo(
        type: this,
        url: '192.168.1.100',
        username: '',
        password: '',
      ),
    };
  }
}
