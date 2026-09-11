import 'package:flutter/material.dart';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/lyrics_lrc_parsed_view.dart';
import 'package:namida/packages/miniplayer.dart';
import 'package:namida/packages/miniplayer_base.dart';
import 'package:namida/ui/dialogs/set_lrc_dialog.dart';
import 'package:namida/ui/pages/current_queue_page.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/player_transport_controls.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

enum _WidePlayerPane { lyrics, queue }

// by claude
class WideScreenPlayerPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_widePlayer;

  const WideScreenPlayerPage({super.key});

  @override
  State<WideScreenPlayerPage> createState() => _WideScreenPlayerPageState();
}

class _WideScreenPlayerPageState extends State<WideScreenPlayerPage> {
  final _lrcViewKey = GlobalKey<LyricsLRCParsedViewState>();
  final _artworkMaxWidth = ValueNotifier<double>(0.0);
  late final Rx<_WidePlayerPane> _selectedPane;

  static const _paneGap = 26.0;
  static const _edgePadding = 16.0;

  @override
  void initState() {
    super.initState();
    final savedIndex = settings.extra.widePlayerPageIndex;
    final savedPane = savedIndex != null && savedIndex >= 0 && savedIndex < _WidePlayerPane.values.length ? _WidePlayerPane.values[savedIndex] : _WidePlayerPane.lyrics;
    _selectedPane = savedPane.obs;
    if (savedPane == _WidePlayerPane.lyrics && !settings.enableLyrics.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _enableLyrics());
    }
    NamidaNavigator.inst.isInWideScreenPlayerPage = true;
    MiniPlayerController.inst.screenValuesVersion.addListener(_screenValuesListener);
  }

  @override
  void dispose() {
    MiniPlayerController.inst.screenValuesVersion.removeListener(_screenValuesListener);
    NamidaNavigator.inst.isInWideScreenPlayerPage = false;
    _selectedPane.close();
    _artworkMaxWidth.dispose();
    super.dispose();
  }

  bool _closeScheduled = false;

  void _screenValuesListener() {
    if (_closeScheduled) return;
    _closeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _closeScheduled = false;
      if (!mounted || Dimensions.inst.miniplayerIsWideScreen) return;
      final route = ModalRoute.of(context);
      // -- remove directly to avoid animations
      if (route != null) Navigator.of(context).removeRoute(route);
    });
  }

  void _enableLyrics() {
    final currentItem = Player.inst.currentItem.value;
    if (currentItem == null) return;
    settings.save(enableLyrics: true);
    Lyrics.inst.updateLyrics(currentItem);
  }

  void _onPaneChanged(_WidePlayerPane pane) {
    if (_selectedPane.value == pane) return;
    _selectedPane.value = pane;
    settings.extra.save(widePlayerPageIndex: pane.index);
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 4.0,
              left: 4.0,
              child: IconButton(
                tooltip: lang.exit,
                icon: Icon(
                  Broken.arrow_left_2,
                  size: 22.0,
                  color: context.defaultIconColor(),
                ),
                onPressed: NamidaNavigator.inst.popRoot,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(_edgePadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: _LeftPane(artworkMaxWidth: _artworkMaxWidth),
                  ),
                  const SizedBox(width: _paneGap),
                  Expanded(
                    flex: 5,
                    child: _RightPane(
                      selectedPane: _selectedPane,
                      onPaneChanged: _onPaneChanged,
                      lrcViewKey: _lrcViewKey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeftPane extends StatelessWidget {
  final ValueNotifier<double> artworkMaxWidth;

  const _LeftPane({required this.artworkMaxWidth});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Player.inst.currentItem,
      builder: (context, currentItem) {
        if (currentItem == null) return const SizedBox();
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight;
            final verticalGap = (maxHeight * 0.02).clampDouble(6.0, 16.0);
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxHeight),
                child: Column(
                  children: [
                    _TrackInfoText(item: currentItem),
                    SizedBox(height: verticalGap),
                    Expanded(
                      child: _Artwork(
                        item: currentItem,
                        artworkMaxWidth: artworkMaxWidth,
                      ),
                    ),
                    SizedBox(height: verticalGap),
                    PlayerTransportControls(
                      addBottomSafePadding: false,
                      waveformHeight: (maxHeight * 0.075).clampDouble(28.0, 64.0),
                      waveformBottomGap: verticalGap * 0.75,
                      bottomPadding: verticalGap * 0.5,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Artwork extends StatelessWidget {
  final Playable item;
  final ValueNotifier<double> artworkMaxWidth;

  const _Artwork({required this.item, required this.artworkMaxWidth});

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final videoInfo = Player.inst.videoPlayerInfo.valueR;
        final scaleHeadroom = MiniplayerThumbnailScale.resolveBase(
          isInversed: settings.animatingThumbnailInversed.valueR,
          userScaleMultiplier: settings.animatingThumbnailScaleMultiplier.valueR,
        ).withMinimum(1.0);
        return ObxOSelect(
          rx: ArtworkWidget.aspectRatiosVersion,
          selector: (_) => ArtworkWidget.aspectRatioOf(playableArtworkCacheKey(item)),
          builder: (context, artworkAspectRatio) => LayoutBuilder(
            builder: (context, constraints) {
              final aspectRatio = resolvePlayableImageAspectRatio(item, videoInfo?.aspectRatio);
              final availableWidth = constraints.maxWidth / scaleHeadroom;
              final availableHeight = constraints.maxHeight / scaleHeadroom;
              final boxWidth = availableWidth.withMaximum(availableHeight * aspectRatio);
              final boxHeight = boxWidth / aspectRatio;
              if (artworkMaxWidth.value != boxWidth) {
                WidgetsBinding.instance.addPostFrameCallback((_) => artworkMaxWidth.value = boxWidth);
              }
              return Center(
                child: SizedBox(
                  width: boxWidth,
                  height: boxHeight,
                  child: MiniplayerArtwork(
                    item: item,
                    maxWidth: artworkMaxWidth,
                    showLyricsOverlay: false,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TrackInfoText extends StatelessWidget {
  final Playable item;

  const _TrackInfoText({required this.item});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final title =
        item.execute(
          selectable: (finalItem) => finalItem.track.title,
          youtubeID: (finalItem) => YoutubeInfoController.utils.getVideoNameSync(finalItem.id) ?? finalItem.id,
        ) ??
        '';
    final subtitle =
        item.execute(
          selectable: (finalItem) => finalItem.track.originalArtist,
          youtubeID: (finalItem) => YoutubeInfoController.utils.getVideoChannelNameSync(finalItem.id) ?? '',
        ) ??
        '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: textTheme.displayLarge,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != '') ...[
          const SizedBox(height: 4.0),
          Text(
            subtitle,
            style: textTheme.displaySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _PlayerActionsRow extends StatelessWidget {
  final double bottomPadding;

  const _PlayerActionsRow({required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        children: [
          const Expanded(
            child: _VideoAudioChip(),
          ),
          const SizedBox(width: 2.0),
          RepeatModeIconButton(
            iconSize: 20.0,
          ),
          const SizedBox(width: 2.0),
          SoundControlButton(
            iconSize: 21.0,
          ),
          const SizedBox(width: 2.0),
          LongPressDetector(
            enableSecondaryTap: true,
            onLongPress: () {
              final currentItem = Player.inst.currentItem.value;
              if (currentItem == null) return;
              showLRCSetDialog(currentItem, CurrentColor.inst.miniplayerColor);
            },
            child: MPCustomIconButton(
              tooltipCallback: null,
              onPressed: <T extends Playable>() {
                final currentItem = Player.inst.currentItem.value;
                if (currentItem == null) return;
                // -- we already in view that is for lyrics.. if they don't want then just select queue and disable lyrics outside
                showLRCSetDialog(currentItem, CurrentColor.inst.miniplayerColor);

                // settings.save(enableLyrics: !settings.enableLyrics.value);
                // Lyrics.inst.updateLyrics(currentItem);
              },
              icon: NamidaMiniPlayerBase.getLrcButton(
                context.theme,
                iconSize: 20.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoAudioChip extends StatefulWidget {
  const _VideoAudioChip();

  @override
  State<_VideoAudioChip> createState() => _VideoAudioChipState();
}

class _VideoAudioChipState extends State<_VideoAudioChip> {
  final _isMenuOpened = false.obs;

  @override
  void dispose() {
    _isMenuOpened.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Player.inst.currentItem,
      builder: (context, currentItem) {
        if (currentItem == null) return const SizedBox();
        final options = miniplayerFocusedMenuOptionsFor(context, currentItem);
        if (options == null) return const SizedBox();
        return PlayerVideoAudioChip(
          focusedMenuOptions: options,
          currentItem: currentItem,
          isMenuOpened: _isMenuOpened,
          menuWidth: (context) => (context.width * 0.28).withMinimum(240.0),
        );
      },
    );
  }
}

class _RightPane extends StatelessWidget {
  final Rx<_WidePlayerPane> selectedPane;
  final void Function(_WidePlayerPane pane) onPaneChanged;
  final GlobalKey<LyricsLRCParsedViewState> lrcViewKey;

  const _RightPane({required this.selectedPane, required this.onPaneChanged, required this.lrcViewKey});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final verticalGap = (constraints.maxHeight * 0.015).clampDouble(4.0, 12.0);
        return Column(
          children: [
            _PlayerActionsRow(bottomPadding: verticalGap),
            Padding(
              padding: EdgeInsets.only(left: 12.0, bottom: verticalGap),
              child: ObxO(
                rx: selectedPane,
                builder: (context, currentPane) => Row(
                  children: [
                    _PaneChip(
                      title: lang.lyrics,
                      icon: Broken.message_text,
                      enabled: currentPane == _WidePlayerPane.lyrics,
                      onTap: () => onPaneChanged(_WidePlayerPane.lyrics),
                    ),
                    const SizedBox(width: 8.0),
                    _PaneChip(
                      title: lang.queue,
                      icon: Broken.row_vertical,
                      enabled: currentPane == _WidePlayerPane.queue,
                      onTap: () => onPaneChanged(_WidePlayerPane.queue),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ObxO(
                rx: selectedPane,
                builder: (context, currentPane) => IndexedStack(
                  index: currentPane.index,
                  sizing: StackFit.expand,
                  children: [
                    LyricsLRCParsedView(
                      key: lrcViewKey,
                      videoOrImage: const SizedBox(),
                      isFullScreenView: false,
                      useSafeArea: false,
                      allowOverflow: false,
                    ),
                    const HeroMode(
                      enabled: false,
                      child: CurrentQueueList(addPageBottomPadding: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PaneChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool enabled;
  final void Function() onTap;

  const _PaneChip({
    required this.title,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Expanded(
      child: NamidaInkWell(
        onTap: onTap,
        borderRadius: 8.0,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        bgColor: enabled ? theme.cardColor : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18.0,
              color: enabled ? theme.colorScheme.onSurface : theme.disabledColor,
            ),
            const SizedBox(width: 6.0),
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.displayMedium?.copyWith(
                  color: enabled ? theme.colorScheme.onSurface : theme.disabledColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
