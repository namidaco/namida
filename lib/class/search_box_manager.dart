import 'package:flutter/material.dart';

import 'package:namida/base/tracks_search_wrapper.dart';
import 'package:namida/controller/settings_controller.dart';
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

  List<String> filterPlaylistNames(List<String> itemsNames, String searchQuery, {KeysSearchWeights? weights}) {
    return filterPlaylistNamesWithResolver(itemsNames, searchQuery, _defaultTextResolver, weights: weights);
  }

  List<T> filterPlaylistNamesWithResolver<T>(List<T> items, String searchQuery, String? Function(T item) toTextResolver, {KeysSearchWeights? weights}) {
    final searchWrapper = KeysSearchWrapper.init(items, title: toTextResolver, weights: weights, cleanup: settings.enableSearchCleanup.value);
    return searchWrapper.filter(searchQuery);
  }
}
