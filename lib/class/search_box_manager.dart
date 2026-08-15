import 'package:flutter/material.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class SearchBoxManager {
  RxBaseCore<bool> get searchBoxVisible => _searchBoxVisible;
  RxBaseCore<String> get searchQuery => _searchQuery;
  TextEditingController get searchController => _searchController;
  FocusNode get searchFocusNode => _searchFocusNode;

  final _searchBoxVisible = false.obs;
  final _searchQuery = ''.obs;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  void dispose() {
    _searchBoxVisible.close();
    _searchQuery.close();
    _searchController.dispose();
    _searchFocusNode.dispose();
  }

  void updateSearchQuery(String value) {
    _searchQuery.value = value;
  }

  void toggleSearchBoxVisibility() {
    if (_searchBoxVisible.value) {
      if (_searchController.text.isEmpty) {
        _searchBoxVisible.value = false;
        _searchFocusNode.unfocus();
      }
    } else {
      _searchBoxVisible.value = true;
      _searchFocusNode.requestFocus();
    }
  }

  void onSearchCloseButtonPressed() {
    _searchController.clear();
    _searchQuery.value = '';
    _searchBoxVisible.value = false;
    _searchFocusNode.unfocus();
  }

  String _defaultTextResolver(String value) => value;

  Iterable<String> filterPlaylistNames(Iterable<String> itemsNames, String searchQuery) {
    return filterPlaylistNamesWithResolver(itemsNames, searchQuery, _defaultTextResolver);
  }

  Iterable<T> filterPlaylistNamesWithResolver<T>(Iterable<T> items, String searchQuery, String? Function(T item) toTextResolver) sync* {
    final cleanup = settings.enableSearchCleanup.value;
    final queryCleaned = cleanup ? searchQuery.cleanUpForComparison : searchQuery.toLowerCase();
    for (final item in items) {
      final itemText = toTextResolver(item);
      if (itemText != null) {
        final isMatch = (cleanup ? itemText.cleanUpForComparison : itemText.toLowerCase()).contains(queryCleaned);
        if (isMatch) yield item;
      }
    }
  }
}
