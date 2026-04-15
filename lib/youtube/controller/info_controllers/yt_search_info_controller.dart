part of '../youtube_info_controller.dart';

class _SearchInfoController {
  const _SearchInfoController();

  Future<List<SearchSuggestionInfo>?> getSuggestions(
    String query, {
    ExecuteDetails? details,
  }) => YoutiPie.search.getSuggestions(
    query,
    details: details,
  );

  Future<YoutiPieSearchResult?> search(
    String query, {
    ExecuteDetails? details,
    bool peopleAlsoWatched = true,
  }) => YoutiPie.search.search(
    query,
    details: details,
    peopleAlsoWatched: peopleAlsoWatched,
  );
}
