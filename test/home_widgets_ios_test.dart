// by claude
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/controller/platform/home_widgets/home_widgets.dart';
import 'package:namida/core/enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('namida/widgets');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;

  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() {
    calls = [];
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  void mockNative({bool liveActivitiesSupported = true}) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'isAvailable' => true,
        'updateLiveActivity' => liveActivitiesSupported,
        _ => null,
      };
    });
  }

  Future<void> sendFromNative(String method, Object? arguments) async {
    final message = const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments));
    await messenger.handlePlatformMessage(channel.name, message, (_) {});
  }

  /// the native side reports placed widgets right after `isAvailable`.
  Future<HomeWidgets> initWidgets({bool hasWidgets = true}) async {
    final widgets = HomeWidgets.platform()!;
    expect(await widgets.init(), isTrue);
    await sendFromNative('onHasWidgetsChanged', hasWidgets);
    calls.clear();
    return widgets;
  }

  Future<void> noAction(HomeWidgetMediaAction action) async {}

  Future<void> updateAll(HomeWidgets widgets, {String title = 'Song', bool isPlaying = true}) {
    return widgets.updateAll(
      title: title,
      message: 'Artist',
      imageFileUri: Uri.file('/var/mobile/Containers/Data/Application/X/Library/Application Support/namida/Artworks/a.png'),
      isPlaying: isPlaying,
      isFavourite: false,
      isFavouriteAsLike: false,
      repeatMode: PlayerRepeatMode.none,
      repeatCount: 0,
      shuffle: false,
    );
  }

  test('a build without the widget extension writes nothing', () async {
    final widgets = HomeWidgets.platform()!;
    expect(await widgets.init(), isFalse);

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    await updateAll(widgets);
    expect(await widgets.updateLiveActivity(title: 'Song', artist: 'Artist', line: 'la la'), isFalse);
    await widgets.endLiveActivity();
    await widgets.onPlayerReady(noAction);
    expect(calls, isEmpty);
  });

  test('only the keys the ios widget shows are sent', () async {
    mockNative();
    final widgets = await initWidgets();

    await updateAll(widgets);
    final sent = calls.single.arguments as Map;
    expect(sent.keys, unorderedEquals(['title', 'message', 'image', 'playing', 'favourite']));

    calls.clear();
    await widgets.updateShuffle(true);
    await widgets.updateRepeatMode(PlayerRepeatMode.all, 2);
    expect(calls, isEmpty);
  });

  test('nothing is written while no widget is placed, everything once one is', () async {
    mockNative();
    final widgets = await initWidgets(hasWidgets: false);

    await updateAll(widgets);
    expect(calls, isEmpty);

    await sendFromNative('onHasWidgetsChanged', true);
    expect(calls.single.method, 'updateHomeWidget');
    expect((calls.single.arguments as Map)['title'], 'Song');
  });

  test('a widget press is performed once the player is ready', () async {
    mockNative();
    final widgets = await initWidgets();
    final performed = <HomeWidgetMediaAction>[];
    await widgets.onPlayerReady((action) async => performed.add(action));
    expect(calls.last.method, 'attachMediaActions');

    await sendFromNative('onMediaAction', 'next');
    await sendFromNative('onMediaAction', 'unknown');
    expect(performed, [HomeWidgetMediaAction.next]);
  });

  test('only changed values are sent, an identical update sends nothing', () async {
    mockNative();
    final widgets = await initWidgets();

    await updateAll(widgets);
    expect(calls.single.method, 'updateHomeWidget');
    final sent = calls.single.arguments as Map;
    expect(sent['title'], 'Song');
    expect(sent['message'], 'Artist');
    expect(sent['playing'], isTrue);
    expect(sent['image'], startsWith('file:///var/mobile/'));

    calls.clear();
    await updateAll(widgets);
    expect(calls, isEmpty);

    await widgets.updateIsPlaying(false);
    expect(calls.single.arguments, {'playing': false});
  });

  test('live activity updates go through and report support', () async {
    mockNative(liveActivitiesSupported: true);
    final widgets = await initWidgets();

    expect(await widgets.updateLiveActivity(title: 'Song', artist: null, line: 'first line'), isTrue);
    expect(calls.single.method, 'updateLiveActivity');
    expect(calls.single.arguments, {'title': 'Song', 'artist': null, 'line': 'first line'});

    await widgets.endLiveActivity();
    expect(calls.last.method, 'endLiveActivity');
  });

  test('unsupported live activities report false so the sink stops', () async {
    mockNative(liveActivitiesSupported: false);
    final widgets = await initWidgets();
    expect(await widgets.updateLiveActivity(title: 'Song', artist: 'Artist', line: null), isFalse);
  });
}
