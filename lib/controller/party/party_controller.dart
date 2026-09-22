import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Colors;

import 'package:namico_subscription_manager/core/enum.dart';
import 'package:namico_subscription_manager/namico_subscription_manager.dart';
import 'package:namida_party_relay/namida_party_relay.dart' show PartyRelayServer, PartyRelayConfig;
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/party/party_connection.dart';
import 'package:namida/controller/party/party_host.dart';
import 'package:namida/controller/party/party_player_binder.dart';
import 'package:namida/controller/party/party_protocol.dart';
import 'package:namida/controller/party/party_state.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

class PartyJoinRequest {
  final String id;
  final String name;
  final String deviceId;
  const PartyJoinRequest(this.id, this.name, this.deviceId);
}

/// a room this device was in, kept so it can be rejoined or closed later.
class PartyRoomMemory {
  final String code;
  final Uri server;
  final String? token;
  final String name;
  final bool hosted;
  final int atMS;

  const PartyRoomMemory({
    required this.code,
    required this.server,
    required this.token,
    required this.name,
    required this.hosted,
    required this.atMS,
  });

  /// rooms die on their own after a day, a stale entry would only fail to reconnect.
  static const _maxAgeMS = 24 * 60 * 60 * 1000;

  bool get isStale => DateTime.now().millisecondsSinceEpoch - atMS > _maxAgeMS;

  static PartyRoomMemory? fromMap(Map<String, dynamic> map) {
    final code = map['c'];
    final server = Uri.tryParse(map['s'] as String? ?? '');
    if (code is! String || server == null || !server.hasScheme) return null;
    return PartyRoomMemory(
      code: code,
      server: server,
      token: map['t'] as String?,
      name: map['n'] as String? ?? '',
      hosted: map['h'] == true,
      atMS: map['at'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'c': code,
    's': server.toString(),
    't': ?token,
    'n': name,
    'h': hosted,
    'at': atMS,
  };
}

class PartyInvite {
  final Uri server;
  final String code;
  const PartyInvite(this.server, this.code);
}

class PartyController implements PartyConnectionListener, PartyHostDelegate, PartyBinderDelegate, PartyStateListener {
  static final inst = PartyController._();
  PartyController._();

  static final defaultServer = Uri.parse('https://party.namida.app');

  /// the relay the user last created a room on, [defaultServer] otherwise.
  static Uri get preferredServer {
    final stored = settings.party.serverUrl.value;
    if (stored == null || stored.isEmpty) return defaultServer;
    final uri = Uri.tryParse(stored);
    return uri != null && uri.hasScheme ? uri : defaultServer;
  }

  static const _inviteHost = 'namida.app';
  static const _invitePath = '/party';
  static const _inviteScheme = 'namida';
  static const _lanRelayPort = 62311;
  static const _inviteSchemeHost = 'party';

  /// an invite opened from outside the app, waiting for the party page to pick it up.
  final pendingInvite = Rxn<String>();

  /// true from the moment a room is being joined until it is left.
  final isActive = false.obs;
  final status = PartyConnectionStatus.closed.obs;
  final isListening = true.obs;

  /// the party queue holds both local & youtube items for this device.
  final forcesMixedQueue = false.obs;

  final syncState = PartySyncState.idle.obs;

  /// bumped on every reaction, the ui reads [lastReaction].
  final reactionTick = 0.obs;
  (int, String)? lastReaction;

  /// what played in the last party, in order. kept after leaving so it can be saved.
  List<PartyEntry> get playedHistory => _playedHistory;
  final _playedHistory = <PartyEntry>[];

  // -- bumped when the matching part of [state] changes
  final infoTick = 0.obs;
  final queueTick = 0.obs;
  final anchorTick = 0.obs;
  final membersTick = 0.obs;
  final chatTick = 0.obs;
  final requestsTick = 0.obs;

  PartyState get state => _state;
  Uri? get server => _server;
  String? get code => _code;
  int get myN => _myN;
  int get hostN => _hostN;
  bool get hostOnline => _hostOnline;
  int get maxMembers => _maxMembers;
  PartyRoomOpts? get opts => _opts;
  List<PartyBan> get bans => _bans;
  Iterable<PartyJoinRequest> get joinRequests => _joinRequests.values;
  PartyPlayerBinder? get binder => _binder;

  @override
  bool get isHost => _myN != 0 && _myN == _hostN;

  @override
  PartyMember? get me => _state.members[_myN];

  PartyState _state = PartyState();
  PartyConnection? _connection;
  PartyRelayServer? _lanRelay;

  /// what others use to reach the room, differs from [_server] when we host the relay ourselves.
  Uri? _inviteServer;

  bool get isLanParty => _lanRelay != null;
  PartyHost? _host;
  PartyPlayerBinder? _binder;

  Uri? _server;
  String? _code;
  String _pendingRoomName = '';
  bool _seedWithPlayerQueue = false;
  bool _pendingPublic = false;
  Timer? _summaryTimer;
  int _lastSummaryMS = 0;
  String? _sentSummaryName;
  String? _sentSummaryTitle;
  String? _sentSummaryArtist;
  int _myN = 0;
  int _hostN = 0;
  bool _hostOnline = false;
  int _maxMembers = 0;
  PartyRoomOpts? _opts;
  List<PartyBan> _bans = const [];
  bool _synced = false;
  final _relayMembers = <int, String>{};
  final _joinRequests = <String, PartyJoinRequest>{};
  int _lastDeniedNoticeMS = 0;

  // ------------------------------------------------------------ invites

  String? get inviteLink {
    final server = _inviteServer ?? _server;
    final code = _code;
    if (server == null || code == null) return null;
    return Uri(
      scheme: 'https',
      host: _inviteHost,
      path: _invitePath,
      queryParameters: {
        if (server != defaultServer) 's': server.toString(),
        'c': code,
      },
    ).toString();
  }

  /// ready to share, mentions what is playing when there is something.
  String? get inviteText {
    final link = inviteLink;
    if (link == null) return null;
    final entry = _state.currentEntry;
    if (entry == null || entry.title.isEmpty) return link;
    final track = entry.artist.isEmpty ? entry.title : '${entry.title} - ${entry.artist}';
    return '${lang.partyInviteTextListeningTo(name: track)}\n$link';
  }

  /// accepts an invite link or a bare room code.
  static PartyInvite? parseInvite(String text) {
    text = text.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri != null && ((uri.host == _inviteHost && uri.path == _invitePath) || (uri.scheme == _inviteScheme && uri.host == _inviteSchemeHost))) {
      final code = uri.queryParameters['c'];
      if (code == null || code.isEmpty) return null;
      final s = uri.queryParameters['s'];
      final server = s == null ? defaultServer : Uri.tryParse(s);
      if (server == null || !server.hasScheme) return null;
      return PartyInvite(server, code.toUpperCase());
    }
    final code = text.toUpperCase();
    if (RegExp(r'^[A-Z2-9]{8}$').hasMatch(code)) return PartyInvite(defaultServer, code);
    return null;
  }

  // ------------------------------------------------------------ remembered rooms

  static const _maxRecentRooms = 8;

  /// newest first, stale ones dropped.
  static List<PartyRoomMemory> recentRooms() {
    final rooms = <PartyRoomMemory>[];
    for (final map in settings.party.recentRooms) {
      final room = PartyRoomMemory.fromMap(map);
      if (room != null && !room.isStale) rooms.add(room);
    }
    return rooms;
  }

  static void _rememberRoom(PartyRoomMemory room) {
    final stored = settings.party.recentRooms;
    settings.party.modify((_) {
      stored.removeWhere((e) => e['c'] == room.code && e['s'] == room.server.toString());
      stored.insert(0, room.toMap());
      stored.removeWhere((e) {
        final stored = PartyRoomMemory.fromMap(e);
        return stored == null || stored.isStale;
      });
      if (stored.length > _maxRecentRooms) stored.removeRange(_maxRecentRooms, stored.length);
    });
  }

  static void forgetRoom(PartyRoomMemory room) {
    final stored = settings.party.recentRooms;
    settings.party.modify((_) => stored.removeWhere((e) => e['c'] == room.code && e['s'] == room.server.toString()));
  }

  Future<void> rejoin(PartyRoomMemory room, {required bool listening}) async {
    if (isActive.value) return;
    _seedWithPlayerQueue = false;
    await _connect(server: room.server, code: room.code, token: room.token, password: null, listening: listening);
  }

  /// closes a room we host from outside of it, used to free a slot when the rooms limit is hit.
  static Future<bool> closeRemoteRoom(PartyRoomMemory room) async {
    final token = room.token;
    if (token == null || !room.hosted) return false;
    final closed = await _RoomCloser(room, token).run();
    if (closed) forgetRoom(room);
    return closed;
  }

  // ------------------------------------------------------------ create / join / leave

  /// returns a relay error code on failure.
  Future<String?> createRoom({
    Uri? server,
    required String roomName,
    required bool listening,
    bool approval = false,
    bool isPublic = false,
    String? password,
    String? serverPassword,
    bool seedWithPlayerQueue = true,
  }) async {
    if (isActive.value) return 'already_in_party';
    server ??= defaultServer;
    final name = await SyncUtils.currentDeviceName;
    final deviceId = await SyncUtils.currentDeviceId;
    final Map<String, dynamic> response;
    try {
      response = await _postJson(server.resolve('/v1/rooms'), {
        'pv': kPartyVersion,
        'name': _displayName(name),
        'did': deviceId,
        'auth': serverPassword != null ? {'kind': 'password', 'password': serverPassword} : await _membershipProof(),
        'opts': {'approval': approval, 'password': password, 'public': isPublic},
      });
    } catch (e, st) {
      logger.error('party create failed', e: e, st: st);
      return 'unreachable';
    }
    final error = response['error'];
    if (error != null) return error.toString();
    final code = response['code'];
    final token = response['token'];
    if (code is! String || token is! String) return 'unreachable';

    final serverToRemember = server == defaultServer ? null : server.toString();
    if (settings.party.serverUrl.value != serverToRemember) {
      settings.party.modify((partySettings) => partySettings.serverUrl.value = serverToRemember);
    }

    _pendingRoomName = roomName.trim().isEmpty ? _displayName(name) : roomName.trim();
    _seedWithPlayerQueue = seedWithPlayerQueue;
    _pendingPublic = isPublic;
    await _connect(server: server, code: code, token: token, password: null, listening: listening);
    return null;
  }

  /// hosts the relay on this device, for parties over the local network (or a forwarded port).
  Future<String?> createLanRoom({
    required String roomName,
    required bool listening,
    bool approval = false,
    bool isPublic = false,
    String? password,
    bool seedWithPlayerQueue = true,
  }) async {
    if (isActive.value) return 'already_in_party';
    final name = await SyncUtils.currentDeviceName;
    final deviceId = await SyncUtils.currentDeviceId;
    final PartyRelayServer relay;
    try {
      relay = await PartyRelayServer.start(
        port: _lanRelayPort,
        config: const PartyRelayConfig(maxRoomsTotal: 1),
      ).catchError((_) => PartyRelayServer.start(config: const PartyRelayConfig(maxRoomsTotal: 1)));
    } catch (e, st) {
      logger.error('party lan relay failed to start', e: e, st: st);
      return 'unreachable';
    }
    final created = relay.createRoom(name: _displayName(name), did: deviceId, pv: kPartyVersion, approval: approval, password: password, public: isPublic);
    final lanAddress = (await SyncUtils.getPreferredInterface())?.addresses.firstOrNull?.address;

    _pendingRoomName = roomName.trim().isEmpty ? _displayName(name) : roomName.trim();
    _seedWithPlayerQueue = seedWithPlayerQueue;
    _pendingPublic = isPublic;
    await _connect(
      server: Uri(scheme: 'http', host: '127.0.0.1', port: relay.port),
      code: created.code,
      token: created.token,
      password: null,
      listening: listening,
      lanRelay: relay,
      inviteServer: lanAddress == null ? null : Uri(scheme: 'http', host: lanAddress, port: relay.port),
    );
    return null;
  }

  Future<void> joinRoom({Uri? server, required String code, String? password, required bool listening}) async {
    if (isActive.value) return;
    _seedWithPlayerQueue = false;
    await _connect(server: server ?? defaultServer, code: code.toUpperCase(), token: null, password: password, listening: listening);
  }

  Future<void> _connect({
    required Uri server,
    required String code,
    required String? token,
    required String? password,
    required bool listening,
    PartyRelayServer? lanRelay,
    Uri? inviteServer,
  }) async {
    final name = await SyncUtils.currentDeviceName;
    final deviceId = await SyncUtils.currentDeviceId;
    _resetSession();
    _lanRelay = lanRelay;
    _inviteServer = inviteServer;
    _server = server;
    _code = code;
    isListening.value = listening;
    isActive.value = true;
    _playedHistory.clear();
    final wsUri = server.replace(scheme: server.scheme == 'https' ? 'wss' : 'ws', path: '/v1/room/$code');
    final connection = PartyConnection(
      roomUri: wsUri,
      partyVersion: kPartyVersion,
      name: _displayName(name),
      deviceId: deviceId,
      listener: this,
      token: token,
      password: password,
    );
    _connection = connection;
    await connection.connect();
  }

  Future<void> leave({bool closeRoom = false}) async {
    final connection = _connection;
    if (connection == null) return;
    // -- our own relay dies with us, tell everyone instead of leaving them reconnecting
    if ((closeRoom || isLanParty) && isHost) connection.closeRoom();
    await connection.leave();
    await _cleanup();
  }

  Future<void> _cleanup() async {
    _connection = null;
    _summaryTimer?.cancel();
    _summaryTimer = null;
    _lastSummaryMS = 0;
    _sentSummaryName = null;
    _sentSummaryTitle = null;
    _sentSummaryArtist = null;
    _pendingPublic = false;
    _host?.dispose();
    _host = null;
    final binder = _binder;
    _binder = null;
    isActive.value = false;
    status.value = .closed;
    await binder?.unbind(restoreQueue: true);
    final lanRelay = _lanRelay;
    _lanRelay = null;
    _resetSession();
    await lanRelay?.close();
  }

  void _resetSession() {
    _state = PartyState()..listener = this;
    syncState.value = .idle;
    _myN = 0;
    _hostN = 0;
    _hostOnline = false;
    _maxMembers = 0;
    _opts = null;
    _bans = const [];
    _synced = false;
    _relayMembers.clear();
    _joinRequests.clear();
    _server = null;
    _inviteServer = null;
    _code = null;
    _bumpAll();
  }

  void _bumpAll() {
    infoTick.value++;
    queueTick.value++;
    anchorTick.value++;
    membersTick.value++;
    chatTick.value++;
    requestsTick.value++;
  }

  static String _displayName(String name) {
    name = name.trim();
    if (name.isEmpty) return 'Namida';
    return name.length > 32 ? name.substring(0, 32) : name;
  }

  Future<Map<String, dynamic>?> _membershipProof() async {
    final membership = YoutubeAccountController.membership;
    bool good(MembershipType? ms) => ms != null && ms.index >= MembershipType.cutie.index;
    if (good(membership.userMembershipTypePatreon.value)) {
      final token = await NamicoSubscriptionManager.cacheManager.getPatreonTokenCache();
      if (token != null) return {'kind': 'patreon', 'token': token.accessToken};
    }
    final sub = membership.userSupabaseSub.value ?? await NamicoSubscriptionManager.supabase.getUserSubInCache();
    final id = sub?.uuid;
    final email = sub?.email;
    if (id != null && email != null) return {'kind': 'supabase', 'id': id, 'email': email};
    return null;
  }

  static Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final text = await response.transform(utf8.decoder).join();
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> _postJson(Uri uri, Map<String, dynamic> body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(const Duration(seconds: 30));
      final text = await response.transform(utf8.decoder).join();
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  // ------------------------------------------------------------ directory

  static const _summaryMinIntervalMS = 20000;
  static final _serverInfoCache = <String, Map<String, dynamic>>{};

  /// `/v1/info` of [server], null when it could not be reached.
  /// only a reply is cached, so an outage never sticks for the session.
  static Future<Map<String, dynamic>?> serverInfo(Uri server) async {
    final key = server.toString();
    final known = _serverInfoCache[key];
    if (known != null) return known;
    try {
      final info = await _getJson(server.resolve('/v1/info'));
      if (info != null) _serverInfoCache[key] = info;
      return info;
    } catch (_) {
      return null;
    }
  }

  /// whether [server] serves a public room listing, null when it could not be reached.
  static Future<bool?> supportsDirectory(Uri server) async {
    final info = await serverInfo(server);
    return info == null ? null : info['directory'] == true;
  }

  /// whether creating a room on [server] needs a membership, null when it could not be reached.
  static Future<bool?> requiresMembership(Uri server) async {
    final info = await serverInfo(server);
    return info == null ? null : info['membership'] == true;
  }

  /// the room slots are full, not a membership problem, it is fixed by closing a room.
  static const kRoomsLimitError = 'rooms_limit';

  static bool isMembershipError(String code) => code == 'membership_required' || code == 'membership_invalid';

  /// null when the listing could not be fetched.
  static Future<PartyRoomsPage?> listRooms({Uri? server, String? after, int limit = 25}) async {
    server ??= defaultServer;
    try {
      final uri = server
          .resolve('/v1/rooms')
          .replace(
            queryParameters: {
              'limit': '$limit',
              'after': ?after,
            },
          );
      final map = await _getJson(uri);
      final rooms = map?['rooms'];
      if (rooms is! List) return null;
      final hidden = settings.party.hiddenOwners;
      final parsed = <PartyPublicRoom>[];
      for (final raw in rooms) {
        final room = PartyPublicRoom.fromMap(raw);
        if (room != null && !hidden.contains(room.ownerId)) parsed.add(room);
      }
      return PartyRoomsPage(parsed, map!['next'] as String?);
    } catch (e, st) {
      logger.error('party rooms listing failed', e: e, st: st);
      return null;
    }
  }

  void _rememberCurrentRoom() {
    final server = _inviteServer ?? _server;
    final code = _code;
    final token = _connection?.token;
    if (server == null || code == null) return;
    _rememberRoom(
      PartyRoomMemory(
        code: code,
        server: server,
        token: token,
        name: _state.roomName,
        hosted: isHost,
        atMS: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// saves what played into a local playlist, a youtube one, or both. returns how many entries landed.
  Future<int> saveHistoryAsPlaylist(String name) async {
    final entries = _playedHistory;
    if (entries.isEmpty) return 0;
    final localIndex = await SyncPathResolver.localCoreIndex();
    final tracks = <Track>[];
    final videoIds = <String>[];
    for (final entry in entries) {
      final ytId = entry.ytId;
      if (ytId != null) {
        videoIds.add(ytId);
        continue;
      }
      final local = localIndex[entry.fingerprint];
      if (local != null) {
        tracks.add(local);
        continue;
      }
      final fallback = entry.fallbackYtId;
      if (fallback != null) videoIds.add(fallback);
    }
    if (tracks.isNotEmpty) await PlaylistController.inst.addNewPlaylist(name, tracks: tracks);
    if (videoIds.isNotEmpty) YoutubePlaylistController.inst.addNewPlaylist(name, videoIds: videoIds);
    return tracks.length + videoIds.length;
  }

  void _recordPlayed() {
    final entry = _state.currentEntry;
    if (entry == null || _playedHistory.lastOrNull?.id == entry.id) return;
    if (_playedHistory.length >= PartyLimits.maxEntries) _playedHistory.removeAt(0);
    _playedHistory.add(entry);
  }

  void _pushSummary({bool force = false}) {
    if (!isHost || _opts?.isPublic != true) return;
    final name = _state.roomName;
    // -- without it the summary only changes with the room itself, which is a handful of pushes per party
    final entry = settings.party.sharePlaying.valueF ? _state.currentEntry : null;
    final title = entry?.title ?? '';
    final artist = entry?.artist ?? '';
    if (!force && name == _sentSummaryName && title == _sentSummaryTitle && artist == _sentSummaryArtist) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _lastSummaryMS;
    if (elapsed < _summaryMinIntervalMS) {
      // -- the relay refreshes the listing on its own schedule, sending faster only burns rate budget
      _summaryTimer ??= Timer(Duration(milliseconds: _summaryMinIntervalMS - elapsed), () {
        _summaryTimer = null;
        _pushSummary();
      });
      return;
    }
    _summaryTimer?.cancel();
    _summaryTimer = null;
    _lastSummaryMS = now;
    _sentSummaryName = name;
    _sentSummaryTitle = title;
    _sentSummaryArtist = artist;
    _connection?.sendSummary(name: name, title: title, artist: artist);
  }

  // ------------------------------------------------------------ member actions

  @override
  void sendCommand(PartyMsg command) {
    final host = _host;
    if (host != null) {
      host.onCommand(_myN, command);
      return;
    }
    if (!_hostOnline) return;
    _connection?.sendData(PartyRoute.toHost, command.encode());
  }

  void sendChat(String text) => sendCommand(PartyMsg.chat(text));
  void sendReaction(String emoji) => sendCommand(PartyMsg.react(emoji));
  void kick(int n, {bool ban = false}) => sendCommand(PartyMsg.kick(n, ban: ban));
  void setRole(int n, PartyRole role) => sendCommand(PartyMsg.role(n, role));
  void setPermissions(PartyPermissions perms) => sendCommand(PartyMsg.perms(perms));

  void unban(String banId) => _connection?.unban(banId);
  void transferHost(int n) => _connection?.transferHost(n);
  void setSharePlaying(bool share) {
    if (settings.party.sharePlaying.valueF == share) return;
    settings.party.modify((partySettings) => partySettings.sharePlaying.value = share);
    _pushSummary(force: true);
  }

  void setRoomOpts({bool? approval, bool? locked, bool? isPublic, String? password, bool clearPassword = false}) {
    _connection?.setOpts(approval: approval, locked: locked, isPublic: isPublic, password: password, clearPassword: clearPassword);
  }

  void answerJoinRequest(String requestId, bool accept) {
    _connection?.approve(requestId, accept);
    if (_joinRequests.remove(requestId) != null) requestsTick.value++;
  }

  Future<void> setListening(bool listening) async {
    if (isListening.value == listening) return;
    isListening.value = listening;
    sendCommand(PartyMsg.listening(listening));
    await _ensureBinder();
    _binder?.setListening(listening);
  }

  /// the player follows the party for the whole stay, listening only decides whether it makes sound.
  Future<void> _ensureBinder() async {
    if (_binder != null) return;
    final binder = PartyPlayerBinder(_state, this);
    _binder = binder;
    await binder.bind(listening: isListening.value);
  }

  // ------------------------------------------------------------ PartyBinderDelegate

  @override
  int nowMS() => _connection?.nowMS() ?? DateTime.now().millisecondsSinceEpoch;

  @override
  void notifyDenied(PartyDenyReason reason, {String? details}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastDeniedNoticeMS < 2000) return;
    _lastDeniedNoticeMS = now;
    snackyy(
      icon: Broken.warning_2,
      title: lang.partyListeningParty,
      message: switch (reason) {
        PartyDenyReason.permission => lang.partyNoPermission,
        PartyDenyReason.queueFull => lang.partyQueueFull,
        PartyDenyReason.invalid => lang.partyInvalidAction,
      },
      top: false,
      isError: true,
    );
  }

  @override
  void onForcesMixedQueueChanged(bool forcesMixedQueue) => this.forcesMixedQueue.value = forcesMixedQueue;

  // ------------------------------------------------------------ PartyConnectionListener

  @override
  void onStatus(PartyConnectionStatus status) => this.status.value = status;

  @override
  void onWelcome(PartyWelcome welcome) {
    _myN = welcome.n;
    _hostN = welcome.hostN;
    _hostOnline = welcome.hostOnline;
    _maxMembers = welcome.maxMembers;
    _opts = welcome.opts;
    _relayMembers
      ..clear()
      ..addAll(welcome.members);
    infoTick.value++;
    _rememberCurrentRoom();

    if (isHost) {
      _becomeHost(isFirstWelcome: _host == null);
    } else {
      _host?.dispose();
      _host = null;
      _synced = false;
      if (_hostOnline) _connection?.sendData(PartyRoute.toHost, PartyMsg.hello(listening: isListening.value).encode());
    }
    _ensureBinder();
    if (isHost) {
      if (_pendingPublic && _opts?.isPublic != true) {
        _connection?.setOpts(isPublic: true);
      } else {
        _pushSummary(force: true);
      }
    }
  }

  void _becomeHost({required bool isFirstWelcome}) {
    final existing = _host;
    if (existing != null) {
      // -- we reconnected, catch up with who came & went meanwhile
      for (final n in _state.members.keys.toList()) {
        if (!_relayMembers.containsKey(n)) existing.onMemberLeft(n);
      }
      for (final e in _relayMembers.entries) {
        if (!_state.members.containsKey(e.key)) existing.onMemberJoined(e.key, e.value);
      }
      return;
    }
    _synced = true;
    if (_state.epoch == 0) {
      _host = PartyHost.create(
        state: _state,
        selfN: _myN,
        selfName: _relayMembers[_myN] ?? '',
        roomName: _pendingRoomName,
        listening: isListening.value,
        delegate: this,
      );
      for (final e in _relayMembers.entries) {
        if (e.key != _myN) _host!.onMemberJoined(e.key, e.value);
      }
      if (_seedWithPlayerQueue) _seedQueueFromPlayer();
    } else {
      _host = PartyHost.takeOver(state: _state, selfN: _myN, connected: Map.of(_relayMembers), delegate: this);
      if (!isFirstWelcome) {
        snackyy(icon: Broken.crown_1, title: lang.partyListeningParty, message: lang.partyYouAreHostNow, top: false);
      }
    }
  }

  void _seedQueueFromPlayer() {
    _seedWithPlayerQueue = false;
    final player = Player.inst;
    final queue = player.currentQueue.value;
    if (queue.isEmpty) return;
    final drafts = queue.take(PartyLimits.maxEntries).map(PartyPlayerBinder.entryOf).toList();
    sendCommand(
      PartyMsg.setQueue(
        drafts,
        index: player.currentIndex.value.clampInt(0, drafts.length - 1),
        positionMS: player.nowPlayingPosition.value,
        playing: player.playWhenReady.value,
      ),
    );
  }

  @override
  void onMemberJoined(int n, String name) {
    _relayMembers[n] = name;
    _host?.onMemberJoined(n, name);
  }

  @override
  void onMemberLeft(int n, String reason) {
    _relayMembers.remove(n);
    _host?.onMemberLeft(n);
  }

  @override
  void onHostChanged(int n, bool online) {
    final wasHost = isHost;
    final hostChanged = _hostN != n;
    _hostN = n;
    _hostOnline = online;
    infoTick.value++;
    if (isHost) {
      if (!wasHost) _becomeHost(isFirstWelcome: false);
      return;
    }
    if (wasHost) {
      _host?.dispose();
      _host = null;
    }
    if (online && !hostChanged && !_synced) {
      // -- the host came back while we were waiting for a snapshot
      _connection?.sendData(PartyRoute.toHost, const PartyMsg.sync().encode());
    }
  }

  @override
  void onOpts(PartyRoomOpts opts) {
    final wasPublic = _opts?.isPublic;
    _opts = opts;
    infoTick.value++;
    if (opts.isPublic && wasPublic != true) _pushSummary(force: true);
  }

  @override
  void onJoinRequest(String requestId, String name, String deviceId) {
    _joinRequests[requestId] = PartyJoinRequest(requestId, name, deviceId);
    requestsTick.value++;
  }

  @override
  void onJoinRequestGone(String requestId) {
    if (_joinRequests.remove(requestId) != null) requestsTick.value++;
  }

  @override
  void onBans(List<PartyBan> bans) {
    _bans = bans;
    infoTick.value++;
  }

  @override
  void onData(int route, int senderN, Uint8List payload) {
    final PartyMsg msg;
    try {
      msg = PartyMsg.decode(payload);
    } catch (_) {
      return;
    }
    if (route == PartyRoute.toHost) {
      _host?.onCommand(senderN, msg);
      return;
    }
    if (senderN != _hostN || isHost || msg.type.isCommand) return;
    _onEvent(msg);
  }

  void _onEvent(PartyMsg event) {
    if (event.type == PartyMsgType.denied) {
      final reason = event.data['r'];
      notifyDenied(reason is int && reason < PartyDenyReason.values.length ? PartyDenyReason.values[reason] : .invalid);
      return;
    }
    if (!_synced && event.type != PartyMsgType.snapshot && !_state.isLoading) return;
    if (_state.apply(event)) {
      _synced = true;
      return;
    }
    if (!_synced) return;
    _synced = false;
    _connection?.sendData(PartyRoute.toHost, const PartyMsg.sync().encode());
  }

  @override
  void onRelayError(String code) {
    if (code == 'rate_limited') notifyDenied(.invalid);
  }

  @override
  void onFatal(String code, Map<String, dynamic> details) {
    final wasActive = isActive.value;
    if (_isGoneForGood(code)) {
      final server = _inviteServer ?? _server;
      final code = _code;
      if (server != null && code != null) {
        forgetRoom(PartyRoomMemory(code: code, server: server, token: null, name: '', hosted: false, atMS: 0));
      }
    }
    _cleanup();
    if (!wasActive) return;
    snackyy(
      icon: Broken.warning_2,
      title: lang.partyListeningParty,
      message: fatalMessage(code),
      borderColor: Colors.red.withOpacityExt(0.4),
      isError: true,
    );
  }

  /// the room can never be reached again, unlike a kick or a wrong password.
  static bool _isGoneForGood(String code) => code == 'not_found' || code == 'closed' || code == 'banned';

  static String fatalMessage(String code) {
    return switch (code) {
      'closed' => lang.partyClosed,
      'kicked' => lang.partyKicked,
      'banned' => lang.partyBanned,
      'version_mismatch' => lang.versionMismatchMakeSureBothAppsAreOnTheSameVersion,
      'not_found' => lang.partyNotFound,
      'full' => lang.partyFull,
      'bad_password' => lang.partyWrongPassword,
      'rejected' => lang.partyJoinRejected,
      'locked' => lang.partyLocked,
      'host_offline' => lang.partyHostOffline,
      'membership_required' || 'membership_invalid' => lang.partyMembershipRequired(name: MembershipType.cutie.name),
      'rooms_limit' => lang.partyRoomsLimit,
      'unreachable' || 'upstream' || 'timeout' => lang.partyUnreachable,
      _ => code,
    };
  }

  // ------------------------------------------------------------ PartyHostDelegate

  @override
  void broadcast(PartyMsg event) => _connection?.sendData(PartyRoute.broadcast, event.encode());

  @override
  void sendTo(int n, PartyMsg event) {
    if (n == _myN) {
      _onLocalHostReply(event);
      return;
    }
    _connection?.sendData(PartyRoute.toMember, event.encode(), n: n);
  }

  void _onLocalHostReply(PartyMsg event) {
    if (event.type != PartyMsgType.denied) return;
    final reason = event.data['r'] as int;
    notifyDenied(PartyDenyReason.values[reason]);
  }

  @override
  void relayKick(int n, {required bool ban}) => _connection?.kick(n, ban: ban);

  @override
  void relaySuccessors(List<int> ns) => _connection?.setSuccessors(ns);

  final _fallbackQueue = Queue<PartyEntry>();
  bool _resolvingFallbacks = false;

  @override
  void resolveFallback(PartyEntry entry) {
    _fallbackQueue.add(entry);
    if (_resolvingFallbacks) return;
    _resolvingFallbacks = true;
    _drainFallbacks();
  }

  Future<void> _drainFallbacks() async {
    try {
      while (_fallbackQueue.isNotEmpty) {
        final host = _host;
        if (host == null) break;
        final entry = _fallbackQueue.removeFirst();
        if (_state.entryById(entry.id) == null) continue;
        final ytId = await _searchYoutubeMatch(entry);
        if (ytId != null) host.setFallback(entry.id, ytId, approximate: true);
      }
    } finally {
      _fallbackQueue.clear();
      _resolvingFallbacks = false;
    }
  }

  /// a match is only offered when its length is close enough, a wrong song is worse than none.
  static int _matchToleranceSeconds(int wantedSeconds) {
    final relative = (wantedSeconds * 0.12).round();
    return relative < 8 ? 8 : relative;
  }

  static Future<String?> _searchYoutubeMatch(PartyEntry entry) async {
    final query = '${entry.artist} ${entry.title}'.trim();
    final wantedSeconds = entry.durationMS ~/ 1000;
    // -- without a length there is nothing to check a candidate against
    if (query.isEmpty || wantedSeconds <= 0) return null;
    try {
      final result = await YoutubeInfoController.search.search(query, peopleAlsoWatched: false);
      if (result == null) return null;
      final tolerance = _matchToleranceSeconds(wantedSeconds);
      String? bestId;
      var bestDiff = tolerance + 1;
      for (final chunk in result.items) {
        for (final item in chunk.items) {
          if (item is! StreamInfoItem || item.isActuallyShortContent == true) continue;
          final seconds = item.durSeconds;
          if (seconds == null) continue;
          final diff = (seconds - wantedSeconds).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            bestId = item.id;
          }
        }
      }
      return bestId;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ PartyStateListener

  @override
  void onQueueSet() {
    queueTick.value++;
    anchorTick.value++;
    _pushSummary();
    _binder?.onQueueSet();
  }

  @override
  void onEntriesAdded(int index, List<PartyEntry> entries) {
    queueTick.value++;
    _binder?.onEntriesAdded(index, entries);
  }

  @override
  void onEntriesRemoved(List<int> ids) {
    queueTick.value++;
    _binder?.onEntriesRemoved(ids);
  }

  @override
  void onEntryMoved(int fromIndex, int toIndex) {
    queueTick.value++;
    _binder?.onEntryMoved(fromIndex, toIndex);
  }

  @override
  void onEntryMetaChanged(PartyEntry entry, {required bool fallbackChanged}) {
    queueTick.value++;
    _binder?.onEntryMetaChanged(entry, fallbackChanged: fallbackChanged);
  }

  @override
  void onAnchorChanged() {
    anchorTick.value++;
    _recordPlayed();
    _pushSummary();
    _binder?.onAnchorChanged();
  }

  @override
  void onMembersChanged() => membersTick.value++;

  @override
  void onPermsChanged() => infoTick.value++;

  @override
  void onChat(PartyChatMessage message) => chatTick.value++;

  @override
  void onReaction(int n, String emoji) {
    lastReaction = (n, emoji);
    reactionTick.value++;
  }

  @override
  void onSyncStateChanged(PartySyncState state) => syncState.value = state;
}

/// one shot connection that closes a room we host, without joining it properly.
class _RoomCloser implements PartyConnectionListener {
  final PartyRoomMemory room;
  final String token;

  _RoomCloser(this.room, this.token);

  final _done = Completer<bool>();
  PartyConnection? _connection;

  Future<bool> run() async {
    final wsUri = room.server.replace(scheme: room.server.scheme == 'https' ? 'wss' : 'ws', path: '/v1/room/${room.code}');
    final connection = PartyConnection(
      roomUri: wsUri,
      partyVersion: kPartyVersion,
      name: 'namida',
      deviceId: await SyncUtils.currentDeviceId,
      listener: this,
      token: token,
    );
    _connection = connection;
    connection.connect();
    return _done.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _finish(false);
        return false;
      },
    );
  }

  void _finish(bool closed) {
    if (_done.isCompleted) return;
    _connection?.dispose();
    _done.complete(closed);
  }

  @override
  void onWelcome(PartyWelcome welcome) {
    if (welcome.n != welcome.hostN) return _finish(false); // -- not ours anymore
    _connection?.closeRoom();
    _finish(true);
  }

  @override
  void onFatal(String code, Map<String, dynamic> details) => _finish(code == 'not_found');

  @override
  void onStatus(PartyConnectionStatus status) {}
  @override
  void onMemberJoined(int n, String name) {}
  @override
  void onMemberLeft(int n, String reason) {}
  @override
  void onHostChanged(int n, bool online) {}
  @override
  void onOpts(PartyRoomOpts opts) {}
  @override
  void onJoinRequest(String requestId, String name, String deviceId) {}
  @override
  void onJoinRequestGone(String requestId) {}
  @override
  void onBans(List<PartyBan> bans) {}
  @override
  void onData(int route, int senderN, Uint8List payload) {}
  @override
  void onRelayError(String code) {}
}
