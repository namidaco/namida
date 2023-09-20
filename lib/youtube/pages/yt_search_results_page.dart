import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeSearchResultsPage extends StatefulWidget {
  final String searchText;
  const YoutubeSearchResultsPage({super.key, required this.searchText});

  @override
  State<YoutubeSearchResultsPage> createState() => _YoutubeSearchResultsPageState();
}

class _YoutubeSearchResultsPageState extends State<YoutubeSearchResultsPage> {
  final _searchResult = <dynamic>[];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _fetchSearch();
  }

  Future<void> _fetchSearch() async {
    _searchResult.clear();
    final result = await YoutubeController.inst.searchForItems(widget.searchText);
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
    return BackgroundWrapper(
      child: _loading
          ? ThreeArchedCircle(
              color: CurrentColor.inst.color,
              size: context.width * 0.4,
            )
          : LazyLoadListView(
              onReachingEnd: () async => await _fetchSearchNextPage(),
              listview: (controller) {
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: kBottomPadding),
                  itemCount: _searchResult.length,
                  controller: controller,
                  itemBuilder: (context, index) {
                    final item = _searchResult[index];
                    switch (item.runtimeType) {
                      case StreamInfoItem:
                        return YoutubeVideoCard(
                          video: item,
                          playlistID: null,
                        );
                      case YoutubePlaylist:
                        return YoutubePlaylistCard(playlist: item);
                      case YoutubeChannel:
                        return Text((item as YoutubeChannel).name ?? ''); // TODO: channel card
                    }
                    return const SizedBox();
                  },
                );
              },
            ),
    );
  }
}
