import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/sponsorblock_segment.dart';
import 'package:youtipie/class/sponsorblock_segments_result.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/sponsorblock.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

class SponsorBlockController {
  static final inst = SponsorBlockController._internal();
  SponsorBlockController._internal();

  final _segmentSkippedOnce = <String, bool>{};

  /// clear skipped once segments only after 4 new fetches, perfect for cases where auto skipping
  /// once at the end would make it impossible to go back and watch the segment
  int _fetchCount = 0;

  final currentSegments = Rxn<SponsorBlockSegmentsResult>();
  String? _latestFetchedVideoId;
  List<String>? _latestFetchedCategoriesNames;

  SponsorBlockCategoryConfig? getConfigForSegment(String name) {
    final category = _segmentNameToCategory[name];
    if (category == null) return null;
    return settings.youtube.sponsorBlockSettings.value.configs[category] ?? category.defaultConfig;
  }

  Future<void> reFetchOnSettingsChangedIfRequired() async {
    final sponorSettings = settings.youtube.sponsorBlockSettings.value;
    if (sponorSettings.enabled) {
      final latestFetched = _latestFetchedCategoriesNames;
      final categoriesNames = sponorSettings.activeCategoriesNames;
      if (latestFetched == null || !latestFetched.isEqualTo(categoriesNames)) {
        final currentItem = Player.inst.currentItem.value;
        if (currentItem is YoutubeID) {
          final videoId = currentItem.id;
          await this.updateSegments(videoId);
        }
      }
    } else {
      clearSegments();
    }
  }

  void clearSegmentsIfVideoIsDifferent(String? videoId) async {
    if (_latestFetchedVideoId == videoId) return; // if new video same as the already fetched one
    clearSegments();
  }

  void clearSegments() async {
    currentSegments.value = null;
    _latestFetchedVideoId = null;
    _latestFetchedCategoriesNames = null;
  }

  Future<void> updateSegments(String videoId, {bool forceRequest = false}) async {
    if (_latestFetchedVideoId == videoId && !forceRequest) return;
    _latestFetchedVideoId = videoId;

    final categoriesNames = settings.youtube.sponsorBlockSettings.value.activeCategoriesNames;
    _latestFetchedCategoriesNames = categoriesNames;

    _fetchCount++;
    if (_fetchCount > 4) {
      _segmentSkippedOnce.clear();
      _fetchCount = 0;
    }

    final newSegments = await YoutubeInfoController.sponsorblock.getSegments(
      videoId,
      categories: categoriesNames,
      serverAddress: settings.youtube.sponsorBlockSettings.value.serverAddress,
      details: forceRequest ? ExecuteDetails.forceRequest() : null,
    );

    currentSegments.value = newSegments;

    if (currentSegments.value == null) {
      clearSegments(); // network error or whatever, reset latest fetched data to refetch next time
    }
  }

  bool canShowSkipButton(SponsorBlockSegment segment) {
    final config = getConfigForSegment(segment.category);
    if (config == null) return false;
    if (config.action == SponsorBlockAction.showSkipButton) return true;
    if (config.action == SponsorBlockAction.autoSkipOnce && _segmentSkippedOnce[segment.uuid] == true) return true;
    return false;
  }

  bool autoSkipIfEnabled(SponsorBlockSegment segment) {
    final config = getConfigForSegment(segment.category);
    if (config?.action == SponsorBlockAction.autoSkip) {
      skipSegment(segment);
      return true;
    } else if (config?.action == SponsorBlockAction.autoSkipOnce && _segmentSkippedOnce[segment.uuid] != true) {
      _segmentSkippedOnce[segment.uuid] = true;
      skipSegment(segment);
      return true;
    }
    return false;
  }

  void skipSegment(SponsorBlockSegment segment) {
    final endDuration = Duration(milliseconds: segment.segmentEndMS.round());
    Player.inst.seek(endDuration);

    final sponsorBlockSettings = settings.youtube.sponsorBlockSettings.value;
    if (sponsorBlockSettings.trackSkipCount) {
      YoutubeInfoController.sponsorblock.trackSkippedSegment(
        segment.uuid,
        serverAddress: sponsorBlockSettings.serverAddress,
      );
    }
  }

  final _segmentNameToCategory = {for (final e in SponsorBlockCategory.values) e.name: e};
}
