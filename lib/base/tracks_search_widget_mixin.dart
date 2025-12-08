import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/base/tracks_search_wrapper.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/expandable_box.dart';

mixin TracksSearchWidgetMixin<W extends StatefulWidget> on State<W>, PortsProvider<Map<String, dynamic>> {
  Iterable<TrackExtended> getTracksExtended();
  RxBaseCore listChangesListenerRx();

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
  FocusNode? _focusNode;
  // bool _showSearchBox = false;
  String? _currentSearch;

  @override
  void initState() {
    _scrollController = ScrollController();
    _focusNode = FocusNode();
    listChangesListenerRx().addListener(_restartSearchPortIfNecessary);
    super.initState();
  }

  @override
  void dispose() {
    listChangesListenerRx().removeListener(_restartSearchPortIfNecessary);
    _focusNode?.dispose();
    _scrollController.dispose();
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
  }

  void _restartSearchPortIfNecessary() async {
    setState(() {
      _searchResults = null; // reset instantly to avoid index changes possible errors
    });
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
  IsolateFunctionReturnBuild<Map<String, dynamic>> isolateFunction(SendPort port) {
    final params = TracksSearchWrapper.generateParams(port, getTracksExtended());
    return IsolateFunctionReturnBuild(_searchTracksIsolate, params);
  }
}

class TracksSearchWidgetBox extends StatelessWidget {
  final TracksSearchWidgetMixin state;
  final String leftText;
  final MediaType type;

  const TracksSearchWidgetBox({
    super.key,
    required this.state,
    required this.leftText,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.mediaItemsTrackSortingReverse,
      builder: (context, sortingModesReverse) {
        final sortIsReverse = sortingModesReverse[type] == true;
        return ObxO(
          rx: settings.mediaItemsTrackSorting,
          builder: (context, sortingModes) {
            final sort = sortingModes[type]?.firstOrNull;
            return TracksSearchWidgetBoxBase(
              state: state,
              leftText: leftText,
              sortReverse: sortIsReverse,
              sort: sort,
              onSortTap: () => NamidaOnTaps.inst.onSubPageTracksSortIconTap(type),
              onReverseIconTap: (newSortReserve) {
                settings.updateMediaItemsTrackSortingReverse(type, newSortReserve);
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
  final void Function() onSortTap;
  final void Function(bool newSortReserve) onReverseIconTap;

  const TracksSearchWidgetBoxBase({
    super.key,
    required this.state,
    required this.leftText,
    required this.sort,
    required this.sortReverse,
    required this.onSortTap,
    required this.onReverseIconTap,
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
        leftWidgets: [
          const Icon(
            Broken.musicnote,
            size: 18.0,
          ),
          const SizedBox(width: 10.0),
        ],
        sortByMenuWidget: SortByMenu(
          title: sort?.toText() ?? lang.CUSTOM,
          popupMenuChild: () => const SizedBox(),
          onSortTap: onSortTap,
          isCurrentlyReversed: sortReverse,
          onReverseIconTap: () {
            onReverseIconTap(!sortReverse);
          },
        ),
        textField: CustomTextFiled(
          focusNode: state.focusNode,
          textFieldController: null,
          textFieldHintText: lang.SEARCH,
          onTextFieldValueChanged: state.searchTracks,
        ),
      ),
    );
  }
}
