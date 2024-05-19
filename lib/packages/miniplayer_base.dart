// ignore_for_file: unused_element
// This is originally a part of [Tear Music](https://github.com/tearone/tearmusic), edited to fit Namida.
// Credits goes for the original author @55nknown

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/focused_menu.dart';
import 'package:namida/packages/miniplayer_raw.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/pages/equalizer_page.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/waveform.dart';

class FocusedMenuOptions<E> {
  final bool Function(E currentItem) onOpen;
  final void Function(E currentItem) onPressed;
  final Widget Function(E currentItem, double size, Color color) videoIconBuilder;
  final Widget Function(E currentItem) builder;
  final RxList<NamidaVideo> localVideos;
  final String? Function(E item) currentId;
  final RxList<VideoOnlyStream> streamVideos;
  final Future<void> Function(E item)? loadQualities;
  final Future<void> Function(E item, NamidaVideo video) onLocalVideoTap;
  final Future<void> Function(E item, String? videoId, VideoOnlyStream stream, File? cacheFile) onStreamVideoTap;

  const FocusedMenuOptions({
    required this.onOpen,
    required this.onPressed,
    required this.videoIconBuilder,
    required this.builder,
    required this.currentId,
    required this.localVideos,
    required this.streamVideos,
    required this.loadQualities,
    required this.onLocalVideoTap,
    required this.onStreamVideoTap,
  });
}

class MiniplayerTextData {
  final String firstLine;
  final String secondLine;
  final bool? isLiked;
  final Future<void> Function(bool isLiked) onLikeTap;
  final void Function(TapUpDetails details) onMenuOpen;
  final IconData likedIcon;
  final IconData normalIcon;

  const MiniplayerTextData({
    required this.firstLine,
    required this.secondLine,
    required this.isLiked,
    required this.onLikeTap,
    required this.onMenuOpen,
    required this.likedIcon,
    required this.normalIcon,
  });
}

class NamidaMiniPlayerBase<E> extends StatefulWidget {
  final List<E> queue;
  final double queueItemExtent;
  final (Widget, Key) Function(BuildContext context, int index, int currentIndex) itemBuilder;
  final int Function(E currentItem)? getDurationMS;
  final String Function(int number) itemsKeyword;
  final void Function(E currentItem) onAddItemsTap;
  final String Function(E currentItem) topText;
  final void Function(E currentItem) onTopTextTap;
  final void Function(E currentItem, TapUpDetails details) onMenuOpen;
  final FocusedMenuOptions<E> focusedMenuOptions;
  final Widget Function(E currentItem) extraActionButton;
  final Widget Function(E item, double cp) imageBuilder;
  final Widget Function(E item, double bcp) currentImageBuilder;
  final MiniplayerTextData Function(E item) textBuilder;
  final bool canShowBuffering;

  const NamidaMiniPlayerBase({
    super.key,
    required this.queue,
    required this.queueItemExtent,
    required this.itemBuilder,
    required this.getDurationMS,
    required this.itemsKeyword,
    required this.onAddItemsTap,
    required this.topText,
    required this.onTopTextTap,
    required this.onMenuOpen,
    required this.focusedMenuOptions,
    required this.extraActionButton,
    required this.imageBuilder,
    required this.currentImageBuilder,
    required this.textBuilder,
    required this.canShowBuffering,
  });

  @override
  State<NamidaMiniPlayerBase<E>> createState() => _NamidaMiniPlayerBaseState<E>();
}

class _NamidaMiniPlayerBaseState<E> extends State<NamidaMiniPlayerBase<E>> {
  final isMenuOpened = false.obs;
  final isLoadingMore = false.obs;
  static const animationDuration = Duration(milliseconds: 150);

  List<E> get _currentQueue => widget.queue;
  E get _getcurrentItem => widget.queue[Player.inst.currentIndex];

  int _getDurationMS(E item) => Player.inst.currentItemDuration?.inMilliseconds ?? widget.getDurationMS?.call(item) ?? 0;

  @override
  void dispose() {
    isMenuOpened.close();
    isLoadingMore.close();
    super.dispose();
  }

  int refine(int index) {
    if (index <= -1) {
      return _currentQueue.length - 1;
    }
    if (index >= _currentQueue.length) {
      return 0;
    }
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final onSecondary = context.theme.colorScheme.onSecondaryContainer;
    const waveformChild = WaveformMiniplayer();

    return Obx(
      () {
        final currentIndex = Player.inst.currentIndex;
        final indminus = refine(currentIndex - 1);
        final indplus = refine(currentIndex + 1);
        final prevItem = _currentQueue.isEmpty ? null : _currentQueue[indminus];
        final currentItem = widget.queue[currentIndex];
        final nextItem = _currentQueue.isEmpty ? null : _currentQueue[indplus];
        final currentDurationInMS = _getDurationMS(currentItem);

        final prevText = prevItem == null ? null : widget.textBuilder(prevItem);
        final currentText = widget.textBuilder(currentItem);
        final nextText = nextItem == null ? null : widget.textBuilder(nextItem);

        final topText = widget.topText(currentItem);
        final videoIconBuilder = widget.focusedMenuOptions.videoIconBuilder(currentItem, 18.0, onSecondary);
        final focusedMenuBuilder = widget.focusedMenuOptions.builder(currentItem);
        final extraActionButton = widget.extraActionButton(currentItem);

        const partyContainersChild = Stack(
          children: [
            NamidaPartyContainer(
              height: 2,
              spreadRadiusMultiplier: 0.8,
            ),
            NamidaPartyContainer(
              width: 2,
              spreadRadiusMultiplier: 0.25,
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: NamidaPartyContainer(
                height: 2,
                spreadRadiusMultiplier: 0.8,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: NamidaPartyContainer(
                width: 2,
                spreadRadiusMultiplier: 0.25,
              ),
            ),
          ],
        );

        final topRowChild = SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: MiniPlayerController.inst.snapToMini,
                  icon: Icon(Broken.arrow_down_2, color: onSecondary),
                  iconSize: 22.0,
                ),
                Expanded(
                  child: NamidaInkWell(
                    borderRadius: 14.0,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    onTap: () => widget.onTopTextTap(_getcurrentItem),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${currentIndex + 1}/${_currentQueue.length}",
                          style: TextStyle(
                            color: onSecondary.withOpacity(.8),
                            fontSize: 12.0.multipliedFontScale,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          topText,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.0.multipliedFontScale, color: onSecondary.withOpacity(.9)),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: TapDetector(
                    onTap: null,
                    initializer: (instance) {
                      void tapUp(TapUpDetails details) => widget.onMenuOpen(_getcurrentItem, details);
                      instance
                        ..onTapUp = tapUp
                        ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.secondary.withOpacity(.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Broken.more, color: onSecondary),
                    ),
                  ),
                  iconSize: 22.0,
                ),
              ],
            ),
          ),
        );

        final positionDurationRowChild = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TapDetector(
              onTap: () => Player.inst.seekSecondsBackward(),
              child: LongPressDetector(
                onLongPress: () => Player.inst.seek(Duration.zero),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(
                        () {
                          final seek = MiniPlayerController.inst.seekValue.value;
                          final diffInMs = seek - Player.inst.nowPlayingPosition;
                          final plusOrMinus = diffInMs < 0 ? '' : '+';
                          final seekText = seek == 0 ? '00:00' : diffInMs.milliSecondsLabel;
                          return Text(
                            "$plusOrMinus$seekText",
                            style: context.textTheme.displaySmall?.copyWith(fontSize: 10.0.multipliedFontScale),
                          ).animateEntrance(
                            showWhen: seek != 0,
                            durationMS: 700,
                            allCurves: Curves.easeInOutQuart,
                          );
                        },
                      ),
                      NamidaHero(
                        tag: 'MINIPLAYER_POSITION',
                        child: Obx(
                          () => Text(
                            Player.inst.nowPlayingPosition.milliSecondsLabel,
                            style: context.textTheme.displaySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TapDetector(
              onTap: () => Player.inst.seekSecondsForward(),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: NamidaHero(
                  tag: 'MINIPLAYER_DURATION',
                  child: Obx(
                    () {
                      final displayRemaining = settings.player.displayRemainingDurInsteadOfTotal.value;
                      final toSubtract = displayRemaining ? Player.inst.nowPlayingPosition : 0;
                      final msToDisplay = currentDurationInMS - toSubtract;
                      final prefix = displayRemaining ? '-' : '';
                      return Text(
                        "$prefix ${msToDisplay.milliSecondsLabel}",
                        style: context.textTheme.displaySmall,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );

        final buttonsRowChild = Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.max,
          children: [
            const RepeatModeIconButton(),
            const EqualizerIconButton(),
            extraActionButton,
            IconButton(
              tooltip: lang.QUEUE,
              visualDensity: VisualDensity.compact,
              style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              padding: const EdgeInsets.all(2.0),
              onPressed: MiniPlayerController.inst.snapToQueue,
              icon: Icon(
                Broken.row_vertical,
                size: 19.0,
                color: context.theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 6.0),
          ],
        );

        final bottomLeftButton = Expanded(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              FocusedMenuHolder(
                menuOpenAlignment: Alignment.bottomLeft,
                bottomOffsetHeight: 12.0,
                leftOffsetHeight: 4.0,
                onMenuOpen: () {
                  final canOpen = widget.focusedMenuOptions.onOpen(_getcurrentItem);
                  isMenuOpened.value = canOpen;
                  return canOpen;
                },
                onMenuClose: () => isMenuOpened.value = false,
                blurSize: 2.0,
                duration: animationDuration,
                animateMenuItems: false,
                menuWidth: context.width * 0.5,
                menuBoxDecoration: BoxDecoration(
                  color: context.theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                ),
                menuWidget: Obx(
                  () {
                    final availableVideos = widget.focusedMenuOptions.localVideos;
                    final ytVideos = widget.focusedMenuOptions.streamVideos.where((s) => s.formatSuffix != 'webm');
                    return ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      children: [
                        if (widget.focusedMenuOptions.loadQualities != null)
                          _MPQualityButton(
                            title: lang.CHECK_FOR_MORE,
                            icon: Broken.chart,
                            bgColor: null,
                            trailing: isLoadingMore.value ? const LoadingIndicator() : null,
                            onTap: () async {
                              isLoadingMore.value = true;
                              await widget.focusedMenuOptions.loadQualities!(currentItem);
                              isLoadingMore.value = false;
                            },
                          ),
                        ...availableVideos.map(
                          (element) {
                            final localOrCache = element.ytID == null ? lang.LOCAL : lang.CACHE;
                            return Obx(
                              () {
                                final isCurrent = element.path == (VideoController.inst.currentVideo.value?.path ?? Player.inst.currentCachedVideo?.path);
                                return _MPQualityButton(
                                  onTap: () => widget.focusedMenuOptions.onLocalVideoTap(currentItem, element),
                                  bgColor: isCurrent ? CurrentColor.inst.miniplayerColor.withAlpha(20) : null,
                                  icon: Broken.video,
                                  title: [
                                    "${element.resolution}p${element.framerateText()}",
                                    localOrCache,
                                  ].join(' • '),
                                  subtitle: [
                                    element.sizeInBytes.fileSizeFormatted,
                                    "${element.bitrate ~/ 1000} kb/s",
                                  ].join(' • '),
                                  trailing: NamidaCheckMark(
                                    active: isCurrent,
                                    size: 12.0,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const NamidaContainerDivider(height: 2.0, margin: EdgeInsets.symmetric(vertical: 6.0)),
                        ...ytVideos.map(
                          (element) {
                            final currentId = widget.focusedMenuOptions.currentId(currentItem);
                            final cacheFile = currentId == null ? null : element.getCachedFile(currentId);
                            final cacheExists = cacheFile != null;
                            return _MPQualityButton(
                              onTap: () => widget.focusedMenuOptions.onStreamVideoTap(currentItem, currentId, element, cacheFile),
                              bgColor: cacheExists ? CurrentColor.inst.miniplayerColor.withAlpha(40) : null,
                              icon: cacheExists ? Broken.tick_circle : Broken.import,
                              title: "${element.resolution} • ${element.sizeInBytes?.fileSizeFormatted}",
                              subtitle: "${element.formatSuffix} • ${element.bitrateText}",
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Obx(
                      () {
                        return AnimatedDecoration(
                          duration: animationDuration,
                          decoration: isMenuOpened.value
                              ? BoxDecoration(
                                  color: context.theme.scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(24.0.multipliedRadius),
                                )
                              : BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                                ),
                          child: TextButton(
                            onPressed: () => widget.focusedMenuOptions.onPressed(_getcurrentItem),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6.0),
                                  decoration: BoxDecoration(
                                    color: context.theme.colorScheme.secondaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: NamidaIconButton(
                                    horizontalPadding: 0.0,
                                    icon: null,
                                    child: videoIconBuilder,
                                    onPressed: () {
                                      String toPercentage(double val) => "${(val * 100).toStringAsFixed(0)}%";

                                      Widget getTextWidget(IconData icon, String title, double value) {
                                        return Row(
                                          children: [
                                            Icon(icon, color: context.defaultIconColor(CurrentColor.inst.miniplayerColor)),
                                            const SizedBox(width: 12.0),
                                            Text(
                                              title,
                                              style: context.textTheme.displayLarge,
                                            ),
                                            const SizedBox(width: 8.0),
                                            Text(
                                              toPercentage(value),
                                              style: context.textTheme.displayMedium,
                                            )
                                          ],
                                        );
                                      }

                                      Widget getSlider({
                                        double min = 0.0,
                                        double max = 2.0,
                                        required double value,
                                        required void Function(double newValue)? onChanged,
                                      }) {
                                        return Slider.adaptive(
                                          min: min,
                                          max: max,
                                          value: value.clamp(min, max),
                                          onChanged: onChanged,
                                          divisions: (max * 100).round(),
                                          label: "${(value * 100).toStringAsFixed(0)}%",
                                        );
                                      }

                                      NamidaNavigator.inst.navigateDialog(
                                        dialog: CustomBlurryDialog(
                                          title: lang.CONFIGURE,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                          actions: [
                                            NamidaIconButton(
                                              icon: Broken.refresh,
                                              onPressed: () {
                                                const val = 1.0;
                                                Player.inst.setPlayerPitch(val);
                                                Player.inst.setPlayerSpeed(val);
                                                Player.inst.setPlayerVolume(val);
                                                settings.player.save(
                                                  pitch: val,
                                                  speed: val,
                                                  volume: val,
                                                );
                                              },
                                            ),
                                            NamidaButton(
                                              text: lang.DONE,
                                              onPressed: () {
                                                NamidaNavigator.inst.closeDialog();
                                              },
                                            )
                                          ],
                                          child: const EqualizerMainSlidersColumn(
                                            verticalInBetweenPadding: 18.0,
                                            tapToUpdate: false,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Flexible(
                                  child: focusedMenuBuilder,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        final bottomRowChild = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
          child: Row(
            children: [
              bottomLeftButton,
              buttonsRowChild,
            ],
          ),
        );

        final queueChild = SafeArea(
          bottom: false,
          child: SizedBox(
            height: context.height,
            width: context.width,
            child: Stack(
              fit: StackFit.loose,
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  height: MiniPlayerController.inst.maxOffset - 100.0 - MiniPlayerController.inst.topInset - 12.0,
                  child: BorderRadiusClip(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32.0.multipliedRadius),
                      topRight: Radius.circular(32.0.multipliedRadius),
                    ),
                    child: Obx(
                      () {
                        final currentIndex = Player.inst.currentIndex;
                        final padding =
                            EdgeInsets.only(bottom: 8.0 + SelectedTracksController.inst.bottomPadding.value + kQueueBottomRowHeight + MediaQuery.paddingOf(context).bottom);

                        return NamidaListView(
                          key: const Key('minikuru'),
                          scrollController: MiniPlayerController.inst.queueScrollController,
                          itemCount: widget.queue.length,
                          itemExtents: List.filled(widget.queue.length, widget.queueItemExtent),
                          onReorderStart: (index) => MiniPlayerController.inst.invokeStartReordering(),
                          onReorderEnd: (index) => MiniPlayerController.inst.invokeDoneReordering(),
                          onReorder: (oldIndex, newIndex) => Player.inst.reorderTrack(oldIndex, newIndex),
                          padding: padding,
                          itemBuilder: (context, i) {
                            final childWK = widget.itemBuilder(context, i, currentIndex);
                            return FadeDismissible(
                              key: Key("Diss_${i}_${childWK.$2}"),
                              onDismissed: (direction) {
                                Player.inst.removeFromQueue(i);
                                MiniPlayerController.inst.invokeDoneReordering();
                              },
                              onUpdate: (details) {
                                final isReordering = details.progress != 0.0;
                                if (isReordering) {
                                  MiniPlayerController.inst.invokeStartReordering();
                                } else {
                                  MiniPlayerController.inst.invokeDoneReordering();
                                }
                              },
                              child: childWK.$1,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  width: context.width,
                  height: kQueueBottomRowHeight + MediaQuery.paddingOf(context).bottom,
                  decoration: BoxDecoration(
                    color: context.theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12.0.multipliedRadius),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0).add(EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom)),
                    child: FittedBox(
                      child: QueueUtilsRow(
                        itemsKeyword: widget.itemsKeyword,
                        onAddItemsTap: () => widget.onAddItemsTap(_getcurrentItem),
                        scrollQueueWidget: Obx(
                          () => NamidaButton(
                            onPressed: MiniPlayerController.inst.animateQueueToCurrentTrack,
                            icon: MiniPlayerController.inst.arrowIcon.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        return MiniplayerRaw(
          builder: (maxOffset, bounceUp, bounceDown, topInset, bottomInset, screenSize, sAnim, sMaxOffset, stParallax, siParallax, p, cp, ip, icp, rp, rcp, qp, qcp, bp, bcp,
              borderRadius, slowOpacity, opacity, fastOpacity, miniplayerbottomnavheight, bottomOffset, navBarHeight) {
            final panelH = (maxOffset + navBarHeight - (100.0 + topInset + 4.0));
            final panelExtra = panelH / 2.25 - navBarHeight - (100.0 + topInset + 4.0);
            final panelFinal = panelH - (panelExtra * (1 - qcp));

            final currentImage = widget.currentImageBuilder(currentItem, bcp);
            final iconBoxSize = (velpy(a: 60.0, b: 80.0, c: rcp) - 8) + 8 * rcp - 8 * icp;
            final iconSize = (velpy(a: 60.0 * 0.5, b: 80.0 * 0.5, c: rp) - 8) + 8 * cp * rcp;
            return Stack(
              children: [
                /// MiniPlayer Body
                Container(
                  color: p > 0 ? Colors.transparent : null, // hit test only when expanded
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Transform.translate(
                      offset: Offset(0, bottomOffset),
                      child: ColoredBox(
                        color: Colors.transparent, // prevents scrolling gap
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6 * (1 - cp * 10 + 9).clamp(0, 1), vertical: 12 * icp),
                          child: SizedBox(
                            height: velpy(a: 82.0, b: panelFinal, c: cp),
                            width: double.infinity,
                            child: AnimatedDecoration(
                              duration: const Duration(milliseconds: kThemeAnimationDurationMS),
                              decoration: BoxDecoration(
                                color: context.theme.scaffoldBackgroundColor,
                                borderRadius: borderRadius,
                                boxShadow: [
                                  BoxShadow(
                                    color: context.theme.shadowColor.withOpacity(0.2 + 0.1 * cp),
                                    blurRadius: 20.0,
                                  )
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.bottomLeft,
                                children: [
                                  Positioned.fill(
                                    child: AnimatedDecoration(
                                      duration: const Duration(milliseconds: kThemeAnimationDurationMS),
                                      // clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        color: CurrentColor.inst.miniplayerColor,
                                        borderRadius: borderRadius,
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(100), CurrentColor.inst.miniplayerColor)
                                                .withOpacity(velpy(a: .38, b: .28, c: icp)),
                                            Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(40), CurrentColor.inst.miniplayerColor)
                                                .withOpacity(velpy(a: .1, b: .22, c: icp)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  /// Smol progress bar
                                  Obx(
                                    () {
                                      final w = currentDurationInMS == 0 ? 0 : Player.inst.nowPlayingPosition / currentDurationInMS;
                                      return Container(
                                        height: 2 * (1 - cp),
                                        width: w > 0 ? ((Get.width * w) * 0.9) : 0,
                                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                                        child: AnimatedDecoration(
                                          duration: const Duration(milliseconds: kThemeAnimationDurationMS),
                                          decoration: BoxDecoration(
                                            color: CurrentColor.inst.miniplayerColor,
                                            borderRadius: BorderRadius.circular(50),
                                            //  color: Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(40), CurrentColor.inst.miniplayerColor)
                                            //   .withOpacity(velpy(a: .3, b: .22, c: icp)),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (settings.enablePartyModeInMiniplayer.value)
                  NamidaOpacity(
                    opacity: cp,
                    child: partyContainersChild,
                  ),

                /// Top Row
                if (rcp > 0.0)
                  Material(
                    type: MaterialType.transparency,
                    child: NamidaOpacity(
                      opacity: rcp,
                      child: Transform.translate(
                        offset: Offset(0, (1 - bp) * -100),
                        child: topRowChild,
                      ),
                    ),
                  ),

                /// Controls
                Material(
                  type: MaterialType.transparency,
                  child: Transform.translate(
                    offset: Offset(
                        0,
                        (bottomOffset +
                                (-maxOffset / 8.8 * bp) +
                                ((-maxOffset + topInset + 80.0) *
                                    (!bounceUp
                                        ? !bounceDown
                                            ? qp
                                            : (1 - bp)
                                        : 0.0))) -
                            (navBarHeight * cp)),
                    child: Padding(
                      padding: EdgeInsets.all(12.0 * icp),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            if (fastOpacity > 0.0)
                              NamidaOpacity(
                                opacity: fastOpacity,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24.0 * (16 * (!bounceDown ? icp : 0.0) + 1)),
                                  child: positionDurationRowChild,
                                ),
                              ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0 * icp, horizontal: 2.0 * (1 - cp)).add(EdgeInsets.only(
                                  right: !bounceDown
                                      ? !bounceUp
                                          ? screenSize.width * rcp / 2 - (80 + 32.0 * 3) * rcp / 1.82 + (qp * 2.0)
                                          : screenSize.width * cp / 2 - (80 + 32.0 * 3) * cp / 1.82
                                      : screenSize.width * bcp / 2 - (80 + 32.0 * 3) * bcp / 1.82 + (qp * 2.0))),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  NamidaIconButton(
                                    icon: Broken.previous,
                                    iconSize: 22.0 + 10 * rcp,
                                    horizontalPadding: 12.0,
                                    verticalPadding: 12.0,
                                    onPressed: MiniPlayerController.inst.snapToPrev,
                                  ),
                                  SizedBox(
                                    key: const Key("playpause"),
                                    height: iconBoxSize,
                                    width: iconBoxSize,
                                    child: Center(
                                      child: Obx(
                                        () {
                                          final isButtonHighlighed = MiniPlayerController.inst.isPlayPauseButtonHighlighted.value;
                                          return TapDetector(
                                            onTap: null,
                                            initializer: (instance) {
                                              instance.onTapDown = (_) => MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = true;
                                              instance.onTapUp = (_) => MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = false;
                                              instance.onTapCancel = () =>
                                                  MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = !MiniPlayerController.inst.isPlayPauseButtonHighlighted.value;
                                              instance.gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
                                            },
                                            child: AnimatedScale(
                                              duration: const Duration(milliseconds: 400),
                                              scale: isButtonHighlighed ? 0.97 : 1.0,
                                              child: AnimatedDecoration(
                                                duration: const Duration(milliseconds: 400),
                                                decoration: BoxDecoration(
                                                  color: isButtonHighlighed
                                                      ? Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(233), Colors.white)
                                                      : CurrentColor.inst.miniplayerColor,
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      CurrentColor.inst.miniplayerColor,
                                                      Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(200), Colors.grey),
                                                    ],
                                                    stops: const [0, 0.7],
                                                  ),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: CurrentColor.inst.miniplayerColor.withAlpha(160),
                                                      blurRadius: 8.0,
                                                      spreadRadius: isButtonHighlighed ? 3.0 : 1.0,
                                                      offset: const Offset(0.0, 2.0),
                                                    ),
                                                  ],
                                                ),
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    IconButton(
                                                      highlightColor: Colors.transparent,
                                                      onPressed: () => Player.inst.togglePlayPause(),
                                                      icon: Padding(
                                                        padding: EdgeInsets.all(6.0 * cp * rcp),
                                                        child: Obx(
                                                          () => AnimatedSwitcher(
                                                            duration: const Duration(milliseconds: 200),
                                                            child: Player.inst.isPlaying
                                                                ? Icon(
                                                                    Broken.pause,
                                                                    size: iconSize,
                                                                    key: const Key("pauseicon"),
                                                                    color: Colors.white.withAlpha(180),
                                                                  )
                                                                : Icon(
                                                                    Broken.play,
                                                                    size: iconSize,
                                                                    key: const Key("playicon"),
                                                                    color: Colors.white.withAlpha(180),
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    if (widget.canShowBuffering)
                                                      IgnorePointer(
                                                        child: Obx(
                                                          () => Player.inst.shouldShowLoadingIndicator
                                                              ? ThreeArchedCircle(
                                                                  color: Colors.white.withAlpha(120),
                                                                  size: iconSize * 1.4,
                                                                )
                                                              : const SizedBox(),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  NamidaIconButton(
                                    icon: Broken.next,
                                    iconSize: 22.0 + 10 * rcp,
                                    horizontalPadding: 12.0,
                                    verticalPadding: 12.0,
                                    onPressed: MiniPlayerController.inst.snapToNext,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                /// Destination selector
                Visibility(
                  maintainState: true,
                  visible: opacity > 0.0,
                  child: NamidaOpacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, -100 * ip),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: SafeArea(
                          child: bottomRowChild,
                        ),
                      ),
                    ),
                  ),
                ),

                /// Track Info
                Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: navBarHeight * cp),
                    child: AnimatedBuilder(
                      animation: sAnim,
                      builder: (context, child) {
                        final leftOpacity = -sAnim.value.clamp(-1.0, 0.0);
                        final rightOpacity = sAnim.value.clamp(0.0, 1.0);
                        return Stack(
                          children: [
                            if (prevText != null && leftOpacity > 0)
                              NamidaOpacity(
                                opacity: leftOpacity,
                                child: Transform.translate(
                                  offset: Offset(-sAnim.value * sMaxOffset / siParallax - sMaxOffset / siParallax, 0),
                                  child: _TrackInfo(
                                    textData: prevText,
                                    p: bp,
                                    cp: bcp,
                                    bottomOffset: bottomOffset,
                                    maxOffset: maxOffset,
                                    screenSize: screenSize,
                                  ),
                                ),
                              ),
                            Opacity(
                              opacity: 1 - sAnim.value.abs(),
                              child: Transform.translate(
                                offset: Offset(
                                    -sAnim.value * sMaxOffset / stParallax + (12.0 * qp),
                                    (-maxOffset + topInset + 102.0) *
                                        (!bounceUp
                                            ? !bounceDown
                                                ? qp
                                                : (1 - bp)
                                            : 0.0)),
                                child: _TrackInfo(
                                  textData: currentText,
                                  p: bp,
                                  cp: bcp,
                                  bottomOffset: bottomOffset,
                                  maxOffset: maxOffset,
                                  screenSize: screenSize,
                                ),
                              ),
                            ),
                            if (nextText != null && rightOpacity > 0)
                              NamidaOpacity(
                                opacity: rightOpacity,
                                child: Transform.translate(
                                  offset: Offset(-sAnim.value * sMaxOffset / siParallax + sMaxOffset / siParallax, 0),
                                  child: _TrackInfo(
                                    textData: nextText,
                                    p: bp,
                                    cp: bcp,
                                    bottomOffset: bottomOffset,
                                    maxOffset: maxOffset,
                                    screenSize: screenSize,
                                  ),
                                ),
                              )
                          ],
                        );
                      },
                    ),
                  ),
                ),

                /// Track Image
                Padding(
                  padding: EdgeInsets.only(bottom: navBarHeight * cp),
                  child: AnimatedBuilder(
                    animation: sAnim,
                    builder: (context, child) {
                      final verticalOffset = !bounceUp ? (-maxOffset + topInset + 108.0) * (!bounceDown ? qp : (1 - bp)) : 0.0;
                      final horizontalOffset = -sAnim.value * sMaxOffset / siParallax;
                      final width = velpy(a: 82.0, b: 92.0, c: qp);
                      final leftOpacity = -sAnim.value.clamp(-1.0, 0.0);
                      final rightOpacity = sAnim.value.clamp(0.0, 1.0);
                      return Stack(
                        children: [
                          if (prevItem != null && leftOpacity > 0)
                            NamidaOpacity(
                              opacity: leftOpacity,
                              child: Transform.translate(
                                offset: Offset(-sAnim.value * sMaxOffset / siParallax - sMaxOffset / siParallax, 0),
                                child: _RawImageContainer(
                                  cp: bcp,
                                  p: bp,
                                  width: width,
                                  screenSize: screenSize,
                                  bottomOffset: bottomOffset,
                                  maxOffset: maxOffset,
                                  child: widget.imageBuilder(prevItem, cp),
                                ),
                              ),
                            ),
                          Opacity(
                            opacity: 1 - sAnim.value.abs(),
                            child: Transform.translate(
                              offset: Offset(horizontalOffset, verticalOffset),
                              child: _RawImageContainer(
                                cp: bcp,
                                p: bp,
                                width: width,
                                screenSize: screenSize,
                                bottomOffset: bottomOffset,
                                maxOffset: maxOffset,
                                child: Padding(
                                  padding: EdgeInsets.all(12.0 * (1 - bcp)),
                                  child: currentImage,
                                ),
                              ),
                            ),
                          ),
                          if (nextItem != null && rightOpacity > 0)
                            NamidaOpacity(
                              opacity: rightOpacity,
                              child: Transform.translate(
                                offset: Offset(-sAnim.value * sMaxOffset / siParallax + sMaxOffset / siParallax, 0),
                                child: _RawImageContainer(
                                  cp: bcp,
                                  p: bp,
                                  width: width,
                                  screenSize: screenSize,
                                  bottomOffset: bottomOffset,
                                  maxOffset: maxOffset,
                                  child: widget.imageBuilder(nextItem, cp),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                /// Slider
                Visibility(
                  maintainState: false,
                  visible: slowOpacity > 0.0,
                  child: Opacity(
                    opacity: slowOpacity,
                    child: Transform.translate(
                      offset: Offset(
                          0,
                          (bottomOffset +
                                  (-maxOffset / 4.4 * p) +
                                  ((-maxOffset + topInset) *
                                      ((!bounceUp
                                          ? !bounceDown
                                              ? qp
                                              : (1 - bp)
                                          : 0.0)) *
                                      0.4)) -
                              (navBarHeight * cp)),
                      child: const Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: waveformChild,
                        ),
                      ),
                    ),
                  ),
                ),

                Visibility(
                  maintainState: true,
                  visible: qp > 0 && !bounceUp,
                  child: Opacity(
                    opacity: qp.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, (1 - qp) * maxOffset * 0.8),
                      child: queueChild,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RawImageContainer extends StatelessWidget {
  const _RawImageContainer({
    Key? key,
    required this.child,
    required this.bottomOffset,
    required this.maxOffset,
    required this.screenSize,
    required this.cp,
    required this.p,
    required this.width,
  }) : super(key: key);

  final Widget child;
  final double width;
  final double bottomOffset;
  final double maxOffset;
  final Size screenSize;
  final double cp;
  final double p;

  @override
  Widget build(BuildContext context) {
    final size = velpy(a: width, b: screenSize.width - 84.0, c: cp);
    final verticalOffset = bottomOffset + (-maxOffset / 2.15 * p.clamp(0, 2));
    return Transform.translate(
      offset: Offset(0, verticalOffset),
      child: Padding(
        padding: EdgeInsets.all(12.0 * (1 - cp)).add(EdgeInsets.only(left: 42.0 * cp)),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            height: size,
            width: size,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  final MiniplayerTextData textData;
  final double cp;
  final double p;
  final Size screenSize;
  final double bottomOffset;
  final double maxOffset;

  const _TrackInfo({
    Key? key,
    required this.textData,
    required this.cp,
    required this.p,
    required this.screenSize,
    required this.bottomOffset,
    required this.maxOffset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double opacity = (inverseAboveOne(p) * 10 - 9).clamp(0, 1);

    return Transform.translate(
      offset: Offset(0, bottomOffset + (-maxOffset / 4.0 * p.clamp(0, 2))),
      child: Padding(
        padding: EdgeInsets.all(12.0 * (1 - cp)).add(EdgeInsets.symmetric(horizontal: 24.0 * cp)),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0).add(EdgeInsets.only(bottom: velpy(a: 0, b: screenSize.width / 9, c: cp))),
            child: SizedBox(
              height: velpy(a: 58.0, b: 82, c: cp),
              child: Row(
                children: [
                  SizedBox(width: 82.0 * (1 - cp)), // Image placeholder
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: 22.0 + 92 * (1 - cp)),
                            child: InkWell(
                              onTapUp: cp == 1 ? textData.onMenuOpen : null,
                              highlightColor: Color.alphaBlend(context.theme.scaffoldBackgroundColor.withAlpha(20), context.theme.highlightColor),
                              borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                              child: Padding(
                                padding: EdgeInsets.only(left: 8.0 * cp),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (textData.firstLine != '')
                                      Text(
                                        textData.firstLine,
                                        maxLines: textData.secondLine == '' ? 2 : 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.textTheme.displayMedium?.copyWith(
                                          fontSize: velpy(a: 14.5, b: 20.0, c: p).multipliedFontScale,
                                          height: 1,
                                        ),
                                      ),
                                    if (textData.firstLine != '' && textData.secondLine != '') const SizedBox(height: 4.0),
                                    if (textData.secondLine != '')
                                      Text(
                                        textData.secondLine,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.textTheme.displayMedium?.copyWith(
                                          fontSize: velpy(a: 12.5, b: 15.0, c: p).multipliedFontScale,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        NamidaOpacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(-100 * (1.0 - cp), 0.0),
                            child: NamidaRawLikeButton(
                              size: 32.0,
                              likedIcon: textData.likedIcon,
                              normalIcon: textData.normalIcon,
                              isLiked: textData.isLiked,
                              onTap: textData.onLikeTap,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WaveformMiniplayer extends StatelessWidget {
  final bool fixPadding;
  const WaveformMiniplayer({super.key, this.fixPadding = false});

  int get _currentDurationInMS {
    final totalDur = Player.inst.currentItemDuration ?? (Player.inst.currentQueue.isNotEmpty ? Player.inst.nowPlayingTrack.duration.seconds : Duration.zero);
    return totalDur.inMilliseconds;
  }

  void onSeekDragUpdate(double deltax, double maxWidth) {
    final percentageSwiped = deltax / maxWidth;
    final newSeek = percentageSwiped * _currentDurationInMS;
    MiniPlayerController.inst.seekValue.value = newSeek.toInt();
  }

  void onSeekEnd() {
    final ms = MiniPlayerController.inst.seekValue.value;
    Player.inst.seek(Duration(milliseconds: ms));
    MiniPlayerController.inst.seekValue.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return NamidaHero(
      tag: 'MINIPLAYER_WAVEFORM',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: 64.0,
            child: Padding(
              padding: fixPadding ? const EdgeInsets.symmetric(horizontal: 16.0 / 2) : EdgeInsets.zero,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) => onSeekDragUpdate(details.localPosition.dx, constraints.maxWidth),
                onTapUp: (details) => onSeekEnd(),
                onTapCancel: () => MiniPlayerController.inst.seekValue.value = 0,
                onHorizontalDragUpdate: (details) => onSeekDragUpdate(details.localPosition.dx, constraints.maxWidth),
                onHorizontalDragEnd: (details) => onSeekEnd(),
                child: const WaveformComponent(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MPQualityButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? bgColor;
  final Widget? trailing;
  final double padding;
  final void Function()? onTap;

  const _MPQualityButton({
    required this.title,
    this.subtitle = '',
    required this.icon,
    this.bgColor,
    this.trailing,
    this.padding = 4.0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaInkWell(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      padding: EdgeInsets.all(padding),
      onTap: onTap,
      borderRadius: 8.0,
      width: context.width,
      bgColor: bgColor,
      child: Row(
        children: [
          Icon(icon, size: 18.0),
          const SizedBox(width: 6.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.displayMedium?.copyWith(
                    fontSize: 13.0.multipliedFontScale,
                  ),
                ),
                if (subtitle != '')
                  Text(
                    subtitle,
                    style: context.textTheme.displaySmall?.copyWith(
                      fontSize: 13.0.multipliedFontScale,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4.0),
            trailing!,
            const SizedBox(width: 4.0),
          ],
        ],
      ),
    );
  }
}
