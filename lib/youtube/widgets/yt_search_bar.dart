import 'package:flutter/material.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/pages/yt_search_results_page.dart';

class YoutubeSearchBar extends StatelessWidget {
  const YoutubeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    return Container(
      padding: const EdgeInsets.only(right: 12.0),
      height: 38.0,
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
          ),
          hintText: lang.SEARCH_YOUTUBE,
        ),
        onChanged: (value) {},
        onSubmitted: (value) {
          searchController.clear();
          NamidaNavigator.inst.navigateTo(YoutubeSearchResultsPage(searchText: value));
        },
      ),
    );
  }
}
