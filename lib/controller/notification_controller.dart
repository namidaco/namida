import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/core/extensions.dart';

class NotificationService {
  //Hanle displaying of notifications.
  static final NotificationService _notificationService = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  factory NotificationService() => NotificationService._internal();

  static NotificationService get inst => _notificationService;

  NotificationService._internal() {
    init();
  }

  final _historyImportID = 1;
  final _historyImportPayload = 'history_import';
  final _historyImportChannelName = 'History Import';
  final _historyImportChannelDescription = 'Imports Tracks to History from a source';

  Future<void> init() async {
    await _flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_musicnote'),
      ),
      onDidReceiveBackgroundNotificationResponse: (details) => _onDidReceiveLocalNotification(details),
      onDidReceiveNotificationResponse: (details) => _onDidReceiveLocalNotification(details),
    );
  }

  void importHistoryNotification(int parsed, int total) {
    _createProgressNotification(
      id: _historyImportID,
      progress: parsed,
      maxProgress: total,
      title: 'Importing History',
      channelName: _historyImportChannelName,
      channelDescription: _historyImportChannelDescription,
      payload: _historyImportPayload,
    );
  }

  void doneImportingHistoryNotification(int totalParsed, int totalAdded) {
    _createNotification(
      id: _historyImportID,
      title: 'Done importing history',
      body: '${totalParsed.formatDecimal(true)} parsed, ${totalAdded.formatDecimal(true)} added',
      channelName: _historyImportChannelName,
      channelDescription: _historyImportChannelDescription,
      subText: '100% ✓',
      payload: _historyImportPayload,
    );
  }

  void _onDidReceiveLocalNotification(NotificationResponse details) async {
    if (details.payload == _historyImportPayload) {
      JsonToHistoryParser.inst.showParsingProgressDialog();
    }
  }

  void _createNotification({
    required int id,
    required String title,
    required String body,
    required String subText,
    required String channelName,
    required String channelDescription,
    required String payload,
  }) {
    _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          '$id',
          channelName,
          channelDescription: channelDescription,
          channelShowBadge: true,
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: true,
          ongoing: false,
          visibility: NotificationVisibility.public,
          icon: 'ic_stat_musicnote',
          subText: subText,
        ),
      ),
      payload: payload,
    );
  }

  void _createProgressNotification({
    required int id,
    required int progress,
    required int maxProgress,
    required String title,
    required String channelName,
    required String channelDescription,
    required String payload,
  }) {
    final p = progress / maxProgress;

    _flutterLocalNotificationsPlugin.show(
      id,
      title,
      '${progress.formatDecimal(true)} / ${maxProgress.formatDecimal(true)}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          '$id',
          channelName,
          channelDescription: channelDescription,
          channelShowBadge: false,
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: true,
          showProgress: true,
          ongoing: true,
          visibility: NotificationVisibility.public,
          maxProgress: maxProgress,
          icon: 'ic_stat_musicnote',
          progress: progress,
          subText: '${((p.isFinite ? p : 0) * 100).round()}%',
        ),
      ),
      payload: payload,
    );
  }
}
