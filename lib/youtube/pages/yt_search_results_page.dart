import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/widgets/yt_channel_card.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeSearchResultsPage extends StatefulWidget {
  final String searchText;
  final void Function(StreamInfoItem video)? onVideoTap;
  const YoutubeSearchResultsPage({super.key, required this.searchText, this.onVideoTap});

  @override
  State<YoutubeSearchResultsPage> createState() => YoutubeSearchResultsPageState();
}

class YoutubeSearchResultsPageState extends State<YoutubeSearchResultsPage> with AutomaticKeepAliveClientMixin<YoutubeSearchResultsPage> {
  @override
  bool get wantKeepAlive => true;

  String get currentSearchText => _latestSearched ?? widget.searchText;
  String? _latestSearched;

  final _searchResult = <dynamic>[];
  bool? _loading;
  @override
  void initState() {
    super.initState();
    fetchSearch();
  }

  Future<void> fetchSearch({String customText = ''}) async {
    _searchResult.clear();
    if (customText == '' && widget.searchText == '') return;
    _loading = true;
    if (mounted) setState(() {});
    final newSearch = customText == '' ? widget.searchText : customText;
    _latestSearched = newSearch;
    final result = await YoutubeController.inst.searchForItems(newSearch);
    _searchResult.addAll(result);
    _loading = false;
    if (mounted) setState(() {});
  }

  Future<void> _fetchSearchNextPage() async {
    if (_searchResult.isEmpty) return; // return if still fetching first results.
    final result = await YoutubeController.inst.searchNextPage();
    _searchResult.addAll(result);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final thumbnailWidth = context.width * 0.36;
    final thumbnailHeight = thumbnailWidth * 9 / 16;
    final thumbnailItemExtent = thumbnailHeight + 8.0 * 2;
    return BackgroundWrapper(
      child: _loading == null
          ? const SizedBox()
          : _loading == true
              ? ThreeArchedCircle(
                  color: CurrentColor.inst.color,
                  size: context.width * 0.4,
                )
              : LazyLoadListView(
                  onReachingEnd: () async => await _fetchSearchNextPage(),
                  listview: (controller) {
                    return ListView.builder(
                      itemExtent: thumbnailItemExtent,
                      padding: kBottomPaddingInsets,
                      itemCount: _searchResult.length,
                      controller: controller,
                      itemBuilder: (context, index) {
                        final item = _searchResult[index];
                        switch (item.runtimeType) {
                          case StreamInfoItem:
                            return YoutubeVideoCard(
                              thumbnailHeight: thumbnailHeight,
                              thumbnailWidth: thumbnailWidth,
                              isImageImportantInCache: false,
                              video: item,
                              playlistID: null,
                              onTap: widget.onVideoTap == null ? null : () => widget.onVideoTap!(item as StreamInfoItem),
                            );
                          case YoutubePlaylist:
                            return YoutubePlaylistCard(
                              playlist: item,
                              thumbnailHeight: thumbnailHeight,
                              thumbnailWidth: thumbnailWidth,
                            );
                          case YoutubeChannel:
                            return YoutubeChannelCard(
                              channel: item,
                              thumbnailSize: context.width * 0.18,
                            );
                        }
                        return const SizedBox();
                      },
                    );
                  },
                ),
    );
  }
}
