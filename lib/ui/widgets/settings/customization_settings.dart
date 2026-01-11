// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/setting_dialog_with_text_field.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings_card.dart';

enum _CustomizationSettingsKeys with SettingKeysBase {
  enableBlur,
  enableGlow,
  enableParallax,
  displayRemainingDur,
  displayActualPosition,
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
  SWIPEACTIONS,
  swipeLeftAction,
  swipeRightAction,
  displayThirdRow,
  displayThirdItemInRow,
  displayFavButtonInTrackTile,
  itemsSeparator,
  // -----------
  MINIPLAYERCUSTOMIZATION,
  partyMode,
  edgeColorsSwitching,
  movingParticles,
  THUMBANIMATIONINTENSITY,
  thumbAnimationIntensityExpanded,
  thumbAnimationIntensityLyrics,
  thumbAnimationIntensityMinimized,
  thumbInverseAnimation,
  ARTWORKGESTURES,
  scaleMultiplier,
  doubleTapLyrics,
  artworkTapAction,
  artworkLongPressAction,
  waveformBarsCount,
  displayAudioInfo,
  displayArtistBeforeTitle,
  appIcons(NamidaFeaturesAvailablity.android),
  ;

  @override
  final NamidaFeaturesAvailablity? availability;
  const _CustomizationSettingsKeys([this.availability]);
}

class CustomizationSettings extends SettingSubpageProvider {
  const CustomizationSettings({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.customization;

  @override
  Map<SettingKeysBase, List<String>> get lookupMap => {
        _CustomizationSettingsKeys.enableBlur: [lang.ENABLE_BLUR_EFFECT],
        _CustomizationSettingsKeys.enableGlow: [lang.ENABLE_GLOW_EFFECT],
        _CustomizationSettingsKeys.enableParallax: [lang.ENABLE_PARALLAX_EFFECT],
        _CustomizationSettingsKeys.displayRemainingDur: [lang.DISPLAY_REMAINING_DURATION_INSTEAD_OF_TOTAL],
        _CustomizationSettingsKeys.displayActualPosition: [lang.DISPLAY_ACTUAL_POSITION_INSTEAD_OF_DIFFERENCE_WHILE_SEEKING],
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
        _CustomizationSettingsKeys.SWIPEACTIONS: [lang.SWIPE_ACTIONS, lang.ON_SWIPING, lang.LEFT_ACTION, lang.RIGHT_ACTION],
        _CustomizationSettingsKeys.swipeLeftAction: [lang.SWIPE_ACTIONS, lang.LEFT_ACTION],
        _CustomizationSettingsKeys.swipeRightAction: [lang.SWIPE_ACTIONS, lang.RIGHT_ACTION],
        _CustomizationSettingsKeys.displayThirdRow: [lang.DISPLAY_THIRD_ROW_IN_TRACK_TILE],
        _CustomizationSettingsKeys.displayThirdItemInRow: [lang.DISPLAY_THIRD_ITEM_IN_ROW_IN_TRACK_TILE],
        _CustomizationSettingsKeys.displayFavButtonInTrackTile: [lang.DISPLAY_FAVOURITE_ICON_IN_TRACK_TILE],
        _CustomizationSettingsKeys.itemsSeparator: [lang.TRACK_TILE_ITEMS_SEPARATOR],
        // -----------
        _CustomizationSettingsKeys.MINIPLAYERCUSTOMIZATION: [lang.MINIPLAYER_CUSTOMIZATION],
        _CustomizationSettingsKeys.partyMode: [lang.ENABLE_PARTY_MODE, lang.ENABLE_PARTY_MODE_SUBTITLE],
        _CustomizationSettingsKeys.edgeColorsSwitching: [lang.EDGE_COLORS_SWITCHING],
        _CustomizationSettingsKeys.movingParticles: [lang.ENABLE_MINIPLAYER_PARTICLES],
        _CustomizationSettingsKeys.THUMBANIMATIONINTENSITY: [lang.ANIMATING_THUMBNAIL_INTENSITY],
        _CustomizationSettingsKeys.thumbAnimationIntensityExpanded: [lang.ANIMATING_THUMBNAIL_INTENSITY, lang.EXPANDED_MINIPLAYER],
        _CustomizationSettingsKeys.thumbAnimationIntensityLyrics: [lang.ANIMATING_THUMBNAIL_INTENSITY, lang.LYRICS],
        _CustomizationSettingsKeys.thumbAnimationIntensityMinimized: [lang.ANIMATING_THUMBNAIL_INTENSITY, lang.MINIMIZED_MINIPLAYER],
        _CustomizationSettingsKeys.thumbInverseAnimation: [lang.ANIMATING_THUMBNAIL_INVERSED, lang.ANIMATING_THUMBNAIL_INVERSED_SUBTITLE],
        _CustomizationSettingsKeys.ARTWORKGESTURES: [lang.ARTWORK_GESTURES],
        _CustomizationSettingsKeys.scaleMultiplier: [lang.SCALE_MULTIPLIER],
        _CustomizationSettingsKeys.doubleTapLyrics: [lang.DOUBLE_TAP_TO_TOGGLE_LYRICS],
        _CustomizationSettingsKeys.artworkTapAction: [lang.TAP_ACTION, lang.ARTWORK],
        _CustomizationSettingsKeys.artworkLongPressAction: [lang.LONG_PRESS_ACTION, lang.ARTWORK],
        _CustomizationSettingsKeys.waveformBarsCount: [lang.WAVEFORM_BARS_COUNT],
        _CustomizationSettingsKeys.displayAudioInfo: [lang.DISPLAY_AUDIO_INFO_IN_MINIPLAYER],
        _CustomizationSettingsKeys.displayArtistBeforeTitle: [lang.DISPLAY_ARTIST_BEFORE_TITLE],
        _CustomizationSettingsKeys.appIcons: [lang.APP_ICON],
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
            child: ObxO(
              rx: settings.enableBlurEffect,
              builder: (context, enableBlurEffect) => CustomSwitchListTile(
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
                value: enableBlurEffect,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.enableGlow,
            child: ObxO(
              rx: settings.enableGlowEffect,
              builder: (context, enableGlowEffect) => CustomSwitchListTile(
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
                value: enableGlowEffect,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.enableParallax,
            child: ObxO(
              rx: settings.enableMiniplayerParallaxEffect,
              builder: (context, enableMiniplayerParallaxEffect) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.enableParallax),
                icon: Broken.maximize,
                title: lang.ENABLE_PARALLAX_EFFECT,
                subtitle: lang.PERFORMANCE_NOTE,
                onChanged: (isTrue) => settings.save(
                  enableMiniplayerParallaxEffect: !isTrue,
                  performanceMode: PerformanceMode.custom,
                ),
                value: enableMiniplayerParallaxEffect,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.brMultiplier,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.brMultiplier),
                icon: Broken.rotate_left_1,
                title: lang.BORDER_RADIUS_MULTIPLIER,
                trailingText: "${settings.borderRadiusMultiplier.valueR}",
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
              (context) => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.fontScale),
                icon: Broken.text,
                title: lang.FONT_SCALE,
                trailingText: "${(settings.fontScaleFactor.valueR * 100).toInt()}%",
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
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.hourFormat12),
                icon: Broken.clock,
                title: lang.HOUR_FORMAT_12,
                onChanged: (p0) {
                  settings.save(hourFormat12: !p0);
                  TrackTileManager.onTrackItemPropChange();
                },
                value: settings.hourFormat12.valueR,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.dateTimeFormat,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.dateTimeFormat),
                icon: Broken.calendar_edit,
                title: lang.DATE_TIME_FORMAT,
                trailingText: settings.dateTimeFormat.valueR,
                onTap: () async {
                  await showSettingDialogWithTextField(
                    title: lang.DATE_TIME_FORMAT,
                    icon: Broken.calendar_edit,
                    dateTimeFormat: true,
                    topWidget: SizedBox(
                      height: namida.height * 0.4,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 58.0),
                        child: NamidaScrollbarWithController(
                          showOnStart: true,
                          child: (c) => SmoothSingleChildScrollView(
                            controller: c,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...kDefaultDateTimeStrings.entries.map(
                                  (e) => SmallListTile(
                                    title: e.value,
                                    active: settings.dateTimeFormat.value == e.key,
                                    onTap: () {
                                      settings.save(dateTimeFormat: e.key);
                                      TrackTileManager.onTrackItemPropChange();
                                      NamidaNavigator.inst.closeDialog();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayRemainingDur,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayRemainingDur),
                icon: Broken.timer,
                title: lang.DISPLAY_REMAINING_DURATION_INSTEAD_OF_TOTAL,
                onChanged: (isTrue) => settings.player.save(displayRemainingDurInsteadOfTotal: !isTrue),
                value: settings.player.displayRemainingDurInsteadOfTotal.valueR,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayActualPosition,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayActualPosition),
                icon: Broken.settings,
                title: lang.DISPLAY_ACTUAL_POSITION_INSTEAD_OF_DIFFERENCE_WHILE_SEEKING,
                onChanged: (isTrue) => settings.player.save(displayActualPositionWhenSeeking: !isTrue),
                value: settings.player.displayActualPositionWhenSeeking.valueR,
              ),
            ),
          ),
          _getAlbumCustomizationsTile(),
          _getTrackTileCustomizationsTile(context),
          _getMiniplayerCustomizationsTile(context),
          getItemWrapper(
            key: _CustomizationSettingsKeys.appIcons,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NamidaContainerDivider(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: getBgColor(_CustomizationSettingsKeys.appIcons),
                    borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                  ),
                  child: const _AppIconWidgetRow(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getSwipeActionTileWidget({
    required BuildContext context,
    required _CustomizationSettingsKeys key,
    bool excludePlayerActions = false,
    required String title,
    required IconData icon,
    required Rx<TrackExecuteActions> rx,
    required void Function(TrackExecuteActions newItem) onSave,
    VisualDensity visualDensity = VisualDensity.compact,
  }) {
    List<Widget> getChildren() {
      var values = TrackExecuteActions.values;
      if (excludePlayerActions) {
        final newValues = <TrackExecuteActions>[];
        for (final v in values) {
          if (v == TrackExecuteActions.playnext || v == TrackExecuteActions.playlast || v == TrackExecuteActions.playafter) {
            // -- exclude
          } else {
            newValues.add(v);
          }
        }
        values = newValues;
      }

      return [
        ...values.map(
          (e) {
            void onTap() {
              onSave(e);
              NamidaNavigator.inst.popMenu();
            }

            return ObxO(
              rx: rx,
              builder: (context, value) => NamidaInkWell(
                margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                borderRadius: 6.0,
                bgColor: value == e ? context.theme.cardColor : null,
                onTap: onTap,
                child: Row(
                  children: [
                    Icon(
                      e.toIcon(),
                      size: 18.0,
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      e.toText(),
                      style: context.textTheme.displayMedium?.copyWith(fontSize: 14.0),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ];
    }

    return getItemWrapper(
      key: key,
      child: NamidaPopupWrapper(
        children: getChildren,
        child: CustomListTile(
          visualDensity: visualDensity,
          bgColor: getBgColor(key),
          icon: icon,
          title: title,
          trailing: NamidaPopupWrapper(
            children: getChildren,
            child: ObxO(
              rx: rx,
              builder: (context, value) => Text(
                value.toText(),
                style: context.textTheme.displaySmall?.copyWith(color: context.theme.colorScheme.onSurface.withAlpha(200)),
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getAlbumCustomizationsTile() {
    return getItemWrapper(
      key: _CustomizationSettingsKeys.ALBUMTILECUSTOMIZATION,
      child: NamidaExpansionTile(
        bgColor: getBgColor(_CustomizationSettingsKeys.ALBUMTILECUSTOMIZATION),
        bigahh: true,
        compact: false,
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
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.trackNumberInAlbumPage),
                icon: Broken.card_remove,
                title: lang.DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE,
                subtitle: lang.DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE_SUBTITLE,
                value: settings.displayTrackNumberinAlbumPage.valueR,
                onChanged: (p0) => settings.save(displayTrackNumberinAlbumPage: !p0),
              ),
            ),
          ),

          /// Album Card Top Right Date
          getItemWrapper(
            key: _CustomizationSettingsKeys.albumCardTopRightDate,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.albumCardTopRightDate),
                icon: Broken.notification_status,
                title: lang.DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE,
                subtitle: lang.DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE_SUBTITLE,
                onChanged: (p0) => settings.save(albumCardTopRightDate: !p0),
                value: settings.albumCardTopRightDate.valueR,
              ),
            ),
          ),

          /// Force Squared Album Thumbnail
          getItemWrapper(
            key: _CustomizationSettingsKeys.forceSquaredAlbumThumb,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.forceSquaredAlbumThumb),
                icon: Broken.crop,
                title: lang.FORCE_SQUARED_ALBUM_THUMBNAIL,
                value: settings.forceSquaredAlbumThumbnail.valueR,
                onChanged: (p0) {
                  settings.save(forceSquaredAlbumThumbnail: !p0);
                  if (!p0 && settings.albumThumbnailSizeinList.value.toInt() != settings.albumListTileHeight.value.toInt()) {
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
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.staggeredAlbumGridview),
                icon: Broken.element_4,
                title: lang.STAGGERED_ALBUM_GRID_VIEW,
                value: settings.useAlbumStaggeredGridView.valueR,
                onChanged: (p0) => settings.save(useAlbumStaggeredGridView: !p0),
              ),
            ),
          ),

          /// Album Thumbnail Size in List
          getItemWrapper(
            key: _CustomizationSettingsKeys.sizeOfAlbumThumb,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.sizeOfAlbumThumb),
                icon: Broken.maximize_3,
                title: lang.ALBUM_THUMBNAIL_SIZE_IN_LIST,
                trailingText: "${settings.albumThumbnailSizeinList.valueR.toInt()}",
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
              (context) => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.heightOfAlbumTile),
                icon: Broken.pharagraphspacing,
                title: lang.HEIGHT_OF_ALBUM_TILE,
                trailingText: "${settings.albumListTileHeight.valueR.toInt()}",
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
        horizontalInset: 64.0,
        verticalInset: 64.0,
        child: SizedBox(
          height: namida.height * 0.5,
          width: namida.width,
          child: NamidaListView(
            listBottomPadding: 0,
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
            itemExtent: null,
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
        bigahh: true,
        compact: false,
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
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.forceSquaredTrackThumb),
                icon: Broken.crop,
                title: lang.FORCE_SQUARED_TRACK_THUMBNAIL,
                value: settings.forceSquaredTrackThumbnail.valueR,
                onChanged: (value) {
                  settings.save(forceSquaredTrackThumbnail: !value);
                  Player.inst.refreshRxVariables();
                  _onSettingsChanged();
                  if (!value && settings.trackThumbnailSizeinList.value.toInt() != settings.trackListTileHeight.value.toInt()) {
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
              (context) => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.sizeOfTrackThumb),
                icon: Broken.maximize_3,
                title: lang.TRACK_THUMBNAIL_SIZE_IN_LIST,
                trailingText: "${settings.trackThumbnailSizeinList.valueR.toInt()}",
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
              (context) => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.heightOfTrackTile),
                icon: Broken.pharagraphspacing,
                title: lang.HEIGHT_OF_TRACK_TILE,
                trailingText: "${settings.trackListTileHeight.valueR.toInt()}",
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
            key: _CustomizationSettingsKeys.SWIPEACTIONS,
            child: NamidaExpansionTile(
              bgColor: getBgColor(_CustomizationSettingsKeys.SWIPEACTIONS),
              initiallyExpanded: true,
              borderless: true,
              icon: Broken.arrow_swap_horizontal,
              iconColor: context.defaultIconColor(),
              titleText: lang.SWIPE_ACTIONS,
              childrenPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              children: [
                _getSwipeActionTileWidget(
                  context: context,
                  key: _CustomizationSettingsKeys.swipeLeftAction,
                  title: lang.LEFT_ACTION,
                  icon: Broken.arrow_left_1,
                  rx: settings.onTrackSwipeLeft,
                  onSave: (newItem) => settings.save(onTrackSwipeLeft: newItem),
                ),
                _getSwipeActionTileWidget(
                  context: context,
                  key: _CustomizationSettingsKeys.swipeRightAction,
                  title: lang.RIGHT_ACTION,
                  icon: Broken.arrow_right,
                  rx: settings.onTrackSwipeRight,
                  onSave: (newItem) => settings.save(onTrackSwipeRight: newItem),
                ),
              ],
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayThirdRow,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayThirdRow),
                icon: Broken.chart_1,
                rotateIcon: 1,
                title: lang.DISPLAY_THIRD_ROW_IN_TRACK_TILE,
                onChanged: (isTrue) {
                  settings.save(displayThirdRow: !isTrue);
                  _onSettingsChanged();
                },
                value: settings.displayThirdRow.valueR,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayThirdItemInRow,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayThirdItemInRow),
                icon: Broken.coin,
                rotateIcon: 3,
                title: lang.DISPLAY_THIRD_ITEM_IN_ROW_IN_TRACK_TILE,
                onChanged: (isTrue) {
                  settings.save(displayThirdItemInEachRow: !isTrue);
                  _onSettingsChanged();
                },
                value: settings.displayThirdItemInEachRow.valueR,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayFavButtonInTrackTile,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayFavButtonInTrackTile),
                icon: Broken.heart,
                title: lang.DISPLAY_FAVOURITE_ICON_IN_TRACK_TILE,
                onChanged: (isTrue) {
                  settings.save(displayFavouriteIconInListTile: !isTrue);
                  _onSettingsChanged();
                },
                value: settings.displayFavouriteIconInListTile.valueR,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.itemsSeparator,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.itemsSeparator),
                icon: Broken.minus_square,
                title: lang.TRACK_TILE_ITEMS_SEPARATOR,
                trailingText: settings.trackTileSeparator.valueR,
                onTap: () => showSettingDialogWithTextField(
                  title: lang.TRACK_TILE_ITEMS_SEPARATOR,
                  trackTileSeparator: true,
                  icon: Broken.minus_square,
                ),
              ),
            ),
          ),
          Obx(
            (context) => Container(
              color: context.theme.cardTheme.color,
              width: context.width,
              height: settings.trackListTileHeight.valueR * 1.5,
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
                    width: settings.trackThumbnailSizeinList.valueR,
                    height: settings.trackThumbnailSizeinList.valueR,
                    child: ArtworkWidget(
                      track: allTracksInLibrary.firstOrNull,
                      key: Key(allTracksInLibrary.firstOrNull?.pathToImage ?? ''),
                      thumbnailSize: settings.trackThumbnailSizeinList.valueR,
                      path: allTracksInLibrary.firstOrNull?.pathToImage,
                      forceSquared: settings.forceSquaredTrackThumbnail.valueR,
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
                              if (settings.displayThirdItemInEachRow.valueR) TrackTilePosition.row1Item3,
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
                              if (settings.displayThirdItemInEachRow.valueR) TrackTilePosition.row2Item3,
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
                        if (settings.displayThirdRow.valueR)
                          FittedBox(
                            child: Row(
                              children: [
                                TrackTilePosition.row3Item1,
                                TrackTilePosition.row3Item2,
                                if (settings.displayThirdItemInEachRow.valueR) TrackTilePosition.row3Item3,
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
                          .addSeparators(separator: const SizedBox(height: 3.0)),
                      if (settings.displayFavouriteIconInListTile.valueR) ...[
                        const SizedBox(height: 3.0),
                        const NamidaRawLikeButton(
                          size: 20.0,
                          isLiked: null,
                          removeConfirmationAction: null,
                          onTap: null,
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
        bigahh: true,
        compact: false,
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
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.partyMode),
                icon: Broken.slider_horizontal_1,
                title: lang.ENABLE_PARTY_MODE,
                subtitle: lang.ENABLE_PARTY_MODE_SUBTITLE,
                onChanged: (value) {
                  if (value) return settings.save(enablePartyModeInMiniplayer: false);
                  SussyBaka.monetize(onEnable: () => settings.save(enablePartyModeInMiniplayer: true));
                },
                value: settings.enablePartyModeInMiniplayer.valueR,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.edgeColorsSwitching,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.edgeColorsSwitching),
                enabled: settings.enablePartyModeInMiniplayer.valueR,
                icon: Broken.colors_square,
                title: lang.EDGE_COLORS_SWITCHING,
                onChanged: (value) {
                  settings.save(enablePartyModeColorSwap: !value);
                  CurrentColor.inst.switchColorPalettes(swapEnabled: !value);
                },
                value: settings.enablePartyModeColorSwap.valueR,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.movingParticles,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.movingParticles),
                icon: Broken.buy_crypto,
                title: lang.ENABLE_MINIPLAYER_PARTICLES,
                onChanged: (value) => settings.save(enableMiniplayerParticles: !value),
                value: settings.enableMiniplayerParticles.valueR,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.THUMBANIMATIONINTENSITY,
            child: NamidaExpansionTile(
              bgColor: getBgColor(_CustomizationSettingsKeys.THUMBANIMATIONINTENSITY),
              initiallyExpanded: true,
              borderless: true,
              icon: Broken.flash,
              iconColor: context.defaultIconColor(),
              titleText: lang.ANIMATING_THUMBNAIL_INTENSITY,
              childrenPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              children: [
                getItemWrapper(
                  key: _CustomizationSettingsKeys.thumbAnimationIntensityExpanded,
                  child: Obx(
                    (context) => CustomListTile(
                      visualDensity: VisualDensity.compact,
                      bgColor: getBgColor(_CustomizationSettingsKeys.thumbAnimationIntensityExpanded),
                      icon: Broken.flash,
                      title: lang.EXPANDED_MINIPLAYER,
                      trailing: NamidaWheelSlider(
                        max: 25,
                        initValue: settings.animatingThumbnailIntensity.valueR,
                        onValueChanged: (val) => settings.save(animatingThumbnailIntensity: val),
                        text: "${(settings.animatingThumbnailIntensity.valueR * 4).toStringAsFixed(0)}%",
                      ),
                    ),
                  ),
                ),
                getItemWrapper(
                  key: _CustomizationSettingsKeys.thumbAnimationIntensityLyrics,
                  child: Obx(
                    (context) => CustomListTile(
                      visualDensity: VisualDensity.compact,
                      bgColor: getBgColor(_CustomizationSettingsKeys.thumbAnimationIntensityLyrics),
                      leading: const StackedIcon(
                        baseIcon: Broken.flash,
                        secondaryIcon: Broken.document,
                        secondaryIconSize: 10.0,
                      ),
                      title: lang.LYRICS,
                      trailing: NamidaWheelSlider(
                        max: 25,
                        initValue: settings.animatingThumbnailIntensityLyrics.valueR,
                        onValueChanged: (val) => settings.save(animatingThumbnailIntensityLyrics: val),
                        text: "${(settings.animatingThumbnailIntensityLyrics.valueR * 4).toStringAsFixed(0)}%",
                      ),
                    ),
                  ),
                ),
                getItemWrapper(
                  key: _CustomizationSettingsKeys.thumbAnimationIntensityMinimized,
                  child: Obx(
                    (context) => CustomListTile(
                      visualDensity: VisualDensity.compact,
                      bgColor: getBgColor(_CustomizationSettingsKeys.thumbAnimationIntensityMinimized),
                      leading: const StackedIcon(
                        baseIcon: Broken.flash,
                        secondaryIcon: Broken.arrow_square_down,
                        secondaryIconSize: 11.0,
                      ),
                      title: lang.MINIMIZED_MINIPLAYER,
                      trailing: NamidaWheelSlider(
                        max: 25,
                        initValue: settings.animatingThumbnailIntensityMinimized.valueR,
                        onValueChanged: (val) => settings.save(animatingThumbnailIntensityMinimized: val),
                        text: "${(settings.animatingThumbnailIntensityMinimized.valueR * 4).toStringAsFixed(0)}%",
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.thumbInverseAnimation,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.thumbInverseAnimation),
                icon: Broken.arrange_circle_2,
                title: lang.ANIMATING_THUMBNAIL_INVERSED,
                subtitle: lang.ANIMATING_THUMBNAIL_INVERSED_SUBTITLE,
                onChanged: (value) {
                  settings.save(animatingThumbnailInversed: !value);
                },
                value: settings.animatingThumbnailInversed.valueR,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.ARTWORKGESTURES,
            child: NamidaExpansionTile(
              bgColor: getBgColor(_CustomizationSettingsKeys.ARTWORKGESTURES),
              icon: Broken.gallery,
              iconColor: context.defaultIconColor(),
              initiallyExpanded: true,
              borderless: true,
              titleText: lang.ARTWORK_GESTURES,
              childrenPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NamidaIconButton(
                    tooltip: () => lang.RESTORE_DEFAULTS,
                    icon: Broken.refresh,
                    iconSize: 20.0,
                    onPressed: () {
                      settings.save(
                        artworkGestureDoubleTapLRC: true,
                        animatingThumbnailScaleMultiplier: 1.0,
                        artworkTapAction: TrackExecuteActions.none,
                        artworkLongPressAction: TrackExecuteActions.none,
                      );
                    },
                  ),
                  const SizedBox(width: 4.0),
                  const Icon(Broken.arrow_down_2, size: 20.0),
                  const SizedBox(width: 12.0),
                ],
              ),
              children: [
                getItemWrapper(
                  key: _CustomizationSettingsKeys.scaleMultiplier,
                  child: ObxO(
                    rx: settings.animatingThumbnailScaleMultiplier,
                    builder: (context, animatingThumbnailScaleMultiplier) {
                      final valueHundred = (animatingThumbnailScaleMultiplier * 100).round();
                      return CustomListTile(
                        visualDensity: VisualDensity.compact,
                        bgColor: getBgColor(_CustomizationSettingsKeys.scaleMultiplier),
                        icon: Broken.maximize,
                        title: lang.SCALE_MULTIPLIER,
                        trailing: NamidaWheelSlider(
                          min: 50,
                          max: 150,
                          initValue: valueHundred,
                          onValueChanged: (val) => settings.save(animatingThumbnailScaleMultiplier: val / 100),
                          text: "$valueHundred%",
                        ),
                      );
                    },
                  ),
                ),
                getItemWrapper(
                  key: _CustomizationSettingsKeys.doubleTapLyrics,
                  child: Obx(
                    (context) => CustomSwitchListTile(
                      visualDensity: VisualDensity.compact,
                      bgColor: getBgColor(_CustomizationSettingsKeys.doubleTapLyrics),
                      leading: const StackedIcon(
                        baseIcon: Broken.document,
                        secondaryIcon: Broken.blend_2,
                        secondaryIconSize: 12.0,
                      ),
                      title: lang.DOUBLE_TAP_TO_TOGGLE_LYRICS,
                      value: settings.artworkGestureDoubleTapLRC.valueR,
                      onChanged: (value) {
                        settings.save(artworkGestureDoubleTapLRC: !value);
                      },
                    ),
                  ),
                ),
                _getSwipeActionTileWidget(
                  context: context,
                  key: _CustomizationSettingsKeys.artworkTapAction,
                  excludePlayerActions: true,
                  title: lang.TAP_ACTION,
                  icon: Broken.cd,
                  rx: settings.artworkTapAction,
                  onSave: (newItem) => settings.save(artworkTapAction: newItem),
                ),
                _getSwipeActionTileWidget(
                  context: context,
                  key: _CustomizationSettingsKeys.artworkLongPressAction,
                  excludePlayerActions: true,
                  title: lang.LONG_PRESS_ACTION,
                  icon: Broken.story,
                  rx: settings.artworkLongPressAction,
                  onSave: (newItem) => settings.save(artworkLongPressAction: newItem),
                ),
                const SizedBox(height: 6.0),
              ],
            ),
          ),
          const SizedBox(height: 6.0),
          getItemWrapper(
            key: _CustomizationSettingsKeys.waveformBarsCount,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.waveformBarsCount),
                icon: Broken.sound,
                title: lang.WAVEFORM_BARS_COUNT,
                trailing: Column(
                  children: [
                    NamidaWheelSlider(
                      width: 80,
                      min: 40,
                      max: 400,
                      initValue: settings.waveformTotalBars.valueR,
                      onValueChanged: (val) {
                        settings.save(waveformTotalBars: val);
                        WaveformController.inst.calculateUIWaveform();
                      },
                      text: settings.waveformTotalBars.valueR.toString(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayAudioInfo,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayAudioInfo),
                icon: Broken.text_block,
                title: lang.DISPLAY_AUDIO_INFO_IN_MINIPLAYER,
                onChanged: (value) => settings.save(displayAudioInfoMiniplayer: !value),
                value: settings.displayAudioInfoMiniplayer.valueR,
              ),
            ),
          ),
          getItemWrapper(
            key: _CustomizationSettingsKeys.displayArtistBeforeTitle,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_CustomizationSettingsKeys.displayArtistBeforeTitle),
                icon: Broken.align_left,
                title: lang.DISPLAY_ARTIST_BEFORE_TITLE,
                onChanged: (value) {
                  settings.save(displayArtistBeforeTitle: !value);
                  Player.inst.refreshRxVariables();
                },
                value: settings.displayArtistBeforeTitle.valueR,
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
    final theme = context.theme;
    return NamidaInkWell(
      bgColor: theme.colorScheme.surface.withAlpha(160),
      onTap: onTap,
      borderRadius: 8.0,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: text != null
          ? Text(
              text!,
              style: theme.textTheme.displaySmall,
            )
          : child,
    );
  }
}

class _AppIconWidgetRow extends StatefulWidget {
  const _AppIconWidgetRow();

  @override
  State<_AppIconWidgetRow> createState() => _AppIconWidgetRowState();
}

class _AppIconWidgetRowState extends State<_AppIconWidgetRow> {
  NamidaAppIcons? _enabledIcon;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final newEnabledIcon = await NamidaChannel.inst.getEnabledAppIcon();
    if (mounted && _enabledIcon != newEnabledIcon) {
      setState(() {
        _enabledIcon = newEnabledIcon;
      });
    }
  }

  Future<void> _onAddTap() {
    const submitUrl = 'https://discord.com/channels/1156253663803740271/1423484977693327430';
    return NamidaLinkUtils.openLink(submitUrl);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final enabledIcon = _enabledIcon;
    final enabledIconAuthorInfo = enabledIcon?.authorInfos.firstOrNull;
    final bgColor = theme.colorScheme.secondaryContainer;
    final iconsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ...NamidaAppIcons.values.map(
          (e) {
            final isEnabled = e == enabledIcon;
            return NamidaInkWell(
              animationDurationMS: 300,
              borderRadius: 12.0,
              padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              enableSecondaryTap: false,
              decoration: isEnabled
                  ? BoxDecoration(
                      color: bgColor.withValues(alpha: 0.75),
                      border: Border.all(
                        color: bgColor,
                        width: 1.5,
                      ),
                    )
                  : BoxDecoration(
                      color: bgColor.withValues(alpha: 0.25),
                    ),
              onTap: () async {
                await NamidaChannel.inst.changeAppIcon(e);
                await _refreshStatus();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    e.assetPath,
                    width: 34.0,
                    height: 35.0,
                    alignment: Alignment.center,
                  ),
                  SizedBox(height: 1.0),
                  Text(
                    e.name,
                    style: textTheme.displaySmall,
                  ),
                ],
              ),
            );
          },
        ),
        NamidaInkWell(
          animationDurationMS: 300,
          borderRadius: 12.0,
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          enableSecondaryTap: false,
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.25),
          ),
          onTap: _onAddTap,
          child: Text(
            lang.ADD,
            style: textTheme.displayMedium,
          ),
        ),
      ]
          .addSeparators(
            separator: SizedBox(width: 4.0),
          )
          .toList(),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 12.0),
        SizedBox(
          width: context.width,
          child: Row(
            children: [
              SizedBox(width: 8.0),
              Icon(
                Broken.attach_square,
                size: 22.0,
                color: context.defaultIconColor(),
              ),
              SizedBox(width: 8.0),
              Expanded(
                child: Wrap(
                  runSpacing: 2.0,
                  alignment: WrapAlignment.start,
                  runAlignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "${lang.APP_ICON}:",
                      style: theme.textTheme.displayMedium,
                    ),
                    if (enabledIcon != null) ...[
                      SizedBox(width: 6.0),
                      Text(
                        enabledIcon.name,
                        style: theme.textTheme.displayMedium,
                      ),
                      if (enabledIconAuthorInfo != null) ...[
                        SizedBox(width: 2.0),
                        Text(
                          "(@${enabledIconAuthorInfo.name})",
                          style: theme.textTheme.displaySmall,
                        ),
                        if (enabledIconAuthorInfo.aiModel != null)
                          NamidaInkWell(
                            bgColor: theme.cardColor,
                            margin: EdgeInsets.symmetric(horizontal: 2.0),
                            padding: EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
                            borderRadius: 4.0,
                            child: Text(
                              "AI",
                              style: theme.textTheme.displaySmall?.copyWith(fontSize: 10.0),
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.0),
        SmoothSingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: iconsRow,
        ),
        SizedBox(height: 8.0),
      ],
    );
  }
}
