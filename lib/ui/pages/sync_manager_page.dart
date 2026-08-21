import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class NamidaSyncManagerPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_Sync;

  const NamidaSyncManagerPage({super.key});

  @override
  State<NamidaSyncManagerPage> createState() => _NamidaSyncManagerPageState();
}

class _NamidaSyncManagerPageState extends State<NamidaSyncManagerPage> {
  final _sizesMap = <SyncDataItem, int>{}.obs;

  @override
  void initState() {
    super.initState();
    SyncDiscovery.client.startSearchForServers();
    _fillItemsSizes();
  }

  @override
  void dispose() {
    SyncDiscovery.client.stopSearch();
    super.dispose();
  }

  void _fillItemsSizes() async {
    for (final item in SyncDataItem.values) {
      int total = 0;
      for (final sub in item.backupPaths) {
        final size = sub.isDir ? await Directory(sub.resolve()).getTotalSize() : await File(sub.resolve()).fileSize();
        total += size ?? 0;
      }
      if (!mounted) return;
      _sizesMap[item] = total;
    }
  }

  void _modifySyncItems(void Function(Set<SyncDataItem> syncItems) modifier) {
    settings.sync.modify((syncSettings) {
      final syncItems = syncSettings.syncItems.value ??= {...SyncDataItem.essentialsSet};
      modifier(syncItems);
      syncSettings.syncItems.refresh();
    });
  }

  void _toggleItem(SyncDataItem item) {
    _modifySyncItems((syncItems) => syncItems.addOrRemove(item));
  }

  void _toggleItems(List<SyncDataItem> items, bool selected) {
    _modifySyncItems((syncItems) {
      if (selected) {
        syncItems.addAll(items);
      } else {
        items.forEach(syncItems.remove);
      }
    });
  }

  void _selectEssentialsOnly() {
    _modifySyncItems(
      (syncItems) => syncItems
        ..clear()
        ..addAll(SyncDataItem.essentialsSet),
    );
    VibratorController.medium();
  }

  List<SyncDataItem> get _selectedItemsSorted {
    final syncItems = settings.sync.syncItems.valueF;
    return SyncDataItem.values.where(syncItems.contains).toList();
  }

  bool _ensureItemsSelected() {
    final syncItems = settings.sync.syncItems.valueF;
    if (syncItems.isEmpty) {
      showMinimumItemsSnack(1);
      return false;
    }
    return true;
  }

  /// 96 steps of 30 mins == 48 hours max.
  static const _kAutoSyncMaxSteps = 96;

  String _autoSyncIntervalText(int minutes) {
    if (minutes <= 0) return lang.manualBackup;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return [if (h > 0) '${h}h', if (m > 0) '${m}m'].join(' ');
  }

  void _sendToDevice(SyncDeviceView device) {
    if (!_ensureItemsSelected()) return;
    SyncSender.inst.sendItemsToDevice(_selectedItemsSorted, device.deviceId);
  }

  void _receiveFromDevice(SyncDeviceView device) {
    if (!_ensureItemsSelected()) return;
    SyncSender.inst.requestItemsFromDevice(_selectedItemsSorted, device.deviceId);
  }

  void _syncWithDevice(SyncDeviceView device) {
    if (!_ensureItemsSelected()) return;
    SyncSender.inst.syncWithDevice(_selectedItemsSorted, device.deviceId);
  }

  void _sendToAll() {
    if (!_ensureItemsSelected()) return;
    SyncSender.inst.sendItemsToAllConnected(_selectedItemsSorted);
  }

  void _openRecentActionsLog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.clock,
        title: lang.recentActions,
        normalTitleStyle: true,
        actions: [
          NamidaButton(
            text: lang.done.toUpperCase(),
            onTap: NamidaNavigator.inst.closeDialog,
          ),
        ],
        child: SizedBox(
          height: namida.height * 0.5,
          width: namida.width,
          child: ObxOClass(
            rx: SyncActionsLog.inst,
            builder: (context, log) {
              final entries = log.entries;
              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    lang.none,
                    style: context.theme.textTheme.displayMedium,
                  ),
                );
              }
              return NamidaScrollbarWithController(
                child: (sc) => SuperSmoothListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: entries.length,
                  itemBuilder: (context, index) => _SyncActionEntryTile(
                    entry: entries[entries.length - 1 - index],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _editDeviceName() async {
    final currentName = settings.sync.customDeviceName.value?.nullifyEmpty() ?? await SyncUtils.currentDeviceName;
    final controller = TextEditingController(text: currentName);
    NamidaNavigator.inst.navigateDialog(
      onDisposing: controller.dispose,
      dialog: CustomBlurryDialog(
        title: lang.deviceName,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.save,
            onTap: () async {
              final newName = controller.text.trim();
              settings.sync.modify((syncSettings) => syncSettings.customDeviceName.value = newName.isEmpty ? null : newName);
              NamidaNavigator.inst.closeDialog();

              // -- restart to broadcast the new name
              if (SyncDiscovery.server.serverWrapper != null) await SyncDiscovery.server.startServer();
            },
          ),
        ],
        child: CustomTagTextField(
          controller: controller,
          hintText: currentName,
          labelText: lang.deviceName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double horizontalMargin = Dimensions.inst.getSettingsHorizontalMargin(context);
    return BackgroundWrapper(
      child: ObxOClass(
        rx: SyncDiscovery.client,
        builder: (context, client) => ObxOClass(
          rx: SyncDiscovery.server,
          builder: (context, server) {
            final devices = SyncDiscovery.sessionDevices;
            final availableNotKnown = client.availableServers.where((e) => !devices.containsKey(e.deviceId)).toList();
            int connectedCount = 0;
            for (final device in devices.values) {
              if (device.isConnected) connectedCount++;
            }
            final blockedClientIds = settings.sync.blockedClientIds;

            return SuperSmoothListView(
              padding: kBottomPaddingInsets.add(EdgeInsets.symmetric(horizontal: horizontalMargin)),
              children: [
                SettingsCard(
                  icon: Broken.cloud_change,
                  title: lang.sync,
                  subtitle: lang.syncAppDataBetweenYourDevices,
                  trailing: NamidaIconButton(
                    icon: Broken.clock,
                    tooltip: () => lang.recentActions,
                    onPressed: _openRecentActionsLog,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 4.0),

                      ObxO(
                        rx: settings.sync.customDeviceName,
                        builder: (context, customDeviceName) => FutureBuilder(
                          future: SyncUtils.fallbackDeviceName,
                          builder: (context, fallbackDeviceNameSnapshot) => CustomListTile(
                            icon: Broken.driver_2,
                            title: lang.server,
                            subtitle:
                                server.serverWrapper?.buildText(
                                  deviceName: customDeviceName?.nullifyEmpty() ?? fallbackDeviceNameSnapshot.data,
                                ) ??
                                lang.startServerToLetOtherDevicesConnectToThisDevice,
                            onTap: server.startServer,
                            trailing: AnimatedShow(
                              isHorizontal: true,
                              show: server.serverWrapper != null,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  NamidaIconButton(
                                    icon: Broken.edit_2,
                                    iconSize: 20.0,
                                    tooltip: () => lang.deviceName,
                                    onPressed: _editDeviceName,
                                  ),
                                  NamidaButton(
                                    text: lang.stop,
                                    onTap: server.stopServer,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      CustomListTile(
                        icon: Broken.global_search,
                        title: lang.search,
                        onTap: client.startSearchForServers,
                        trailing: client.allowAutoRetryDiscovery
                            ? NamidaButton(
                                text: lang.stop,
                                isLoading: client.isDiscovering,
                                onTap: client.stopSearch,
                              )
                            : NamidaButton(
                                text: lang.start,
                                onTap: client.startSearchForServers,
                              ),
                      ),
                      ObxOF(
                        rx: settings.sync.autoReconnect,
                        builder: (context, autoReconnectDevices, fallback) => CustomSwitchListTile(
                          icon: Broken.refresh_circle,
                          title: '${lang.auto} ${lang.reconnect}',
                          value: autoReconnectDevices ?? fallback,
                          onChanged: (isTrue) => settings.sync.modify(
                            (syncSettings) => syncSettings.autoReconnect.value = !isTrue,
                          ),
                        ),
                      ),
                      ObxOF(
                        rx: settings.sync.autoSyncIntervalMinutes,
                        builder: (context, intervalN, fallback) {
                          final intervalMinutes = intervalN ?? fallback;
                          return CustomListTile(
                            icon: Broken.timer,
                            title: lang.autoSyncInterval,
                            trailing: NamidaWheelSlider(
                              max: _kAutoSyncMaxSteps,
                              initValue: intervalMinutes <= 0 ? 0 : intervalMinutes ~/ 30,
                              onValueChanged: (val) {
                                settings.sync.modify(
                                  (syncSettings) => syncSettings.autoSyncIntervalMinutes.value = val <= 0 ? -1 : val * 30,
                                );
                                SyncSender.inst.setupAutoSync();
                              },
                              text: _autoSyncIntervalText(intervalMinutes),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4.0),

                      NamidaContainerDivider(
                        margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      ),

                      const SizedBox(height: 4.0),
                      _SectionTitle(
                        title: lang.connectedDevices,
                        count: devices.length,
                      ),
                      ...devices.values.map(
                        (device) => _DeviceCard(
                          device: device,
                          onSend: () => _sendToDevice(device),
                          onReceive: () => _receiveFromDevice(device),
                          onSync: () => _syncWithDevice(device),
                        ),
                      ),

                      const SizedBox(height: 12.0),
                      _SectionTitle(
                        title: lang.availableDevices,
                        count: availableNotKnown.length,
                      ),
                      ...availableNotKnown.map(
                        (serverDevice) => _AvailableDeviceCard(
                          serverDevice: serverDevice,
                        ),
                      ),

                      const SizedBox(height: 4.0),

                      NamidaContainerDivider(
                        margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      ),

                      const SizedBox(height: 4.0),
                      ObxO(
                        rx: settings.sync.syncItems,
                        builder: (context, syncItems) => _SectionTitle(
                          title: lang.dataToSendAndReceive,
                          count: syncItems?.length ?? settings.sync.syncItems.fallback.length,
                          total: SyncDataItem.values.length,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              NamidaIconButton(
                                icon: Broken.magicpen,
                                iconColor: context.defaultIconColor(),
                                iconSize: 16.0,
                                horizontalPadding: 4.0,
                                tooltip: () => lang.restoreDefaults,
                                onPressed: _selectEssentialsOnly,
                              ),
                              const SizedBox(width: 4.0),
                              const _AdvancedViewToggle(),
                            ],
                          ),
                        ),
                      ),
                      ObxOF(
                        rx: settings.sync.syncItemsAdvancedView,
                        builder: (context, advancedView, advancedViewF) => ObxO(
                          rx: settings.sync.syncItems,
                          builder: (context, syncItemsN) {
                            final syncItems = syncItemsN ?? SyncDataItem.essentialsSet;
                            return (advancedView ?? advancedViewF)
                                ? _SyncItemsAdvancedList(
                                    syncItems: syncItems,
                                    sizesMap: _sizesMap,
                                    onToggleItem: _toggleItem,
                                  )
                                : _SyncItemsGroupedList(
                                    syncItems: syncItems,
                                    sizesMap: _sizesMap,
                                    onToggleItems: _toggleItems,
                                  );
                          },
                        ),
                      ),

                      const SizedBox(height: 12.0),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ObxO(
                          rx: settings.sync.syncItems,
                          builder: (context, syncItems) => Row(
                            children: [
                              Expanded(
                                child: ObxOClass(
                                  rx: SyncSender.inst,
                                  builder: (context, sender) => NamidaButton(
                                    icon: Broken.send_2,
                                    minHeight: NamidaButton.kDefaultMinHeight * 1.25,
                                    borderRadius: 18.0,
                                    text: connectedCount > 1 ? '${lang.sendToAllDevices} ($connectedCount)' : lang.send,
                                    enabled: connectedCount > 0 && (syncItems == null || syncItems.isNotEmpty),
                                    isLoading: sender.isSendingAny,
                                    onTap: _sendToAll,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (blockedClientIds.isNotEmpty) ...[
                        const SizedBox(height: 8.0),
                        _BlockedDevicesTile(
                          blockedClientIds: blockedClientIds,
                        ),
                      ],

                      const SizedBox(height: 4.0),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int? count;
  final int? total;
  final Widget? trailing;

  const _SectionTitle({
    required this.title,
    this.count,
    this.total,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          if (count != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 24.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                  color: context.theme.colorScheme.secondaryContainer.withOpacityExt(0.4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  child: Text(
                    total == null ? '$count' : '$count/$total',
                    style: context.theme.textTheme.displaySmall?.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          if (count != null) const SizedBox(width: 6.0),
          Expanded(
            child: Text(
              title,
              style: context.theme.textTheme.displayMedium,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _AdvancedViewToggle extends StatelessWidget {
  const _AdvancedViewToggle();

  @override
  Widget build(BuildContext context) {
    return ObxOF(
      rx: settings.sync.syncItemsAdvancedView,
      builder: (context, advancedViewN, advancedViewF) {
        final advancedView = advancedViewN ?? advancedViewF;
        return NamidaInkWell(
          borderRadius: 8.0,
          bgColor: advancedView ? context.theme.colorScheme.secondaryContainer.withOpacityExt(0.5) : null,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          onTap: () => settings.sync.modify((syncSettings) => syncSettings.syncItemsAdvancedView.value = !advancedView),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Broken.setting_4,
                size: 14.0,
                color: context.defaultIconColor(),
              ),
              const SizedBox(width: 6.0),
              Text(
                lang.advanced,
                style: context.theme.textTheme.displaySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SyncItemsAdvancedList extends StatelessWidget {
  final Set<SyncDataItem> syncItems;
  final RxMap<SyncDataItem, int> sizesMap;
  final void Function(SyncDataItem item) onToggleItem;

  const _SyncItemsAdvancedList({
    required this.syncItems,
    required this.sizesMap,
    required this.onToggleItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...SyncDataItem.values.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
            child: ListTileWithCheckMark(
              dense: true,
              icon: item.toIcon(),
              titleWidget: _SyncItemTitle(
                title: item.toText(),
                isHeavy: item.isHeavy,
                sizeItems: item.backupPaths.isEmpty ? const [] : [item],
                sizesMap: sizesMap,
              ),
              active: syncItems.contains(item),
              onTap: () => onToggleItem(item),
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncItemsGroup {
  final IconData icon;
  final String title;
  final List<SyncDataItem> items;
  final List<SyncDataItem> itemsYt;

  final bool ytMirrorsMain;

  const _SyncItemsGroup({
    required this.icon,
    required this.title,
    required this.items,
    this.itemsYt = const [],
    this.ytMirrorsMain = false,
  });
}

class _SyncItemsGroupedList extends StatelessWidget {
  final Set<SyncDataItem> syncItems;
  final RxMap<SyncDataItem, int> sizesMap;
  final void Function(List<SyncDataItem> items, bool selected) onToggleItems;

  const _SyncItemsGroupedList({
    required this.syncItems,
    required this.sizesMap,
    required this.onToggleItems,
  });

  @override
  Widget build(BuildContext context) {
    final groups = [
      _SyncItemsGroup(
        icon: Broken.box_1,
        title: lang.database,
        items: const [SyncDataItem.stats, SyncDataItem.latestPlayedForSource, SyncDataItem.audioConfigs, SyncDataItem.videosPriority],
        itemsYt: const [SyncDataItem.statsYt],
      ),
      _SyncItemsGroup(
        icon: Broken.play_cricle,
        title: lang.playbackSetting,
        items: const [SyncDataItem.playerQueue, SyncDataItem.playback],
      ),
      _SyncItemsGroup(
        icon: Broken.music_library_2,
        title: lang.playlists,
        items: const [SyncDataItem.playlists, SyncDataItem.smartPlaylists, SyncDataItem.favourites],
        itemsYt: const [SyncDataItem.playlistsYt, SyncDataItem.favouritesYt],
      ),
      _SyncItemsGroup(
        icon: Broken.refresh,
        title: lang.history,
        items: const [SyncDataItem.history],
        itemsYt: const [SyncDataItem.historyYt],
      ),
      _SyncItemsGroup(
        icon: Broken.driver,
        title: lang.queues,
        items: const [SyncDataItem.queues],
      ),
      _SyncItemsGroup(
        icon: Broken.document,
        title: lang.lyrics,
        items: const [SyncDataItem.lyrics],
      ),
      _SyncItemsGroup(
        icon: Broken.video,
        title: lang.videoCache,
        items: const [SyncDataItem.videosCache],
      ),
      _SyncItemsGroup(
        icon: Broken.audio_square,
        title: lang.audioCache,
        items: const [SyncDataItem.audiosCache],
      ),
      _SyncItemsGroup(
        icon: Broken.image,
        title: lang.artworks,
        items: const [SyncDataItem.artworksArtists, SyncDataItem.artworksAlbums, SyncDataItem.playlistsArtworks, SyncDataItem.smartPlaylistsArtworks],
        itemsYt: const [SyncDataItem.playlistsArtworksYt],
      ),
      _SyncItemsGroup(
        icon: Broken.image,
        title: lang.thumbnails,
        items: const [SyncDataItem.thumbnailsYt, SyncDataItem.thumbnailsChannelsYt],
        ytMirrorsMain: true,
      ),
      _SyncItemsGroup(
        icon: Broken.user_tick,
        title: lang.subscriptions,
        items: const [SyncDataItem.subscriptionsYt],
        ytMirrorsMain: true,
      ),
    ];
    return Column(
      children: [
        ...groups.map(
          (group) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
            child: _SyncItemsGroupTile(
              group: group,
              syncItems: syncItems,
              sizesMap: sizesMap,
              onToggleItems: onToggleItems,
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncItemsGroupTile extends StatelessWidget {
  final _SyncItemsGroup group;
  final Set<SyncDataItem> syncItems;
  final RxMap<SyncDataItem, int> sizesMap;
  final void Function(List<SyncDataItem> items, bool selected) onToggleItems;

  const _SyncItemsGroupTile({
    required this.group,
    required this.syncItems,
    required this.sizesMap,
    required this.onToggleItems,
  });

  int _selectedCount(List<SyncDataItem> items) {
    int count = 0;
    for (final item in items) {
      if (syncItems.contains(item)) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final items = group.items;
    final itemsYt = group.itemsYt;

    final selectedCount = _selectedCount(items);
    final allSelected = selectedCount == items.length;
    final partiallySelected = selectedCount > 0 && !allSelected;

    final ytAvailable = group.ytMirrorsMain || itemsYt.isNotEmpty;
    final ytSelectedCount = group.ytMirrorsMain ? selectedCount : _selectedCount(itemsYt);
    final ytAllSelected = group.ytMirrorsMain ? allSelected : itemsYt.isNotEmpty && ytSelectedCount == itemsYt.length;
    final ytPartiallySelected = ytSelectedCount > 0 && !ytAllSelected;

    return Row(
      children: [
        Expanded(
          child: ListTileWithCheckMark(
            dense: true,
            icon: group.icon,
            titleWidget: _SyncItemTitle(
              title: group.title,
              isHeavy: items.any((e) => e.isHeavy) || itemsYt.any((e) => e.isHeavy),
              sizeItems: items,
              sizeItemsYt: itemsYt,
              sizesMap: sizesMap,
              extraText: partiallySelected ? '$selectedCount/${items.length}' : null,
            ),
            active: allSelected,
            halfActive: partiallySelected,
            onTap: () => onToggleItems(items, !allSelected),
          ),
        ),
        const SizedBox(width: 8.0),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: ytAvailable ? 1.0 : 0.1,
          child: NamidaIconButton(
            tooltip: () => lang.youtube,
            horizontalPadding: 0.0,
            icon: null,
            onPressed: () {
              if (ytAvailable) {
                final targetItems = group.ytMirrorsMain ? items : itemsYt;
                onToggleItems(targetItems, !ytAllSelected);
              }
            },
            child: StackedIcon(
              iconSize: 28.0,
              baseIcon: Broken.video_square,
              smallChild: ytPartiallySelected
                  ? Icon(
                      Broken.minus,
                      size: 12.0,
                      color: context.theme.colorScheme.secondary,
                    )
                  : NamidaCheckMark(
                      size: 12.0,
                      active: ytAllSelected,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8.0),
      ],
    );
  }
}

class _SyncActionEntryTile extends StatelessWidget {
  final SyncActionEntry entry;

  const _SyncActionEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final statusColor = switch (entry.status) {
      SyncActionStatus.inProgress => Colors.orange,
      SyncActionStatus.success => Colors.green,
      SyncActionStatus.failed => Colors.red,
    };
    final colorScheme = Color.alphaBlend(statusColor.withOpacityExt(0.5), theme.colorScheme.onSurface);
    final deviceName = settings.sync.deviceIdNames[entry.deviceId] ?? entry.deviceId;
    final isSent = entry.type == SyncActionType.sent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: SizedBox(
        width: context.width,
        child: NamidaCoolBox(
          colorScheme: colorScheme,
          reducedColors: true,
          builder: (context) => Row(
            children: [
              Icon(
                isSent ? Broken.send_2 : Broken.received,
                size: 20.0,
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: theme.textTheme.displayMedium,
                    ),
                    if (entry.items.isNotEmpty)
                      Text(
                        entry.items.map((e) => e.toText()).join(', '),
                        style: theme.textTheme.displaySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '${entry.sizeBytes.fileSizeFormatted} • ${entry.count}',
                      style: theme.textTheme.displaySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  entry.status == SyncActionStatus.inProgress
                      ? const SizedBox(
                          width: 14.0,
                          height: 14.0,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        )
                      : Icon(
                          entry.status == SyncActionStatus.success ? Broken.tick_circle : Broken.close_circle,
                          size: 16.0,
                          color: colorScheme,
                        ),
                  const SizedBox(height: 2.0),
                  Text(
                    entry.timeMS.clockFormatted,
                    style: theme.textTheme.displaySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncItemTitle extends StatelessWidget {
  final String title;
  final bool isHeavy;
  final List<SyncDataItem> sizeItems;
  final List<SyncDataItem> sizeItemsYt;
  final RxMap<SyncDataItem, int> sizesMap;

  final String? extraText;

  const _SyncItemTitle({
    required this.title,
    required this.isHeavy,
    required this.sizeItems,
    this.sizeItemsYt = const [],
    required this.sizesMap,
    this.extraText,
  });

  static (int, bool) _sumSizes(List<SyncDataItem> items, Map<SyncDataItem, int> sizes) {
    int total = 0;
    bool hasUnknown = false;
    for (final item in items) {
      final size = sizes[item];
      if (size == null) {
        hasUnknown = true;
      } else {
        total += size;
      }
    }
    return (total, hasUnknown);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.theme.textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                style: textTheme.displayMedium,
              ),
            ),
            if (isHeavy) ...[
              const SizedBox(width: 6.0),
              Tooltip(
                message: lang.performanceNote,
                child: Icon(
                  Broken.danger,
                  size: 14.0,
                  color: textTheme.displayMedium?.color?.withOpacityExt(0.5),
                ),
              ),
            ],
          ],
        ),
        if (sizeItems.isNotEmpty || extraText != null)
          ObxO(
            rx: sizesMap,
            builder: (context, sizes) {
              final (size, hasUnknown) = _sumSizes(sizeItems, sizes);
              final (sizeYt, hasUnknownYt) = _sumSizes(sizeItemsYt, sizes);
              final buffer = StringBuffer();
              if (extraText != null) buffer.write('$extraText • ');
              if (sizeItems.isNotEmpty) {
                buffer.write('(${size.fileSizeFormatted})');
                if (hasUnknown) buffer.write('?');
                if (sizeItemsYt.isNotEmpty) {
                  buffer.write(' + (${sizeYt.fileSizeFormatted})');
                  if (hasUnknownYt) buffer.write('?');
                }
              }
              return Text(
                buffer.toString(),
                style: textTheme.displaySmall,
              );
            },
          ),
      ],
    );
  }
}

class SyncStatusIconWrapper extends StatelessWidget {
  final IconData icon;
  final double? iconSize;
  final Color? color;
  final bool showDisconnectedDot;

  const SyncStatusIconWrapper({
    super.key,
    this.icon = Broken.cloud_change,
    this.iconSize,
    this.color,
    this.showDisconnectedDot = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.theme.colorScheme.secondary;
    return ObxO(
      rx: SyncDiscovery.serverRunning,
      builder: (context, serverRunning) => ObxO(
        rx: SyncDiscovery.anyDeviceConnected,
        builder: (context, connected) => ObxO(
          rx: SyncDiscovery.anySessionDevice,
          builder: (context, anySessionDevice) {
            final iconWidget = serverRunning
                ? StackedIcon(
                    baseIcon: icon,
                    secondaryIcon: Broken.radar_1,
                    iconSize: iconSize,
                    baseIconColor: color,
                    secondaryIconColor: color,
                    secondaryIconSize: 13.0,
                  )
                : Icon(
                    icon,
                    size: iconSize,
                    color: color,
                  );
            final showDot = connected || (showDisconnectedDot && anySessionDevice);
            if (!showDot) return iconWidget;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                iconWidget,
                Positioned(
                  top: 0.0,
                  right: 0.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected ? Colors.green.withOpacityExt(0.8) : context.theme.colorScheme.onSurface.withOpacityExt(0.4),
                      border: Border.all(
                        color: context.theme.scaffoldBackgroundColor,
                        width: 1.0,
                      ),
                    ),
                    child: const SizedBox(width: 7.0, height: 7.0),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;

  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.green.withOpacityExt(0.8) : context.theme.colorScheme.onSurface.withOpacityExt(0.3),
      ),
      child: const SizedBox(width: 8.0, height: 8.0),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String text;

  const _RoleChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final color = context.theme.colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
        color: color.withOpacityExt(0.12),
        border: Border.all(color: color.withOpacityExt(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        child: Text(
          text,
          style: context.theme.textTheme.displaySmall?.copyWith(fontSize: 11.0),
        ),
      ),
    );
  }
}

class _DeviceInfoColumn extends StatelessWidget {
  final bool isConnected;
  final String name;
  final String? details;

  const _DeviceInfoColumn({
    required this.isConnected,
    required this.name,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final details = this.details;
    return Row(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: _StatusDot(active: isConnected),
        ),
        const SizedBox(width: 8.0),
        Flexible(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              Text(
                name,
                style: context.theme.textTheme.displayMedium,
              ),
              if (details != null && details.isNotEmpty) ...[
                Text(
                  details,
                  style: context.theme.textTheme.displaySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final SyncDeviceView device;
  final void Function() onSend;
  final void Function() onReceive;
  final void Function() onSync;

  const _DeviceCard({
    required this.device,
    required this.onSend,
    required this.onReceive,
    required this.onSync,
  });

  Future<void> _disconnect() async {
    if (device.connectedAsClient) await SyncDiscovery.client.disconnectFromServer(device.deviceId);
    if (device.connectedAsServer) await SyncDiscovery.server.disconnectConnection(device.deviceId);
  }

  // Iterable<NamidaPopupItem> _actionsMenuItems() {
  //   final deviceId = device.deviceId;
  //   final networkDevice = device.networkDevice;
  //   final isBlocked = settings.sync.blockedClientIds.contains(deviceId);
  //   return [
  //     NamidaPopupItem(
  //       icon: Broken.link_1,
  //       title: device.connectedAsClient ? lang.reconnect : lang.connect,
  //       enabled: networkDevice != null,
  //       onTap: () {
  //         if (networkDevice != null) SyncDiscovery.client.connectToServer(networkDevice, forceReconnect: device.connectedAsClient);
  //       },
  //     ),
  //     NamidaPopupItem(
  //       icon: Broken.close_circle,
  //       title: lang.disconnect,
  //       enabled: device.isConnected,
  //       onTap: _disconnect,
  //     ),
  //     isBlocked
  //         ? NamidaPopupItem(
  //             icon: Broken.shield_tick,
  //             title: lang.unblock,
  //             onTap: () => SyncDiscovery.server.unblockConnection(deviceId),
  //           )
  //         : NamidaPopupItem(
  //             icon: Broken.shield_slash,
  //             title: lang.block,
  //             onTap: () => SyncDiscovery.server.blockConnection(deviceId),
  //           ),
  //   ];
  // }

  @override
  Widget build(BuildContext context) {
    final deviceId = device.deviceId;
    final networkDevice = device.networkDevice;
    final details = networkDevice != null ? '${networkDevice.address}:${networkDevice.port}' : device.remoteAddress;
    final isBlocked = settings.sync.blockedClientIds.contains(deviceId);
    // final statusCocolorSchemelor = device.isConnected ? Color.alphaBlend(Colors.green.withOpacityExt(0.5), context.theme.colorScheme.onSurface) : context.theme.colorScheme.onSurface;
    final colorScheme = context.theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: SizedBox(
        width: context.width,
        child: NamidaCoolBox(
          colorScheme: colorScheme,
          reducedColors: true,
          extraVPadding: true,
          vPadding: 10.0,
          builder: (context) => Column(
            children: [
              Row(
                crossAxisAlignment: .start,
                children: [
                  Expanded(
                    child: _DeviceInfoColumn(
                      isConnected: device.isConnected,
                      name: device.displayName,
                      details: details,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  if (device.asClient) _RoleChip(text: lang.server),
                  if (device.asClient && device.asServer) const SizedBox(width: 2.0),
                  if (device.asServer) _RoleChip(text: lang.client),
                  // const SizedBox(width: 4.0),
                  // NamidaPopupWrapper(
                  //   childrenDefault: _actionsMenuItems,
                  // ),
                ],
              ),
              _ReceiveProgress(deviceId: deviceId),
              const SizedBox(height: 12.0),
              _DeviceActionsRow(
                colorScheme: colorScheme,
                actions: [
                  _DeviceAction(
                    title: device.connectedAsClient ? lang.reconnect : lang.connect,
                    enabled: networkDevice != null,
                    onTap: networkDevice == null ? null : () => SyncDiscovery.client.connectToServer(networkDevice, forceReconnect: device.connectedAsClient),
                  ),
                  _DeviceAction(
                    title: lang.disconnect,
                    enabled: device.isConnected,
                    onTap: _disconnect,
                  ),
                  isBlocked
                      ? _DeviceAction(
                          title: lang.unblock,
                          onTap: () => SyncDiscovery.server.unblockConnection(deviceId),
                        )
                      : _DeviceAction(
                          title: lang.block,
                          onTap: () => SyncDiscovery.server.blockConnection(deviceId),
                        ),
                ],
              ),
              const SizedBox(height: 12.0),
              ObxOClass(
                rx: SyncSender.inst,
                builder: (context, sender) {
                  final enabled = device.isConnected;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 8,
                            child: NamidaButton(
                              dense: true,
                              direction: .vertical,
                              minHeight: NamidaButton.kDefaultMinHeight * 1.2,
                              borderRadius: 18.0,
                              icon: Broken.arrow_swap,
                              text: lang.sync,
                              tooltip: () => lang.sync,
                              enabled: enabled,
                              onTap: onSync,
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Expanded(
                            flex: 7,
                            child: NamidaButton(
                              dense: true,
                              direction: .vertical,
                              minHeight: NamidaButton.kDefaultMinHeight * 1.2,
                              borderRadius: 18.0,
                              icon: Broken.received,
                              text: lang.receive,
                              tooltip: () => lang.receive,
                              enabled: enabled,
                              onTap: onReceive,
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Expanded(
                            flex: 7,
                            child: NamidaButton(
                              dense: true,
                              direction: .vertical,
                              minHeight: NamidaButton.kDefaultMinHeight * 1.2,
                              borderRadius: 18.0,
                              icon: Broken.send_2,
                              text: lang.send,
                              tooltip: () => lang.send,
                              enabled: enabled,
                              isLoading: sender.isSendingTo(deviceId),
                              onTap: onSend,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceAction {
  final String title;
  final bool enabled;
  final void Function()? onTap;

  const _DeviceAction({
    required this.title,
    this.enabled = true,
    required this.onTap,
  });
}

class _DeviceActionsRow extends StatelessWidget {
  final Color colorScheme;
  final List<_DeviceAction> actions;

  const _DeviceActionsRow({
    required this.colorScheme,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    const kBrRaw = 8.0;
    return SizedBox(
      width: context.width,
      child: NamidaCoolBox(
        colorScheme: colorScheme,
        reducedColors: true,
        borderRadius: BorderRadius.circular(kBrRaw.multipliedRadius),
        hPadding: 0.0,
        vPadding: 0.0,
        builder: (context) => IntrinsicHeight(
          child: Row(
            children: actions
                .map(
                  (a) => Expanded(
                    child: NamidaInkWell(
                      borderRadius: kBrRaw * 0.75,
                      onTap: a.enabled ? a.onTap : null,
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: a.enabled ? 1.0 : 0.4,
                        child: Text(
                          a.title,
                          textAlign: TextAlign.center,
                          style: context.theme.textTheme.displaySmall,
                        ),
                      ),
                    ),
                  ),
                )
                .addSeparators(
                  skipFirst: 1,
                  separator: const NamidaContainerDivider(
                    height: 12.0,
                    width: 1.5,
                    margin: EdgeInsets.symmetric(horizontal: 2.0),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _ReceiveProgress extends StatelessWidget {
  final String deviceId;

  const _ReceiveProgress({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: SyncDiscovery.batchProgressForDeviceIdRx,
      builder: (context, batchProgressForDeviceIdRx) {
        final batchInfo = batchProgressForDeviceIdRx[deviceId];
        final batchInfoItem = batchInfo?.progressItem;
        if (batchInfo == null || (batchInfo.progress <= 0 && batchInfo.total <= 0)) return const SizedBox();

        final progressRx = SyncDiscovery.receiveProgressOf(deviceId);
        return ObxOrNull(
          rx: progressRx,
          builder: (context, progress) {
            final received = progress?.$1;
            final total = progress?.$2;
            final barValue = received == null || total == null
                ? null
                : received >= total
                ? 1.0
                : received / total;
            return Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.0.multipliedRadius),
                    child: LinearProgressIndicator(
                      borderRadius: BorderRadius.circular(99.0),
                      value: barValue,
                      minHeight: 3.0,
                      backgroundColor: context.theme.colorScheme.onSurface.withOpacityExt(0.1),
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            batchInfoItem == null ? '${batchInfo.progress}/${batchInfo.total}' : '${batchInfo.progress} / ${batchInfo.total} • ${batchInfoItem.toText()}',
                            style: context.theme.textTheme.displaySmall,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4.0),

                      if (received != null)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            '${received.fileSizeFormatted} / ${total?.fileSizeFormatted ?? '?'}',
                            style: context.theme.textTheme.displaySmall,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AvailableDeviceCard extends StatelessWidget {
  final NetworkDevice serverDevice;

  const _AvailableDeviceCard({required this.serverDevice});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      child: SizedBox(
        width: context.width,
        child: NamidaCoolBox(
          colorScheme: context.theme.colorScheme.secondary,
          extraVPadding: true,
          builder: (context) => Row(
            children: [
              Expanded(
                child: _DeviceInfoColumn(
                  isConnected: false,
                  name: serverDevice.deviceName,
                  details: '${serverDevice.address}:${serverDevice.port}',
                ),
              ),
              const SizedBox(width: 8.0),
              NamidaButton(
                icon: Broken.link,
                text: lang.connect,
                onTap: () => SyncDiscovery.client.connectToServer(serverDevice),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedDevicesTile extends StatelessWidget {
  final Set<String> blockedClientIds;

  const _BlockedDevicesTile({required this.blockedClientIds});

  @override
  Widget build(BuildContext context) {
    return NamidaExpansionTile(
      icon: Broken.shield_slash,
      titleText: '${lang.blockedDevices} (${blockedClientIds.length})',
      children: blockedClientIds
          .map(
            (deviceId) => CustomListTile(
              icon: Broken.forbidden_2,
              title: settings.sync.deviceIdNames[deviceId] ?? deviceId,
              subtitle: deviceId,
              trailingRaw: NamidaButton(
                text: lang.unblock,
                onTap: () => SyncDiscovery.server.unblockConnection(deviceId),
              ),
            ),
          )
          .toList(),
    );
  }
}
