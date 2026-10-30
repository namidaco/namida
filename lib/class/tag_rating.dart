import 'package:flutter_taglib/flutter_taglib.dart';

import 'package:namida/core/extensions.dart';

// by claude
/// a 0-100 rating in every place players keep one: text fields (`RATING`, `FMPS_RATING`, `RATING:xxx`...) each in
/// its own scale, ID3v2 POPM frames and the ASF `WM/SharedUserRating` attribute.
class TagRating {
  /// added when a file holds no rating yet and its format has no dedicated rating field.
  static const kDefaultField = 'RATING';
  static const kFmpsField = 'FMPS_RATING';

  /// the email windows reads ratings from.
  static const kPopularimeterEmail = 'Windows Media Player 9 Series';

  // -- the whole stars windows, musicbee, kid3 & co agree on, values in between are interpolated
  static const _popmStars = _StarsValues([0, 1, 64, 128, 196, 255]);
  static const _asfStars = _StarsValues([0, 1, 25, 50, 75, 99]);

  static bool isRatingField(String field) => field == kFmpsField || field.startsWith(kDefaultField);

  /// [ratingPercentage] is 0.0-1.0.
  static int percentOf(double ratingPercentage) => (ratingPercentage * 100).round().withMinimum(0).withMaximum(100);

  /// null when [text] holds no rating. [field] picks the scale for fields that have a fixed one.
  static int? percentFromText(String text, {String? field}) {
    final value = num.tryParse(text.trim());
    if (value == null || value <= 0) return null;
    final scale = _RatingScale.of(value, text: text, field: field);
    final percent = scale.toPercent(value).withMaximum(100);
    return percent > 0 ? percent : null;
  }

  /// null when no rating field holds a rating. `RATING` and `FMPS_RATING` come first, then the rest.
  static int? percentFromFields(Map<String, List<String>> properties) {
    final percent = _percentOfField(properties, kDefaultField) ?? _percentOfField(properties, kFmpsField);
    if (percent != null) return percent;
    for (final field in properties.keys) {
      if (field == kDefaultField || !field.startsWith(kDefaultField)) continue;
      final otherPercent = _percentOfField(properties, field);
      if (otherPercent != null) return otherPercent;
    }
    return null;
  }

  static int? _percentOfField(Map<String, List<String>> properties, String field) {
    final text = properties[field]?.firstOrNull;
    if (text == null) return null;
    return percentFromText(text, field: field);
  }

  static int? percentFromPopularimeters(List<TagLibPopularimeter> popularimeters) {
    final rated = popularimeters.firstWhereEff((p) => p.rating > 0);
    if (rated == null) return null;
    return percentFromPopm(rated.rating);
  }

  static int percentFromPopm(int popm) => _popmStars.toPercent(popm);

  /// never 0 for a rated [percent], 0 means unknown.
  static int popmFromPercent(int percent) => _popmStars.fromPercent(percent);

  static int percentFromAsfSharedUserRating(int asfSharedUserRating) => _asfStars.toPercent(asfSharedUserRating);

  /// never 0 for a rated [percent], 0 removes the attribute.
  static int asfSharedUserRatingFromPercent(int percent) => _asfStars.fromPercent(percent);

  /// [percent] as [kDefaultField] holds it, empty when 0 so the field gets removed.
  static String toDefaultFieldText(int percent) => percent > 0 ? _RatingScale.percent.toText(percent) : '';

  /// sets [percent] (0 removes the rating) everywhere [tagFile] keeps one, [properties] being its properties to set
  /// afterwards. false when a dedicated rating field couldn't be written.
  static bool applyToFile(TagLibFile tagFile, {required int percent, required Map<String, List<String>> properties}) {
    final tagType = tagFile.getTagType();
    applyToFields(percent: percent, properties: properties, tagType: tagType);
    switch (tagType) {
      case TagLibTagType.id3v2:
        final oldPopularimeters = tagFile.readPopularimeters() ?? const <TagLibPopularimeter>[];
        final newPopularimeters = popularimetersWith(percent, oldPopularimeters);
        return tagFile.setPopularimeters(newPopularimeters);
      case TagLibTagType.asf:
        final asfSharedUserRating = asfSharedUserRatingFromPercent(percent);
        return tagFile.setAsfSharedUserRating(asfSharedUserRating);
      case TagLibTagType.xiphComment || TagLibTagType.mp4 || TagLibTagType.ape || TagLibTagType.matroska || TagLibTagType.mod || TagLibTagType.unknown:
        return true;
    }
  }

  /// sets [percent] (0 removes the rating) on every rating field of [properties], each keeping its scale.
  /// [kDefaultField] gets the rating when no field holds one and [tagType] has no dedicated rating field.
  static void applyToFields({required int percent, required Map<String, List<String>> properties, required TagLibTagType tagType}) {
    final defaultScale = _RatingScale.defaultOf(tagType);
    final ratingFields = properties.keys.where(isRatingField).toFixedList(); // -- the map changes below
    var didSetField = false;
    for (final field in ratingFields) {
      final oldText = properties[field]?.firstOrNull;
      final scale = _RatingScale.ofField(field, oldText, defaultScale: defaultScale);
      if (percent == 0 || scale == null) {
        properties.remove(field);
        continue;
      }
      properties[field] = [scale.toText(percent)];
      didSetField = true;
    }
    if (!didSetField && percent > 0 && defaultScale != null) properties[kDefaultField] = [defaultScale.toText(percent)];
  }

  /// keeps each frame's email & counter, a frame without a play count is dropped when clearing.
  static List<TagLibPopularimeter> popularimetersWith(int percent, List<TagLibPopularimeter> popularimeters) {
    if (percent == 0) {
      return popularimeters.where((p) => p.counter > 0).map((p) => TagLibPopularimeter(email: p.email, rating: 0, counter: p.counter)).toFixedList();
    }
    final popm = popmFromPercent(percent);
    if (popularimeters.isEmpty) return [TagLibPopularimeter(email: kPopularimeterEmail, rating: popm)];
    return popularimeters.map((p) => TagLibPopularimeter(email: p.email, rating: popm, counter: p.counter)).toFixedList();
  }
}

enum _RatingScale {
  /// 0.0-1.0, ex: `FMPS_RATING`.
  fraction,

  /// 1-5, ex: foobar2000, matroska.
  stars,

  /// 0-100, ex: musicbee, kid3.
  percent,
  ;

  /// same rules namida always read with: a fraction up to 1 is 0.0-1.0, up to 5 is stars, the rest is 0-100.
  static _RatingScale of(num value, {required String text, required String? field}) {
    if (field == TagRating.kFmpsField) return fraction;
    if (value <= 1 && text.contains('.')) return fraction;
    if (value <= 5) return stars;
    return percent;
  }

  /// the scale of [TagRating.kDefaultField], null for tags that keep the rating in a dedicated field.
  static _RatingScale? defaultOf(TagLibTagType tagType) {
    return switch (tagType) {
      TagLibTagType.xiphComment || TagLibTagType.mp4 || TagLibTagType.ape || TagLibTagType.unknown => percent,
      TagLibTagType.matroska => stars, // -- 0-5 per the matroska spec
      TagLibTagType.id3v2 || TagLibTagType.asf || TagLibTagType.mod => null,
    };
  }

  /// null when [field] must be removed.
  /// `RATING` holding 0.0-1.0 (written by older namida) or no number moves to [defaultScale], or is dropped when the
  /// tag keeps the rating in a dedicated field.
  static _RatingScale? ofField(String field, String? oldText, {required _RatingScale? defaultScale}) {
    if (field == TagRating.kFmpsField) return fraction;
    final oldValue = oldText == null ? null : num.tryParse(oldText.trim());
    final oldScale = oldValue == null || oldValue <= 0 ? null : of(oldValue, text: oldText!, field: field);
    final isOwnField = field == TagRating.kDefaultField && (oldScale == null || oldScale == fraction);
    if (isOwnField) return defaultScale;
    return oldScale ?? percent;
  }

  int toPercent(num value) {
    return switch (this) {
      fraction => (value * 100).round(),
      stars => (value * 20).round(),
      percent => value.round(),
    };
  }

  /// [ratingPercent] is 1-100.
  String toText(int ratingPercent) {
    return switch (this) {
      fraction => (ratingPercent / 100).toString(),
      stars => (ratingPercent / 20).round().withMinimum(1).toString(),
      percent => ratingPercent.toString(),
    };
  }
}

/// maps 0-100 to a scale whose whole stars sit at [values] (index 0 is unrated), interpolating in between.
class _StarsValues {
  final List<int> values;
  const _StarsValues(this.values);

  int toPercent(int value) {
    if (value <= 0) return 0;
    if (value >= values.last) return 100;
    var i = 0;
    while (value > values[i + 1]) {
      i++;
    }
    final lowValue = values[i];
    final valueRange = values[i + 1] - lowValue;
    final percentInRange = ((value - lowValue) * 20 / valueRange).round();
    return i * 20 + percentInRange;
  }

  /// never 0 for a rated [percent].
  int fromPercent(int percent) {
    if (percent <= 0) return 0;
    if (percent >= 100) return values.last;
    final i = (percent - 1) ~/ 20;
    final lowValue = values[i];
    final valueRange = values[i + 1] - lowValue;
    final valueInRange = ((percent - i * 20) * valueRange / 20).round();
    return (lowValue + valueInRange).withMinimum(1);
  }
}
