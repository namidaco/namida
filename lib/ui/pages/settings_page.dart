import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/advanced_settings.dart';
import 'package:namida/ui/widgets/settings/backup_restore_settings.dart';
import 'package:namida/ui/widgets/settings/customization_settings.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings/indexer_settings.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';
import 'package:namida/ui/widgets/settings/youtube_settings.dart';

LinearGradient _bgLinearGradient(BuildContext context) {
  final firstC = context.theme.appBarTheme.backgroundColor ?? CurrentColor.inst.color.withAlpha(context.isDarkMode ? 0 : 25);
  final secondC = CurrentColor.inst.color.withAlpha(context.isDarkMode ? 40 : 60);
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.2, 1.0],
    colors: [
      firstC,
      secondC,
    ],
  );
}

class SettingsPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.SETTINGS_page;

  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Stack(
        children: [
          Container(
            height: context.height,
            decoration: BoxDecoration(
              gradient: _bgLinearGradient(context),
            ),
          ),
          ObxO(
            rx: settings.useSettingCollapsedTiles,
            builder: (context, collapsed) => collapsed
                ? const CollapsedSettingTiles()
                : SuperSmoothListView(
                    padding: EdgeInsets.symmetric(horizontal: Dimensions.inst.getSettingsHorizontalMargin(context)),
                    children: [
                      const _QuickSuggestionsForSettings(),
                      const ThemeSetting(),
                      const IndexerSettings(),
                      const PlaybackSettings(),
                      const CustomizationSettings(),
                      const YoutubeSettings(),
                      const ExtrasSettings(),
                      const BackupAndRestore(),
                      const AdvancedSettings(),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: AboutPageTileWidget(),
                      ),
                      kBottomPaddingWidget,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class SettingsSubPage extends StatelessWidget with NamidaRouteWidget {
  @override
  String? get name => title();
  @override
  RouteType get route => RouteType.SETTINGS_subpage;

  final String Function() title;
  final Widget child;
  const SettingsSubPage({super.key, required this.child, required this.title});
  @override
  Widget build(BuildContext context) {
    final double horizontalMargin = Dimensions.inst.getSettingsHorizontalMargin(context);
    return BackgroundWrapper(
      child: Stack(
        children: [
          Container(
            height: context.height,
            decoration: BoxDecoration(
              gradient: _bgLinearGradient(context),
            ),
          ),
          SmoothSingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                child,
                kBottomPaddingWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CollapsedSettingTiles extends StatelessWidget {
  const CollapsedSettingTiles({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final double horizontalMargin = 0.5 * Dimensions.inst.getSettingsHorizontalMargin(context);
    return SuperSmoothListView(
      padding: EdgeInsets.symmetric(horizontal: 8.0 + horizontalMargin),
      children: [
        const _QuickSuggestionsForSettings(),
        CustomCollapsedListTile(
          title: () => lang.themeSettings,
          subtitle: lang.themeSettingsSubtitle,
          icon: Broken.brush_2,
          page: () => const ThemeSetting(),
        ),
        CustomCollapsedListTile(
          title: () => lang.indexer,
          subtitle: lang.indexerSubtitle,
          icon: Broken.component,
          page: () => const IndexerSettings(),
          trailing: const IndexingPercentage(size: 32.0),
        ),
        CustomCollapsedListTile(
          title: () => lang.playbackSetting,
          subtitle: lang.playbackSettingSubtitle,
          icon: Broken.play_cricle,
          page: () => const PlaybackSettings(),
          trailing: const VideosExtractingPercentage(size: 32.0),
        ),
        CustomCollapsedListTile(
          title: () => lang.customizations,
          subtitle: lang.customizationsSubtitle,
          icon: Broken.brush_1,
          page: () => const CustomizationSettings(),
        ),
        CustomCollapsedListTile(
          title: () => lang.youtube,
          subtitle: lang.youtubeSettingsSubtitle,
          icon: Broken.video,
          page: () => const YoutubeSettings(),
        ),
        CustomCollapsedListTile(
          title: () => lang.extras,
          subtitle: lang.extrasSubtitle,
          icon: Broken.command_square,
          page: () => const ExtrasSettings(),
        ),
        CustomCollapsedListTile(
          title: () => lang.backupAndRestore,
          subtitle: lang.backupAndRestoreSubtitle,
          icon: Broken.refresh_circle,
          page: () => const BackupAndRestore(),
          trailing: const ParsingJsonPercentage(size: 32.0),
        ),
        CustomCollapsedListTile(
          title: () => lang.advancedSettings,
          subtitle: lang.advancedSettingsSubtitle,
          icon: Broken.hierarchy_3,
          page: () => const AdvancedSettings(),
        ),
        const AboutPageTileWidget(),
        // const CollapsedSettingTileWidget(),
        kBottomPaddingWidget,
      ],
    );
  }
}

class CustomCollapsedListTile extends StatelessWidget {
  final Color? bgColor;
  final String Function() title;
  final String? subtitle;
  final Widget Function()? page;
  final NamidaRouteWidget Function()? rawPage;
  final IconData? icon;
  final Widget? trailing;

  const CustomCollapsedListTile({
    super.key,
    this.bgColor,
    required this.title,
    required this.subtitle,
    required this.page,
    this.rawPage,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
      largeTitle: true,
      title: title(),
      subtitle: subtitle,
      icon: icon,
      dense: false,
      trailingRaw: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 8.0),
          if (trailing != null) ...[trailing!, const SizedBox(width: 8.0)],
          const Icon(
            Broken.arrow_right_3,
          ),
        ],
      ),
      onTap: () {
        final r = rawPage != null
            ? rawPage!()
            : page != null
            ? SettingsSubPage(
                title: title,
                child: page!(),
              )
            : null;
        r?.navigate();
      },
    );
  }
}

class _QuickSuggestionsForSettings extends StatelessWidget {
  const _QuickSuggestionsForSettings();

  @override
  Widget build(BuildContext context) {
    const indexer = IndexerSettings();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: SizedBox(
        width: Dimensions.inst.availableAppContentWidthContext(context),
        child: FittedBox(
          alignment: AlignmentGeometry.centerStart,
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              _QuickSuggestionsTile(
                icon: Broken.folder_add,
                title: lang.addFolder,
                subtitle: indexer.getAddFolderSubtitleKeys(includeAllInfo: false).join(', '),
                onTap: indexer.promptAddFolderType,
              ),
              const SizedBox(width: 8.0),
              _QuickSuggestionsTile(
                expanded: false,
                icon: null,
                leading: const RefreshLibraryIcon(
                  widgetKey: 'quick_suggestions',
                  size: 20.0,
                ),
                title: lang.refreshLibrary,
                subtitle: '',
                onTap: () {
                  showRefreshPromptDialog(false, allowBypassing: true);
                },
              ),
              const SizedBox(width: 8.0),
              _QuickSuggestionsTile(
                expanded: false,
                icon: Broken.box_add,
                title: lang.createBackup,
                subtitle: '',
                onTap: () {
                  final backup = BackupAndRestore();
                  backup.promptCreateBackup(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickSuggestionsTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool expanded;

  const _QuickSuggestionsTile({
    required this.icon,
    this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final title = expanded ? this.title : '';
    final tooltip = this.title;

    final theme = context.theme;
    final textTheme = theme.textTheme;
    final isDarkMode = context.isDarkMode;
    final colorScheme = CurrentColor.inst.color;
    final scaffoldBgColor = Color.alphaBlend(theme.scaffoldBackgroundColor.withOpacityExt(0.5), isDarkMode ? Colors.black : Colors.white);
    const foregroundColorOpacity = 0.8;
    final foregroundColor = Color.alphaBlend(colorScheme.withOpacityExt(0.1), theme.colorScheme.onSurface).withOpacityExt(foregroundColorOpacity);
    return Tooltip(
      message: tooltip,
      child: NamidaInkWell(
        onTap: onTap,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
          border: Border.all(
            color: colorScheme.withOpacityExt(0.25),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(scaffoldBgColor.withOpacityExt(0.95), colorScheme).withOpacityExt(1.0),
              Color.alphaBlend(scaffoldBgColor.withOpacityExt(0.75), colorScheme).withOpacityExt(1.0),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.withAlpha(isDarkMode ? 20 : 60),
              spreadRadius: 0.1,
              blurRadius: 4.0,
              offset: const Offset(0.0, 2.0),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 42.0,
            maxHeight: 42.0,
            minWidth: 48.0,
            maxWidth: (context.width * 0.5).withMinimum(48.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 4.0),
              leading ??
                  Icon(
                    icon,
                    size: 20.0,
                    color: foregroundColor.withOpacityExt(foregroundColorOpacity * 0.85),
                  ),
              if (title.isNotEmpty || subtitle.isNotEmpty) ...[
                const SizedBox(width: 8.0),
                Flexible(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: textTheme.displayMedium?.copyWith(
                            color: foregroundColor.withOpacityExt(foregroundColorOpacity * 0.85),
                          ),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: textTheme.displaySmall?.copyWith(
                            color: foregroundColor.withOpacityExt(foregroundColorOpacity * 0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 4.0),
            ],
          ),
        ),
      ),
    );
  }
}
