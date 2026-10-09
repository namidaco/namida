// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/split_config.dart';
import 'package:namida/controller/indexer_controller.dart';

void main() {
  const artistSeparators = ['&', ',', ';', '//', ' ft. ', ' x '];

  ArtistsSplitConfig artistsConfig({List<String> separators = artistSeparators, List<String> blacklist = const [], bool addFeatArtist = true}) {
    return ArtistsSplitConfig(addFeatArtist: addFeatArtist, separators: separators, separatorsBlacklist: blacklist);
  }

  List<String> splitArtist(String? title, String? artist, {ArtistsSplitConfig? config}) {
    return Indexer.splitArtist(title: title, originalArtist: artist, config: config ?? artistsConfig());
  }

  group('separators', () {
    test('padded separators split when the text pads them with non-breaking spaces', () {
      final config = artistsConfig();
      expect(config.splitText('A\u00A0x\u00A0B'), ['A', 'B']);
      expect(config.splitText('A\u00A0ft.\u00A0B'), ['A', 'B']);
    });

    test('extra whitespace is collapsed and trimmed', () {
      final config = artistsConfig();
      expect(config.splitText('  A   &   B  '), ['A', 'B']);
      expect(config.splitText('A  x  B'), ['A', 'B']);
      expect(config.splitText('The \t Beatles'), ['The Beatles']);
    });

    test('separators match ignoring case', () {
      expect(artistsConfig().splitText('A X B'), ['A', 'B']);
    });

    test('a non-breaking space separator splits', () {
      expect(SimpleSplitConfig().splitText('A\u00A0B'), ['A', 'B']);
      expect(SimpleSplitConfig().splitText(' A \u00A0 B '), ['A', 'B']);
    });

    test('albums do not split on slashes', () {
      expect(SimpleSplitConfig().splitText('A // B'), ['A // B']);
      expect(SimpleSplitConfig().splitText('A; B'), ['A', 'B']);
    });

    test('parts differing only in case are kept once, the first one wins', () {
      final config = GenresSplitConfig(separators: const [';', ','], separatorsBlacklist: const []);
      expect(config.splitText('Rock; rock; ROCK, Pop'), ['Rock', 'Pop']);
    });

    test('null or blank text gives the fallback', () {
      final config = SimpleSplitConfig();
      expect(config.splitText(null, fallback: 'U'), ['U']);
      expect(config.splitText('   ', fallback: 'U'), ['U']);
      expect(config.splitText('\u00A0', fallback: 'U'), ['U']);
      expect(config.splitText(';', fallback: 'U'), ['U']);
      expect(config.splitText(null), isEmpty);
    });

    test('without separators the text stays whole and blank text still gives the fallback', () {
      final config = GenresSplitConfig(separators: const [], separatorsBlacklist: const []);
      expect(config.splitText('  Rock  &  Pop '), ['Rock & Pop']);
      expect(config.splitText('   ', fallback: 'U'), ['U']);
    });

    test('normalizing keeps what splitting needs', () {
      final albumConfig = SimpleSplitConfig();
      final normalized = albumConfig.normalize('  One\u00A0Two  ');
      expect(normalized, 'One\u00A0Two');
      expect(albumConfig.splitText(normalized), albumConfig.splitText('  One\u00A0Two  '));
      expect(artistsConfig().normalize(' A\u00A0x  B '), 'A x B');
    });
  });

  group('blacklist', () {
    test('blacklisted names stay whole', () {
      final config = artistsConfig(blacklist: ['Simon & Garfunkel']);
      expect(config.splitText('Simon & Garfunkel'), ['Simon & Garfunkel']);
      expect(config.splitText('Simon & Garfunkel, Queen'), ['Simon & Garfunkel', 'Queen']);
      expect(config.splitText('Queen, Simon & Garfunkel'), ['Queen', 'Simon & Garfunkel']);
    });

    test('blacklisted names match through extra or non-breaking spaces', () {
      final config = artistsConfig(blacklist: ['Simon & Garfunkel']);
      expect(config.splitText('Simon  &  Garfunkel, Queen'), ['Simon & Garfunkel', 'Queen']);
      expect(config.splitText('Simon\u00A0&\u00A0Garfunkel, Queen'), ['Simon & Garfunkel', 'Queen']);
      expect(config.splitText(' Simon & Garfunkel '), ['Simon & Garfunkel']);
    });

    test('blacklist entries with extra spaces still match', () {
      final config = artistsConfig(blacklist: [' Simon  &  Garfunkel ']);
      expect(config.splitText('Simon & Garfunkel, Queen'), ['Simon & Garfunkel', 'Queen']);
    });

    test('several blacklisted names keep the text order', () {
      final config = artistsConfig(separators: ['&', '/'], blacklist: ['AC/DC']);
      expect(config.splitText('Queen & AC/DC & Muse'), ['Queen', 'AC/DC', 'Muse']);
    });

    test('blank blacklist entries are ignored', () {
      final config = artistsConfig(blacklist: ['', '  ']);
      expect(config.splitText('A & B'), ['A', 'B']);
    });
  });

  group('feat artists', () {
    test('are added from the title', () {
      expect(splitArtist('Song (feat. C)', 'A & B'), ['A', 'B', 'C']);
      expect(splitArtist('Song (ft. C & D)', 'A'), ['A', 'C', 'D']);
      expect(splitArtist('Song [feat. C & D]', 'A'), ['A', 'C', 'D']);
    });

    test('already in the artist tag are not added again, ignoring case', () {
      expect(splitArtist('X (feat. Queen)', 'Queen'), ['Queen']);
      expect(splitArtist('X (feat. queen)', 'Queen'), ['Queen']);
      expect(splitArtist('X (feat. QUEEN & Muse)', 'Queen'), ['Queen', 'Muse']);
    });

    test('are read up to the closing bracket', () {
      expect(splitArtist('X (feat. A) [Live]', 'B'), ['B', 'A']);
      expect(splitArtist('X (feat. A', 'B'), ['B', 'A']);
      expect(splitArtist('X (feat. A) (feat. C)', 'B'), ['B', 'A']);
    });

    test('padded with non-breaking spaces still split', () {
      expect(splitArtist('X (feat. C\u00A0x\u00A0D)', 'A'), ['A', 'C', 'D']);
    });

    test('are ignored when feat extraction is off', () {
      expect(splitArtist('Song (feat. C)', 'A', config: artistsConfig(addFeatArtist: false)), ['A']);
    });

    test('titles without feat leave the artists as split', () {
      expect(splitArtist('Song (Live)', 'A x B'), ['A', 'B']);
      expect(splitArtist(null, 'A'), ['A']);
    });
  });
}
