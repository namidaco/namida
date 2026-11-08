// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/controller/network_proxy_controller.dart';

void main() {
  group('tryParseUrl', () {
    test('scheme, credentials, ports', () {
      final plain = NetworkProxy.tryParseUrl('127.0.0.1:7890')!;
      expect((plain.host, plain.port, plain.username, plain.password), ('127.0.0.1', 7890, null, null));

      final withScheme = NetworkProxy.tryParseUrl('  HTTP://proxy.lan:3128  ')!;
      expect((withScheme.host, withScheme.port), ('proxy.lan', 3128));

      final auth = NetworkProxy.tryParseUrl('http://us%40r:p%3Ass@10.0.0.2:8080')!;
      expect((auth.username, auth.password), ('us@r', 'p:ss'));
      expect(auth.toUrl(), 'http://us%40r:p%3Ass@10.0.0.2:8080');
      expect(auth.toDisplayUrl(), 'http://10.0.0.2:8080');

      final userOnly = NetworkProxy.tryParseUrl('http://user@host.test:1')!;
      expect((userOnly.username, userOnly.password, userOnly.toUrl()), ('user', null, 'http://user@host.test:1'));

      final ipv6 = NetworkProxy.tryParseUrl('[::1]:8080')!;
      expect((ipv6.host, ipv6.toUrl()), ('::1', 'http://[::1]:8080'));

      expect(NetworkProxy.tryParseUrl('http://host.test')!.port, 80);
    });

    test('rejected', () {
      for (final text in [null, '', '   ', 'socks5://127.0.0.1:1080', 'https://127.0.0.1:443', 'http://', 'http://:8080', 'http://host:99999', 'http://host:0']) {
        expect(NetworkProxy.tryParseUrl(text), isNull, reason: '$text');
      }
    });
  });

  group('environment', () {
    test('precedence and no_proxy', () {
      final proxy = NetworkProxy.fromEnvironment({
        'HTTPS_PROXY': 'http://upper:1',
        'https_proxy': 'http://lower:2',
        'http_proxy': 'http://plain:3',
        'no_proxy': 'example.com, .corp.test,10.1.0.0/16',
      })!;
      expect((proxy.host, proxy.port), ('lower', 2));
      expect(proxy.bypass, ['example.com', '.corp.test', '10.1.0.0/16']);
    });

    test('socks https_proxy falls back to the http one', () {
      final proxy = NetworkProxy.fromEnvironment({'https_proxy': 'socks5://127.0.0.1:1080', 'http_proxy': '127.0.0.1:8080'})!;
      expect(proxy.port, 8080);
    });

    test('nothing usable', () {
      expect(NetworkProxy.fromEnvironment({}), isNull);
      expect(NetworkProxy.fromEnvironment({'all_proxy': 'socks5h://x:1', 'no_proxy': '*'}), isNull);
      expect(NetworkProxy.fromEnvironment({'https_proxy': ''}), isNull);
    });
  });

  group('windows registry', () {
    test('disabled or missing', () {
      expect(NetworkProxy.fromWindowsSettings(proxyEnable: 0, proxyServer: '127.0.0.1:7890', proxyOverride: null), isNull);
      expect(NetworkProxy.fromWindowsSettings(proxyEnable: null, proxyServer: '127.0.0.1:7890', proxyOverride: null), isNull);
      expect(NetworkProxy.fromWindowsSettings(proxyEnable: 1, proxyServer: null, proxyOverride: null), isNull);
    });

    test('server formats', () {
      NetworkProxy? parse(String server) => NetworkProxy.fromWindowsSettings(proxyEnable: 1, proxyServer: server, proxyOverride: null);
      expect(parse('127.0.0.1:7890')!.port, 7890);
      expect(parse('http://127.0.0.1:7891')!.port, 7891);
      expect(parse('http=127.0.0.1:1;https=127.0.0.1:2;ftp=127.0.0.1:3')!.port, 2);
      expect(parse('http=127.0.0.1:1;socks=127.0.0.1:4')!.port, 1);
      expect(parse('socks=127.0.0.1:4'), isNull);
    });

    test('override list', () {
      final proxy = NetworkProxy.fromWindowsSettings(
        proxyEnable: 1,
        proxyServer: '127.0.0.1:7890',
        proxyOverride: 'localhost;127.*;10.*;172.16.*;192.168.*;*.example.com;<local>;;',
      )!;
      expect(proxy.bypass, ['localhost', '127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/16', '192.168.0.0/16', '.example.com', '<local>']);
    });
  });

  group('platform map', () {
    test('android & darwin', () {
      final proxy = NetworkProxy.fromPlatformMap({
        'host': '192.168.1.5',
        'port': 8888,
        'bypass': ['*.foo.com', '169.254/16', 'bar.test', '<local>'],
      })!;
      expect((proxy.host, proxy.port), ('192.168.1.5', 8888));
      expect(proxy.bypass, ['.foo.com', '169.254.0.0/16', 'bar.test', '<local>']);

      final ipv6 = NetworkProxy.fromPlatformMap({'host': 'fd00::5', 'port': 3128, 'bypass': null})!;
      expect(ipv6.host, 'fd00::5');
      expect(ipv6.bypass, isEmpty);
    });

    test('invalid', () {
      expect(NetworkProxy.fromPlatformMap(null), isNull);
      expect(NetworkProxy.fromPlatformMap({'host': '', 'port': 1}), isNull);
      expect(NetworkProxy.fromPlatformMap({'host': 'x', 'port': -1}), isNull);
      expect(NetworkProxy.fromPlatformMap({'host': 'x', 'port': null}), isNull);
    });
  });

  test('normalizeBypassEntry', () {
    final cases = <String, String?>{
      '': null, '  ': null, '*': '*', '<local>': '<local>', '<LOCAL>': '<local>', //
      'Example.COM': 'example.com', '.example.com': '.example.com', '*.example.com': '.example.com', '*example.com': 'example.com',
      'http://example.com': 'example.com', 'example.com:8080': 'example.com', 'https://example.com:443': 'example.com',
      '127.*': '127.0.0.0/8', '10.*.*.*': '10.0.0.0/8', '192.168.1.*': '192.168.1.0/24', '1.2.3.*': '1.2.3.0/24',
      '169.254/16': '169.254.0.0/16', '10/8': '10.0.0.0/8', '192.168.1.0/24': '192.168.1.0/24', '10/33': null,
      '::1': '::1', '[::1]': '::1', '[::1]:8080': '::1', 'fe80::/10': 'fe80::/10',
      'a.*.com': null,
    };
    for (final MapEntry(key: raw, value: expected) in cases.entries) {
      expect(NetworkProxy.normalizeBypassEntry(raw), expected, reason: raw);
    }
  });

  group('shouldBypass', () {
    final proxy = NetworkProxy(host: '127.0.0.1', port: 7890, bypass: ['example.com', '.corp.test', '203.0.113.0/24', '2001:db8::/32']);

    test('defaults: loopback and lan', () {
      const bypassed = [
        'localhost', 'LOCALHOST', 'foo.localhost', '127.0.0.1', '127.255.255.254', '::1', '[::1]', //
        '10.0.0.1', '10.255.255.255', '172.16.0.1', '172.31.255.255', '192.168.0.1', '192.168.255.255', '169.254.10.10',
        'fd12:3456::1', 'fc00::1', 'fe80::1', '[fe80::1]', 'nas', 'jellyfin', 'printer.local', 'router.lan', 'x.home.arpa', 'svc.internal',
      ];
      for (final host in bypassed) {
        expect(proxy.shouldBypass(host), isTrue, reason: host);
      }
    });

    test('public hosts go through', () {
      const proxied = [
        'youtube.com', 'www.youtube.com', 'rr1---sn-x.googlevideo.com', '8.8.8.8', '172.15.255.255', '172.32.0.1', '11.0.0.1', '192.169.0.1', //
        '2a00:1450::1', '[2a00:1450::1]', 'local.com', 'lan.example.org', 'notexample.com', 'example.com.evil.test',
      ];
      for (final host in proxied) {
        expect(proxy.shouldBypass(host), isFalse, reason: host);
      }
    });

    test('own entries', () {
      for (final host in ['example.com', 'www.example.com', 'a.b.example.com', 'corp.test', 'x.corp.test', '203.0.113.7', '2001:db8::1']) {
        expect(proxy.shouldBypass(host), isTrue, reason: host);
      }
      for (final host in ['example.org', 'corp.testing', '203.0.114.1', '2001:db9::1']) {
        expect(proxy.shouldBypass(host), isFalse, reason: host);
      }
    });

    test('* bypasses everything', () {
      final all = NetworkProxy(host: 'h', port: 1, bypass: ['*']);
      expect(all.shouldBypass('youtube.com'), isTrue);
      expect(all.shouldBypass('8.8.8.8'), isTrue);
    });
  });

  test('dart:io findProxy text', () {
    final proxy = NetworkProxy(host: '127.0.0.1', port: 7890);
    expect(proxy.toFindProxyText(Uri.parse('https://youtube.com/watch')), 'PROXY 127.0.0.1:7890');
    expect(proxy.toFindProxyText(Uri.parse('http://127.0.0.1:5555/x')), 'DIRECT');
    expect(proxy.toFindProxyText(Uri.parse('http://192.168.1.4:8096/')), 'DIRECT');
    final auth = NetworkProxy(host: '::1', port: 1, username: 'u', password: 'p');
    expect(auth.toFindProxyText(Uri.parse('https://youtube.com')), 'PROXY u:p@[::1]:1');
  });

  test('chromium rules', () {
    final proxy = NetworkProxy(host: '127.0.0.1', port: 7890, bypass: ['.corp.test', '203.0.113.9']);
    final rules = proxy.toChromiumBypassRules();
    expect(rules, containsAll(['<local>', 'localhost', '*.localhost', '127.0.0.0/8', '::1/128', 'local', '*.local', 'corp.test', '*.corp.test', '203.0.113.9/32']));
    expect(proxy.toChromiumArguments(), startsWith('--proxy-server="http://127.0.0.1:7890" --proxy-bypass-list="<local>;localhost;*.localhost;'));
  });

  test('equality', () {
    expect(NetworkProxy(host: 'h', port: 1, bypass: ['a']), NetworkProxy(host: 'h', port: 1, bypass: ['a']));
    expect(NetworkProxy(host: 'h', port: 1, bypass: ['a']) == NetworkProxy(host: 'h', port: 1, bypass: ['b']), isFalse);
    expect(NetworkProxy(host: 'h', port: 1, username: 'u') == NetworkProxy(host: 'h', port: 1), isFalse);
  });
}
