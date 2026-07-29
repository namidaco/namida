import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/base/tracks_search_wrapper.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/create_smart_playlist_dialog.dart';
import 'package:namida/ui/pages/search_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';

mixin TracksSearchWidgetMixin<W extends StatefulWidget> on State<W>, PortsProvider<Map<String, dynamic>> {
  Iterable<TrackExtended> getTracksExtended();

  /// example: sort, sortReverse
  List<RxBaseCore> _listChangesListenersInstantRx() => [settings.mediaItemsTrackSorting, settings.mediaItemsTrackSortingReverse];

  /// example: main list or map that gets updated
  RxBaseCore listChangesListenerRx();

  /// example: another main list or map that gets updated
  RxBaseCore? listChangesListenerAltRx() {
    return null;
  }

  bool shouldHideIndex(int index) {
    final searchRes = this.searchResults;
    return searchRes != null && !searchRes.contains(index);
  }

  ScrollController get scrollController => _scrollController;
  FocusNode? get focusNode => _focusNode;
  Set<int>? get searchResults => _searchResults;
  bool get isSearching => _searchResults != null;

  Set<int>? _searchResults;
  late ScrollController _scrollController;
  late TextEditingController _textEditingController;
  FocusNode? _focusNode;
  // bool _showSearchBox = false;
  String? _currentSearch;

  @override
  void initState() {
    _scrollController = NamidaScrollController.create();
    _textEditingController = TextEditingController();
    _focusNode = FocusNode();
    for (final l in _listChangesListenersInstantRx()) {
      l.addListener(_restartSearchPortIfNecessary);
    }
    listChangesListenerRx().addListener(_closeSearchPortIfNecessary);
    listChangesListenerAltRx()?.addListener(_closeSearchPortIfNecessary);
    super.initState();
  }

  @override
  void dispose() {
    for (final l in _listChangesListenersInstantRx()) {
      l.removeListener(_restartSearchPortIfNecessary);
    }
    listChangesListenerRx().removeListener(_closeSearchPortIfNecessary);
    listChangesListenerAltRx()?.removeListener(_closeSearchPortIfNecessary);
    _focusNode?.dispose();
    _scrollController.dispose();
    _textEditingController.dispose();
    disposePort();
    super.dispose();
  }

  bool onSearchBoxVisibilityChange(bool newShow) {
    if (newShow) {
      _focusNode?.requestFocus();
      return true;
    } else if (_currentSearch?.isEmpty ?? true) {
      // -- only if not searching
      _focusNode?.unfocus();
      searchTracks(null);
      return true;
    }
    return false;
  }

  void clearSearch() {
    searchTracks(null);
    _textEditingController.clear();
  }

  void _closeSearchPortIfNecessary() async {
    if (_searchResults != null) {
      setState(() => _searchResults = null);
    }

    if (isInitialized) {
      await disposePort();
    }
  }

  void _restartSearchPortIfNecessary() async {
    if (_searchResults != null) {
      setState(() {
        _searchResults = null; // reset instantly to avoid index changes possible errors
      });
    }

    if (!isInitialized) return; // dont bother if wasn't even searching or initialized
    await disposePort();
    if (!mounted) return;
    if (!isInitialized) await initialize();
    if (!mounted) return;
    searchTracks(_currentSearch);
  }

  Future<void> searchTracks(String? value) async {
    _currentSearch = value;
    if (value != null && value.isNotEmpty) {
      if (!isInitialized) await initialize();
      await sendPort(value);
    } else {
      if (_searchResults != null) setState(() => _searchResults = null);
    }
  }

  static void _searchTracksIsolate(Map params) {
    final sendPort = params['sendPort'] as SendPort;

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final searchWrapper = TracksSearchWrapper.init(params);

    StreamSubscription? streamSub;
    streamSub = receivePort.listen((p) {
      if (PortsProvider.isDisposeMessage(p)) {
        receivePort.close();
        streamSub?.cancel();
        return;
      }
      final text = p as String;
      final result = searchWrapper.filterIndicesAsSet(text);
      sendPort.send((result, text));
    });

    sendPort.send(null);
  }

  @override
  void onResult(dynamic result) {
    if (!mounted) return;
    result as (Set<int>, String);
    final text = result.$2;
    if (_currentSearch == text) {
      // try {
      //   _scrollController.jumpTo(0);
      // } catch (_) {}
      setState(() => _searchResults = result.$1);
    }
  }

  @override
  Future<IsolateFunctionReturnBuild<Map<String, dynamic>>> isolateFunction(SendPort port) async {
    await HistoryController.inst.waitForHistoryAndMostPlayedLoad;
    final topTracksMapListens = HistoryController.inst.topTracksMapListens.value;
    final params = TracksSearchWrapper.generateParams(port, getTracksExtended(), topTracksMapListens);
    return IsolateFunctionReturnBuild(_searchTracksIsolate, params);
  }
}

class TracksSearchWidgetBox extends StatefulWidget {
  final TracksSearchWidgetMixin state;
  final String leftText;
  final MediaType type;
  final String pageTitle;
  final bool disableSort;

  const TracksSearchWidgetBox({
    super.key,
    required this.state,
    required this.leftText,
    required this.type,
    required this.pageTitle,
    this.disableSort = false,
  });

  @override
  State<TracksSearchWidgetBox> createState() => _TracksSearchWidgetBoxState();
}

class _TracksSearchWidgetBoxState extends State<TracksSearchWidgetBox> {
  SmartPlaylistRuleBase _createTextRule(SmartPlaylistRuleFilterTextSource source, String text) {
    return SmartPlaylistRuleText(
      data: [
        SmartPlaylistTextDataTokenLiteral(text),
      ],
      filter: SmartPlaylistRuleFilterText.isSame,
      source: source,
      enableCleanup: false,
    );
  }

  SmartPlaylistRuleBase? _createNumberRule(SmartPlaylistRuleFilterNumberSource source, int? number) {
    if (number == null) return null;
    return SmartPlaylistRuleNumber(
      data: number,
      data2: null,
      filter: SmartPlaylistRuleFilterNumber.isGreaterThanOrEq,
      source: source,
      enableCleanup: false,
    );
  }

  SmartPlaylistRuleBase? _getRuleForType(MediaType type, String pageTitle) {
    return switch (type) {
      MediaType.track => _createTextRule(SmartPlaylistRuleFilterTextSource.title, pageTitle),
      MediaType.album => _createTextRule(SmartPlaylistRuleFilterTextSource.album, pageTitle),
      MediaType.artist => _createTextRule(SmartPlaylistRuleFilterTextSource.artist, pageTitle),
      MediaType.albumArtist => _createTextRule(SmartPlaylistRuleFilterTextSource.albumArtist, pageTitle),
      MediaType.composer => _createTextRule(SmartPlaylistRuleFilterTextSource.composer, pageTitle),
      MediaType.genre => _createTextRule(SmartPlaylistRuleFilterTextSource.genre, pageTitle),
      MediaType.folder => _createTextRule(SmartPlaylistRuleFilterTextSource.folderName, pageTitle),
      MediaType.folderMusic => _createTextRule(SmartPlaylistRuleFilterTextSource.folderName, pageTitle),
      MediaType.folderVideo => _createTextRule(SmartPlaylistRuleFilterTextSource.folderName, pageTitle),
      MediaType.mood => _createTextRule(SmartPlaylistRuleFilterTextSource.moods, pageTitle),
      MediaType.tag => _createTextRule(SmartPlaylistRuleFilterTextSource.tags, pageTitle),
      MediaType.rating => _createNumberRule(SmartPlaylistRuleFilterNumberSource.rating, int.tryParse(pageTitle)),
      MediaType.playlist => null,
    };
  }

  SmartPlaylistWrapper? createSmartPlaylist({
    required MediaType type,
    required SortType? sort,
    required bool sortReverse,
    required String pageTitle,
  }) {
    final rule = _getRuleForType(type, pageTitle);
    if (rule == null) return null;
    return SmartPlaylistWrapper(
      SmartPlaylist(
        name: lang.search,
        creationDate: DateTime.now(),
        joiner: SmartJoiner.defaultForGroups,
        sort: sort,
        sortReverse: sortReverse,
        moods: [],
        ruleGroups: [
          SmartPlaylistRuleGroup.create(rules: [rule]),
        ],
      ),
    );
  }

  void _onFilterIconLongPress({
    required MediaType type,
    required SortType? sort,
    required bool sortReverse,
    required String pageTitle,
  }) async {
    final initialSmartPlaylist = _cachedInitialSmartPlaylist ??= createSmartPlaylist(
      type: type,
      sort: sort,
      sortReverse: sortReverse,
      pageTitle: pageTitle,
    );

    if (initialSmartPlaylist == null) return;
    final smartPlaylistWrapper = await CreateSmartPlaylistDialog.getTempPlaylist(
      initialSmartPlaylistWrapper: initialSmartPlaylist,
    );

    if (mounted) {
      if (smartPlaylistWrapper != null && smartPlaylistWrapper.value.ruleGroups.isValid()) {
        _cachedInitialSmartPlaylist = smartPlaylistWrapper;

        ScrollSearchController.inst.searchBarKey.currentState?.openCloseSearchBar(forceOpen: true);
        ScrollSearchController.inst.showSearchMenu();
        ScrollSearchController.inst.resetSearch();

        Timer(
          const Duration(milliseconds: 50),
          () {
            SearchPage.setSmartSearchPlaylistWrapper(initialSmartSearchPlaylistWrapper: smartPlaylistWrapper);
          },
        );
      }
    }
  }

  SmartPlaylistWrapper? _cachedInitialSmartPlaylist;

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    return ObxO(
      rx: settings.mediaItemsTrackSortingReverse,
      builder: (context, sortingModesReverse) {
        final sortIsReverse = sortingModesReverse[type] == true;
        return ObxO(
          rx: settings.mediaItemsTrackSorting,
          builder: (context, sortingModes) {
            final sort = sortingModes[type]?.firstOrNull;
            return TracksSearchWidgetBoxBase(
              state: widget.state,
              leftText: widget.leftText,
              sort: sort,
              sortReverse: sortIsReverse,
              disableSort: widget.disableSort,
              onFilterIconLongPress: () => _onFilterIconLongPress(
                type: type,
                sort: sort,
                sortReverse: sortIsReverse,
                pageTitle: widget.pageTitle,
              ),
              onSortTap: () => NamidaOnTaps.inst.onSubPageTracksSortIconTap(type),
              onReverseIconTap: (newSortReverse) {
                settings.updateMediaItemsTrackSortingReverse(type, newSortReverse);
                Indexer.inst.sortMediaTracksSubLists([type]);
              },
            );
          },
        );
      },
    );
  }
}

class TracksSearchWidgetBoxBase extends StatelessWidget {
  final TracksSearchWidgetMixin state;
  final String leftText;
  final SortType? sort;
  final bool sortReverse;
  final bool disableSort;
  final void Function() onSortTap;
  final void Function(bool newSortReverse) onReverseIconTap;
  final void Function()? onFilterIconLongPress;

  const TracksSearchWidgetBoxBase({
    super.key,
    required this.state,
    required this.leftText,
    required this.sort,
    required this.sortReverse,
    this.disableSort = false,
    required this.onSortTap,
    required this.onReverseIconTap,
    this.onFilterIconLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.scaffoldBackgroundColor,
      child: ExpandableBox(
        enableHero: false,
        isBarVisible: true,
        leftText: leftText,
        onSearchBoxVisibilityChange: state.onSearchBoxVisibilityChange,
        onCloseButtonPressed: state.clearSearch,
        onFilterIconLongPress: onFilterIconLongPress,
        leftWidgets: [
          const Icon(
            Broken.musicnote,
            size: 18.0,
          ),
          const SizedBox(width: 10.0),
        ],
        sortByMenuWidget: SortByMenu(
          title: sort?.toText() ?? lang.custom,
          popupMenuChild: null,
          onSortTap: onSortTap,
          isCurrentlyReversed: sortReverse,
          onReverseIconTap: () {
            onReverseIconTap(!sortReverse);
          },
        ),
        disableSorting: disableSort,
        textField: CustomTextField(
          focusNode: state.focusNode,
          textFieldController: state._textEditingController,
          textFieldHintText: lang.search,
          onTextFieldValueChanged: state.searchTracks,
        ),
      ),
    );
  }
}
