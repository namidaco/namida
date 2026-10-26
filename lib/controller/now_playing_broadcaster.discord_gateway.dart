// by claude
part of 'now_playing_broadcaster.dart';

/// mobile has no local discord ipc, presence goes through a gateway session of an oauth token limited to presence.
class _DiscordGatewayTransport extends _DiscordPresenceTransport {
  _DiscordGatewayTransport() : super(supportsImageUrls: false);

  /// id of the `namida_icon_full` asset, changes if it gets re-uploaded.
  static const _kIconAssetId = '1560434531691929701';

  @override
  String get iconAsset => _kIconAssetId;

  static const _kGatewayUrl = 'wss://gateway.discord.gg/?v=10&encoding=json';
  static const _kAppName = 'Namida';
  static const _kIdleDisconnectDelay = Duration(minutes: 5);
  static const _kReconnectBaseDelaySeconds = 5;
  static const _kReconnectMaxShift = 6;

  static const _kOpDispatch = 0;
  static const _kOpHeartbeat = 1;
  static const _kOpIdentify = 2;
  static const _kOpPresenceUpdate = 3;
  static const _kOpReconnect = 7;
  static const _kOpInvalidSession = 9;
  static const _kOpHello = 10;
  static const _kOpHeartbeatAck = 11;

  static const _kCloseNormal = 1000;
  static const _kCloseHeartbeatNotAcked = 4000;
  static const _kCloseAuthenticationFailed = 4004;

  Map<String, dynamic>? _activity;
  WebSocket? _socket;
  bool _isConnecting = false;
  bool _isReady = false;
  int? _lastSequence;
  bool _didAckHeartbeat = true;
  int _reconnectAttempts = 0;
  Timer? _heartbeatTimer;
  Timer? _idleTimer;
  Timer? _reconnectTimer;

  @override
  void setActivity(Map<String, dynamic>? activity) {
    _activity = activity;
    _idleTimer?.cancel();
    if (_isReady) {
      _sendPresence();
    } else if (activity != null) {
      _connectIfNeeded();
    }
    if (activity == null && _socket != null) _idleTimer = Timer(_kIdleDisconnectDelay, _disconnect);
  }

  /// the gateway only connects while playing, the account comes from the saved login.
  @override
  void probe() => _DiscordOAuth.inst.publishAccount();

  @override
  void close() {
    _activity = null;
    _disconnect();
  }

  void _connectIfNeeded() {
    if (_socket != null || _isConnecting) return;
    _reconnectTimer?.cancel();
    _isConnecting = true;
    final status = _DiscordPresenceReport.inst.status;
    final isRetryingAfterFailure = status.value == DiscordPresenceStatus.unreachable;
    if (!isRetryingAfterFailure) status.value = DiscordPresenceStatus.connecting;
    _connect().whenComplete(() => _isConnecting = false);
  }

  Future<void> _connect() async {
    try {
      final token = await _DiscordOAuth.inst.getAccessToken();
      if (token == null) {
        _DiscordPresenceReport.inst.status.value = DiscordPresenceStatus.idle;
        return;
      }
      final socket = await WebSocket.connect(_kGatewayUrl);
      _onConnected(socket, token);
    } catch (e, st) {
      logger.error('discord gateway connect failed', e: e, st: st);
      _DiscordPresenceReport.inst.status.value = DiscordPresenceStatus.unreachable;
      _scheduleReconnect();
    }
  }

  void _onConnected(WebSocket socket, String token) {
    if (_activity == null) {
      socket.close(_kCloseNormal);
      _DiscordPresenceReport.inst.status.value = DiscordPresenceStatus.idle;
      return;
    }
    _socket = socket;
    socket.listen(
      (data) => _onMessage(socket, data, token),
      onError: _ignoreSocketError,
      onDone: () => _onClosed(socket),
    );
  }

  static void _ignoreSocketError(Object _) {}

  void _onMessage(WebSocket socket, dynamic data, String token) {
    if (_socket != socket) return;
    final message = jsonDecode(data as String) as Map<String, dynamic>;
    final sequence = message['s'] as int?;
    if (sequence != null) _lastSequence = sequence;
    switch (message['op']) {
      case _kOpHello:
        final hello = message['d'] as Map<String, dynamic>;
        _startHeartbeat(hello['heartbeat_interval'] as int);
        _identify(token);
      case _kOpDispatch:
        if (message['t'] == 'READY') _onReady(message['d'] as Map<String, dynamic>);
      case _kOpHeartbeat:
        _sendHeartbeat();
      case _kOpHeartbeatAck:
        _didAckHeartbeat = true;
      case _kOpReconnect || _kOpInvalidSession:
        _socket?.close(_kCloseNormal);
    }
  }

  void _startHeartbeat(int intervalMS) {
    _heartbeatTimer?.cancel();
    _didAckHeartbeat = true;
    _heartbeatTimer = Timer.periodic(Duration(milliseconds: intervalMS), (_) => _beat());
  }

  void _beat() {
    if (!_didAckHeartbeat) {
      _socket?.close(_kCloseHeartbeatNotAcked);
      return;
    }
    _didAckHeartbeat = false;
    _sendHeartbeat();
  }

  void _sendHeartbeat() => _send(_kOpHeartbeat, _lastSequence);

  void _identify(String token) {
    _send(_kOpIdentify, {
      'token': 'Bearer $token',
      'intents': 0,
      'properties': {'os': Platform.operatingSystem, 'browser': _kAppName, 'device': _kAppName},
    });
  }

  void _onReady(Map<String, dynamic> ready) {
    _isReady = true;
    _reconnectAttempts = 0;
    _DiscordPresenceReport.inst.status.value = DiscordPresenceStatus.connected;
    final user = ready['user'] as Map<String, dynamic>?;
    if (user != null) _DiscordOAuth.inst.updateAccount(DiscordAccount.fromUserJson(user));
    _sendPresence();
  }

  void _sendPresence() {
    final activity = _activity;
    _send(_kOpPresenceUpdate, {
      'since': null,
      'activities': [
        if (activity != null) {'name': _kAppName, 'application_id': _DiscordPresenceSink._kApplicationId, ...activity},
      ],
      'status': 'online',
      'afk': false,
    });
    _DiscordPresenceReport.inst.isSharing.value = activity != null;
  }

  void _send(int op, Object? data) {
    final message = jsonEncode({'op': op, 'd': data});
    _socket?.add(message);
  }

  void _onClosed(WebSocket socket) {
    if (_socket != socket) return;
    _resetConnection();
    if (socket.closeCode == _kCloseAuthenticationFailed) _DiscordOAuth.inst.markAccessTokenRejected();
    if (_activity != null) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final shift = _reconnectAttempts.withMaximum(_kReconnectMaxShift);
    final delaySeconds = _kReconnectBaseDelaySeconds << shift;
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), _reconnect);
  }

  void _reconnect() {
    if (_activity != null) _connectIfNeeded();
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    final socket = _socket;
    _resetConnection();
    socket?.close(_kCloseNormal);
  }

  void _resetConnection() {
    _heartbeatTimer?.cancel();
    _idleTimer?.cancel();
    _socket = null;
    _isReady = false;
    _lastSequence = null;
    final report = _DiscordPresenceReport.inst;
    report.status.value = DiscordPresenceStatus.idle;
    report.isSharing.value = false;
  }
}

/// pkce on a public client, so no secret ships with the app. the login lives in its own file, out of settings, backups and sync.
class _DiscordOAuth {
  static final inst = _DiscordOAuth._();

  _DiscordOAuth._();

  static const _kRedirectUri = 'app://discordauth.msob7y.namida/callback';
  static const _kScope = 'sdk.social_layer_presence';
  static const _kTokenUrl = 'https://discord.com/api/v10/oauth2/token';
  static const _kRevokeUrl = 'https://discord.com/api/v10/oauth2/token/revoke';
  static const _kCurrentUserUrl = 'https://discord.com/api/v10/users/@me';
  static const _kLoginTimeout = Duration(minutes: 5);
  static const _kExpiryMarginMS = 60 * 1000;

  _DiscordLogInAttempt? _ongoingLogIn;
  _DiscordLogin? _login;
  bool _didLoadLogin = false;
  bool _isAccessTokenRejected = false;

  /// a page left open from an older attempt is ignored, its code belongs to another verifier.
  bool handleRedirect(String link) {
    if (!link.startsWith(_kRedirectUri)) return false;
    final uri = Uri.tryParse(link);
    final attempt = _ongoingLogIn;
    if (uri == null || attempt == null) return true;
    final isAttemptRedirect = uri.queryParameters['state'] == attempt.state;
    if (isAttemptRedirect) attempt.redirect.completeIfWasnt(uri);
    return true;
  }

  Future<bool> hasLogin() async {
    final login = await _loadLogin();
    return login != null;
  }

  /// false when the user cancelled or denied, throws on real failures.
  /// a call while another one waits opens the same page again and shares its result.
  Future<bool> logIn() async {
    final ongoing = _ongoingLogIn;
    if (ongoing != null) {
      await NamidaLinkUtils.openLink(ongoing.authorizeUri.toString());
      return ongoing.result;
    }

    final verifier = _generateUrlSafeRandom(64);
    final verifierBytes = utf8.encode(verifier);
    final challengeDigest = sha256.convert(verifierBytes);
    final challenge = _toUnpaddedBase64Url(challengeDigest.bytes);
    final state = _generateUrlSafeRandom(16);
    final authorizeUri = Uri.https('discord.com', '/oauth2/authorize', {
      'client_id': _DiscordPresenceSink._kApplicationId,
      'response_type': 'code',
      'redirect_uri': _kRedirectUri,
      'scope': _kScope,
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });

    final redirect = Completer<Uri?>();
    final result = _completeLogIn(authorizeUri, redirect, verifier);
    _ongoingLogIn = _DiscordLogInAttempt(authorizeUri, state, redirect, result);
    try {
      return await result;
    } finally {
      _ongoingLogIn = null;
    }
  }

  Future<bool> _completeLogIn(Uri authorizeUri, Completer<Uri?> redirect, String verifier) async {
    final didOpen = await NamidaLinkUtils.openLink(authorizeUri.toString());
    if (!didOpen) throw Exception('could not open $authorizeUri');
    final redirectUri = await redirect.future.timeout(_kLoginTimeout, onTimeout: () => null);
    if (redirectUri == null) return false;

    final code = redirectUri.queryParameters['code'];
    if (code == null) return false;
    final tokensJson = await _requestTokens({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': _kRedirectUri,
      'code_verifier': verifier,
    });
    if (tokensJson == null) throw Exception('discord rejected the login');
    final accessToken = tokensJson['access_token'] as String;
    final account = await _fetchAccount(accessToken).ignoreError();
    final login = _DiscordLogin.fromTokenResponse(tokensJson, account);
    await _saveLogin(login);
    _DiscordPresenceReport.inst.account.value = account;
    return true;
  }

  Future<void> logOut() async {
    final login = await _loadLogin();
    await _clearLogin();
    if (login == null) return;
    await _request('POST', _kRevokeUrl, form: {'token': login.refreshToken, 'token_type_hint': 'refresh_token'});
  }

  Future<void> publishAccount() async {
    final login = await _loadLogin();
    _DiscordPresenceReport.inst.account.value = login?.account;
  }

  Future<void> updateAccount(DiscordAccount account) async {
    _DiscordPresenceReport.inst.account.value = account;
    final login = await _loadLogin();
    if (login == null || login.account == account) return;
    await _saveLogin(login.withAccount(account));
  }

  void markAccessTokenRejected() => _isAccessTokenRejected = true;

  /// null when logged out, throws when discord can't be reached for a refresh.
  Future<String?> getAccessToken() async {
    final login = await _loadLogin();
    if (login == null) return null;
    final nowMS = DateTime.now().millisecondsSinceEpoch;
    final isExpired = nowMS > login.expiresAtMS - _kExpiryMarginMS;
    if (!isExpired && !_isAccessTokenRejected) return login.accessToken;

    final tokensJson = await _requestTokens({'grant_type': 'refresh_token', 'refresh_token': login.refreshToken});
    if (tokensJson == null) {
      await _clearLogin();
      settings.discordPresence.save(false);
      return null;
    }
    final refreshed = _DiscordLogin.fromTokenResponse(tokensJson, login.account);
    await _saveLogin(refreshed);
    return refreshed.accessToken;
  }

  Future<_DiscordLogin?> _loadLogin() async {
    if (_didLoadLogin) return _login;
    _didLoadLogin = true;
    final json = await File(AppPaths.DISCORD_AUTH).readAsJson();
    if (json is Map<String, dynamic>) _login = _DiscordLogin.fromJson(json);
    return _login;
  }

  Future<void> _saveLogin(_DiscordLogin login) async {
    _login = login;
    _didLoadLogin = true;
    _isAccessTokenRejected = false;
    await File(AppPaths.DISCORD_AUTH).writeAsJson(login.toJson());
  }

  Future<void> _clearLogin() async {
    _login = null;
    _didLoadLogin = true;
    _DiscordPresenceReport.inst.account.value = null;
    await File(AppPaths.DISCORD_AUTH).tryDeleting();
  }

  /// null when discord rejected the grant.
  Future<Map<String, dynamic>?> _requestTokens(Map<String, String> grant) async {
    final response = await _request('POST', _kTokenUrl, form: grant);
    final statusCode = response.statusCode;
    final isGrantRejected = statusCode == HttpStatus.badRequest || statusCode == HttpStatus.unauthorized;
    if (isGrantRejected) {
      logger.error('discord oauth rejected', e: response.body);
      return null;
    }
    if (statusCode != HttpStatus.ok) throw HttpException('discord oauth $statusCode: ${response.body}');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<DiscordAccount> _fetchAccount(String accessToken) async {
    final response = await _request('GET', _kCurrentUserUrl, accessToken: accessToken);
    final statusCode = response.statusCode;
    if (statusCode != HttpStatus.ok) throw HttpException('discord user $statusCode: ${response.body}');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return DiscordAccount.fromUserJson(json);
  }

  static Future<({int statusCode, String body})> _request(String method, String url, {Map<String, String>? form, String? accessToken}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.parse(url);
      final request = await client.openUrl(method, uri);
      if (accessToken != null) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      if (form != null) {
        request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
        final formWithClient = {'client_id': _DiscordPresenceSink._kApplicationId, ...form};
        final body = Uri(queryParameters: formWithClient).query;
        request.write(body);
      }
      final response = await request.close().timeout(const Duration(seconds: 15));
      final responseChunks = response.transform(utf8.decoder);
      final responseBody = await responseChunks.join();
      return (statusCode: response.statusCode, body: responseBody);
    } finally {
      client.close(force: true);
    }
  }

  static String _generateUrlSafeRandom(int bytesCount) {
    final random = Random.secure();
    final bytes = Uint8List(bytesCount);
    for (int i = 0; i < bytesCount; i++) {
      bytes[i] = random.nextInt(256);
    }
    return _toUnpaddedBase64Url(bytes);
  }

  static String _toUnpaddedBase64Url(List<int> bytes) {
    final encoded = base64Url.encode(bytes);
    return encoded.replaceAll('=', '');
  }
}

class _DiscordLogin {
  final String accessToken;
  final String refreshToken;
  final int expiresAtMS;
  final DiscordAccount? account;

  const _DiscordLogin(this.accessToken, this.refreshToken, this.expiresAtMS, this.account);

  factory _DiscordLogin.fromTokenResponse(Map<String, dynamic> json, DiscordAccount? account) {
    final expiresInSeconds = json['expires_in'] as int;
    final expiresAtMS = DateTime.now().millisecondsSinceEpoch + expiresInSeconds * 1000;
    return _DiscordLogin(json['access_token'] as String, json['refresh_token'] as String, expiresAtMS, account);
  }

  factory _DiscordLogin.fromJson(Map<String, dynamic> json) {
    final accountJson = json['account'] as Map<String, dynamic>?;
    final account = accountJson == null ? null : DiscordAccount.fromJson(accountJson);
    return _DiscordLogin(json['accessToken'] as String, json['refreshToken'] as String, json['expiresAtMS'] as int, account);
  }

  _DiscordLogin withAccount(DiscordAccount account) => _DiscordLogin(accessToken, refreshToken, expiresAtMS, account);

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAtMS': expiresAtMS,
    'account': ?account?.toJson(),
  };
}

class _DiscordLogInAttempt {
  final Uri authorizeUri;
  final String state;
  final Completer<Uri?> redirect;
  final Future<bool> result;

  const _DiscordLogInAttempt(this.authorizeUri, this.state, this.redirect, this.result);
}
