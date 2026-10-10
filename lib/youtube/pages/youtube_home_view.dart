// rewritten by claude, new one keeps local/youtube per section (picked from the selected tab), custom sections header with an expanding label that names the source, sections can be pinned as library tabs, account pages show a sign in placeholder
import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/pages/home_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/pages/youtube_feed_page.dart';
import 'package:namida/youtube/pages/youtube_main_page_fetcher_acc_base.dart';
import 'package:namida/youtube/pages/youtube_notifications_page.dart';
import 'package:namida/youtube/pages/youtube_user_playlists_page.dart';
import 'package:namida/youtube/pages/yt_channels_page.dart';
import 'package:namida/youtube/pages/yt_downloads_page.dart';
import 'package:namida/youtube/youtube_playlists_view.dart';

class YouTubeHomeView extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_HOME;

  const YouTubeHomeView({super.key});

  static void openSection(YTHomePages section) {
    settings.extra.ytInitialHomePage.save(section);
    ScrollSearchController.inst.animatePageController(LibraryTab.youtube);
  }

  @override
  State<YouTubeHomeView> createState() => _YouTubeHomeViewState();
}

class _YouTubeHomeViewState extends State<YouTubeHomeView> with SingleTickerProviderStateMixin {
  static const _tabCurve = Curves.fastEaseInToSlowEaseOut;

  late YTHomePages _selectedSection = settings.extra.ytInitialHomePage.value;
  late final _tabController = TabController(
    length: YTHomePages.values.length,
    initialIndex: _selectedSection.index,
    animationDuration: const Duration(milliseconds: 300),
    vsync: this,
  );
  final _sectionPages = YTHomePages.values
      .map(
        (section) => _SectionPage(
          section: section,
        ),
      )
      .toFixedList();

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabIndexChanged);
    settings.extra.ytInitialHomePage.addListener(_onSavedSectionChanged);
  }

  @override
  void dispose() {
    settings.extra.ytInitialHomePage.removeListener(_onSavedSectionChanged);
    _tabController.removeListener(_onTabIndexChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabIndexChanged() {
    final section = YTHomePages.values[_tabController.index];
    if (section == _selectedSection) return;
    setState(() => _selectedSection = section);
    settings.extra.ytInitialHomePage.save(section);
  }

  void _onSavedSectionChanged() {
    final section = settings.extra.ytInitialHomePage.value;
    if (section == _selectedSection) return;
    _tabController.animateTo(section.index, curve: _tabCurve);
  }

  void _selectSection(YTHomePages section) => _tabController.animateTo(section.index, curve: _tabCurve);

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Column(
        children: [
          _SectionsHeader(
            selectedSection: _selectedSection,
            position: _tabController.animation!,
            onSelect: _selectSection,
          ),
          Expanded(
            child: TabBarView(
              physics: isDesktop ? const NeverScrollableScrollPhysics() : null,
              controller: _tabController,
              children: _sectionPages,
            ),
          ),
        ],
      ),
    );
  }
}

class YouTubeHomeSectionView extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_HOME_SECTION;

  @override
  String get name => section.name;

  final YTHomePages section;

  const YouTubeHomeSectionView({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final Widget sectionPage = section.hasSourceChoice
        ? _SectionSourcesSplitPage(
            section: section,
          )
        : _SourcePage(
            section: section,
            source: section.sources.first,
          );
    return BackgroundWrapper(
      child: sectionPage,
    );
  }
}

class _SectionsHeader extends StatelessWidget {
  final YTHomePages selectedSection;
  final Animation<double> position;
  final void Function(YTHomePages section) onSelect;

  const _SectionsHeader({required this.selectedSection, required this.position, required this.onSelect});

  static const _itemsPadding = 3.0;
  static const _selectedWidthMultiplier = 2.2;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final headerColor = theme.cardTheme.color ?? theme.cardColor;
    final selectedBgColor = theme.colorScheme.secondary.withOpacityExt(0.18);
    final sections = YTHomePages.values;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 4.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: headerColor,
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_itemsPadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final collapsedWidth = constraints.maxWidth / (sections.length - 1 + _selectedWidthMultiplier);
              final expandedWidth = constraints.maxWidth - collapsedWidth * (sections.length - 1);
              final labelMaxWidth = (expandedWidth - _SectionTabItem.reservedWidth).withMinimum(0.0);
              return AnimatedBuilder(
                animation: position,
                builder: (context, _) {
                  final positionValue = position.value;
                  return Row(
                    children: sections.map(
                      (section) {
                        final distance = (positionValue - section.index).abs();
                        final expansion = (1.0 - distance).clampDouble(0.0, 1.0);
                        final width = collapsedWidth + (expandedWidth - collapsedWidth) * expansion;
                        return _SectionTab(
                          section: section,
                          isSelected: section == selectedSection,
                          expansion: expansion,
                          width: width,
                          labelMaxWidth: labelMaxWidth,
                          selectedBgColor: selectedBgColor,
                          badgeColor: headerColor,
                          onSelect: onSelect,
                        );
                      },
                    ).toFixedList(),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final YTHomePages section;
  final bool isSelected;
  final double expansion;
  final double width;
  final double labelMaxWidth;
  final Color selectedBgColor;
  final Color badgeColor;
  final void Function(YTHomePages section) onSelect;

  const _SectionTab({
    required this.section,
    required this.isSelected,
    required this.expansion,
    required this.width,
    required this.labelMaxWidth,
    required this.selectedBgColor,
    required this.badgeColor,
    required this.onSelect,
  });

  void _onTap() => onSelect(section);

  String _getTooltip(YTHomeSource source) {
    final sectionText = section.toText();
    if (!section.showsSource) return sectionText;
    return '$sectionText (${source.toText()})';
  }

  @override
  Widget build(BuildContext context) {
    if (!section.hasSourceChoice) {
      final source = section.sources.first;
      return Tooltip(
        message: _getTooltip(source),
        child: NamidaInkWell(
          borderRadius: 9.0,
          onTap: isSelected ? null : _onTap,
          child: _SectionTabItem(
            section: section,
            source: source,
            expansion: expansion,
            width: width,
            labelMaxWidth: labelMaxWidth,
            selectedBgColor: selectedBgColor,
            badgeColor: badgeColor,
          ),
        ),
      );
    }
    return ObxO(
      rx: settings.extra.ytHomeSectionSources,
      builder: (context, _) {
        final source = settings.extra.getYTHomeSectionSource(section);
        return Tooltip(
          message: _getTooltip(source),
          child: NamidaPopupWrapper(
            openOnTap: isSelected,
            onTap: isSelected ? null : _onTap,
            childrenDefault: () => section.sources.map(
              (itemSource) => NamidaPopupItem(
                icon: itemSource.toIcon(),
                title: itemSource.toText(),
                selected: itemSource == source,
                onTap: () => settings.extra.setYTHomeSectionSource(section, itemSource),
              ),
            ),
            child: _SectionTabItem(
              section: section,
              source: source,
              expansion: expansion,
              width: width,
              labelMaxWidth: labelMaxWidth,
              selectedBgColor: selectedBgColor,
              badgeColor: badgeColor,
            ),
          ),
        );
      },
    );
  }
}

class _SectionTabItem extends StatelessWidget {
  final YTHomePages section;
  final YTHomeSource source;
  final double expansion;
  final double width;
  final double labelMaxWidth;
  final Color selectedBgColor;
  final Color badgeColor;

  const _SectionTabItem({
    required this.section,
    required this.source,
    required this.expansion,
    required this.width,
    required this.labelMaxWidth,
    required this.selectedBgColor,
    required this.badgeColor,
  });

  static const _iconSize = 20.0;
  static const _labelGap = 8.0;
  static const _horizontalPadding = 8.0;
  static const reservedWidth = _horizontalPadding * 2 + _iconSize + _labelGap;

  @override
  Widget build(BuildContext context) {
    final showsSource = section.showsSource;
    final bgColor = selectedBgColor.withOpacityExt(selectedBgColor.a * expansion);
    final badgeBgColor = Color.alphaBlend(bgColor, badgeColor);
    final icon = Icon(
      section.toIcon(),
      size: _iconSize,
    );
    final Widget iconWidget = showsSource
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              icon,
              Positioned(
                right: -7.0,
                bottom: -4.0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(
                      source.toIcon(),
                      size: 11.0,
                    ),
                  ),
                ),
              ),
            ],
          )
        : icon;
    return Container(
      width: width,
      height: 40.0,
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          if (expansion > 0.0)
            Flexible(
              child: ClipRect(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: expansion,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: _labelGap),
                    child: _SectionTabLabel(
                      section: section,
                      source: source,
                      expansion: expansion,
                      maxWidth: labelMaxWidth,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTabLabel extends StatelessWidget {
  final YTHomePages section;
  final YTHomeSource source;
  final double expansion;
  final double maxWidth;

  const _SectionTabLabel({
    required this.section,
    required this.source,
    required this.expansion,
    required this.maxWidth,
  });

  Color? _getFaded(Color? color) => color?.withOpacityExt(color.a * expansion);

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final titleStyle = textTheme.displayMedium?.copyWith(height: 1.15);
    final sourceStyle = textTheme.displaySmall?.copyWith(fontSize: 10.0, height: 1.0);
    final hasSourceChoice = section.hasSourceChoice;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.toText(),
              maxLines: 1,
              style: titleStyle?.copyWith(color: _getFaded(titleStyle.color)),
            ),
            if (section.showsSource)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 1.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      source.toText(),
                      maxLines: 1,
                      style: sourceStyle?.copyWith(color: _getFaded(sourceStyle.color)),
                    ),
                    if (hasSourceChoice) const SizedBox(width: 1.0),
                    if (hasSourceChoice)
                      Icon(
                        Broken.arrow_down_2,
                        size: 9.0,
                        color: _getFaded(context.defaultIconColor()),
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

class _SectionPage extends StatelessWidget {
  final YTHomePages section;

  const _SectionPage({required this.section});

  @override
  Widget build(BuildContext context) {
    if (!section.hasSourceChoice) {
      return _SourcePage(
        section: section,
        source: section.sources.first,
      );
    }
    return ObxO(
      rx: settings.extra.ytHomeSectionSources,
      builder: (context, _) {
        final source = settings.extra.getYTHomeSectionSource(section);
        return _SourcePage(
          key: ValueKey(source),
          section: section,
          source: source,
        );
      },
    );
  }
}

class _SectionSourcesSplitPage extends StatelessWidget {
  final YTHomePages section;

  const _SectionSourcesSplitPage({required this.section});

  @override
  Widget build(BuildContext context) {
    final sources = section.sources;
    final initialSource = settings.extra.getYTHomeSectionSource(section);
    return SplitPage(
      initialIndex: sources.indexOf(initialSource),
      onIndexChanged: (index) => settings.extra.setYTHomeSectionSource(section, sources[index]),
      pages: sources
          .map(
            (source) => SplitPageInfo(
              title: source.toText(),
              page: _SourcePage(
                key: ValueKey(source),
                section: section,
                source: source,
              ),
            ),
          )
          .toFixedList(),
    );
  }
}

class _SourcePage extends StatelessWidget {
  final YTHomePages section;
  final YTHomeSource source;

  const _SourcePage({super.key, required this.section, required this.source});

  @override
  Widget build(BuildContext context) {
    final Widget page = switch ((section, source)) {
      (YTHomePages.home, YTHomeSource.local) => const YTHomePageLocal(),
      (YTHomePages.home, YTHomeSource.youtube) => const YoutubeHomeFeedPage(),
      (YTHomePages.notifications, _) => const YoutubeNotificationsPage(),
      (YTHomePages.channels, YTHomeSource.local) => const YoutubeChannelsPage(),
      (YTHomePages.channels, YTHomeSource.youtube) => const YoutubeChannelsHostedPage(),
      (YTHomePages.playlists, YTHomeSource.local) => const YoutubePlaylistsView(),
      (YTHomePages.playlists, YTHomeSource.youtube) => const YoutubeUserPlaylistsPage(),
      (YTHomePages.downloads, _) => const YTDownloadsPage(),
    };
    if (!source.requiresAccount) return page;
    return ObxO(
      rx: YoutubeAccountController.current.activeAccountChannel,
      builder: (context, activeAccountChannel) => activeAccountChannel == null ? const YoutubeSignInRequiredPage() : page,
    );
  }
}
