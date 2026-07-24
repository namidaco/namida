import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:opensubsonic_api/opensubsonic_api.dart';

import 'package:namida/controller/music_web_server/music_web_server_base.dart';

sealed class ServerAuthModel {
  final String username;
  const ServerAuthModel._(this.username);

  static ServerAuthModel createModel(String username, String password, String? share, String? subdir, bool legacyAuth, bool legacyAuthEncode) {
    if (legacyAuth) {
      if (legacyAuthEncode) {
        // -- encoding gives nothing extra, except avoid illegal chars in url
        return ServerAuthModel.encodedPassword(username, 'enc:${_hexEncode(password)}');
      } else {
        return ServerAuthModel.rawPassword(username, password);
      }
    }
    return ServerAuthModel.randomSalt(username, password);
  }

  static String _generateSalt([int length = 32]) {
    final buffer = Uint8List(length);
    final rng = Random.secure();
    for (var i = 0; i < length; i++) {
      buffer[i] = rng.nextInt(256);
    }
    const encoder = Base64Encoder();
    return encoder.convert(buffer);
  }

  static String _generateToken({required String password, String salt = ''}) {
    return md5.convert(utf8.encode('$password$salt')).toString();
  }

  static String _hexEncode(String input) {
    final buffer = StringBuffer();
    for (final c in input.codeUnits) {
      buffer.write(c.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  const factory ServerAuthModel.rawPassword(
    String username,
    String password,
  ) = _ServerAuthWithRawPassword;

  const factory ServerAuthModel.encodedPassword(
    String username,
    String encodedPassword,
  ) = _ServerAuthWithEncodedPassword;

  const factory ServerAuthModel.token(
    String username,
    String token,
    String salt,
  ) = _ServerAuthWithToken;

  factory ServerAuthModel.salt(
    String username,
    String password,
    String salt,
  ) {
    final token = _generateToken(
      password: password,
      salt: salt,
    );
    return ServerAuthModel.token(username, token, salt);
  }

  factory ServerAuthModel.randomSalt(String username, String password) {
    return ServerAuthModel.salt(username, password, _generateSalt());
  }

  Map<String, String> toUrlParams();
}

class _ServerAuthWithRawPassword extends ServerAuthModel {
  final String password;
  const _ServerAuthWithRawPassword(super.username, this.password) : super._();

  @override
  Map<String, String> toUrlParams() => {
    'u': username,
    'p': password,
  };
}

class _ServerAuthWithEncodedPassword extends ServerAuthModel {
  final String encodedPassword;

  const _ServerAuthWithEncodedPassword(super.username, this.encodedPassword) : super._();

  @override
  Map<String, String> toUrlParams() => {
    'u': username,
    'p': encodedPassword,
  };
}

class _ServerAuthWithToken extends ServerAuthModel {
  final String token;
  final String salt;

  const _ServerAuthWithToken(super.username, this.token, this.salt) : super._();

  @override
  Map<String, String> toUrlParams() => {
    'u': username,
    's': salt,
    't': token,
  };
}

extension ServerAuthModelExt on ServerAuthModel {
  SubsonicAuthModel toSubsonicAuthModel() {
    final authMap = toUrlParams();

    final token = authMap['t'];
    final username = authMap['u'] ?? '';
    final password = authMap['p'];

    return token != null
        ? SubsonicAuthModel.token(
            username,
            token,
            authMap['s'] as String, // new salt would result in auth error [40]
          )
        : SubsonicAuthModel.password(
            username,
            password!,
          );
  }

  WebDAVAuth toWebDAVAuthModel() {
    final authMap = toUrlParams();

    final username = authMap['u'] ?? '';
    final password = authMap['p'] ?? '';

    return WebDAVAuth(
      username: username,
      password: password,
    );
  }

  SMBAuth toSMBAuthModel() {
    final authMap = toUrlParams();

    final username = authMap['u'] ?? '';
    final password = authMap['p'] ?? '';

    return SMBAuth(
      username: username,
      password: password,
    );
  }

  JellyfinAuth toJellyfinAuthModel() {
    final authMap = toUrlParams();

    final username = authMap['u'] ?? '';
    final password = authMap['p'] ?? '';

    return JellyfinAuth(
      username: username,
      password: password,
    );
  }
}
