import 'dart:async';
import 'dart:math';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:home_widget/home_widget.dart';
import 'package:namida/base/audio_handler.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/main.dart';
import 'package:workmanager/workmanager.dart';

/// Used for Background Updates using Workmanager Plugin
@pragma("vm:entry-point")
void namidaWidgetDispatcher() {
  Workmanager().executeTask((taskName, inputData) {
    final now = DateTime.now();
    return Future.wait<bool?>([
      HomeWidget.saveWidgetData(
        'title',
        'Updated from Background',
      ),
      HomeWidget.saveWidgetData(
        'message',
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      ),
      HomeWidget.updateWidget(
        name: _widgetID1,
      ),
    ]).then((value) {
      return !value.contains(false);
    });
  });
}

/// Called when Doing Background Work initiated from Widget
@pragma("vm:entry-point")
Future<void> interactiveCallback(Uri? data) async {
  print('NAMIDAWIDGET: $data');
  try {
    // -- initialize main
  } catch (e) {
    print('NAMIDAWIDGET: $e');
  }
  print('NAMIDAWIDGET: initialized main');
  if (data?.host == 'titleclicked') {
    final greetings = [
      'Hello',
      'Hallo',
      'Bonjour',
      'Hola',
      'Ciao',
      '哈洛',
      '안녕하세요',
      'xin chào',
    ];
    final selectedGreeting = greetings[Random().nextInt(greetings.length)];
    await HomeWidget.setAppGroupId(_groupId);
    await HomeWidget.saveWidgetData<String>('title', selectedGreeting);
    await HomeWidget.updateWidget(
      name: _widgetID1,
    );
  }
}

const _groupId = 'kurukuru';
const _widgetID1 = 'SchwarzSechsPrototypeMkII';

class NamidaWidgetController {
  static initManager() {
    Workmanager().initialize(namidaWidgetDispatcher, isInDebugMode: kDebugMode);
  }

  static initWidget() {
    HomeWidget.setAppGroupId(_groupId);
    HomeWidget.registerInteractivityCallback(interactiveCallback);
  }

  static onDepChange() {
    _checkForWidgetLaunch();
    HomeWidget.widgetClicked.listen(_launchedFromWidget);
  }

  static void _checkForWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
  }

  static void _launchedFromWidget(Uri? uri) {
    if (uri != null) printo('NAMIDAWIDGET: App started from HomeScreenWidget, uri: $uri');
  }

  static Future updateData({
    required String title,
    required String subtitle,
  }) async {
    await _sendData(title: title, subtitle: subtitle);
    await _updateWidget();
  }

  static Future _sendData({
    required String title,
    required String subtitle,
  }) async {
    try {
      return Future.wait([
        HomeWidget.saveWidgetData<String>('title', title),
        HomeWidget.saveWidgetData<String>('message', subtitle),
        HomeWidget.renderFlutterWidget(
          const Icon(
            Icons.abc,
            size: 200,
          ),
          logicalSize: const Size(200, 200),
          key: 'dashIcon',
        ),
        HomeWidget.renderFlutterWidget(
          const Icon(
            Icons.fork_left,
            size: 24,
          ),
          logicalSize: const Size(24, 24),
          key: 'previous',
        ),
        HomeWidget.renderFlutterWidget(
          const Icon(
            Icons.play_arrow,
            size: 24,
          ),
          logicalSize: const Size(24, 24),
          key: 'play_pause',
        ),
        HomeWidget.renderFlutterWidget(
          const Icon(
            Icons.fork_right,
            size: 24,
          ),
          logicalSize: const Size(24, 24),
          key: 'next',
        ),
      ]);
    } on PlatformException catch (exception) {
      printo('NAMIDAWIDGET: Error Sending Data. $exception', isError: true);
    }
  }

  static Future<bool?> _updateWidget() async {
    try {
      return HomeWidget.updateWidget(name: _widgetID1);
    } on PlatformException catch (exception) {
      printo('NAMIDAWIDGET: Error Updating Widget. $exception', isError: true);
      return null;
    }
  }
}

// class MyApp extends StatefulWidget {
//   const MyApp({Key? key}) : super(key: key);

//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   final TextEditingController _titleController = TextEditingController();
//   final TextEditingController _messageController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     HomeWidget.setAppGroupId('YOUR_GROUP_ID');
//     HomeWidget.registerInteractivityCallback(interactiveCallback);
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     _checkForWidgetLaunch();
//     HomeWidget.widgetClicked.listen(_launchedFromWidget);
//   }

//   @override
//   void dispose() {
//     _titleController.dispose();
//     _messageController.dispose();
//     super.dispose();
//   }

//   Future _sendData() async {
//     try {
//       return Future.wait([
//         HomeWidget.saveWidgetData<String>('title', _titleController.text),
//         HomeWidget.saveWidgetData<String>('message', _messageController.text),
//         HomeWidget.renderFlutterWidget(
//           const Icon(
//             Icons.flutter_dash,
//             size: 200,
//           ),
//           logicalSize: const Size(200, 200),
//           key: 'dashIcon',
//         ),
//       ]);
//     } on PlatformException catch (exception) {
//       debugPrint('Error Sending Data. $exception');
//     }
//   }

//   Future _updateWidget() async {
//     try {
//       return HomeWidget.updateWidget(
//         name: 'HomeWidgetExampleProvider',
//         iOSName: 'HomeWidgetExample',
//       );
//     } on PlatformException catch (exception) {
//       debugPrint('Error Updating Widget. $exception');
//     }
//   }

//   Future _loadData() async {
//     try {
//       return Future.wait([
//         HomeWidget.getWidgetData<String>('title', defaultValue: 'Default Title').then((value) => _titleController.text = value ?? ''),
//         HomeWidget.getWidgetData<String>(
//           'message',
//           defaultValue: 'Default Message',
//         ).then((value) => _messageController.text = value ?? ''),
//       ]);
//     } on PlatformException catch (exception) {
//       debugPrint('Error Getting Data. $exception');
//     }
//   }

//   Future<void> _sendAndUpdate() async {
//     await _sendData();
//     await _updateWidget();
//   }

//   void _checkForWidgetLaunch() {
//     HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
//   }

//   void _launchedFromWidget(Uri? uri) {
//     if (uri != null) {
//       showDialog(
//         context: context,
//         builder: (buildContext) => AlertDialog(
//           title: const Text('App started from HomeScreenWidget'),
//           content: Text('Here is the URI: $uri'),
//         ),
//       );
//     }
//   }

  // void _startBackgroundUpdate() {
  //   Workmanager().registerPeriodicTask(
  //     '1',
  //     'widgetBackgroundUpdate',
  //     frequency: const Duration(minutes: 15),
  //   );
  // }

  // void _stopBackgroundUpdate() {
  //   Workmanager().cancelByUniqueName('1');
  // }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('HomeWidget Example'),
//       ),
//       body: Center(
//         child: Column(
//           children: [
//             TextField(
//               decoration: const InputDecoration(
//                 hintText: 'Title',
//               ),
//               controller: _titleController,
//             ),
//             TextField(
//               decoration: const InputDecoration(
//                 hintText: 'Body',
//               ),
//               controller: _messageController,
//             ),
//             ElevatedButton(
//               onPressed: _sendAndUpdate,
//               child: const Text('Send Data to Widget'),
//             ),
//             ElevatedButton(
//               onPressed: _loadData,
//               child: const Text('Load Data'),
//             ),
//             ElevatedButton(
//               onPressed: _checkForWidgetLaunch,
//               child: const Text('Check For Widget Launch'),
//             ),
//             if (Platform.isAndroid)
//               ElevatedButton(
//                 onPressed: _startBackgroundUpdate,
//                 child: const Text('Update in background'),
//               ),
//             if (Platform.isAndroid)
//               ElevatedButton(
//                 onPressed: _stopBackgroundUpdate,
//                 child: const Text('Stop updating in background'),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
