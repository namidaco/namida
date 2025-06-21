import 'dart:async';
import 'dart:convert';

import 'package:rhttp/rhttp.dart';

import 'package:namida/class/version_wrapper.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class VersionController {
  static final inst = VersionController._();
  VersionController._();

  RxBaseCore<VersionWrapper?> get latestVersion => _latestVersion;
  RxBaseCore<List<VersionReleaseInfo>?> get releasesAfterCurrent => _releasesAfterCurrent;

  final _latestVersion = Rxn<VersionWrapper>();
  final _releasesAfterCurrent = Rxn<List<VersionReleaseInfo>>();
  VersionWrapper? get _currentVersion => VersionWrapper.current;

  DateTime? _allReleaseslastFetchedTime;

  void ensureInitialized() async {
    await VersionWrapper.waitForCurrentVersionFetch;
    if (_latestVersion.value == null) {
      ConnectivityController.inst.executeOrRegister(_fetchLatestVersion);
    }
  }

  Future<VersionWrapper?> _fetchLatestVersion() async {
    final isBeta = _currentVersion?.isBeta ?? false; // use stable if anything
    final latest = await __fetchLatestVersionOnly(isBeta);
    _latestVersion.value = latest;
    ConnectivityController.inst.removeOnConnectionRestored(_fetchLatestVersion);
    return latest;
  }

  Future<List<VersionReleaseInfo>?> fetchReleasesAfterCurrent() async {
    final current = _currentVersion;
    if (current == null) return [];
    if (_releasesAfterCurrent.value?.firstOrNull?.version == _latestVersion.value && !_preferReFetchAllReleases()) return _releasesAfterCurrent.value!;
    _releasesAfterCurrent.value = null;
    _allReleaseslastFetchedTime = DateTime.now();
    final releases = await _fetchReleasesAfterOnly(currentVersion: current);
    _releasesAfterCurrent.value = releases;
    if (releases != null && releases.first.version != _latestVersion.value) {
      _fetchLatestVersion();
    }
    return releases;
  }

  bool _preferReFetchAllReleases() {
    final latestFetchedTime = _allReleaseslastFetchedTime;
    if (latestFetchedTime == null) return true;
    return latestFetchedTime.difference(DateTime.now()).abs() > const Duration(hours: 2);
  }

  Future<VersionWrapper?> __fetchLatestVersionOnly(bool isBeta) async {
    return _IsolateExecuter.__fetchLatestVersionOnlyIsolate.thready(isBeta);
  }

  Future<List<VersionReleaseInfo>?> _fetchReleasesAfterOnly({required VersionWrapper currentVersion}) async {
    return _IsolateExecuter._fetchReleasesAfterOnlyIsolate.thready(currentVersion);
  }
}

class VersionReleaseInfo {
  final VersionWrapper version;
  final String body;

  const VersionReleaseInfo({
    required this.version,
    required this.body,
  });

  @override
  String toString() => 'VersionReleaseInfo(name: $version, body: $body)';
}

class _IsolateExecuter {
  static Future<dynamic> _requestReleasesApi(bool isBeta, {String endpoint = '', Map<String, dynamic>? queryParameters}) async {
    final repoName = isBeta ? 'namida-snapshots' : 'namida';
    final uri = Uri.https('api.github.com', '/repos/namidaco/$repoName/releases$endpoint', queryParameters);
    const String? token = null;
    final response = await Rhttp.get(
      uri.toString(),
      headers: HttpHeaders.rawMap({
        'User-Agent': 'namida',
        if (token != null) 'Authorization': 'Bearer $token',
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<VersionWrapper?> __fetchLatestVersionOnlyIsolate(bool isBeta) async {
    await Rhttp.init().ignoreError();
    try {
      final resMap = await _requestReleasesApi(isBeta, endpoint: '/latest') as Map;
      final latestRelease = resMap['name'] as String?;
      if (latestRelease != null) {
        return VersionWrapper(latestRelease);
      }
    } catch (_) {}
    return null;
  }

  static Future<List<VersionReleaseInfo>?> _fetchReleasesAfterOnlyIsolate(VersionWrapper currentVersion) async {
    await Rhttp.init().ignoreError();

    final allReleasesAfterCurrent = <VersionReleaseInfo>[];

    final int perPage = currentVersion.isBeta ? 20 : 10;

    int page = 1;
    while (page < 100) {
      try {
        final releases = await _requestReleasesApi(
          currentVersion.isBeta,
          queryParameters: {
            'per_page': '$perPage',
            'page': '$page',
          },
        ) as List<dynamic>;

        if (releases.isEmpty) break;
        final releasesAfterCurrent = _filterReleasesAfter(
          currentVersion: currentVersion,
          allReleases: releases.cast(),
        );
        if (releasesAfterCurrent.isEmpty) break;
        allReleasesAfterCurrent.addAll(releasesAfterCurrent);

        page++;
      } on RhttpStatusCodeException catch (e) {
        if (e.statusCode == 422) {
          // -- exceeded pages
        } else {
          return []; // error happened, all above are useless
        }
      }
    }
    return allReleasesAfterCurrent;
  }

  static List<VersionReleaseInfo> _filterReleasesAfter({
    required VersionWrapper currentVersion,
    required List<Map<String, dynamic>> allReleases,
  }) {
    final releasesAfterCurrent = <VersionReleaseInfo>[];
    for (final release in allReleases) {
      final tag = (release['name'] ?? release['tag_name']) as String?;
      if (tag == null) continue;
      final releaseVersion = VersionWrapper(tag);
      final isAfter = releaseVersion.isAfter(currentVersion) ?? false;
      if (isAfter) {
        final body = release['body'] as String? ?? '';
        final info = VersionReleaseInfo(
          version: releaseVersion,
          body: body,
        );
        releasesAfterCurrent.add(info);
      }
    }
    return releasesAfterCurrent;
  }
}
