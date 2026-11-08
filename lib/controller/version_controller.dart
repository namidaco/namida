import 'dart:async';
import 'dart:convert';

import 'package:rhttp/rhttp.dart';

import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/class/version_wrapper.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/network_proxy_controller.dart';
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

  void ensureRefreshed() async {
    await VersionWrapper.waitForCurrentVersionFetch;
    ConnectivityController.inst.executeOrRegister(_fetchLatestVersion);
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
    final newestRelease = releases?.firstOrNull;
    if (newestRelease != null && newestRelease.version != _latestVersion.value) {
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
    final settings = NetworkProxyController.inst.rhttpSettings;
    return _IsolateExecuter.__fetchLatestVersionOnlyIsolate.thready((isBeta, settings));
  }

  Future<List<VersionReleaseInfo>?> _fetchReleasesAfterOnly({required VersionWrapper currentVersion}) async {
    final settings = NetworkProxyController.inst.rhttpSettings;
    return _IsolateExecuter._fetchReleasesAfterOnlyIsolate.thready((currentVersion, settings));
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
  static Future<dynamic> _requestReleasesApi(bool isBeta, ClientSettings? settings, {String endpoint = '', Map<String, dynamic>? queryParameters}) async {
    final repoName = isBeta ? 'namida-snapshots' : 'namida';
    final uri = Uri.https('api.github.com', '/repos/namidaco/$repoName/releases$endpoint', queryParameters);
    const String? token = null;
    final response = await NamidaHttp.get(
      uri.toString(),
      settings: settings,
      headers: const HttpHeaders.rawMap({
        'User-Agent': 'namida',
        if (token != null) 'Authorization': 'Bearer $token',
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<VersionWrapper?> __fetchLatestVersionOnlyIsolate((bool, ClientSettings?) params) async {
    final (isBeta, settings) = params;
    await Rhttp.init().ignoreError();
    try {
      final resMap = await _requestReleasesApi(isBeta, settings, endpoint: '/latest') as Map;
      final latestRelease = resMap['name'] as String?;
      if (latestRelease != null) {
        return VersionWrapper(latestRelease);
      }
    } catch (_) {}
    return null;
  }

  static Future<List<VersionReleaseInfo>?> _fetchReleasesAfterOnlyIsolate((VersionWrapper, ClientSettings?) params) async {
    final (currentVersion, settings) = params;
    await Rhttp.init().ignoreError();

    final allReleasesAfterCurrent = <VersionReleaseInfo>[];

    final int perPage = currentVersion.isBeta ? 20 : 10;

    int page = 1;
    while (page < 100) {
      try {
        final releases =
            await _requestReleasesApi(
                  currentVersion.isBeta,
                  settings,
                  queryParameters: {
                    'per_page': '$perPage',
                    'page': '$page',
                  },
                )
                as List<dynamic>;

        if (releases.isEmpty) break;
        final releasesAfterCurrent = _filterReleasesAfter(
          currentVersion: currentVersion,
          allReleases: releases.cast(),
        );
        if (releasesAfterCurrent.isEmpty) break;
        allReleasesAfterCurrent.addAll(releasesAfterCurrent);

        page++;
      } catch (e) {
        if (e is RhttpStatusCodeException && e.statusCode == 422) break; // -- exceeded pages
        return []; // error happened, all above are useless
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
