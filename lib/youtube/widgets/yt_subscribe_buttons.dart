import 'package:flutter/material.dart';
import 'package:youtipie/class/channels/channel_page_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

class _YTSubscribeButtonManager {
  const _YTSubscribeButtonManager();

  static final _activeChannelInfos = <String, List<RxBaseCore<YoutiPieChannelPageResult?>>>{};
  static final _activeModifications = <String, bool>{}.obs;

  static void add(String? channelId, RxBaseCore<YoutiPieChannelPageResult?> channelPageRx) {
    if (channelId == null) return;
    _activeChannelInfos.addForce(channelId, channelPageRx);
  }

  static void remove(String? channelId, RxBaseCore<YoutiPieChannelPageResult?> channelPageRx) {
    if (channelId == null) return;
    _activeChannelInfos[channelId]?.remove(channelPageRx);
    if (_activeChannelInfos[channelId]?.isEmpty == true) _activeChannelInfos.remove(channelId);
  }

  static void onModifyStart(String? channelId) {
    if (channelId == null) return;
    _activeModifications[channelId] = true;
  }

  static void onModifyDone(String? channelId) {
    if (channelId == null) return;
    _activeModifications[channelId] = false;
  }

  static void afterModifySuccess(String? channelId, RxBaseCore<YoutiPieChannelPageResult?> channelPageRx) {
    if (channelId == null) return;
    _activeChannelInfos[channelId]?.loop(
      (item) {
        item.value?.rebuild(
          newSubscribed: channelPageRx.value?.subscribed,
          newNotifications: channelPageRx.value?.notifications,
          newNotificationParameters: channelPageRx.value?.notificationParameters,
        );
        item.refresh();
      },
    );
  }
}

class YTSubscribeButton extends StatefulWidget {
  final String? channelID;
  final RxBaseCore<YoutiPieChannelPageResult?> mainChannelInfo;

  const YTSubscribeButton({
    super.key,
    required this.channelID,
    required this.mainChannelInfo,
  });

  @override
  State<YTSubscribeButton> createState() => _YTSubscribeButtonState();
}

class _YTSubscribeButtonState extends State<YTSubscribeButton> {
  late bool? _currentSubscribed;
  late ChannelNotifications? _currentNotificationsStatus;

  void _onPageChanged() {
    if (mounted) {
      final channelInfo = widget.mainChannelInfo.value;
      setState(() {
        _currentSubscribed = channelInfo?.subscribed;
        _currentNotificationsStatus = channelInfo?.notifications;
      });
    }
  }

  Future<bool> _onChangeSubscribeStatus(bool isSubscribed, void Function() onStart, void Function() onEnd) async {
    final channelInfo = widget.mainChannelInfo.value;
    if (channelInfo == null) return isSubscribed;

    onStart();
    _YTSubscribeButtonManager.onModifyStart(widget.channelID);
    final res = await YoutiPie.channelAction.changeSubscribeStatus(
      mainChannelPage: widget.mainChannelInfo.value,
      channelEngagement: channelInfo.channelEngagement,
      subscribe: !isSubscribed,
    );
    _YTSubscribeButtonManager.onModifyDone(widget.channelID);
    onEnd();
    if (res != null) {
      _YTSubscribeButtonManager.afterModifySuccess(widget.channelID, widget.mainChannelInfo);
      refreshState(() {
        _currentSubscribed = res.isNowSubbed;
        _currentNotificationsStatus = res.newNotificationStatus;
      });
      return !isSubscribed;
    }

    return isSubscribed;
  }

  void _onNotificationsTap() async {
    final tileActiveNoti = _currentNotificationsStatus.obs;
    final isSaving = false.obs;

    await NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        tileActiveNoti.close();
        isSaving.close();
      },
      dialog: CustomBlurryDialog(
        title: lang.CONFIGURE,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          ObxO(
            rx: tileActiveNoti,
            builder: (activeNoti) => ObxO(
              rx: isSaving,
              builder: (saving) => NamidaButton(
                enabled: activeNoti != null && !saving,
                text: lang.SAVE.toUpperCase(),
                textWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (saving) const LoadingIndicator(),
                    if (saving) const SizedBox(width: 4.0),
                    NamidaButtonText(lang.SAVE.toUpperCase()),
                  ],
                ),
                onPressed: () async {
                  final notiToActivate = tileActiveNoti.value;
                  if (notiToActivate == null) return;

                  isSaving.value = true;
                  _YTSubscribeButtonManager.onModifyStart(widget.channelID);
                  final res = await YoutiPie.channelAction.changeChannelNotificationStatus(
                    mainChannelPage: widget.mainChannelInfo.value,
                    notifications: notiToActivate,
                  );
                  _YTSubscribeButtonManager.onModifyDone(widget.channelID);
                  isSaving.value = false;
                  if (res == true) {
                    _YTSubscribeButtonManager.afterModifySuccess(widget.channelID, widget.mainChannelInfo);
                    refreshState(() => _currentNotificationsStatus = notiToActivate);
                    NamidaNavigator.inst.closeDialog();
                  }
                },
              ),
            ),
          ),
        ],
        child: ObxO(
          rx: tileActiveNoti,
          builder: (activeNoti) => Column(
            children: [
              ...ChannelNotifications.values.map(
                (e) {
                  return Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: ListTileWithCheckMark(
                      leading: _notificationsToIcon(e, 24.0),
                      title: e.toText(),
                      active: e == activeNoti,
                      onTap: () => tileActiveNoti.value = e,
                    ),
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    _YTSubscribeButtonManager.add(widget.channelID, widget.mainChannelInfo);
    _onPageChanged(); // fill initial values
    widget.mainChannelInfo.addListener(_onPageChanged);
    super.initState();
  }

  @override
  void dispose() {
    _YTSubscribeButtonManager.remove(widget.channelID, widget.mainChannelInfo);
    widget.mainChannelInfo.removeListener(_onPageChanged);
    super.dispose();
  }

  Future<bool> _confirmUnsubscribe() async {
    bool confirmed = false;
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: lang.CONFIRM,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.REMOVE.toUpperCase(),
            onPressed: () async {
              NamidaNavigator.inst.closeDialog();
              confirmed = true;
            },
          ),
        ],
      ),
    );
    return confirmed;
  }

  Widget? _notificationsToIcon(ChannelNotifications? noti, double iconSize) {
    return switch (noti) {
      ChannelNotifications.all => Icon(
          Broken.notification_bing,
          size: iconSize,
          color: context.defaultIconColor(),
        ),
      ChannelNotifications.personalized => Icon(
          Broken.notification_1,
          size: iconSize,
          color: context.defaultIconColor(),
        ),
      ChannelNotifications.none => StackedIcon(
          baseIcon: Broken.notification_1,
          secondaryIcon: Broken.slash,
          iconSize: iconSize,
          secondaryIconSize: 11.0,
        ),
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final subscribed = _currentSubscribed == true;
    const iconSize = 20.0;
    final notificationIcon = _notificationsToIcon(_currentNotificationsStatus, iconSize);

    return ObxO(
      rx: _YTSubscribeButtonManager._activeModifications,
      builder: (activeModifications) => AnimatedEnabled(
        enabled: activeModifications[widget.channelID] != true && _currentSubscribed != null,
        durationMS: 300,
        child: Row(
          children: [
            if (subscribed && notificationIcon != null)
              NamidaLoadingSwitcher(
                size: iconSize,
                builder: (startLoading, stopLoading, isLoading) => NamidaIconButton(
                  horizontalPadding: 4.0,
                  onPressed: () {
                    final info = widget.mainChannelInfo.value;
                    if (info == null) return;
                    _onNotificationsTap();
                  },
                  icon: null,
                  child: notificationIcon,
                ),
              ),
            NamidaLoadingSwitcher(
              size: 24.0,
              builder: (startLoading, stopLoading, isLoading) => TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Color.alphaBlend(Colors.grey.withOpacity(subscribed ? 0.6 : 0.0), context.theme.colorScheme.primary),
                ),
                child: NamidaButtonText(
                  subscribed ? lang.SUBSCRIBED : lang.SUBSCRIBE,
                ),
                onPressed: () async {
                  final info = widget.mainChannelInfo.value;
                  if (info == null) return;
                  if (subscribed) {
                    final confirmed = await _confirmUnsubscribe();
                    if (!confirmed) return;
                  }
                  _onChangeSubscribeStatus(
                    subscribed,
                    startLoading,
                    stopLoading,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class YTSubscribeButtonLocal extends StatelessWidget {
  final String? channelID;
  const YTSubscribeButtonLocal({super.key, required this.channelID});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: YoutubeSubscriptionsController.inst.availableChannels,
      builder: (availableChannels) {
        final disabled = channelID == null;
        final subscribed = availableChannels[channelID ?? '']?.subscribed ?? false;
        return AnimatedOpacity(
          opacity: disabled ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Color.alphaBlend(Colors.grey.withOpacity(subscribed ? 0.6 : 0.0), context.theme.colorScheme.primary),
            ),
            child: Row(
              children: [
                Icon(subscribed ? Broken.tick_square : Broken.video, size: 20.0),
                const SizedBox(width: 8.0),
                NamidaButtonText(
                  subscribed ? lang.SUBSCRIBED : lang.SUBSCRIBE,
                ),
              ],
            ),
            onPressed: () async {
              final chid = channelID;
              if (chid != null) {
                await YoutubeSubscriptionsController.inst.toggleChannelSubscription(chid);
              }
            },
          ),
        );
      },
    );
  }
}
