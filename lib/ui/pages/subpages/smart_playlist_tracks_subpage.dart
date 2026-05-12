import 'package:flutter/material.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class SmartPlaylistTracksPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.SUBPAGE_smartPlaylistTracks;

  @override
  String get name => smartPlaylist.name;

  final SmartPlaylist smartPlaylist;

  const SmartPlaylistTracksPage({
    super.key,
    required this.smartPlaylist,
  });

  @override
  State<SmartPlaylistTracksPage> createState() => _SmartPlaylistTracksPageState();
}

class _SmartPlaylistTracksPageState extends State<SmartPlaylistTracksPage> with TickerProviderStateMixin, PullToRefreshMixin {
  final _controller = ScrollController();

  var _tracks = <Track>[];

  void _reFetchTracks() {
    setState(() {
      _tracks = widget.smartPlaylist.resolve();
    });
  }

  @override
  void initState() {
    _reFetchTracks();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final queueSource = QueueSource.smartPlaylist(name);
    return BackgroundWrapper(
      child: PullToRefreshWidget(
        state: this,
        controller: _controller,
        onRefresh: () async => _reFetchTracks(),
        child: NamidaTracksList(
          scrollController: _controller,
          infoBox: (maxWidth) => SubpageInfoContainer(
            maxWidth: maxWidth,
            source: queueSource,
            title: name,
            subtitle: [
              _tracks.length.displayTrackKeyword,
              _tracks.totalDurationFormatted,
            ].join(' - '),
            heroTag: '',
            imageBuilder: (size) => MultiArtworkContainer(
              heroTag: '',
              size: size,
              tracks: _tracks.toImageTracks(),
            ),
            tracksFn: () => _tracks,
          ),
          queueLength: _tracks.length,
          queueSource: queueSource,
          queue: _tracks,
        ),
      ),
    );
  }
}
