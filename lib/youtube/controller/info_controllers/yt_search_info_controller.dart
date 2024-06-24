part of namidayoutubeinfo;

class _SearchInfoController {
  const _SearchInfoController();

  Future<YoutiPieSearchResult?> search(
    String query, {
    ExecuteDetails? details,
    bool peopleAlsoWatched = true,
  }) async {
    return YoutiPie.search.search(
      query,
      details: details,
      peopleAlsoWatched: peopleAlsoWatched,
    );
  }

  YoutiPieSearchResult? searchSync(
    String query, {
    ExecuteDetails? details,
    bool peopleAlsoWatched = true,
  }) {
    final cache = YoutiPie.cacheBuilder.forSearchResults(query: query);
    return cache.read();
  }
}
