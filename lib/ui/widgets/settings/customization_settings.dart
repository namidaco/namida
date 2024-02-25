// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/setting_dialog_with_text_field.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings_card.dart';

enum _CustomizationSettingsKeys {
  enableBlur,
  enableGlow,
  enableParallax,
  displayRemainingDur,
  brMultiplier,
  fontScale,
  hourFormat12,
  dateTimeFormat,
  // -----------
  ALBUMTILECUSTOMIZATION,
  trackNumberInAlbumPage,
  albumCardTopRightDate,
  forceSquaredAlbumThumb,
  staggeredAlbumGridview,
  sizeOfAlbumThumb,
  heightOfAlbumTile,
  // -----------
  TRACKTILECUSTOMIZATION,
  forceSquaredTrackThumb,
  sizeOfTrackThumb,
  heightOfTrackTile,
  displayThirdRow,
  displayThirdItemInRow,
  displayFavButtonInTrackTile,
  itemsSeparator,
  // -----------
  MINIPLAYERCUSTOMIZATION,
  partyMode,
  edgeColorsSwitching,
  movingParticles,
  thumbAnimationIntensity,
  thumbInverseAnimation,
  artworkGesture,
  waveformBarsCount,
  displayAudioInfo,
  displayArtistBeforeTitle,
}

class CustomizationSettings extends SettingSubpageProvider {
  const CustomizationSettings({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.customization;

  @override
  Map<Enum, List<String>> get lookupMap => {
        _CustomizationSettingsKeys.enableBlur: [lang.ENABLE_BLUR_EFFECT],
        _CustomizationSettingsKeys.enableGlow: [lang.ENABLE_GLOW_EFFECT],
        _CustomizationSettingsKeys.enableParallax: [lang.ENABLE_PARALLAX_EFFECT],
        _CustomizationSettingsKeys.displayRemainingDur: [lang.DISPLAY_REMAINING_DURATION_INSTEAD_OF_TOTAL],
        _CustomizationSettingsKeys.brMultiplier: [lang.BORDER_RADIUS_MULTIPLIER],
        _CustomizationSettingsKeys.fontScale: [lang.FONT_SCALE],
        _CustomizationSettingsKeys.hourFormat12: [lang.HOUR_FORMAT_12],
        _CustomizationSettingsKeys.dateTimeFormat: [lang.DATE_TIME_FORMAT],
        // -----------
        _CustomizationSettingsKeys.ALBUMTILECUSTOMIZATION: [lang.ALBUM_TILE_CUSTOMIZATION],
        _CustomizationSettingsKeys.trackNumberInAlbumPage: [lang.DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE, lang.DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE_SUBTITLE],
        _CustomizationSettingsKeys.albumCardTopRightDate: [lang.DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE, lang.DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE_SUBTITLE],
        _CustomizationSettingsKeys.forceSquaredAlbumThumb: [lang.FORCE_SQUARED_ALBUM_THUMBNAIL],
        _CustomizationSettingsKeys.staggeredAlbumGridview: [lang.STAGGERED_ALBUM_GRID_VIEW],
        _CustomizationSettingsKeys.sizeOfAlbumThumb: [lang.ALBUM_THUMBNAIL_SIZE_IN_LIST],
        _CustomizationSettingsKeys.heightOfAlbumTile: [lang.HEIGHT_OF_ALBUM_TILE],
        // -----------
        _CustomizationSettingsKeys.TRACKTILECUSTOMIZATION: [lang.TRACK_TILE_CUSTOMIZATION],
        _CustomizationSettingsKeys.forceSquaredTrackThumb: [lang.FORCE_SQUARED_TRACK_THUMBNAIL],
        _CustomizationSettingsKeys.sizeOfTrackThumb: [lang.TRACK_THUMBNAIL_SIZE_IN_LIST],
        _CustomizationSettingsKeys.heightOfTrackTile: [lang.HEIGHT_OF_TRACK_TILE],
        _CustomizationSettingsKeys.displayThirdRow: [lang.DISPLAY_THIRD_ROW_IN_TRACK_TILE],
        _CustomizationSettingsKeys.displayThirdItemInRow: [lang.DISPLAY_THIRD_ITEM_IN_ROW_IN_TRACK_TILE],
        _CustomizationSettingsKeys.displayFavButtonInTrackTile: [lang.DISPLAY_FAVOURITE_ICON_IN_TRACK_TILE],
        _CustomizationSettingsKeys.itemsSeparator: [lang.TRACK_TILE_ITEMS_SEPARATOR],
        // -----------
        _CustomizationSettingsKeys.MINIPLAYERCUSTOMIZATION: [lang.MINIPLAYER_CUSTOMIZATION],
        _CustomizationSettingsKeys.partyMode: [lang.ENABLE_PARTY_MODE, lang.ENABLE_PARTY_MODE_SUBTITLE],
        _CustomizationSettingsKeys.edgeColorsSwitching: [lang.EDGE_COLORS_SWITCHING],
        _CustomizationSettingsKeys.movingParticles: [lang.ENABLE_MINIPLAYER_PARTICLES],
        _CustomizationSettingsKeys.thumbAnimationIntensity: [lang.ANIMATING_THUMBNAIL_INTENSITY],
        _CustomizationSettingsKeys.thumbInverseAnimation: [lang.ANIMATING_THUMBNAIL_INVERSED, lang.ANIMATING_THUMBNAIL_INVERSED_SUBTITLE],
        _CustomizationSettingsKeys.artworkGesture: [lang.ARTWORK_GESTURES],
        _CustomizationSettingsKeys.waveformBarsCount: [lang.WAVEFORM_BARS_COUNT],
        _CustomizationSettingsKeys.displayAudioInfo: [lang.DISPLAY_AUDIO_INFO_IN_MINIPLAYER],
        _CustomizationSettingsKeys.displayArtistBeforeTitle: [lang.DISPLAY_ARTIST_BEFORE_TITLE],
      };

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.CUSTOMIZATIONS,
      subtitle: lang.CUSTOMIZATIONS_SUBTITLE,
      icon: Broken.brush_1,
      child: Column(
        children: [
          getItemWrapper(
            key: _CustomizationSettingsKeys.enableBlur,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.enableBlur),
                icon: Broken.drop,
                title: lang.ENABLE_BLUR_EFFECT,
                subtitle: lang.PERFORMANCE_NOTE,
                onChanged: (p0) {
                  settings.save(
                    enableBlurEffect: !p0,
                    performanceMode: PerformanceMode.custom,
                  );
                },
                value: settings.enableBlurEffect.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.enableGlow,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.enableGlow),
                icon: Broken.sun_1,
                title: lang.ENABLE_GLOW_EFFECT,
                subtitle: lang.PERFORMANCE_NOTE,
                onChanged: (p0) {
                  settings.save(
                    enableGlowEffect: !p0,
                    performanceMode: PerformanceMode.custom,
                  );
                },
                value: settings.enableGlowEffect.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.enableParallax,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.enableParallax),
                icon: Broken.maximize,
                title: lang.ENABLE_PARALLAX_EFFECT,
                subtitle: lang.PERFORMANCE_NOTE,
                onChanged: (isTrue) => settings.save(
                  enableMiniplayerParallaxEffect: !isTrue,
                  performanceMode: PerformanceMode.custom,
                ),
                value: settings.enableMiniplayerParallaxEffect.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayRemainingDur,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayRemainingDur),
                icon: Broken.timer,
                title: lang.DISPLAY_REMAINING_DURATION_INSTEAD_OF_TOTAL,
                onChanged: (isTrue) => settings.player.save(displayRemainingDurInsteadOfTotal: !isTrue),
                value: settings.player.displayRemainingDurInsteadOfTotal.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.brMultiplier,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.brMultiplier),
                icon: Broken.rotate_left_1,
                title: lang.BORDER_RADIUS_MULTIPLIER,
                trailingText: "${settings.borderRadiusMultiplier.value}",
                onTap: () {
                  showSettingDialogWithTextField(
                    title: lang.BORDER_RADIUS_MULTIPLIER,
                    borderRadiusMultiplier: true,
                    icon: Broken.rotate_left_1,
                  );
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.fontScale,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.fontScale),
                icon: Broken.text,
                title: lang.FONT_SCALE,
                trailingText: "${(settings.fontScaleFactor.value * 100).toInt()}%",
                onTap: () {
                  showSettingDialogWithTextField(
                    title: lang.FONT_SCALE,
                    fontScaleFactor: true,
                    icon: Broken.text,
                  );
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.hourFormat12,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.hourFormat12),
                icon: Broken.clock,
                title: lang.HOUR_FORMAT_12,
                onChanged: (p0) {
                  settings.save(hourFormat12: !p0);
                },
                value: settings.hourFormat12.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.dateTimeFormat,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.dateTimeFormat),
                icon: Broken.calendar_edit,
                title: lang.DATE_TIME_FORMAT,
                trailingText: "${settings.dateTimeFormat}",
                onTap: () async {
                  final scrollController = ScrollController();

                  await showSettingDialogWithTextField(
                    title: lang.DATE_TIME_FORMAT,
                    icon: Broken.calendar_edit,
                    dateTimeFormat: true,
                    topWidget: SizedBox(
                      height: Get.height * 0.4,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 58.0),
                        child: Stack(
                          children: [
                            SingleChildScrollView(
                              controller: scrollController,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ...kDefaultDateTimeStrings.entries.map(
                                    (e) => SmallListTile(
                                      title: e.value,
                                      active: settings.dateTimeFormat.value == e.key,
                                      onTap: () {
                                        settings.save(dateTimeFormat: e.key);
                                        NamidaNavigator.inst.closeDialog();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 20,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(color: Get.theme.cardTheme.color, shape: BoxShape.circle),
                                child: NamidaIconButton(
                                  icon: Broken.arrow_circle_down,
                                  onPressed: () {
                                    scrollController.animateTo(
                                      scrollController.position.maxScrollExtent,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                  scrollController.disposeAfterAnimation();
                },
              ),
            ),
          ),
          _getAlbumCustomizationsTile(),
          _getTrackTileCustomizationsTile(context),
          _getMiniplayerCustomizationsTile(context),
        ],
      ),
    );
  }

  Widget _getAlbumCustomizationsTile() {
    return getItemWrapper(
      key: _CustomizationSettingsKeys.ALBUMTILECUSTOMIZATION,
      child: NamidaExpansionTile(
        bgColor: getBgColor(_CustomizationSettingsKeys.ALBUMTILECUSTOMIZATION),
        initiallyExpanded: settings.useSettingCollapsedTiles.value,
        leading: const StackedIcon(
          baseIcon: Broken.brush,
          secondaryIcon: Broken.music_dashboard,
        ),
        titleText: lang.ALBUM_TILE_CUSTOMIZATION,
        children: [
          /// Track Number in a small Box
          getItemWrapper(
            key: _CustomizationSettingsKeys.trackNumberInAlbumPage,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.trackNumberInAlbumPage),
                icon: Broken.card_remove,
                title: lang.DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE,
                subtitle: lang.DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE_SUBTITLE,
                value: settings.displayTrackNumberinAlbumPage.value,
                onChanged: (p0) => settings.save(displayTrackNumberinAlbumPage: !p0),
              ),
            ),
          ),

          /// Album Card Top Right Date
          getItemWrapper(
            key: _CustomizationSettingsKeys.albumCardTopRightDate,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.albumCardTopRightDate),
                icon: Broken.notification_status,
                title: lang.DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE,
                subtitle: lang.DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE_SUBTITLE,
                onChanged: (p0) => settings.save(albumCardTopRightDate: !p0),
                value: settings.albumCardTopRightDate.value,
              ),
            ),
          ),

          /// Force Squared Album Thumbnail
          getItemWrapper(
            key: _CustomizationSettingsKeys.forceSquaredAlbumThumb,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.forceSquaredAlbumThumb),
                icon: Broken.crop,
                title: lang.FORCE_SQUARED_ALBUM_THUMBNAIL,
                value: settings.forceSquaredAlbumThumbnail.value,
                onChanged: (p0) {
                  settings.save(forceSquaredAlbumThumbnail: !p0);
                  if (!p0 && settings.albumThumbnailSizeinList.toInt() != settings.albumListTileHeight.toInt()) {
                    NamidaNavigator.inst.navigateDialog(
                      dialog: CustomBlurryDialog(
                        normalTitleStyle: true,
                        isWarning: true,
                        bodyText: lang.FORCE_SQUARED_THUMBNAIL_NOTE,
                        actions: [
                          const CancelButton(),
                          NamidaButton(
                            text: lang.CONFIRM,
                            onPressed: () {
                              settings.save(albumThumbnailSizeinList: settings.albumListTileHeight.value);
                              NamidaNavigator.inst.closeDialog();
                            },
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ),

          /// Staggered Album Gridview
          getItemWrapper(
            key: _CustomizationSettingsKeys.staggeredAlbumGridview,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.staggeredAlbumGridview),
                icon: Broken.element_4,
                title: lang.STAGGERED_ALBUM_GRID_VIEW,
                value: settings.useAlbumStaggeredGridView.value,
                onChanged: (p0) => settings.save(useAlbumStaggeredGridView: !p0),
              ),
            ),
          ),

          /// Album Thumbnail Size in List
          getItemWrapper(
            key: _CustomizationSettingsKeys.sizeOfAlbumThumb,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.sizeOfAlbumThumb),
                icon: Broken.maximize_3,
                title: lang.ALBUM_THUMBNAIL_SIZE_IN_LIST,
                trailingText: "${settings.albumThumbnailSizeinList.toInt()}",
                onTap: () {
                  showSettingDialogWithTextField(
                    title: lang.ALBUM_THUMBNAIL_SIZE_IN_LIST,
                    albumThumbnailSizeinList: true,
                    icon: Broken.maximize_3,
                  );
                },
              ),
            ),
          ),

          /// Album Tile Height
          getItemWrapper(
            key: _CustomizationSettingsKeys.heightOfAlbumTile,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.heightOfAlbumTile),
                icon: Broken.pharagraphspacing,
                title: lang.HEIGHT_OF_ALBUM_TILE,
                trailingText: "${settings.albumListTileHeight.toInt()}",
                onTap: () {
                  showSettingDialogWithTextField(
                    title: lang.HEIGHT_OF_ALBUM_TILE,
                    albumListTileHeight: true,
                    icon: Broken.pharagraphspacing,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSettingsChanged() => TrackTileManager.onTrackItemPropChange();

  void _showTrackItemsDialog(TrackTilePosition p) {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.CHOOSE,
        normalTitleStyle: true,
        insetPadding: const EdgeInsets.all(64.0),
        child: SizedBox(
          height: Get.height * 0.5,
          width: Get.width,
          child: NamidaListView(
            padding: EdgeInsets.zero,
            itemBuilder: (context, i) {
              final trItem = TrackTileItem.values[i];
              return SmallListTile(
                key: ValueKey(i),
                title: trItem.toText(),
                onTap: () {
                  settings.updateTrackItemList(p, trItem);
                  _onSettingsChanged();
                  NamidaNavigator.inst.closeDialog();
                },
                active: settings.trackItem[p] == trItem,
              );
            },
            itemCount: TrackTileItem.values.length,
            itemExtents: null,
          ),
        ),
      ),
    );
  }

  Widget _getTrackTileCustomizationsTile(BuildContext context) {
    return getItemWrapper(
      key: _CustomizationSettingsKeys.TRACKTILECUSTOMIZATION,
      child: NamidaExpansionTile(
        bgColor: getBgColor(_CustomizationSettingsKeys.TRACKTILECUSTOMIZATION),
        initiallyExpanded: settings.useSettingCollapsedTiles.value,
        leading: const StackedIcon(
          baseIcon: Broken.brush,
          secondaryIcon: Broken.music_circle,
        ),
        titleText: lang.TRACK_TILE_CUSTOMIZATION,
        children: [
          getItemWrapper(
            key: _CustomizationSettingsKeys.forceSquaredTrackThumb,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.forceSquaredTrackThumb),
                icon: Broken.crop,
                title: lang.FORCE_SQUARED_TRACK_THUMBNAIL,
                value: settings.forceSquaredTrackThumbnail.value,
                onChanged: (value) {
                  settings.save(forceSquaredTrackThumbnail: !value);
                  Player.inst.refreshRxVariables();
                  _onSettingsChanged();
                  if (!value && settings.trackThumbnailSizeinList.toInt() != settings.trackListTileHeight.toInt()) {
                    NamidaNavigator.inst.navigateDialog(
                      dialog: CustomBlurryDialog(
                        normalTitleStyle: true,
                        isWarning: true,
                        bodyText: lang.FORCE_SQUARED_THUMBNAIL_NOTE,
                        actions: [
                          const CancelButton(),
                          NamidaButton(
                            text: lang.CONFIRM,
                            onPressed: () {
                              settings.save(trackThumbnailSizeinList: settings.trackListTileHeight.value);
                              NamidaNavigator.inst.closeDialog();
                            },
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.sizeOfTrackThumb,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.sizeOfTrackThumb),
                icon: Broken.maximize_3,
                title: lang.TRACK_THUMBNAIL_SIZE_IN_LIST,
                trailingText: "${settings.trackThumbnailSizeinList.toInt()}",
                onTap: () {
                  showSettingDialogWithTextField(
                    title: lang.TRACK_THUMBNAIL_SIZE_IN_LIST,
                    trackThumbnailSizeinList: true,
                    icon: Broken.maximize_3,
                  );
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.heightOfTrackTile,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.heightOfTrackTile),
                icon: Broken.pharagraphspacing,
                title: lang.HEIGHT_OF_TRACK_TILE,
                trailingText: "${settings.trackListTileHeight.toInt()}",
                onTap: () {
                  showSettingDialogWithTextField(
                    title: lang.HEIGHT_OF_TRACK_TILE,
                    trackListTileHeight: true,
                    icon: Broken.pharagraphspacing,
                  );
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayThirdRow,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayThirdRow),
                icon: Broken.chart_1,
                rotateIcon: 1,
                title: lang.DISPLAY_THIRD_ROW_IN_TRACK_TILE,
                onChanged: (isTrue) {
                  settings.save(displayThirdRow: !isTrue);
                  _onSettingsChanged();
                },
                value: settings.displayThirdRow.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayThirdItemInRow,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayThirdItemInRow),
                icon: Broken.coin,
                rotateIcon: 3,
                title: lang.DISPLAY_THIRD_ITEM_IN_ROW_IN_TRACK_TILE,
                onChanged: (isTrue) {
                  settings.save(displayThirdItemInEachRow: !isTrue);
                  _onSettingsChanged();
                },
                value: settings.displayThirdItemInEachRow.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayFavButtonInTrackTile,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayFavButtonInTrackTile),
                icon: Broken.heart,
                title: lang.DISPLAY_FAVOURITE_ICON_IN_TRACK_TILE,
                onChanged: (isTrue) {
                  settings.save(displayFavouriteIconInListTile: !isTrue);
                  _onSettingsChanged();
                },
                value: settings.displayFavouriteIconInListTile.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.itemsSeparator,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.itemsSeparator),
                icon: Broken.minus_square,
                title: lang.TRACK_TILE_ITEMS_SEPARATOR,
                trailingText: settings.trackTileSeparator.value,
                onTap: () => showSettingDialogWithTextField(
                  title: lang.TRACK_TILE_ITEMS_SEPARATOR,
                  trackTileSeparator: true,
                  icon: Broken.minus_square,
                ),
              ),
            ),
          ),
          Obx(
            () => Container(
              color: context.theme.cardTheme.color,
              width: context.width,
              height: settings.trackListTileHeight * 1.5,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 7.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  const SizedBox(
                    width: 12.0,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 0.0,
                    ),
                    width: settings.trackThumbnailSizeinList.value,
                    height: settings.trackThumbnailSizeinList.value,
                    child: ArtworkWidget(
                      track: allTracksInLibrary.firstOrNull,
                      key: Key(allTracksInLibrary.firstOrNull?.pathToImage ?? ''),
                      thumbnailSize: settings.trackThumbnailSizeinList.value,
                      path: allTracksInLibrary.firstOrNull?.pathToImage,
                      forceSquared: settings.forceSquaredTrackThumbnail.value,
                    ),
                  ),
                  const SizedBox(
                    width: 12.0,
                  ),

                  /// Main Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          child: Row(
                            children: [
                              TrackTilePosition.row1Item1,
                              TrackTilePosition.row1Item2,
                              if (settings.displayThirdItemInEachRow.value) TrackTilePosition.row1Item3,
                            ]
                                .map(
                                  (e) => TrackItemSmallBox(
                                    text: settings.trackItem[e]?.label,
                                    onTap: () => _showTrackItemsDialog(e),
                                  ),
                                )
                                .addSeparators(separator: const SizedBox(width: 6.0))
                                .toList(),
                          ),
                        ),
                        const SizedBox(
                          height: 4.0,
                        ),
                        FittedBox(
                          child: Row(
                            children: [
                              TrackTilePosition.row2Item1,
                              TrackTilePosition.row2Item2,
                              if (settings.displayThirdItemInEachRow.value) TrackTilePosition.row2Item3,
                            ]
                                .map(
                                  (e) => TrackItemSmallBox(
                                    text: settings.trackItem[e]?.label,
                                    onTap: () => _showTrackItemsDialog(e),
                                  ),
                                )
                                .addSeparators(separator: const SizedBox(width: 6.0))
                                .toList(),
                          ),
                        ),
                        const SizedBox(
                          height: 4.0,
                        ),
                        if (settings.displayThirdRow.value)
                          FittedBox(
                            child: Row(
                              children: [
                                TrackTilePosition.row3Item1,
                                TrackTilePosition.row3Item2,
                                if (settings.displayThirdItemInEachRow.value) TrackTilePosition.row3Item3,
                              ]
                                  .map(
                                    (e) => TrackItemSmallBox(
                                      text: settings.trackItem[e]?.label,
                                      onTap: () => _showTrackItemsDialog(e),
                                    ),
                                  )
                                  .addSeparators(separator: const SizedBox(width: 6.0))
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6.0),

                  /// Right Items
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...[
                        TrackTilePosition.rightItem1,
                        TrackTilePosition.rightItem2,
                      ]
                          .map(
                            (e) => TrackItemSmallBox(
                              text: settings.trackItem[e]?.label,
                              onTap: () => _showTrackItemsDialog(e),
                            ),
                          )
                          .addSeparators(separator: const SizedBox(height: 3.0))
                          .toList(),
                      if (settings.displayFavouriteIconInListTile.value) ...[
                        const SizedBox(height: 3.0),
                        const NamidaLikeButton(
                          track: null,
                          size: 20,
                        ),
                      ]
                    ],
                  ),
                  const SizedBox(width: 6.0),
                  const MoreIcon(
                    iconSize: 20,
                  ),
                  const SizedBox(width: 6.0),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _getMiniplayerCustomizationsTile(BuildContext context) {
    return getItemWrapper(
      key: _CustomizationSettingsKeys.MINIPLAYERCUSTOMIZATION,
      child: NamidaExpansionTile(
        bgColor: getBgColor(_CustomizationSettingsKeys.MINIPLAYERCUSTOMIZATION),
        initiallyExpanded: settings.useSettingCollapsedTiles.value,
        leading: const StackedIcon(
          baseIcon: Broken.brush,
          secondaryIcon: Broken.external_drive,
        ),
        titleText: lang.MINIPLAYER_CUSTOMIZATION,
        children: [
          getItemWrapper(
            key: _CustomizationSettingsKeys.partyMode,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.partyMode),
                icon: Broken.slider_horizontal_1,
                title: lang.ENABLE_PARTY_MODE,
                subtitle: lang.ENABLE_PARTY_MODE_SUBTITLE,
                onChanged: (value) {
                  // disable
                  if (value) {
                    settings.save(enablePartyModeInMiniplayer: false);
                  }
                  // pls lemme enable
                  if (!value) {
                    if (settings.didSupportNamida) {
                      settings.save(enablePartyModeInMiniplayer: true);
                    } else {
                      NamidaNavigator.inst.navigateDialog(
                        dialog: CustomBlurryDialog(
                          normalTitleStyle: true,
                          title: 'uwu',
                          actions: const [NamidaSupportButton()],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onDoubleTap: () {
                                  settings.save(didSupportNamida: true);
                                },
                                child: const Text('a- ano...'),
                              ),
                              const Text(
                                'this one is actually supposed to be for supporters, if you don\'t mind u can support namida and get the power to unleash this cool feature',
                              ),
                              TapDetector(
                                onTap: () {
                                  NamidaNavigator.inst.closeDialog();
                                  NamidaNavigator.inst.navigateDialog(
                                    dialog: CustomBlurryDialog(
                                      normalTitleStyle: true,
                                      title: '!!',
                                      bodyText: "EH? YOU DON'T WANT TO SUPPORT?",
                                      actions: [
                                        NamidaSupportButton(title: lang.YES),
                                        NamidaButton(
                                          text: lang.NO,
                                          onPressed: () {
                                            NamidaNavigator.inst.closeDialog();
                                            NamidaNavigator.inst.navigateDialog(
                                              dialog: CustomBlurryDialog(
                                                title: 'kechi',
                                                bodyText: 'hidoii ಥ_ಥ here use it as much as u can, dw im not upset or anything ^^, or am i?',
                                                actions: [
                                                  NamidaButton(
                                                    text: lang.UNLOCK.toUpperCase(),
                                                    onPressed: () {
                                                      NamidaNavigator.inst.closeDialog();
                                                      settings.save(enablePartyModeInMiniplayer: true);
                                                    },
                                                  ),
                                                  NamidaButton(
                                                    text: lang.SUPPORT.toUpperCase(),
                                                    onPressed: () {
                                                      NamidaNavigator.inst.closeDialog();
                                                      NamidaLinkUtils.openLink(AppSocial.DONATE_BUY_ME_A_COFFEE);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('or you just wanna use it like that? mattaku'),
                              )
                            ],
                          ),
                        ),
                      );
                    }
                  }
                },
                value: settings.enablePartyModeInMiniplayer.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.edgeColorsSwitching,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.edgeColorsSwitching),
                enabled: settings.enablePartyModeInMiniplayer.value,
                icon: Broken.colors_square,
                title: lang.EDGE_COLORS_SWITCHING,
                onChanged: (value) {
                  settings.save(enablePartyModeColorSwap: !value);
                },
                value: settings.enablePartyModeColorSwap.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.movingParticles,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.movingParticles),
                icon: Broken.buy_crypto,
                title: lang.ENABLE_MINIPLAYER_PARTICLES,
                onChanged: (value) => settings.save(enableMiniplayerParticles: !value),
                value: settings.enableMiniplayerParticles.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.thumbAnimationIntensity,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.thumbAnimationIntensity),
                icon: Broken.flash,
                title: lang.ANIMATING_THUMBNAIL_INTENSITY,
                trailing: NamidaWheelSlider(
                  totalCount: 25,
                  initValue: settings.animatingThumbnailIntensity.value,
                  itemSize: 6,
                  onValueChanged: (val) {
                    settings.save(animatingThumbnailIntensity: val as int);
                  },
                  text: "${(settings.animatingThumbnailIntensity.value * 4).toStringAsFixed(0)}%",
                ),
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.thumbInverseAnimation,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.thumbInverseAnimation),
                icon: Broken.arrange_circle_2,
                title: lang.ANIMATING_THUMBNAIL_INVERSED,
                subtitle: lang.ANIMATING_THUMBNAIL_INVERSED_SUBTITLE,
                onChanged: (value) {
                  settings.save(animatingThumbnailInversed: !value);
                },
                value: settings.animatingThumbnailInversed.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.artworkGesture,
            child: NamidaExpansionTile(
              icon: Broken.gallery,
              iconColor: context.defaultIconColor(),
              initiallyExpanded: true,
              titleText: lang.ARTWORK_GESTURES,
              childrenPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NamidaIconButton(
                    tooltip: lang.RESTORE_DEFAULTS,
                    icon: Broken.refresh,
                    iconSize: 20.0,
                    onPressed: () {
                      settings.save(
                        artworkGestureScale: false,
                        artworkGestureDoubleTapLRC: true,
                        animatingThumbnailScaleMultiplier: 1.0,
                      );
                    },
                  ),
                  const SizedBox(width: 4.0),
                  const Icon(Broken.arrow_down_2, size: 20.0),
                  const SizedBox(width: 12.0),
                ],
              ),
              children: [
                Obx(
                  () => CustomSwitchListTile(
                    visualDensity: VisualDensity.compact,
                    icon: Broken.maximize,
                    title: lang.SCALE_MULTIPLIER,
                    subtitle: "${(settings.animatingThumbnailScaleMultiplier.value * 100).round()}%",
                    value: settings.artworkGestureScale.value,
                    onChanged: (value) {
                      settings.save(artworkGestureScale: !value);
                    },
                  ),
                ),
                Obx(
                  () => CustomSwitchListTile(
                    visualDensity: VisualDensity.compact,
                    leading: const StackedIcon(
                      baseIcon: Broken.document,
                      secondaryIcon: Broken.blend_2,
                      secondaryIconSize: 12.0,
                    ),
                    title: lang.DOUBLE_TAP_TO_TOGGLE_LYRICS,
                    value: settings.artworkGestureDoubleTapLRC.value,
                    onChanged: (value) {
                      settings.save(artworkGestureDoubleTapLRC: !value);
                    },
                  ),
                ),
                const SizedBox(height: 6.0),
              ],
            ),
          ),
          const SizedBox(height: 6.0),
          getItemWrapper(
            key: _CustomizationSettingsKeys.waveformBarsCount,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.waveformBarsCount),
                icon: Broken.sound,
                title: lang.WAVEFORM_BARS_COUNT,
                trailing: SizedBox(
                  width: 80,
                  child: Column(
                    children: [
                      NamidaWheelSlider<int>(
                        totalCount: 360,
                        initValue: settings.waveformTotalBars.value - 40,
                        itemSize: 6,
                        onValueChanged: (val) {
                          final v = (val + 40);
                          settings.save(waveformTotalBars: v);
                          WaveformController.inst.calculateUIWaveform();
                        },
                        text: settings.waveformTotalBars.value.toString(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayAudioInfo,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayAudioInfo),
                icon: Broken.text_block,
                title: lang.DISPLAY_AUDIO_INFO_IN_MINIPLAYER,
                onChanged: (value) => settings.save(displayAudioInfoMiniplayer: !value),
                value: settings.displayAudioInfoMiniplayer.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayArtistBeforeTitle,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayArtistBeforeTitle),
                icon: Broken.align_left,
                title: lang.DISPLAY_ARTIST_BEFORE_TITLE,
                onChanged: (value) {
                  settings.save(displayArtistBeforeTitle: !value);
                  Player.inst.refreshRxVariables();
                },
                value: settings.displayArtistBeforeTitle.value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TrackItemSmallBox extends StatelessWidget {
  final void Function()? onTap;
  final Widget? child;
  final String? text;
  const TrackItemSmallBox({super.key, this.onTap, this.child, this.text});

  @override
  Widget build(BuildContext context) {
    return NamidaInkWell(
      bgColor: context.theme.colorScheme.background.withAlpha(160),
      onTap: onTap,
      borderRadius: 8.0,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: text != null
          ? Text(
              text!,
              style: context.theme.textTheme.displaySmall,
            )
          : child,
    );
  }
}
