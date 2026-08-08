import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

class NamidaSyncManagerPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_Sync;

  const NamidaSyncManagerPage({super.key});

  @override
  State<NamidaSyncManagerPage> createState() => _NamidaSyncManagerPageState();
}

class _NamidaSyncManagerPageState extends State<NamidaSyncManagerPage> {
  @override
  void initState() {
    super.initState();
    SyncDiscovery.client.startSearchForServers();
  }

  @override
  void dispose() {
    SyncDiscovery.client.stopSearch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double horizontalMargin = Dimensions.inst.getSettingsHorizontalMargin(context);
    return BackgroundWrapper(
      child: ObxOClass(
        rx: SyncDiscovery.client,
        builder: (context, client) {
          Widget testButton({
            required NetworkDevice serverDevice,
            required String title,
            required Future<BaseMessage> Function(String deviceId) msg,
          }) => NamidaButton(
            text: title,
            onTap: () async {
              final deviceId = await SyncUtils.currentDeviceId;
              await client.sendMessageToServer(
                await msg(deviceId),
                serverDevice,
              );
            },
          );
          return SuperSmoothListView(
            padding: kBottomPaddingInsets.add(EdgeInsets.symmetric(horizontal: horizontalMargin)),
            children: [
              SettingsCard(
                icon: Broken.cloud_connection,
                title: 'Sync',
                subtitle: null,
                trailing: NamidaIconButton(
                  icon: Broken.cpu,
                  onPressed: () {
                    final connectedServersCount = client.connectedDevicesCount;
                    client.sendMessageToAllConnected(
                      PingMessage(
                        messageInfo: BaseMessageInfo.connection('All'),
                        message: 'Hello everynyan, this message is broadcasted to all listeners, yes all $connectedServersCount of you.',
                      ),
                    );
                  },
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 4.0),

                    ObxOClass(
                      rx: SyncDiscovery.server,
                      builder: (context, server) => CustomListTile(
                        icon: Broken.driver_2,
                        title: 'Start Server',
                        subtitle: server.serverWrapper?.buildText(),
                        onTap: server.startServer,
                        trailing: AnimatedShow(
                          isHorizontal: true,
                          show: server.serverWrapper != null,
                          child: NamidaButton(
                            text: lang.stop,
                            onTap: server.stopServer,
                          ),
                        ),
                      ),
                    ),
                    CustomListTile(
                      icon: Broken.global_search,
                      title: 'Search',
                      onTap: client.startSearchForServers,
                      trailing: Row(
                        children: [
                          client.allowAutoRetryDiscovery
                              ? NamidaButton(
                                  text: lang.stop,
                                  isLoading: client.isDiscovering,
                                  onTap: client.stopSearch,
                                )
                              : NamidaButton(
                                  text: lang.start,
                                  onTap: client.startSearchForServers,
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8.0),

                    ...client.availableServers.map(
                      (serverDevice) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                        child: SizedBox(
                          width: context.width,
                          child: NamidaCoolBox(
                            colorScheme: context.theme.colorScheme.primary,
                            extraVPadding: true,
                            builder: (context) => Column(
                              crossAxisAlignment: .start,
                              mainAxisSize: .min,
                              children: [
                                Text(
                                  serverDevice.buildText(),
                                  style: context.theme.textTheme.displaySmall,
                                ),

                                const SizedBox(height: 8.0),
                                Wrap(
                                  spacing: 6.0,
                                  runSpacing: 6.0,
                                  children: [
                                    client.isConnectedToServer(serverDevice)
                                        ? NamidaButton(
                                            text: 'Disconnect',
                                            onTap: () => client.disconnectFromServer(serverDevice.deviceId),
                                          )
                                        : NamidaButton(
                                            text: 'Connect',
                                            onTap: () => client.connectToServer(serverDevice),
                                          ),

                                    testButton(
                                      serverDevice: serverDevice,
                                      title: 'Test',
                                      msg: (deviceId) async {
                                        return PingMessage(
                                          messageInfo: BaseMessageInfo.connection(deviceId),
                                        );
                                      },
                                    ),

                                    testButton(
                                      serverDevice: serverDevice,
                                      title: 'Test Large',
                                      msg: (deviceId) async {
                                        final buffer = StringBuffer();
                                        for (var i = 0; i < 10000; i++) {
                                          buffer.writeln(i);
                                        }

                                        snackyy(message: 'Length: ${buffer.length}');

                                        return PingMessage(
                                          messageInfo: BaseMessageInfo.connection(deviceId),
                                          message: buffer.toString(),
                                        );
                                      },
                                    ),

                                    testButton(
                                      serverDevice: serverDevice,
                                      title: 'Test History 2 (YT)',
                                      msg: (deviceId) async {
                                        final videos = YoutubeHistoryController.inst.historyMap.value.values.firstOrNull ?? [];
                                        return YTHistoryListensMessage(
                                          videos: videos,
                                          messageInfo: BaseMessageInfo.connection(deviceId),
                                        );
                                      },
                                    ),

                                    testButton(
                                      serverDevice: serverDevice,
                                      title: 'Sync History ALL',
                                      msg: (deviceId) async {
                                        final tracks = HistoryController.inst.historyTracks;
                                        return HistoryListensMessage(
                                          tracks: tracks,
                                          messageInfo: BaseMessageInfo.connection(deviceId),
                                        );
                                      },
                                    ),

                                    testButton(
                                      serverDevice: serverDevice,
                                      title: 'Sync History ALL (YT)',
                                      msg: (deviceId) async {
                                        final videos = YoutubeHistoryController.inst.historyTracks;
                                        return YTHistoryListensMessage(
                                          videos: videos,
                                          messageInfo: BaseMessageInfo.connection(deviceId),
                                        );
                                      },
                                    ),

                                    testButton(
                                      serverDevice: serverDevice,
                                      title: 'Sync Playlists',
                                      msg: (deviceId) async {
                                        return RequestMessage(
                                          msgRequestType: .playlistsManifest,
                                          messageInfo: BaseMessageInfo.connection(deviceId),
                                        );
                                      },
                                    ),
                                    testButton(
                                      serverDevice: serverDevice,
                                      title: 'Sync Playlists (YT)',
                                      msg: (deviceId) async {
                                        return RequestMessage(
                                          msgRequestType: .ytPlaylistsManifest,
                                          messageInfo: BaseMessageInfo.connection(deviceId),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4.0),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
