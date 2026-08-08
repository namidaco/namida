part of '../sync_manager.dart';

class BaseMessageInfo {
  final MessageActionType action;
  final String senderDeviceId;

  const BaseMessageInfo({
    required this.action,
    required this.senderDeviceId,
  });

  const BaseMessageInfo.connection(this.senderDeviceId) : action = .connection;

  factory BaseMessageInfo.fromMap(Map<String, dynamic> map) {
    return BaseMessageInfo(
      action: MessageActionType.lookupMap[map['a']]!,
      senderDeviceId: map['sdid'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'a': action.name,
      'sdid': senderDeviceId,
    };
  }
}

sealed class BaseMessage {
  final MessageType type;
  final BaseMessageInfo messageInfo;
  const BaseMessage(this.type, {required this.messageInfo});

  Map<String, dynamic> _encodeToMap();

  /// Code to execute on receiving this message.
  ///
  /// ex: show snackbar, update database, add to history, etc...
  FutureOr<void> executeOnReceived();

  String toRawInfo() => _encodeToMap().toString();

  static BaseMessage Function(Map<String, dynamic> map, BaseMessageInfo messageInfo) getFactory(MessageType type) {
    return switch (type) {
      // ------------- core -------------
      MessageType.ping => PingMessage.fromMap,
      MessageType.connectionRequest => ConnectionRequestMessage.fromMap,
      MessageType.messageRequest => RequestMessage.fromMap,
      // ------------- local -------------
      MessageType.historyListens => HistoryListensMessage.fromMap,
      MessageType.playlists => PlaylistsMessage.fromMap,
      MessageType.playlistsManifestResponse => PlaylistsManifestResponseMessage.fromMap,
      // -------------  yt   -------------
      MessageType.ytHistoryListens => YTHistoryListensMessage.fromMap,
      MessageType.ytPlaylists => YTPlaylistsMessage.fromMap,
      MessageType.ytPlaylistsManifestResponse => YTPlaylistsManifestResponseMessage.fromMap,
    };
  }

  Uint8List encodeBytes() {
    final map = _encodeToMap();
    final params = List<dynamic>.filled(3, null, growable: false);
    params
      ..[0] = type.name
      ..[1] = messageInfo.toMap()
      ..[2] = map;
    final json = jsonEncode(params);
    return utf8.encode(json);
  }

  static BaseMessage decodeBytes(Uint8List bytes, Set<String> allowedDeviceIds, Set<String> blockedDeviceIds) {
    final json = utf8.decode(bytes);
    final params = jsonDecode(json) as List;
    final message = _decodeFromList(params, allowedDeviceIds, blockedDeviceIds);
    return message;
  }

  static BaseMessage _decodeFromList(List params, Set<String> allowedDeviceIds, Set<String> blockedDeviceIds) {
    final typeName = params[0] as String;
    // if (typeName == null) throw FormatException('Message type is missing');

    final type = MessageType.lookupMap[typeName];
    if (type == null) throw FormatException('Unknown Message type: $type');

    final info = BaseMessageInfo.fromMap(params[1] as Map<String, dynamic>);
    final senderDeviceId = info.senderDeviceId;

    if (blockedDeviceIds.contains(senderDeviceId)) {
      throw BlockedMessageException(senderDeviceId, type);
    }
    if (!allowedDeviceIds.contains(senderDeviceId)) {
      if (type != MessageType.connectionRequest) {
        throw NonAllowedMessageException(senderDeviceId, type);
      }
    }

    final map = params[2] as Map<String, dynamic>;
    final factory = getFactory(type);
    return factory(map, info);
  }
}

class PingMessage extends BaseMessage {
  final String? message;

  const PingMessage({
    required super.messageInfo,
    this.message,
  }) : super(MessageType.ping);

  factory PingMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return PingMessage(
      message: map['m'] as String?,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'm': ?message,
  };

  @override
  FutureOr<void> executeOnReceived() {
    // -- do nothing
  }
}

class RequestMessage extends BaseMessage {
  final MessageRequestType msgRequestType;

  const RequestMessage({
    required super.messageInfo,
    required this.msgRequestType,
  }) : super(MessageType.messageRequest);

  factory RequestMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return RequestMessage(
      msgRequestType: MessageRequestType.lookupMap[map['msgRequestType']]!,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'msgRequestType': msgRequestType.name,
  };

  @override
  FutureOr<void> executeOnReceived() async {
    final available = <PlaylistManifest>[];

    final PlaylistManager plManager = switch (msgRequestType) {
      MessageRequestType.playlistsManifest => PlaylistController.inst,
      MessageRequestType.ytPlaylistsManifest => YoutubePlaylistController.inst,
    };

    for (final pl in plManager.playlistsMap.value.values) {
      final manifest = PlaylistManifest(
        name: pl.name,
        modifiedDate: pl.modifiedDate,
      );
      available.add(manifest);
    }

    final deviceId = await SyncUtils.currentDeviceId;
    final createdMessageInfo = BaseMessageInfo(senderDeviceId: deviceId, action: .manifest);
    final msg = switch (msgRequestType) {
      MessageRequestType.playlistsManifest => PlaylistsManifestResponseMessage(
        messageInfo: createdMessageInfo,
        available: available,
      ),
      MessageRequestType.ytPlaylistsManifest => YTPlaylistsManifestResponseMessage(
        messageInfo: createdMessageInfo,
        available: available,
      ),
    };

    await SyncDiscovery.sendMessage(msg, messageInfo.senderDeviceId);
  }
}

class ConnectionRequestMessage extends BaseMessage {
  final ConnectionRequestMessageType connectionType;
  final String senderDeviceName;
  final int version;
  final String? reason;

  const ConnectionRequestMessage({
    required this.connectionType,
    required this.senderDeviceName,
    required this.version,
    required this.reason,
    required super.messageInfo,
  }) : super(MessageType.connectionRequest);

  static Future<ConnectionRequestMessage> createForCurrentDevice(ConnectionRequestMessageType connectionType, {String? reason}) async {
    return ConnectionRequestMessage(
      connectionType: connectionType,
      senderDeviceName: await SyncUtils.currentDeviceName,
      version: SyncUtils.kSyncVersion,
      reason: reason,
      messageInfo: BaseMessageInfo.connection(await SyncUtils.currentDeviceId),
    );
  }

  factory ConnectionRequestMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return ConnectionRequestMessage(
      connectionType: ConnectionRequestMessageType.values.getEnum(map['ct'] as String)!,
      senderDeviceName: map['sdn'] as String,
      version: map['v'] as int,
      reason: map['reason'] as String?,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'ct': connectionType.name,
    'sdn': senderDeviceName,
    'v': version,
    'reason': reason,
  };

  @override
  Future<void> executeOnReceived() async {
    switch (connectionType) {
      case ConnectionRequestMessageType.connect:
        final senderDeviceId = messageInfo.senderDeviceId;
        settings.sync.updateDeviceName(senderDeviceId, senderDeviceName);
        if (version != SyncUtils.kSyncVersion) {
          VibratorController.high();
          final reasonMessage = 'Version mismatch, make sure both apps are on the same version';
          await SyncDiscovery.server.rejectConnection(senderDeviceId, reason: reasonMessage);
          await NamidaNavigator.inst.navigateDialog(
            dialog: CustomBlurryDialog(
              isWarning: true,
              normalTitleStyle: true,
              title: 'Connection Rejected - $senderDeviceName',
              bodyText: reasonMessage,
              actions: [
                NamidaButton(
                  text: lang.done.toUpperCase(),
                  onTap: () {
                    NamidaNavigator.inst.closeDialog();
                  },
                ),
              ],
            ),
          );
          return;
        }
        await NamidaNavigator.inst.navigateDialog(
          dialog: CustomBlurryDialog(
            isWarning: true,
            normalTitleStyle: true,
            bodyText: 'Accept Connection from "$senderDeviceName"?',
            actions: [
              NamidaButton(
                text: 'block'.toUpperCase(),
                onTap: () async {
                  await SyncDiscovery.server.blockConnection(senderDeviceId);
                  NamidaNavigator.inst.closeDialog();
                },
              ),
              NamidaButton(
                text: 'reject'.toUpperCase(),
                onTap: () async {
                  await SyncDiscovery.server.rejectConnection(senderDeviceId);
                  NamidaNavigator.inst.closeDialog();
                },
              ),
              NamidaButton(
                text: 'accept'.toUpperCase(),
                onTap: () async {
                  await SyncDiscovery.server.acceptConnection(senderDeviceId);
                  NamidaNavigator.inst.closeDialog();
                },
              ),
            ],
          ),
        );
        break;
      case ConnectionRequestMessageType.disconnect:
        await SyncDiscovery.server.disconnectConnection(messageInfo.senderDeviceId);
        break;
      case ConnectionRequestMessageType.accepted:
        await SyncDiscovery.client.onConnectionAccepted(this);
      case ConnectionRequestMessageType.rejected:
        await SyncDiscovery.client.onConnectionRejected(this);
      case ConnectionRequestMessageType.blocked:
        await SyncDiscovery.client.onConnectionBlocked(this);
      case ConnectionRequestMessageType.unblocked:
        await SyncDiscovery.client.onConnectionUnBlocked(this);
    }
  }
}

abstract class PlaylistsManifestResponseMessageUtils {
  PlaylistsManifestResponseMessageUtils._();

  static Map<String, dynamic> encodeToMap(List<PlaylistManifest> available) => {
    'available': available.map((e) => e.toMap()).toFixedList(),
  };

  static FutureOr<void> sendRequiredPlaylists<T extends PlaylistItemWithDate, E, S>({
    required BaseMessageInfo messageInfo,
    required List<PlaylistManifest> available,
    required PlaylistManager<T, E, S> playlistsManager,
    required BaseMessage Function(List<GeneralPlaylist<T, S>> playlistsToSend) createPlaylistsMessage,
  }) async {
    final alreadyAvailableOnOtherDevice = available;
    final playlistsToSend = <GeneralPlaylist<T, S>>[];
    for (final plInLibrary in playlistsManager.playlistsMap.value.values) {
      final plAlrOnOther = alreadyAvailableOnOtherDevice.firstWhereEff((e) => e.name == plInLibrary.name);
      if (plAlrOnOther == null || plInLibrary.modifiedDate > plAlrOnOther.modifiedDate) {
        playlistsToSend.add(plInLibrary);
      }
    }
    final msg = createPlaylistsMessage(playlistsToSend);
    snackyy(message: '==> playlistsToSend[${playlistsManager.runtimeType}]: ${playlistsToSend.map((e) => e.name).toList()}');
    await SyncDiscovery.sendMessage(msg, messageInfo.senderDeviceId);
  }
}

class PlaylistManifest {
  final String name;
  final int modifiedDate;

  const PlaylistManifest({
    required this.name,
    required this.modifiedDate,
  });

  static List<PlaylistManifest> fromMapAsList(Map<String, dynamic> map) {
    return (map['available'] as List).map((e) => PlaylistManifest.fromMap(e)).toList();
  }

  factory PlaylistManifest.fromMap(Map<String, dynamic> map) {
    return PlaylistManifest(
      name: map['name'] as String,
      modifiedDate: map['modifiedDate'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'modifiedDate': modifiedDate,
  };
}
