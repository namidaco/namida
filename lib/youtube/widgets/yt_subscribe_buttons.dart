// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:like_button/like_button.dart';
import 'package:youtipie/class/channels/channel_info.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class _YTSubscribeButtonManager {
  const _YTSubscribeButtonManager();

  static final _activeChannelInfos = <String, List<RxBaseCore<YoutiPieChannelInfo?>>>{};
  static final _activeModifications = <String, bool>{}.obs;

  static void add(String? channelId, RxBaseCore<YoutiPieChannelInfo?> channelPageRx) {
    if (channelId == null) return;
    _activeChannelInfos.addForce(channelId, channelPageRx);
  }

  static void remove(String? channelId, RxBaseCore<YoutiPieChannelInfo?> channelPageRx) {
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

  static void afterModifySuccess(String? channelId, RxBaseCore<YoutiPieChannelInfo?> channelPageRx) {
    if (channelId == null) return;
    final activeChannels = _activeChannelInfos[channelId];
    if (activeChannels != null) {
      for (var item in activeChannels) {
        item.value?.rebuild(
          newSubscribed: channelPageRx.value?.subscribed,
          newNotifications: channelPageRx.value?.notifications,
          newNotificationParameters: channelPageRx.value?.notificationParameters,
        );
        item.refresh();
      }
    }
  }
}

class YTSubscribeButton extends StatefulWidget {
  final String? channelID;
  final RxBaseCore<YoutiPieChannelInfo?> mainChannelInfo;
  final SubscribeTextDisplayPolicy subscribeTextDisplayPolicy;
  final bool subscribeTextOnLeft;

  const YTSubscribeButton({
    super.key,
    required this.channelID,
    required this.mainChannelInfo,
    this.subscribeTextDisplayPolicy = SubscribeTextDisplayPolicy.always,
    this.subscribeTextOnLeft = false,
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
      mainChannelInfo: widget.mainChannelInfo.value,
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
        title: lang.configure,
        normalTitleStyle: true,
        actions: [
          CancelButtonDisabled(
            disabledRx: isSaving,
          ),
          ObxO(
            rx: tileActiveNoti,
            builder: (context, activeNoti) => ObxO(
              rx: isSaving,
              builder: (context, saving) => NamidaButton(
                enabled: activeNoti != _currentNotificationsStatus && !saving,
                text: lang.save.toUpperCase(),
                isLoading: saving,
                onTap: () async {
                  final notiToActivate = tileActiveNoti.value;
                  if (notiToActivate == null) return;

                  isSaving.value = true;
                  _YTSubscribeButtonManager.onModifyStart(widget.channelID);
                  final res = await YoutiPie.channelAction.changeChannelNotificationStatus(
                    mainChannelInfo: widget.mainChannelInfo.value,
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
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ObxO(
            rx: tileActiveNoti,
            builder: (context, activeNoti) => Column(
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
                ),
              ],
            ),
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
        bodyText: "${lang.confirm}: ${lang.unsubscribe}?",
        actions: [
          const CancelButton(),
          NamidaButton(
            colorScheme: Colors.red,
            text: lang.unsubscribe.toUpperCase(),
            onTap: () async {
              confirmed = true;
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
      ),
    );
    return confirmed;
  }

  Widget? _notificationsToIcon(ChannelNotifications? noti, double iconSize) {
    final colorScheme = context.theme.colorScheme.secondary;
    final foregroundColor = context.defaultIconColor(colorScheme).withOpacityExt(0.75);
    return switch (noti) {
      ChannelNotifications.all => Icon(
        Broken.notification_bing,
        size: iconSize,
        color: foregroundColor,
      ),
      ChannelNotifications.personalized => Icon(
        Broken.notification_1,
        size: iconSize,
        color: foregroundColor,
      ),
      ChannelNotifications.none => StackedIcon(
        baseIcon: Broken.notification_1,
        secondaryIcon: Broken.slash,
        iconSize: iconSize,
        secondaryIconSize: 11.0,
        baseIconColor: foregroundColor,
        secondaryIconColor: foregroundColor,
      ),
      null => null,
    };
  }

  void _showChannelGroupsSheet(String channelID) {
    final info = widget.mainChannelInfo.value;
    final thumbnailUrl = info?.thumbnails.pick()?.url;
    NamidaNavigator.inst.showSheet(
      isScrollControlled: true,
      builder: (context, bottomPadding, maxWidth, maxHeight) => _ChannelGroupsSheet(
        channelID: channelID,
        title: info?.title,
        thumbnailUrl: thumbnailUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subscribed = _currentSubscribed == true;
    const iconSize = 20.0;
    final notificationIcon = _notificationsToIcon(_currentNotificationsStatus, iconSize);

    final canDisplaySubscribeTextWidget = switch (widget.subscribeTextDisplayPolicy) {
      SubscribeTextDisplayPolicy.never => false,
      SubscribeTextDisplayPolicy.always => true,
      SubscribeTextDisplayPolicy.onlyIfNotSubscribed => !subscribed,
    };

    final subscribeTextWidget = canDisplaySubscribeTextWidget
        ? NamidaLoadingSwitcher(
            builder: (loadingController) => NamidaButton(
              dense: true,
              minHeight: NamidaButton.kDefaultMinHeight * 0.9,
              colors: subscribed ? .dimmed : .mid,
              text: subscribed ? lang.subscribed : lang.subscribe,
              onTap: () async {
                final info = widget.mainChannelInfo.value;
                if (info == null) return;
                if (subscribed) {
                  final confirmed = await _confirmUnsubscribe();
                  if (!confirmed) return;
                }
                _onChangeSubscribeStatus(
                  subscribed,
                  loadingController.startLoading,
                  loadingController.stopLoading,
                );
              },
            ),
          )
        : const SizedBox();

    return LongPressDetector(
      enableSecondaryTap: true,
      onLongPress: widget.channelID == null ? null : () => _showChannelGroupsSheet(widget.channelID!),
      child: ObxO(
        rx: _YTSubscribeButtonManager._activeModifications,
        builder: (context, activeModifications) => AnimatedEnabled(
          enabled: activeModifications[widget.channelID] != true && _currentSubscribed != null,
          durationMS: 300,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.subscribeTextOnLeft) subscribeTextWidget,
              Visibility(
                visible: subscribed && notificationIcon != null,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true, // keeps a stable space for the text
                child: NamidaIconButton(
                  horizontalPadding: 8.0,
                  onPressed: () {
                    final info = widget.mainChannelInfo.value;
                    if (info == null) return;
                    _onNotificationsTap();
                  },
                  icon: null,
                  child: notificationIcon,
                ),
              ),
              if (!widget.subscribeTextOnLeft) subscribeTextWidget,
            ],
          ),
        ),
      ),
    );
  }
}

enum SubscribeTextDisplayPolicy {
  never,
  always,
  onlyIfNotSubscribed,
}

// rewritten by claude, new one searches and creates groups inline, shows channel counts, and renames/removes on long-press
class _ChannelGroupsSheet extends StatefulWidget {
  final String channelID;
  final String? title;
  final String? thumbnailUrl;

  const _ChannelGroupsSheet({
    required this.channelID,
    required this.title,
    required this.thumbnailUrl,
  });

  @override
  State<_ChannelGroupsSheet> createState() => _ChannelGroupsSheetState();
}

class _ChannelGroupsSheetState extends State<_ChannelGroupsSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _createError;
  bool _didChangeGroups = false;

  /// kept from opening, so ticking a group doesn't move its tile.
  late final Set<String> _leadingGroups;

  @override
  void initState() {
    super.initState();
    final controller = YoutubeSubscriptionsController.inst;
    final sub = controller.availableChannels.value[widget.channelID];
    _leadingGroups = {...?sub?.groups};
    final title = widget.title;
    if (title != null && controller.fillMissingTitle(widget.channelID, title)) _didChangeGroups = true;
    controller.fillMissingGroupsTitlesFromCache();
  }

  @override
  void dispose() {
    if (_didChangeGroups) YoutubeSubscriptionsController.inst.saveFile();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String text) {
    setState(() {
      _query = text.trim();
      _createError = null;
    });
  }

  String? _validateNewGroup(String group) {
    if (group.isEmpty) return lang.emptyValue;
    final allGroups = YoutubeSubscriptionsController.inst.allGroups.value;
    if (allGroups.contains(group)) return lang.pleaseEnterADifferentName;
    return null;
  }

  void _onGroupTap(String group) {
    _didChangeGroups = true;
    YoutubeSubscriptionsController.inst.toggleChannelGroup(widget.channelID, group, title: widget.title);
  }

  void _onCreateTap() {
    final group = _query;
    final error = _validateNewGroup(group);
    if (error != null) {
      setState(() => _createError = error);
      return;
    }
    _searchController.clear();
    setState(() => _query = '');
    _leadingGroups.add(group);
    YoutubeSubscriptionsController.inst.createGroup(group);
    _onGroupTap(group);
  }

  void _onRenameTap(String group) {
    showNamidaBottomSheetWithTextField(
      title: lang.rename,
      textfieldConfig: BottomSheetTextFieldConfig(
        initalControllerText: group,
        hintText: group,
        labelText: lang.group,
        validator: (value) {
          final name = value?.trim() ?? '';
          if (name.isEmpty) return lang.emptyValue;
          final allGroups = YoutubeSubscriptionsController.inst.allGroups.value;
          if (name != group && allGroups.contains(name)) return lang.pleaseEnterADifferentName;
          return null;
        },
      ),
      buttonText: lang.save,
      onButtonTap: (text) async {
        final newName = text.trim();
        if (newName == group) return true;
        final wasLeading = _leadingGroups.remove(group);
        if (wasLeading) _leadingGroups.add(newName);
        await YoutubeSubscriptionsController.inst.renameGroup(group, newName);
        return true;
      },
    );
  }

  void _onRemoveTap(String group) {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: '${lang.remove}: ${group.addDQuotation()}?',
        actions: [
          const CancelButton(),
          NamidaButton(
            colorScheme: Colors.red,
            text: lang.remove.toUpperCase(),
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              _leadingGroups.remove(group);
              YoutubeSubscriptionsController.inst.removeGroup(group);
            },
          ),
        ],
      ),
    );
  }

  List<NamidaPopupItem> _menuItems(String group) => [
    NamidaPopupItem(
      icon: Broken.edit_2,
      title: lang.rename,
      onTap: () => _onRenameTap(group),
    ),
    NamidaPopupItem(
      icon: Broken.trash,
      title: lang.remove,
      onTap: () => _onRemoveTap(group),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = YoutubeSubscriptionsController.inst;
    final maxHeight = context.height * 0.6;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChannelGroupsSheetHeader(
              channelID: widget.channelID,
              title: widget.title,
              thumbnailUrl: widget.thumbnailUrl,
            ),
            const NamidaContainerDivider(
              margin: EdgeInsets.symmetric(horizontal: 18.0),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
              child: CustomTagTextField(
                controller: _searchController,
                hintText: lang.search,
                labelText: '',
                validator: (_) => _createError,
                validatorMode: AutovalidateMode.always,
                onChanged: _onQueryChanged,
                onFieldSubmitted: (_) => _onCreateTap(),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Broken.search_normal,
                        size: 18.0,
                      ),
                      const SizedBox(
                        width: 8.0,
                      ),
                      NamidaInkWellButton(
                        icon: Broken.add_circle,
                        text: lang.create,
                        onTap: _onCreateTap,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Flexible(
              child: Obx(
                (context) {
                  final allGroups = controller.allGroups.valueR;
                  final channels = controller.availableChannels.valueR;
                  final channelGroups = channels[widget.channelID]?.groups ?? const <String>[];
                  final groupsChannels = controller.getGroupsChannels();
                  final queryLower = _query.toLowerCase();
                  final groups = <String>[];
                  final otherGroups = <String>[];
                  final unmatchedGroups = <String>[];
                  for (final group in allGroups) {
                    final isMatch = queryLower.isEmpty || group.toLowerCase().contains(queryLower);
                    if (!isMatch) {
                      unmatchedGroups.add(group);
                    } else if (_leadingGroups.contains(group)) {
                      groups.add(group);
                    } else {
                      otherGroups.add(group);
                    }
                  }
                  groups.addAll(otherGroups);
                  final matchedCount = groups.length;
                  groups.addAll(unmatchedGroups);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: CustomScrollView(
                      shrinkWrap: true,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
                          sliver: SliverList.builder(
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final group = groups[index];
                              return _ChannelGroupTile(
                                group: group,
                                channels: groupsChannels[group] ?? const [],
                                isActive: channelGroups.contains(group),
                                isDimmed: index >= matchedCount,
                                onTap: () => _onGroupTap(group),
                                menuItems: () => _menuItems(group),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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

class _ChannelGroupsSheetHeader extends StatelessWidget {
  final String channelID;
  final String? title;
  final String? thumbnailUrl;

  const _ChannelGroupsSheetHeader({
    required this.channelID,
    required this.title,
    required this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final controller = YoutubeSubscriptionsController.inst;
    final sub = controller.availableChannels.value[channelID];
    final channelTitle = title ?? sub?.title ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18.0, 24.0, 18.0, 12.0),
      child: Row(
        children: [
          YoutubeThumbnail(
            type: ThumbnailType.channel,
            key: Key(thumbnailUrl ?? ''),
            width: 42.0,
            isImportantInCache: true,
            customUrl: thumbnailUrl,
            urlSymLinkId: channelID,
            isCircle: true,
          ),
          const SizedBox(
            width: 12.0,
          ),
          Expanded(
            child: Text(
              channelTitle,
              style: textTheme.displayLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(
            width: 8.0,
          ),
          _ChannelFavouriteButton(
            channelID: channelID,
            title: title,
          ),
        ],
      ),
    );
  }
}

class _ChannelFavouriteButton extends StatefulWidget {
  final String channelID;
  final String? title;

  const _ChannelFavouriteButton({
    required this.channelID,
    required this.title,
  });

  @override
  State<_ChannelFavouriteButton> createState() => _ChannelFavouriteButtonState();
}

class _ChannelFavouriteButtonState extends State<_ChannelFavouriteButton> {
  final _likeButtonKey = GlobalKey<LikeButtonState>();

  void _onTap() => _likeButtonKey.currentState?.onTap();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final controller = YoutubeSubscriptionsController.inst;
    return ObxO(
      rx: controller.availableChannels,
      builder: (context, channels) {
        final isFavourite = channels[widget.channelID]?.subscribed == true;
        final bgColor = isFavourite ? colorScheme.secondaryContainer : colorScheme.secondaryContainer.withOpacityExt(0.2);
        return NamidaInkWellButton(
          icon: null,
          leading: NamidaRawLikeButton(
            likeButtonKey: _likeButtonKey,
            size: 18.0,
            isLiked: isFavourite,
            removeConfirmationAction: lang.removeFromFavourites,
            onTap: (isLiked) => controller.toggleChannelSubscription(widget.channelID, title: widget.title),
          ),
          text: lang.favourite,
          bgColor: bgColor,
          onTap: _onTap,
        );
      },
    );
  }
}

class _ChannelGroupTile extends StatelessWidget {
  final String group;
  final List<YoutubeSubscription> channels;
  final bool isActive;
  final bool isDimmed;
  final VoidCallback onTap;
  final List<NamidaPopupItem> Function() menuItems;

  const _ChannelGroupTile({
    required this.group,
    required this.channels,
    required this.isActive,
    required this.isDimmed,
    required this.onTap,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final channelsTitles = channels.map((e) => e.title).where((title) => title.isNotEmpty).join(', ');
    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: menuItems,
      child: AnimatedOpacity(
        opacity: isDimmed ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: ListTileWithCheckMark(
            icon: Broken.people,
            titleWidget: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group,
                  style: textTheme.displayMedium,
                ),
                if (channelsTitles.isNotEmpty)
                  Text(
                    channelsTitles,
                    style: textTheme.displaySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            active: isActive,
            trailing: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Text(
                channels.length.formatDecimal(),
                style: textTheme.displaySmall,
              ),
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
