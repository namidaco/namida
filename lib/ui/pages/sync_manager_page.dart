import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
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
  Future<void> _startServer() async {
    try {
      await SyncDiscovery.server.startServer();
    } catch (e) {
      snackyy(title: lang.error, message: e.toString(), isError: true);
    }
  }

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
    settings.sync.syncItems.update(modifier);
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
    final syncItems = settings.sync.syncItems.value;
    return SyncDataItem.values.where(syncItems.contains).toList();
  }

  bool _ensureItemsSelected() {
    final syncItems = settings.sync.syncItems.value;
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
                  child: NamidaText(
                    lang.none,
                    style: NText.medium,
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

  void _openConnectByIpDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: const _ConnectByIpDialog(),
    );
  }

  void _openDiagnosticsDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: const _SyncDiagnosticsDialog(),
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
              settings.sync.customDeviceName.save(newName.nullifyEmpty());
              NamidaNavigator.inst.closeDialog();

              // -- restart to broadcast the new name
              if (SyncDiscovery.server.serverWrapper != null) await _startServer();
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
            final blockedClientIds = settings.sync.blockedClientIds.value;

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
                            onTap: _startServer,
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
                        subtitle: client.lastDiscoveryError == null ? null : '${lang.discoveryFailedTryReenablingNetworkAdapter}\n${client.lastDiscoveryError}',
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
                      ObxO(
                        rx: settings.sync.autoReconnect,
                        builder: (context, autoReconnectDevices) => CustomSwitchListTile(
                          icon: Broken.refresh_circle,
                          title: '${lang.auto} ${lang.reconnect}',
                          value: autoReconnectDevices,
                          onChanged: (isTrue) => settings.sync.autoReconnect.save(!isTrue),
                        ),
                      ),
                      ObxO(
                        rx: settings.sync.autoSyncIntervalMinutes,
                        builder: (context, intervalMinutes) {
                          return CustomListTile(
                            icon: Broken.timer,
                            title: lang.autoSyncInterval,
                            trailing: NamidaWheelSlider(
                              max: _kAutoSyncMaxSteps,
                              initValue: intervalMinutes <= 0 ? 0 : intervalMinutes ~/ 30,
                              onValueChanged: (val) {
                                final intervalMinutes = val <= 0 ? -1 : val * 30;
                                settings.sync.autoSyncIntervalMinutes.save(intervalMinutes);
                                SyncSender.inst.setupAutoSync();
                              },
                              text: _autoSyncIntervalText(intervalMinutes),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4.0),

                      const NamidaContainerDivider(
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NamidaIconButton(
                              icon: Broken.health,
                              iconColor: NColors.defaultIcon(),
                              iconSize: 16.0,
                              horizontalPadding: 4.0,
                              tooltip: () => lang.diagnostics,
                              onPressed: _openDiagnosticsDialog,
                            ),
                            const SizedBox(width: 4.0),
                            NamidaIconButton(
                              icon: Broken.link_21,
                              iconColor: NColors.defaultIcon(),
                              iconSize: 16.0,
                              horizontalPadding: 4.0,
                              tooltip: () => lang.connectByIp,
                              onPressed: _openConnectByIpDialog,
                            ),
                          ],
                        ),
                      ),
                      ...availableNotKnown.map(
                        (serverDevice) => _AvailableDeviceCard(
                          serverDevice: serverDevice,
                        ),
                      ),

                      const SizedBox(height: 4.0),

                      const NamidaContainerDivider(
                        margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      ),

                      const SizedBox(height: 4.0),
                      ObxO(
                        rx: settings.sync.syncItems,
                        builder: (context, syncItems) => _SectionTitle(
                          title: lang.dataToSendAndReceive,
                          count: syncItems.length,
                          total: SyncDataItem.values.length,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              NamidaIconButton(
                                icon: Broken.magicpen,
                                iconColor: NColors.defaultIcon(),
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
                      ObxO(
                        rx: settings.sync.syncItemsAdvancedView,
                        builder: (context, advancedView) => ObxO(
                          rx: settings.sync.syncItems,
                          builder: (context, syncItems) {
                            return advancedView
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
                                    enabled: connectedCount > 0 && syncItems.isNotEmpty,
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
              child: NDecoratedBox(
                decoration: (colors) => BoxDecoration(
                  borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                  color: colors.secondaryContainer.withOpacityExt(0.4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  child: NamidaText(
                    total == null ? '$count' : '$count/$total',
                    style: const NText(.small, weight: FontWeight.w600),
                    color: NColors.primary,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          if (count != null) const SizedBox(width: 6.0),
          Expanded(
            child: NamidaText(
              title,
              style: NText.medium,
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
    return ObxO(
      rx: settings.sync.syncItemsAdvancedView,
      builder: (context, advancedView) {
        return NamidaInkWell(
          borderRadius: 8.0,
          bgColor: advancedView ? const NColors(.secondaryContainer, opacity: 0.5) : null,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          onTap: () => settings.sync.syncItemsAdvancedView.save(!advancedView),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NIcon(
                Broken.setting_4,
                size: 14.0,
                color: NColors.defaultIcon(),
              ),
              const SizedBox(width: 6.0),
              NamidaText(
                lang.advanced,
                style: NText.small,
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
        icon: Broken.setting_2,
        title: lang.settings,
        items: const [SyncDataItem.settingsGeneral, SyncDataItem.settingsPlayer],
        itemsYt: const [SyncDataItem.settingsYoutube],
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
              smallChild: NamidaTristateCheckMark(
                size: 12.0,
                active: ytAllSelected,
                halfActive: ytPartiallySelected,
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
    final colors = NColorsData.of(context);
    final statusColor = switch (entry.status) {
      SyncActionStatus.inProgress => Colors.orange,
      SyncActionStatus.success => Colors.green,
      SyncActionStatus.failed => Colors.red,
    };
    final colorScheme = Color.alphaBlend(statusColor.withOpacityExt(0.5), colors.onSurface);
    final deviceName = settings.sync.deviceIdNames.value[entry.deviceId] ?? entry.deviceId;
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
                    NamidaText(
                      deviceName,
                      style: NText.medium,
                    ),
                    if (entry.items.isNotEmpty)
                      NamidaText(
                        entry.items.map((e) => e.toText()).join(', '),
                        style: NText.small,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    NamidaText(
                      '${entry.sizeBytes.fileSizeFormatted} • ${entry.count}',
                      style: NText.small,
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
                  NamidaText(
                    entry.timeMS.clockFormatted,
                    style: NText.small,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: NamidaText(
                title,
                style: NText.medium,
              ),
            ),
            if (isHeavy) ...[
              const SizedBox(width: 6.0),
              Tooltip(
                message: lang.performanceNote,
                child: Icon(
                  Broken.danger,
                  size: 14.0,
                  color: NText.medium.of(context).color?.withOpacityExt(0.5),
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
              return NamidaText(
                buffer.toString(),
                style: NText.small,
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
    final color = this.color ?? NColorsData.of(context).secondary;
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
                    baseIconColor: NColors.fixed(color),
                    secondaryIconColor: NColors.fixed(color),
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
                  child: NDecoratedBox(
                    decoration: (colors) => BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected ? Colors.green.withOpacityExt(0.8) : colors.onSurface.withOpacityExt(0.4),
                      border: Border.all(
                        color: colors.scaffold,
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
    return NDecoratedBox(
      decoration: (colors) => BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.green.withOpacityExt(0.8) : colors.onSurface.withOpacityExt(0.3),
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
    return NDecoratedBox(
      decoration: (colors) {
        final color = colors.primary;
        return BoxDecoration(
          borderRadius: BorderRadius.circular(6.0.multipliedRadius),
          color: color.withOpacityExt(0.12),
          border: Border.all(color: color.withOpacityExt(0.3)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        child: NamidaText(
          text,
          style: const NText(.small, size: .s11),
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
              NamidaText(
                name,
                style: NText.medium,
              ),
              if (details != null && details.isNotEmpty) ...[
                NamidaText(
                  details,
                  style: NText.small,
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
    if (device.connectedAsClient || device.isConnectingAsClient) await SyncDiscovery.client.disconnectFromServer(device.deviceId);
    if (device.connectedAsServer) await SyncDiscovery.server.disconnectConnection(device.deviceId);
  }

  // Iterable<NamidaPopupItem> _actionsMenuItems() {
  //   final deviceId = device.deviceId;
  //   final networkDevice = device.networkDevice;
  //   final isBlocked = settings.sync.blockedClientIds.value.contains(deviceId);
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
    final isBlocked = settings.sync.blockedClientIds.value.contains(deviceId);
    final canDisconnect = device.isConnected || device.isConnectingAsClient;
    // final statusCocolorSchemelor = device.isConnected ? Color.alphaBlend(Colors.green.withOpacityExt(0.5), context.theme.colorScheme.onSurface) : context.theme.colorScheme.onSurface;
    final deviceContent = Column(
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
        _DeviceProgress(deviceId: deviceId),
        const SizedBox(height: 12.0),
        _DeviceActionsRow(
          actions: [
            _DeviceAction(
              title: device.connectedAsClient ? lang.reconnect : lang.connect,
              enabled: networkDevice != null,
              onTap: networkDevice == null ? null : () => SyncDiscovery.client.connectToServer(networkDevice, forceReconnect: device.connectedAsClient),
            ),
            _DeviceAction(
              title: lang.disconnect,
              enabled: canDisconnect,
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
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: SizedBox(
        width: context.width,
        child: NBuilder(
          builder: (context, colors) => NamidaCoolBox(
            colorScheme: colors.primary,
            reducedColors: true,
            extraVPadding: true,
            vPadding: 10.0,
            builder: (context) => deviceContent,
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
  final List<_DeviceAction> actions;

  const _DeviceActionsRow({
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    const kBrRaw = 8.0;
    final actionsRow = IntrinsicHeight(
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
                    child: NamidaText(
                      a.title,
                      textAlign: TextAlign.center,
                      style: NText.small,
                    ),
                  ),
                ),
              ),
            )
            .addSeparators(
              separator: const NamidaContainerDivider(
                height: 12.0,
                width: 1.5,
                margin: EdgeInsets.symmetric(horizontal: 2.0),
              ),
            )
            .toList(),
      ),
    );
    return SizedBox(
      width: context.width,
      child: NBuilder(
        builder: (context, colors) => NamidaCoolBox(
          colorScheme: colors.primary,
          reducedColors: true,
          borderRadius: BorderRadius.circular(kBrRaw.multipliedRadius),
          hPadding: 0.0,
          vPadding: 0.0,
          builder: (context) => actionsRow,
        ),
      ),
    );
  }
}

class _DeviceProgress extends StatelessWidget {
  final String deviceId;
  const _DeviceProgress({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: SyncDiscovery.batchProgressOutgoingRx,
      builder: (context, outgoingForDeviceId) => ObxO(
        rx: SyncDiscovery.batchProgressIncomingRx,
        builder: (context, incomingForDeviceId) {
          final outgoing = outgoingForDeviceId[deviceId];
          final incoming = incomingForDeviceId[deviceId];
          if (outgoing == null && incoming == null) return const SizedBox();
          return Column(
            mainAxisSize: .min,
            children: [
              if (outgoing != null)
                _SyncProgressRow(
                  icon: Broken.send_2,
                  info: outgoing,
                ),
              if (incoming != null)
                _SyncProgressRow(
                  icon: Broken.received,
                  info: incoming,
                  // -- only meaningful while bytes are landing on our socket
                  incomingDeviceId: deviceId,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SyncProgressRow extends StatelessWidget {
  final IconData icon;
  final BatchInfoMessage info;
  final String? incomingDeviceId;

  const _SyncProgressRow({
    required this.icon,
    required this.info,
    this.incomingDeviceId,
  });

  Widget _socketProgressText(String incomingDeviceId) {
    final progressRx = SyncDiscovery.receiveProgressOf(incomingDeviceId);
    if (progressRx == null) return const SizedBox();
    return ObxO(
      rx: progressRx,
      builder: (context, progress) => progress == null
          ? const SizedBox()
          : NamidaText(
              '${progress.$1.fileSizeFormatted} / ${progress.$2.fileSizeFormatted}',
              style: NText.small,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headlineItem = info.headlineItem;
    final extraItemsCount = info.extraActiveItemsCount;
    final itemProgress = info.itemProgress;

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 18.0),
                child: NDecoratedBox(
                  decoration: (colors) => BoxDecoration(
                    borderRadius: BorderRadius.circular(4.0.multipliedRadius),
                    color: colors.secondaryContainer.withOpacityExt(0.3),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                    child: Row(
                      mainAxisSize: .min,
                      children: [
                        NIcon(
                          icon,
                          size: 12.0,
                          color: NColors.defaultIcon(),
                        ),
                        const SizedBox(width: 4.0),
                        Flexible(
                          child: NamidaText(
                            '${info.progress}/${info.total}',
                            style: const NText(.small, weight: FontWeight.w500),
                            color: NColors.secondary,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4.0),
              Expanded(
                child: headlineItem == null
                    ? const SizedBox()
                    : NamidaText(
                        extraItemsCount > 0 ? '${headlineItem.toText()} +$extraItemsCount' : headlineItem.toText(),
                        style: NText.small,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              const SizedBox(width: 4.0),
              if (itemProgress != null)
                NamidaText(
                  itemProgress.totalBytes > 0
                      ? '${itemProgress.count}/${itemProgress.totalCount} • ${itemProgress.bytes.fileSizeFormatted} / ${itemProgress.totalBytes.fileSizeFormatted}'
                      : '${itemProgress.count}/${itemProgress.totalCount}',
                  style: const NText(.small, size: .s12),
                )
              else if (incomingDeviceId != null)
                _socketProgressText(incomingDeviceId!),
            ],
          ),
          const SizedBox(height: 6.0),
          NBuilder(
            builder: (context, colors) => LinearProgressIndicator(
              borderRadius: BorderRadius.circular(99.0),
              value: info.overallFraction,
              minHeight: 3.0,
              backgroundColor: colors.onSurface.withOpacityExt(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailableDeviceCard extends StatelessWidget {
  final NetworkDevice serverDevice;

  const _AvailableDeviceCard({required this.serverDevice});

  @override
  Widget build(BuildContext context) {
    final deviceRow = Row(
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
          onTap: () => SyncDiscovery.client.connectToServer(serverDevice).catchError(_showConnectErrorSnack),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      child: SizedBox(
        width: context.width,
        child: NBuilder(
          builder: (context, colors) => NamidaCoolBox(
            colorScheme: colors.secondary,
            extraVPadding: true,
            builder: (context) => deviceRow,
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
      showRail: false,
      children: blockedClientIds
          .map(
            (deviceId) => CustomListTile(
              icon: Broken.forbidden_2,
              title: settings.sync.deviceIdNames.value[deviceId] ?? deviceId,
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

void _showConnectErrorSnack(Object error) {
  snackyy(
    title: lang.error,
    message: '$error',
    isError: true,
  );
}

class _ConnectByIpDialog extends StatefulWidget {
  const _ConnectByIpDialog();

  @override
  State<_ConnectByIpDialog> createState() => _ConnectByIpDialogState();
}

class _ConnectByIpDialogState extends State<_ConnectByIpDialog> {
  final _controller = TextEditingController();
  bool _isConnecting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _controller.text.trim();
    if (host.isEmpty || _isConnecting) return;
    setState(() => _isConnecting = true);
    try {
      await SyncDiscovery.client.connectToAddress(host);
      NamidaNavigator.inst.closeDialog();
      snackyy(
        icon: Broken.link_21,
        message: lang.waitingForTheOtherDeviceToAccept,
        isError: false,
      );
    } catch (e) {
      _showConnectErrorSnack(e);
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBlurryDialog(
      icon: Broken.link_21,
      title: lang.connectByIp,
      normalTitleStyle: true,
      actions: [
        const CancelButton(),
        NamidaButton(
          text: lang.connect,
          isLoading: _isConnecting,
          onTap: _connect,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: NamidaText(
              lang.enterTheAddressShownOnTheOtherDevice,
              style: NText.small,
            ),
          ),
          const SizedBox(height: 12.0),
          const SizedBox(height: 8.0),
          CustomTagTextField(
            controller: _controller,
            hintText: '192.168.1.5',
            labelText: lang.address,
            keyboardType: TextInputType.url,
            autofocus: true,
            onFieldSubmitted: (_) => _connect(),
          ),
        ],
      ),
    );
  }
}

class _SyncDiagnosticsDialog extends StatefulWidget {
  const _SyncDiagnosticsDialog();

  @override
  State<_SyncDiagnosticsDialog> createState() => _SyncDiagnosticsDialogState();
}

class _SyncDiagnosticsDialogState extends State<_SyncDiagnosticsDialog> {
  late final _reportFuture = SyncDiagnostics.run();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _reportFuture,
      builder: (context, snapshot) {
        final report = snapshot.data ?? (snapshot.hasError ? '${snapshot.error}' : null);
        return CustomBlurryDialog(
          icon: Broken.health,
          title: lang.diagnostics,
          normalTitleStyle: true,
          actions: [
            NamidaButton(
              icon: Broken.share,
              text: lang.share,
              enabled: report != null,
              onTap: () => NamidaUtils.shareText(report!),
            ),
            NamidaButton(
              icon: Broken.copy,
              text: lang.copy,
              enabled: report != null,
              onTap: () => NamidaUtils.copyToClipboard(content: report!),
            ),
          ],
          child: SizedBox(
            height: namida.height * 0.5,
            width: namida.width,
            child: report == null
                ? Center(
                    child: NBuilder(
                      builder: (context, colors) => ThreeArchedCircle(
                        color: colors.secondary.withOpacityExt(0.5),
                        size: 48.0,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: SelectableText(
                      report,
                      style: NText.small.of(context).copyWith(fontFamily: 'monospace'),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
