import 'package:dart_extensions/dart_extensions.dart';

import 'package:namida/core/constants.dart';

class FilePathMatcher extends SearchMatcher {
  FilePathMatcher.init(super.paths) : super.init(transformer: _pathTransformer);

  static String _pathTransformer(String item) => item.getFilenameWOExt;

  Map<String, List<String>> get videosGroupedByYTID => _videosGroupedByYTID ??= _buildYTIDIndex();

  Map<String, List<String>>? _videosGroupedByYTID;

  Map<String, List<String>> _buildYTIDIndex() {
    final map = <String, List<String>>{};
    for (final vp in items) {
      var id = NamidaLinkRegex.youtubeIdInFilenameRegex.firstMatch(vp.getFilenameWOExt)?.group(1);
      if (id != null && id.isNotEmpty) {
        map.addForce(id, vp);
      }
    }
    return map;
  }
}

abstract class SearchMatcher {
  final Iterable<String> items;
  SearchMatcher.init(this.items, {String Function(String item)? transformer}) {
    _fillData(items, transformer: transformer);
  }

  final _tokenIndex = <String, Set<String>>{};

  void _fillData(Iterable<String> items, {required String Function(String item)? transformer}) {
    for (final p in items) {
      final tokens = _tokenize(transformer?.call(p) ?? p);
      for (final token in tokens) {
        final set = _tokenIndex[token] ??= {};
        set.add(p);
      }
    }
  }

  static Iterable<String> tokenize(String text) => _tokenize(text);

  static Iterable<String> _tokenize(String text) => text.cleanUpForComparison.split(' ').where((t) => t.isNotEmpty);

  Set<String> matchAllTokens(Iterable<String> tokens) {
    final sets = tokens.map((t) => _tokenIndex[t] ?? <String>{});
    if (sets.isEmpty) return {};
    return sets.reduce((a, b) => a.intersection(b));
  }

  Set<String> matchText(String text) => matchAllTokens(_tokenize(text));

  Set<String> matchBoth(String a, String b) => matchText(a).intersection(matchText(b));
}
