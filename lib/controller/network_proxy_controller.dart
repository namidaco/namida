// by claude
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:namico_login_manager/namico_login_manager.dart';
import 'package:rhttp/rhttp.dart';

import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';

/// the proxy every network client uses: the proxy url flag, else the env or system proxy.
/// with none, nothing is installed anywhere and every client runs exactly as without this controller.
class NetworkProxyController {
  static final inst = NetworkProxyController._();
  NetworkProxyController._();

  NetworkProxy? get current => _current;
  NetworkProxy? _current;

  ProxySettings? get rhttpProxySettings => _rhttpProxySettings;
  ProxySettings? _rhttpProxySettings;

  /// null when no proxy is active, so clients keep their default settings.
  ClientSettings? get rhttpSettings => _rhttpSettings;
  ClientSettings? _rhttpSettings;

  /// completes after the first system proxy read.
  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  NetworkProxy? _systemProxy;

  final _onChanged = <void Function(NetworkProxy? proxy)>[];

  void addOnChanged(void Function(NetworkProxy? proxy) fn) => _onChanged.add(fn);
  void removeOnChanged(void Function(NetworkProxy? proxy) fn) => _onChanged.remove(fn);

  void init() {
    settings.proxyUrl.addListener(_resolve);
    // -- env proxies win over the os one and never change while running
    final envProxy = NetworkProxy.fromEnvironment(Platform.environment);
    if (envProxy != null) {
      _systemProxy = envProxy;
      _resolve();
      _readyCompleter.complete();
      return;
    }
    _resolve();
    _refreshSystemProxy().whenComplete(_readyCompleter.completeIfWasnt);
    NamidaChannel.inst.listenSystemProxyChanges(_refreshSystemProxy);
  }

  Future<void> _refreshSystemProxy() async {
    _systemProxy = await NamidaChannel.inst.getSystemProxy().ignoreError();
    _resolve();
  }

  void _resolve() {
    final flagProxy = NetworkProxy.tryParseUrl(settings.proxyUrl.value);
    final proxy = flagProxy ?? _systemProxy;
    _applyWebViewProxy(flagProxy);
    if (proxy == _current) return;
    final hadProxy = _current != null;
    _current = proxy;
    final proxySettings = proxy?.toRhttpProxySettings();
    _rhttpProxySettings = proxySettings;
    _rhttpSettings = proxySettings == null ? null : ClientSettings(proxySettings: proxySettings);
    // -- only while a proxy is active, dart:io clients created meanwhile keep following [current]
    if (proxy == null) {
      HttpOverrides.global = null;
    } else if (!hadProxy) {
      HttpOverrides.global = _NetworkProxyHttpOverrides(this);
    }
    NamidaChannel.inst.setAppProxy(proxy).ignoreError();
    for (final fn in _onChanged) {
      fn(proxy);
    }
  }

  /// webviews follow the system proxy by themselves, only the flag needs applying.
  NetworkProxy? _webViewFlagProxy;

  void _applyWebViewProxy(NetworkProxy? flagProxy) {
    if (flagProxy == _webViewFlagProxy) return;
    _webViewFlagProxy = flagProxy;
    if (Platform.isWindows) {
      // -- read once when the login webview environment is created
      NamicoLoginManager.windowsBrowserArguments = flagProxy?.toChromiumArguments();
    } else if (Platform.isAndroid) {
      _applyAndroidWebViewProxy(flagProxy).ignoreError();
    }
  }

  Future<void> _applyAndroidWebViewProxy(NetworkProxy? flagProxy) async {
    final isSupported = await webview.WebViewFeature.isFeatureSupported(webview.WebViewFeature.PROXY_OVERRIDE);
    if (!isSupported) return;
    final proxyController = webview.ProxyController.instance();
    if (flagProxy == null) return proxyController.clearProxyOverride();
    final proxySettings = webview.ProxySettings(
      proxyRules: [webview.ProxyRule(url: flagProxy.toDisplayUrl())],
      bypassRules: flagProxy.toChromiumBypassRules(),
    );
    await proxyController.setProxyOverride(settings: proxySettings);
  }

  String _findProxy(Uri uri) {
    final proxy = _current;
    if (proxy == null) return 'DIRECT';
    return proxy.toFindProxyText(uri);
  }
}

/// a [PortsProvider] whose isolate makes rhttp requests. the isolate gets the settings in its spawn message ([rhttpSettingsForSpawn]),
/// and a [NetworkProxyIsolateMessage] only when the proxy changes while it runs. it handles that message after its own requests.
mixin NetworkProxyPortsProvider<E> on PortsProvider<E> {
  ClientSettings? _spawnedRhttpSettings;

  ClientSettings? rhttpSettingsForSpawn() => _spawnedRhttpSettings = NetworkProxyController.inst.rhttpSettings;

  void _sendProxyToIsolate(NetworkProxy? _) {
    final message = NetworkProxyIsolateMessage(NetworkProxyController.inst.rhttpSettings);
    sendPort(message);
  }

  @override
  void onPreparing(bool prepared) {
    super.onPreparing(prepared);
    final controller = NetworkProxyController.inst;
    if (!prepared) return controller.removeOnChanged(_sendProxyToIsolate);
    controller.addOnChanged(_sendProxyToIsolate);
    // -- changed while spawning
    if (!identical(_spawnedRhttpSettings, controller.rhttpSettings)) _sendProxyToIsolate(null);
  }
}

class NetworkProxyIsolateMessage {
  final ClientSettings? rhttpSettings;
  const NetworkProxyIsolateMessage(this.rhttpSettings);
}

class _NetworkProxyHttpOverrides extends HttpOverrides {
  final NetworkProxyController _controller;
  _NetworkProxyHttpOverrides(this._controller);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..findProxy = _controller._findProxy;
  }
}

/// an http proxy with the hosts that skip it. only http proxies, every client (rhttp, dart:io, mpv, android, webviews) supports them.
class NetworkProxy {
  final String host;
  final int port;
  final String? username;
  final String? password;

  /// curl style entries (domains with their subdomains, ips, cidr ranges, `*`) and [kSimpleHostnames], on top of [kDefaultBypass].
  final List<String> bypass;

  NetworkProxy({
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.bypass = const [],
  });

  /// hostnames without a dot, same token as windows and rhttp.
  static const kSimpleHostnames = '<local>';

  /// loopback (local cache streams, offline docs) and lan (servers, sync, party) never go through the proxy.
  static const kDefaultBypass = [
    kSimpleHostnames, 'localhost', '127.0.0.0/8', '::1', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '169.254.0.0/16', 'fc00::/7', 'fe80::/10', //
    '.local', '.lan', '.home.arpa', '.internal',
  ];

  /// one rule set for defaults and own entries, a host is parsed once per check.
  late final _rules = _BypassRules.parse([...kDefaultBypass, ...bypass]);

  static const _kEnvProxyKeys = ['https_proxy', 'HTTPS_PROXY', 'http_proxy', 'HTTP_PROXY', 'all_proxy', 'ALL_PROXY'];
  static const _kEnvNoProxyKeys = ['no_proxy', 'NO_PROXY'];

  /// `[http://][user:pass@]host[:port]`, null for empty text or another scheme.
  static NetworkProxy? tryParseUrl(String? text, {List<String> bypass = const []}) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final urlText = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final uri = Uri.tryParse(urlText);
    if (uri == null || uri.scheme.toLowerCase() != 'http' || uri.host.isEmpty) return null;
    if (uri.hasPort && (uri.port <= 0 || uri.port > 65535)) return null;
    final userInfo = uri.userInfo;
    String? username;
    String? password;
    if (userInfo.isNotEmpty) {
      final separatorIndex = userInfo.indexOf(':');
      final usernamePre = separatorIndex == -1 ? userInfo : userInfo.substring(0, separatorIndex);
      username = Uri.decodeComponent(usernamePre);
      if (separatorIndex != -1) {
        final passwordPre = userInfo.substring(separatorIndex + 1);
        password = Uri.decodeComponent(passwordPre);
      }
    }
    return NetworkProxy(
      host: uri.host,
      port: uri.port,
      username: username,
      password: password,
      bypass: bypass,
    );
  }

  static NetworkProxy? fromEnvironment(Map<String, String> env) {
    final proxyValues = _kEnvProxyKeys.map((k) => env[k]).where((e) => e != null && e.isNotEmpty);
    if (proxyValues.isEmpty) return null;
    final noProxyText = _kEnvNoProxyKeys.map((k) => env[k]).firstWhereEff((e) => e != null && e.isNotEmpty);
    final bypass = _parseBypassList(noProxyText, separator: ',');
    for (final value in proxyValues) {
      final proxy = tryParseUrl(value, bypass: bypass);
      if (proxy != null) return proxy;
    }
    return null;
  }

  /// `Internet Settings` registry values: `ProxyServer` is `host:port` or `http=host:port;https=host:port;socks=...`.
  static NetworkProxy? fromWindowsSettings({required int? proxyEnable, required String? proxyServer, required String? proxyOverride}) {
    if (proxyEnable != 1 || proxyServer == null) return null;
    String? server;
    if (proxyServer.contains('=')) {
      final serverByType = <String, String>{};
      for (final entry in proxyServer.split(';')) {
        final separatorIndex = entry.indexOf('=');
        if (separatorIndex == -1) continue;
        final type = entry.substring(0, separatorIndex).trim().toLowerCase();
        serverByType[type] = entry.substring(separatorIndex + 1).trim();
      }
      server = serverByType['https'] ?? serverByType['http'];
    } else {
      server = proxyServer;
    }
    final bypass = _parseBypassList(proxyOverride, separator: ';');
    return tryParseUrl(server, bypass: bypass);
  }

  /// what the android & darwin channels send: `{host, port, bypass}`, bypass entries in any of the system formats.
  static NetworkProxy? fromPlatformMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final host = map['host'] as String?;
    final port = map['port'] as int?;
    if (host == null || host.isEmpty || port == null || port <= 0 || port > 65535) return null;
    final bypassPre = (map['bypass'] as List?)?.cast<String>();
    final bypass = bypassPre?.map(normalizeBypassEntry).nonNulls.toFixedList() ?? const <String>[];
    final hostUrl = host.contains(':') ? '[$host]' : host;
    return tryParseUrl('$hostUrl:$port', bypass: bypass);
  }

  static List<String> _parseBypassList(String? text, {required String separator}) {
    if (text == null || text.isEmpty) return const [];
    return text.split(separator).map(normalizeBypassEntry).nonNulls.toFixedList();
  }

  static final _ipv4WildcardRegex = RegExp(r'^(\d{1,3}(?:\.\d{1,3}){0,2})(?:\.\*){1,3}$');
  static final _ipv4PartialCidrRegex = RegExp(r'^(\d{1,3}(?:\.\d{1,3}){0,3})/(\d{1,2})$');

  /// any system format (windows `ProxyOverride`, macos exceptions, android exclusions, `no_proxy`) to a curl style entry.
  static String? normalizeBypassEntry(String raw) {
    var entry = raw.trim().toLowerCase();
    if (entry.isEmpty) return null;
    if (entry == kSimpleHostnames || entry == '*') return entry;

    final schemeIndex = entry.indexOf('://');
    if (schemeIndex != -1) entry = entry.substring(schemeIndex + 3);
    if (entry.startsWith('[')) {
      final closingIndex = entry.indexOf(']');
      if (closingIndex == -1) return null;
      entry = entry.substring(1, closingIndex);
    } else if (':'.allMatches(entry).length == 1) {
      entry = entry.substring(0, entry.indexOf(':'));
    }

    final ipv4Wildcard = _ipv4WildcardRegex.firstMatch(entry);
    if (ipv4Wildcard != null) {
      final octets = ipv4Wildcard.group(1)!.split('.');
      return _ipv4CidrOf(octets, octets.length * 8);
    }
    final ipv4PartialCidr = _ipv4PartialCidrRegex.firstMatch(entry);
    if (ipv4PartialCidr != null) {
      final octets = ipv4PartialCidr.group(1)!.split('.');
      final prefixLength = int.parse(ipv4PartialCidr.group(2)!);
      return _ipv4CidrOf(octets, prefixLength);
    }

    if (entry.startsWith('*.')) return entry.substring(1);
    if (entry.startsWith('*')) entry = entry.substring(1);
    if (entry.isEmpty || entry.contains('*')) return null;
    return entry;
  }

  static String? _ipv4CidrOf(List<String> octets, int prefixLength) {
    if (prefixLength > 32) return null;
    final padded = [...octets, for (int i = octets.length; i < 4; i++) '0'];
    return '${padded.join('.')}/$prefixLength';
  }

  bool shouldBypass(String host) => _rules.matches(host);

  String _hostForUrl() => host.contains(':') ? '[$host]' : host;

  String _userInfoForUrl() {
    final username = this.username;
    if (username == null) return '';
    final password = this.password;
    final encodedUsername = Uri.encodeComponent(username);
    if (password == null) return '$encodedUsername@';
    final encodedPassword = Uri.encodeComponent(password);
    return '$encodedUsername:$encodedPassword@';
  }

  String toUrl() => 'http://${_userInfoForUrl()}${_hostForUrl()}:$port';

  /// without credentials, for logs and ui.
  String toDisplayUrl() => 'http://${_hostForUrl()}:$port';

  String toNoProxyText() => [...kDefaultBypass, ...bypass].join(',');

  ProxySettings toRhttpProxySettings() => ProxySettings.proxy(toUrl(), noProxy: toNoProxyText());

  /// chromium matches a plain domain exactly, curl style also matches its subdomains.
  List<String> toChromiumBypassRules() {
    final rules = <String>[];
    for (final entry in [...kDefaultBypass, ...bypass]) {
      final ipRange = _IpRange.tryParse(entry);
      if (ipRange != null) {
        final cidrRule = entry.contains('/') ? entry : '$entry/${ipRange.networkBytes.length * 8}';
        rules.add(cidrRule);
      } else if (entry == kSimpleHostnames || entry == '*') {
        rules.add(entry);
      } else {
        final domain = entry.startsWith('.') ? entry.substring(1) : entry;
        rules.add(domain);
        rules.add('*.$domain');
      }
    }
    return rules;
  }

  /// webview2 browser arguments, credentials can't be passed this way.
  String toChromiumArguments() {
    final bypassList = toChromiumBypassRules().join(';');
    return '--proxy-server="${toDisplayUrl()}" --proxy-bypass-list="$bypassList"';
  }

  /// dart:io `findProxy` format.
  String toFindProxyText(Uri uri) {
    if (shouldBypass(uri.host)) return 'DIRECT';
    final username = this.username;
    final password = this.password;
    final credentials = username == null ? '' : '$username:${password ?? ''}@';
    return 'PROXY $credentials${_hostForUrl()}:$port';
  }

  Map<String, Object?> toPlatformMap() => {
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'bypass': [...kDefaultBypass, ...bypass],
  };

  @override
  bool operator ==(Object other) {
    if (other is! NetworkProxy) return false;
    return other.host == host && other.port == port && other.username == username && other.password == password && other.bypass.isEqualTo(bypass);
  }

  @override
  int get hashCode => Object.hash(host, port, username, password, Object.hashAll(bypass));
}

/// same matching as rhttp (hyper-util `NoProxy`) plus [NetworkProxy.kSimpleHostnames].
class _BypassRules {
  final bool matchesAll;
  final bool matchesSimpleHostnames;
  final List<String> domains;
  final List<_IpRange> ipRanges;

  const _BypassRules(this.matchesAll, this.matchesSimpleHostnames, this.domains, this.ipRanges);

  factory _BypassRules.parse(List<String> entries) {
    bool matchesAll = false;
    bool matchesSimpleHostnames = false;
    final domains = <String>[];
    final ipRanges = <_IpRange>[];
    for (final entry in entries) {
      if (entry == '*') {
        matchesAll = true;
      } else if (entry == NetworkProxy.kSimpleHostnames) {
        matchesSimpleHostnames = true;
      } else {
        final ipRange = _IpRange.tryParse(entry);
        if (ipRange != null) {
          ipRanges.add(ipRange);
        } else {
          final domain = entry.startsWith('.') ? entry.substring(1) : entry;
          if (domain.isNotEmpty) domains.add(domain.toLowerCase());
        }
      }
    }
    return _BypassRules(matchesAll, matchesSimpleHostnames, domains, ipRanges);
  }

  bool matches(String hostPre) {
    if (matchesAll) return true;
    final isBracketed = hostPre.startsWith('[') && hostPre.endsWith(']');
    final host = isBracketed ? hostPre.substring(1, hostPre.length - 1) : hostPre;
    final ip = InternetAddress.tryParse(host);
    if (ip != null) {
      final ipBytes = ip.rawAddress;
      for (final ipRange in ipRanges) {
        if (ipRange.contains(ipBytes)) return true;
      }
      return false;
    }
    if (matchesSimpleHostnames && !host.contains('.')) return true;
    final hostLower = host.toLowerCase();
    for (final domain in domains) {
      if (hostLower == domain) return true;
      if (hostLower.length > domain.length && hostLower.endsWith(domain) && hostLower.codeUnitAt(hostLower.length - domain.length - 1) == 0x2E) return true;
    }
    return false;
  }
}

class _IpRange {
  final Uint8List networkBytes;
  final int prefixLength;

  const _IpRange(this.networkBytes, this.prefixLength);

  static _IpRange? tryParse(String entry) {
    final separatorIndex = entry.indexOf('/');
    final ipText = separatorIndex == -1 ? entry : entry.substring(0, separatorIndex);
    final ip = InternetAddress.tryParse(ipText);
    if (ip == null) return null;
    final bytes = ip.rawAddress;
    final maxPrefixLength = bytes.length * 8;
    final prefixLength = separatorIndex == -1 ? maxPrefixLength : int.tryParse(entry.substring(separatorIndex + 1));
    if (prefixLength == null || prefixLength < 0 || prefixLength > maxPrefixLength) return null;
    return _IpRange(bytes, prefixLength);
  }

  bool contains(Uint8List ipBytes) {
    if (ipBytes.length != networkBytes.length) return false;
    final fullBytes = prefixLength >> 3;
    for (int i = 0; i < fullBytes; i++) {
      if (ipBytes[i] != networkBytes[i]) return false;
    }
    final remainingBits = prefixLength & 7;
    if (remainingBits == 0) return true;
    final mask = (0xFF << (8 - remainingBits)) & 0xFF;
    return (ipBytes[fullBytes] & mask) == (networkBytes[fullBytes] & mask);
  }
}
