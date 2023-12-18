import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_import_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

enum _VideosSorting {
  date,
  views,
  duration,
}

class YoutubeChannelsPage extends StatefulWidget {
  const YoutubeChannelsPage({super.key});

  @override
  State<YoutubeChannelsPage> createState() => _YoutubeChannelsPageState();
}

class _YoutubeChannelsPageState extends State<YoutubeChannelsPage> {
  late final ScrollController _horizontalListController;
  late final ScrollController _uploadsScrollController;

  YoutubeSubscription? _channel;
  final _streamsList = <StreamInfoItem>[];
  final _sorting = _VideosSorting.date.obs;
  final _sortingByTop = true.obs;

  bool _isLoadingInitialStreams = true;
  final _isLoadingMoreUploads = false.obs;
  final _lastLoadingMoreWasEmpty = false.obs;

  final _allChannelsStreamsProgress = 0.0.obs;

  @override
  void initState() {
    _horizontalListController = ScrollController();
    _uploadsScrollController = ScrollController();
    YoutubeSubscriptionsController.inst.sortByLastFetched();
    final sub = YoutubeSubscriptionsController.inst.subscribedChannels.values.lastOrNull;
    _updateChannel(sub);
    super.initState();
  }

  @override
  void dispose() {
    _horizontalListController.dispose();
    _uploadsScrollController.dispose();
    _isLoadingMoreUploads.close();
    _lastLoadingMoreWasEmpty.close();
    _allChannelsStreamsProgress.close();
    _sorting.close();
    super.dispose();
  }

  void _updateChannel(YoutubeSubscription? sub) {
    _lastLoadingMoreWasEmpty.value = false;
    if (_uploadsScrollController.hasClients) _uploadsScrollController.jumpTo(0);
    setState(() {
      _isLoadingInitialStreams = true;
      _channel = sub;
      _streamsList.clear();
    });

    if (sub != null) {
      _fetchChannelStreams(sub);
    } else {
      _fetchAllChannelsStreams(null);
    }
  }

  Future<void> _fetchAllChannelsStreams(DateTime? since) async {
    final streams = <StreamInfoItem>[];
    final ids = YoutubeSubscriptionsController.inst.subscribedChannels.keys.toList();
    final idsLength = ids.length;
    for (int i = 0; i < idsLength; i++) {
      final channelID = ids[i];
      _allChannelsStreamsProgress.value = i / idsLength;
      final st = await YoutubeController.inst.getChannelStreams(channelID);
      printy('p: $i / $idsLength = ${_allChannelsStreamsProgress.value} =>> ${st.length} videos');
      if (_channel != null) {
        _allChannelsStreamsProgress.value = 0.0;
        return;
      }
      YoutubeSubscriptionsController.inst.refreshLastFetchedTime(channelID, saveToStorage: false);
      streams.addAll(st);
    }
    YoutubeSubscriptionsController.inst.sortByLastFetched();
    _allChannelsStreamsProgress.value = 0.0;

    _sortStreams();

    setState(() {
      _isLoadingInitialStreams = false;
      _streamsList.addAll(streams);
    });
  }

  Future<void> _fetchChannelStreams(YoutubeSubscription sub) async {
    final st = await YoutubeController.inst.getChannelStreams(sub.channelID);
    YoutubeSubscriptionsController.inst.refreshLastFetchedTime(sub.channelID);
    setState(() {
      _isLoadingInitialStreams = false;
      if (sub == _channel) {
        _streamsList.addAll(st);
      }
    });
  }

  Future<void> _fetchStreamsNextPage(YoutubeSubscription? sub) async {
    if (_isLoadingMoreUploads.value) return;
    if (_lastLoadingMoreWasEmpty.value) return;

    _isLoadingMoreUploads.value = true;
    final st = await YoutubeController.inst.getChannelStreamsNextPage();
    _isLoadingMoreUploads.value = false;
    if (st.isEmpty) {
      _lastLoadingMoreWasEmpty.value = true;
      return;
    }
    if (sub == _channel) {
      setState(() {
        _streamsList.addAll(st);
      });
    }
  }

  Future<void> _onSubscriptionFileImportTap() async {
    final files = await FilePicker.platform.pickFiles(allowedExtensions: ['csv', 'CSV'], type: FileType.custom);
    final fp = files?.files.firstOrNull?.path;
    if (fp != null) {
      final imported = await YoutubeImportController().importSubscriptions(fp);
      if (imported > 0) {
        snackyy(message: lang.IMPORTED_N_CHANNELS_SUCCESSFULLY.replaceFirst('_NUM_', '$imported'));
      } else {
        snackyy(message: "${lang.CORRUPTED_FILE}\nPlease choose a valid subscriptions.csv file", isError: true);
      }
    }
  }

  void _sortStreams({List<StreamInfoItem>? streams, _VideosSorting? sort, bool? sortingByTop}) {
    sort ??= _sorting.value;
    streams ??= _streamsList;
    sortingByTop ??= _sortingByTop.value;
    switch (sort) {
      case _VideosSorting.date:
        sortingByTop ? streams.sortByReverse((e) => e.date ?? DateTime(0)) : streams.sortBy((e) => e.date ?? DateTime(0));
        break;

      case _VideosSorting.views:
        sortingByTop ? streams.sortByReverse((e) => e.viewCount ?? 0) : streams.sortBy((e) => e.viewCount ?? 0);
        break;

      case _VideosSorting.duration:
        sortingByTop ? streams.sortByReverse((e) => e.duration ?? Duration.zero) : streams.sortBy((e) => e.duration ?? Duration.zero);
        break;

      default:
        null;
    }
    _sorting.value = sort;
    _sortingByTop.value = sortingByTop;
  }

  (String, IconData) _sortToTextAndIcon(_VideosSorting sort) {
    switch (sort) {
      case _VideosSorting.date:
        return (lang.DATE, Broken.calendar);
      case _VideosSorting.views:
        return (lang.VIEWS, Broken.eye);
      case _VideosSorting.duration:
        return (lang.DURATION, Broken.timer_1);
    }
  }

  static const _thumbSize = 48.0;
  double get _listBottomPadding => Dimensions.inst.globalBottomPaddingEffective - 6.0;
  final _listTopPadding = 6.0;
  double get listHeight => _thumbSize + 12 * 2 + _listBottomPadding + _listTopPadding;

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 6.0;

    final thumbnailWidth = context.width * 0.3;
    final thumbnailHeight = thumbnailWidth * 9 / 16;
    final thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    final ch = _channel;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ch == null
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Obx(
                    () => Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ..._VideosSorting.values.map(
                          (e) {
                            final details = _sortToTextAndIcon(e);
                            final enabled = _sorting.value == e;
                            return NamidaInkWell(
                              animationDurationMS: 200,
                              borderRadius: 6.0,
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              margin: const EdgeInsets.symmetric(horizontal: 3.0),
                              bgColor: enabled ? CurrentColor.inst.color : context.theme.cardColor,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  enabled
                                      ? Obx(
                                          () => StackedIcon(
                                            baseIcon: details.$2,
                                            secondaryIcon: _sortingByTop.value ? Broken.arrow_down_2 : Broken.arrow_up_3,
                                            iconSize: 20.0,
                                            secondaryIconSize: 10.0,
                                            blurRadius: 4.0,
                                          ),
                                        )
                                      : Icon(
                                          details.$2,
                                          size: 20.0,
                                        ),
                                  const SizedBox(width: 4.0),
                                  Text(details.$1, style: context.textTheme.displayMedium),
                                ],
                              ),
                              onTap: () => setState(
                                () => _sortStreams(sort: e, sortingByTop: enabled ? !_sortingByTop.value : null),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: NamidaInkWell(
                          borderRadius: 24.0,
                          bgColor: context.theme.cardColor,
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 4.0),
                              YoutubeThumbnail(
                                key: Key(ch.channelID),
                                width: 32.0,
                                isImportantInCache: true,
                                channelUrl: /*  info?.avatarUrl ?? info?.thumbnailUrl ?? */ ch.channelID,
                                channelIDForHQImage: ch.channelID,
                                isCircle: true,
                              ),
                              const SizedBox(width: 8.0),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ch.title,
                                    style: context.textTheme.displayMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (ch.subscribed ?? false)
                                    Text(
                                      lang.SUBSCRIBED,
                                      style: context.textTheme.displaySmall?.copyWith(fontSize: 10.0.multipliedFontScale),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              const SizedBox(width: 8.0),
                              const SizedBox(width: 4.0),
                              const SizedBox(width: 4.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    NamidaButton(
                      text: lang.IMPORT,
                      onPressed: _onSubscriptionFileImportTap,
                    )
                  ],
                ),
        ),
        Expanded(
          child: NamidaScrollbar(
            controller: _uploadsScrollController,
            child: _isLoadingInitialStreams
                ? ShimmerWrapper(
                    shimmerEnabled: true,
                    child: ListView.builder(
                      itemCount: 15,
                      itemBuilder: (context, index) {
                        return const YoutubeVideoCard(
                          isImageImportantInCache: false,
                          video: null,
                          playlistID: null,
                          thumbnailWidthPercentage: 0.8,
                        );
                      },
                    ),
                  )
                : LazyLoadListView(
                    scrollController: _uploadsScrollController,
                    onReachingEnd: () async {
                      await _fetchStreamsNextPage(_channel);
                    },
                    listview: (controller) {
                      return ListView.builder(
                        controller: controller,
                        itemExtent: thumbnailItemExtent,
                        itemCount: _streamsList.length,
                        itemBuilder: (context, index) {
                          final item = _streamsList[index];
                          return YoutubeVideoCard(
                            key: Key("${context.hashCode}_${(item).id}"),
                            thumbnailHeight: thumbnailHeight,
                            thumbnailWidth: thumbnailWidth,
                            isImageImportantInCache: false,
                            video: item,
                            playlistID: null,
                            thumbnailWidthPercentage: 0.8,
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
        Obx(
          () => _isLoadingMoreUploads.value
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      LoadingIndicator(),
                    ],
                  ),
                )
              : const SizedBox(),
        ),
        const NamidaContainerDivider(margin: EdgeInsets.only(left: 8.0, right: 8.0)),
        Container(
          width: context.width,
          height: listHeight,
          padding: EdgeInsets.only(bottom: _listBottomPadding, top: _listTopPadding),
          decoration: BoxDecoration(
            color: Color.alphaBlend(context.theme.scaffoldBackgroundColor.withOpacity(0.4), context.theme.cardTheme.color!),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(12.0.multipliedRadius),
            ),
          ),
          child: Obx(
            () {
              final channelIDS = YoutubeSubscriptionsController.inst.subscribedChannels.keys.toList();
              final totalIDsLength = channelIDS.length;
              return Row(
                children: [
                  NamidaInkWell(
                    borderRadius: 10.0,
                    animationDurationMS: 150,
                    bgColor: _channel == null ? context.theme.colorScheme.secondary.withOpacity(0.15) : null,
                    width: _thumbSize,
                    margin: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                    padding: const EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
                    onTap: () {
                      _updateChannel(null);
                    },
                    child: Column(
                      children: [
                        const SizedBox(height: 4.0),
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: _thumbSize / 2,
                              child: FittedBox(
                                child: Text("$totalIDsLength"),
                              ),
                            ),
                            Positioned.fill(
                              child: FittedBox(
                                child: Obx(
                                  () => CircularProgressIndicator(
                                    value: _allChannelsStreamsProgress.value,
                                    strokeWidth: 2.0,
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          lang.ALL,
                          style: context.textTheme.displaySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _horizontalListController,
                      padding: EdgeInsets.only(right: Dimensions.inst.globalBottomPaddingFAB + 12.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: totalIDsLength,
                      itemExtent: _thumbSize + horizontalPadding * 2,
                      itemBuilder: (context, indexPre) {
                        final index = totalIDsLength - indexPre - 1;
                        final key = channelIDS[index];
                        final ch = YoutubeSubscriptionsController.inst.subscribedChannels[key]!;
                        final info = YoutubeController.inst.fetchChannelDetailsFromCacheSync(ch.channelID);
                        final channelName = info?.name == null || info?.name == '' ? ch.title : info?.name;
                        return NamidaInkWell(
                          borderRadius: 10.0,
                          animationDurationMS: 150,
                          bgColor: _channel == ch ? context.theme.colorScheme.secondary.withOpacity(0.1) : null,
                          width: _thumbSize,
                          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
                          margin: const EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
                          onTap: () => _updateChannel(ch),
                          child: Column(
                            children: [
                              const SizedBox(height: 4.0),
                              YoutubeThumbnail(
                                key: Key(ch.channelID),
                                width: _thumbSize,
                                isImportantInCache: true,
                                channelUrl: info?.avatarUrl ?? info?.thumbnailUrl ?? ch.channelID,
                                channelIDForHQImage: ch.channelID,
                                isCircle: true,
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                channelName ?? '',
                                style: context.textTheme.displaySmall,
                                overflow: TextOverflow.ellipsis,
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
