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

  // because it would execute as soon as manifest info is received,
  // causing minor inconveniences like progress flashing for different items
  static final _queue = Queue(parallel: 1);

  /// calls [executeOnReceived]. if [type] is a manifest response, it adds [executeOnReceived] to a queue first.
  Future<void> executeOnReceivedWithQueue() async {
    if (type.isManifestResponse) {
      return _queue.add(() async => executeOnReceived());
    }
    return executeOnReceived();
  }

  Map<String, dynamic> _encodeToMap();

  /// Code to execute on receiving this message.
  ///
  /// ex: show snackbar, update database, add to history, etc...
  @visibleForOverriding
  FutureOr<void> executeOnReceived();

  String toRawInfo() => _encodeToMap().toString();

  static BaseMessage Function(Map<String, dynamic> map, BaseMessageInfo messageInfo) getFactory(MessageType type) {
    return switch (type) {
      // ------------- core -------------
      MessageType.ping => PingMessage.fromMap,
      MessageType.connectionRequest => ConnectionRequestMessage.fromMap,
      MessageType.messageRequest => RequestMessage.fromMap,
      MessageType.batchInfo => BatchInfoMessage.fromMap,
      MessageType.syncItemsRequest => SyncItemsRequestMessage.fromMap,
      // ------------- local -------------
      MessageType.historyListens => HistoryListensMessage.fromMap,
      MessageType.playlists => PlaylistsMessage.fromMap,
      MessageType.tracksDbFingerprints => TracksDbFingerprintsMessage.fromMap,
      MessageType.latestPlayedForSource => LatestPlayedForSourceMessage.fromMap,
      MessageType.audioConfigs => AudioConfigsMessage.fromMap,
      MessageType.smartPlaylists => SmartPlaylistsMessage.fromMap,
      MessageType.trackStats => TrackStatsMessage.fromMap,
      MessageType.favourites => FavouritesMessage.fromMap,
      MessageType.playlistsManifestResponse => PlaylistsManifestResponseMessage.fromMap,
      // -------------  yt   -------------
      MessageType.ytHistoryListens => YTHistoryListensMessage.fromMap,
      MessageType.ytPlaylists => YTPlaylistsMessage.fromMap,
      MessageType.ytLikes => YTLikesMessage.fromMap,
      MessageType.ytSubscriptions => YTSubscriptionsMessage.fromMap,
      MessageType.ytSubscriptionsGroups => YTSubscriptionsGroupsMessage.fromMap,
      MessageType.ytPlaylistsManifestResponse => YTPlaylistsManifestResponseMessage.fromMap,
      // ------------- files -------------
      MessageType.dirFilesManifestRequest => DirFilesManifestRequestMessage.fromMap,
      MessageType.dirFilesManifestResponse => DirFilesManifestResponseMessage.fromMap,
      MessageType.dirFile => DirFileMessage.fromMap,
      MessageType.dbFile => DbFileMessage.fromMap,
      MessageType.dbManifestRequest => DbManifestRequestMessage.fromMap,
      MessageType.dbManifestResponse => DbManifestResponseMessage.fromMap,
      MessageType.dbEntries => DbEntriesMessage.fromMap,
      // ------------- playback -----------
      MessageType.playerQueue => PlayerQueueMessage.fromMap,
      MessageType.playback => PlaybackStateMessage.fromMap,
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

/// a message that has raw bytes message in a separate binary frame right after its
/// json frame, avoiding base64/byte-array in json. see [_FrameWriter.sendMessage].
mixin BinaryPayloadMessage on BaseMessage {
  /// set by the sender at construction, and by the receiver right before [executeOnReceived].
  Uint8List? binaryPayload;
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
  final SyncBatchRef? batchRef;

  const RequestMessage({
    required super.messageInfo,
    required this.msgRequestType,
    required this.batchRef,
  }) : super(MessageType.messageRequest);

  factory RequestMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return RequestMessage(
      msgRequestType: MessageRequestType.lookupMap[map['msgRequestType']]!,
      batchRef: SyncBatchRef.fromMap(map['br']),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'msgRequestType': msgRequestType.name,
    'br': ?batchRef?.toMap(),
  };

  @override
  FutureOr<void> executeOnReceived() {
    return switch (msgRequestType) {
      MessageRequestType.playlistsManifest => _sendPlaylistsManifest(PlaylistController.inst),
      MessageRequestType.ytPlaylistsManifest => _sendPlaylistsManifest(YoutubePlaylistController.inst),
      MessageRequestType.playerQueue => _sendPlayerQueue(),
      // -- they lost our fingerprints (ex: restarted), force resend even if we think they have them
      MessageRequestType.tracksDbFingerprints => SyncSender.inst.resendFingerprints(messageInfo.senderDeviceId),
    };
  }

  Future<void> _sendPlaylistsManifest(PlaylistManager plManager) async {
    final available = <PlaylistManifest>[];

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
        batchRef: batchRef,
      ),
      MessageRequestType.ytPlaylistsManifest => YTPlaylistsManifestResponseMessage(
        messageInfo: createdMessageInfo,
        available: available,
        batchRef: batchRef,
      ),
      MessageRequestType.playerQueue || MessageRequestType.tracksDbFingerprints => throw Exception('playlist manifest only'),
    };

    await SyncDiscovery.sendMessage(msg, messageInfo.senderDeviceId);
  }

  Future<void> _sendPlayerQueue() async {
    final receiverDeviceId = messageInfo.senderDeviceId;
    final msg = await PlayerQueueMessage.createForCurrentDevice();
    if (msg == null) return; // -- empty queue, nothing to send
    await SyncSender.inst.ensureFingerprintsSent(receiverDeviceId);
    await SyncDiscovery.sendMessage(msg, receiverDeviceId);
  }
}

/// asks the other device to send us [items].
/// items are chosen by the requesting (receiving) device, which is us.
class SyncItemsRequestMessage extends BaseMessage {
  final List<SyncDataItem> items;

  const SyncItemsRequestMessage({
    required this.items,
    required super.messageInfo,
  }) : super(MessageType.syncItemsRequest);

  static Future<SyncItemsRequestMessage> createForCurrentDevice(List<SyncDataItem> items) async {
    return SyncItemsRequestMessage(
      items: items,
      messageInfo: await SyncUtils.createMessageInfo(.manifest),
    );
  }

  factory SyncItemsRequestMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return SyncItemsRequestMessage(
      items: (map['items'] as List).map((e) => SyncDataItem.lookupMap[e]).nonNulls.toList(),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'items': items.map((e) => e.name).toFixedList(),
  };

  @override
  String toRawInfo() => 'SyncItemsRequest(${items.map((e) => e.name).join(', ')})';

  @override
  FutureOr<void> executeOnReceived() {
    if (items.isEmpty) return null;
    return SyncSender.inst.sendItemsToDevice(items, messageInfo.senderDeviceId);
  }
}

/// a progress snapshot of a [SyncBatch], built & sent by the origin device only.
///
/// snapshots are self contained & travel on the same socket, so they always
/// arrive in order & the receiver can simply display the latest one, no matter
/// how out of order the items themselves completed.
class BatchInfoMessage extends BaseMessage {
  final String batchId;

  /// how many items of the batch are fully done.
  final int progress;
  final int total;

  /// items currently transferring, the last one is the most recently started.
  final List<SyncDataItem> activeItems;

  /// sub-progress within a single item (dir files, db entries..), if any.
  final SyncItemProgress? itemProgress;

  /// the batch ended (finished or aborted), the receiver drops it.
  final bool finished;

  const BatchInfoMessage({
    required super.messageInfo,
    required this.batchId,
    required this.progress,
    required this.total,
    required this.activeItems,
    required this.itemProgress,
    required this.finished,
  }) : super(MessageType.batchInfo);

  factory BatchInfoMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return BatchInfoMessage(
      batchId: map['b'] as String,
      progress: map['p'] as int,
      total: map['t'] as int,
      activeItems: (map['ai'] as List?)?.map((e) => SyncDataItem.lookupMap[e]).nonNulls.toList() ?? const [],
      itemProgress: SyncItemProgress.fromList(map['ip']),
      finished: map['f'] as bool? ?? false,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'b': batchId,
    'p': progress,
    't': total,
    'ai': activeItems.map((e) => e.name).toFixedList(),
    'ip': ?itemProgress?.toList(),
    'f': finished,
  };

  @override
  String toRawInfo() => 'BatchInfo($progress/$total${finished ? ', finished' : ''}${activeItems.isEmpty ? '' : ', ${activeItems.map((e) => e.name).join('+')}'})';

  /// the item to display, the most recently started one.
  SyncDataItem? get headlineItem => itemProgress?.item ?? (activeItems.isEmpty ? null : activeItems.last);

  /// how many items are running besides [headlineItem].
  int get extraActiveItemsCount => activeItems.isEmpty ? 0 : activeItems.length - 1;

  /// 0..1 of the whole batch, counting the running item's own progress as a
  /// fraction of one item. null when there is nothing to base it on.
  double? get overallFraction {
    if (total <= 0) return null;
    final itemFraction = itemProgress?.fraction ?? 0.0;
    return ((progress + itemFraction) / total).clampDouble(0.0, 1.0);
  }

  @override
  FutureOr<void> executeOnReceived() {
    SyncDiscovery.batchProgressIncomingRx[messageInfo.senderDeviceId] = finished ? null : this;
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
          final reasonMessage = lang.versionMismatchMakeSureBothAppsAreOnTheSameVersion;
          await SyncDiscovery.server.rejectConnection(senderDeviceId, reason: reasonMessage);
          await NamidaNavigator.inst.navigateDialog(
            dialog: CustomBlurryDialog(
              isWarning: true,
              normalTitleStyle: true,
              title: '${lang.connectionRejected} - $senderDeviceName',
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
        if (settings.sync.autoReconnect.valueF && settings.sync.allowedDeviceIds.contains(senderDeviceId)) {
          // -- device was accepted before, silently accept again (blocked devices are ignored in _FrameDispatcher)
          await SyncDiscovery.server.acceptConnection(senderDeviceId);
          return;
        }
        await NamidaNavigator.inst.navigateDialog(
          dialog: CustomBlurryDialog(
            isWarning: true,
            normalTitleStyle: true,
            bodyText: lang.acceptConnectionFromName(name: '"$senderDeviceName"'),
            trailingWidgets: [
              NamidaIconButton(
                icon: Broken.shield_slash,
                tooltip: () => lang.block.toUpperCase(),
                onPressed: () async {
                  await SyncDiscovery.server.blockConnection(senderDeviceId);
                  NamidaNavigator.inst.closeDialog();
                },
              ),
            ],
            actions: [
              NamidaButton(
                text: lang.reject.toUpperCase(),
                onTap: () async {
                  await SyncDiscovery.server.rejectConnection(senderDeviceId);
                  NamidaNavigator.inst.closeDialog();
                },
              ),
              NamidaButton(
                text: lang.accept.toUpperCase(),
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

  static Map<String, dynamic> encodeToMap(List<PlaylistManifest> available, SyncBatchRef? batchRef) => {
    'available': available.map((e) => e.toMap()).toFixedList(),
    'br': ?batchRef?.toMap(),
  };

  static Future<void> sendRequiredPlaylists<T extends PlaylistItemWithDate, E, S>({
    required BaseMessageInfo messageInfo,
    required List<PlaylistManifest> available,
    required PlaylistManager<T, E, S> playlistsManager,
    required bool tracksArePaths,
    required SyncBatchRef? batchRef,
    required BaseMessage Function(List<GeneralPlaylist<T, S>> playlistsToSend, BaseMessageInfo createdMessageInfo) createPlaylistsMessage,
  }) async {
    batchRef?.markTransferring();
    try {
      final alreadyAvailableOnOtherDevice = available;
      final playlistsToSend = <GeneralPlaylist<T, S>>[];
      for (final plInLibrary in playlistsManager.playlistsMap.value.values) {
        final plAlrOnOther = alreadyAvailableOnOtherDevice.firstWhereEff((e) => e.name == plInLibrary.name);
        if (plAlrOnOther == null || plInLibrary.modifiedDate > plAlrOnOther.modifiedDate) {
          playlistsToSend.add(plInLibrary);
        }
      }
      if (playlistsToSend.isEmpty) return; // -- they are up to date
      final receiverDeviceId = messageInfo.senderDeviceId;
      final createdMessageInfo = await SyncUtils.createMessageInfo(.add);
      final msg = createPlaylistsMessage(playlistsToSend, createdMessageInfo);
      if (tracksArePaths) await SyncSender.inst.ensureFingerprintsSent(receiverDeviceId);
      await SyncDiscovery.sendMessage(msg, receiverDeviceId);
    } finally {
      batchRef?.markDone();
    }
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
