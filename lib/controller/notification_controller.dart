import 'package:flutter/material.dart';
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

  final _youtubeDownloadID = 2;
  final _youtubeDownloadPayload = 'youtube_download';
  final _youtubeDownloadChannelName = 'Downloads';
  final _youtubeDownloadChannelDescription = 'Downlaod content from youtube';

  Future<void> init() async {
    await _flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_musicnote'),
      ),
      onDidReceiveBackgroundNotificationResponse: (details) => _onDidReceiveLocalNotification(details),
      onDidReceiveNotificationResponse: (details) => _onDidReceiveLocalNotification(details),
    );
  }

  void mediaNotification({
    required String title,
    required String subText,
    required String subtitle,
    String? imagePath,
    required int progressMS,
    required int durationMS,
    required DateTime displayTime,
    required Color? color,
  }) {
    const id = 10;
    final pic = imagePath == null ? null : FilePathAndroidBitmap(imagePath);

    _flutterLocalNotificationsPlugin.show(
      id,
      title,
      subtitle,
      NotificationDetails(
        android: AndroidNotificationDetails(
          '$id',
          'media',
          channelDescription: 'media',
          groupKey: '$id',
          category: AndroidNotificationCategory.progress,
          setAsGroupSummary: true,
          channelShowBadge: false,
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: true,
          showProgress: true,
          ongoing: true,
          visibility: NotificationVisibility.public,
          styleInformation: const MediaStyleInformation(), // this gets displayed instead of subtitle
          largeIcon: pic,
          progress: progressMS,
          maxProgress: durationMS,
          icon: 'ic_stat_musicnote',
          subText: subText,
          color: color,
          colorized: true,
          // showWhen: displayTime != null,
          when: displayTime.millisecondsSinceEpoch,
          // tag: tag,
        ),
      ),
      // payload: payload,
    );
  }

  void downloadYoutubeNotification({
    required String notificationID,
    required String title,
    required String Function(String progressText) subtitle,
    String? imagePath,
    required int progress,
    required int total,
    required DateTime displayTime,
  }) {
    _createProgressNotification(
      id: _youtubeDownloadID,
      progress: progress,
      maxProgress: total,
      title: title,
      subtitle: subtitle,
      channelName: _youtubeDownloadChannelName,
      channelDescription: _youtubeDownloadChannelDescription,
      payload: _youtubeDownloadPayload,
      imagePath: imagePath,
      isInBytes: true,
      tag: notificationID,
      displayTime: displayTime,
    );
  }

  void doneDownloadingYoutubeNotification({
    required String notificationID,
    required String videoTitle,
    required String subtitle,
    required bool failed,
    String? imagePath,
  }) async {
    await _flutterLocalNotificationsPlugin.cancel(_youtubeDownloadID, tag: notificationID);
    _createNotification(
      id: _youtubeDownloadID,
      title: videoTitle,
      body: subtitle,
      subText: failed ? 'error' : '100% ✓',
      channelName: _youtubeDownloadChannelName,
      channelDescription: _youtubeDownloadChannelDescription,
      payload: _youtubeDownloadPayload,
      imagePath: imagePath,
      isInBytes: true,
      tag: notificationID,
      displayTime: DateTime.now(),
    );
  }

  void importHistoryNotification(int parsed, int total, DateTime displayTime) {
    _createProgressNotification(
      id: _historyImportID,
      progress: parsed,
      maxProgress: total,
      title: 'Importing History',
      subtitle: (progressText) => progressText,
      channelName: _historyImportChannelName,
      channelDescription: _historyImportChannelDescription,
      payload: _historyImportPayload,
      isInBytes: false,
      displayTime: displayTime,
    );
  }

  void doneImportingHistoryNotification(int totalParsed, int totalAdded) {
    _createNotification(
      id: _historyImportID,
      title: 'Done importing history',
      body: '${totalParsed.formatDecimal()} parsed, ${totalAdded.formatDecimal()} added',
      channelName: _historyImportChannelName,
      channelDescription: _historyImportChannelDescription,
      subText: '100% ✓',
      payload: _historyImportPayload,
      isInBytes: false,
      displayTime: DateTime.now(),
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
    String? imagePath,
    required bool isInBytes,
    String? tag,
    required DateTime? displayTime,
  }) {
    final pic = imagePath == null ? null : BigPictureStyleInformation(FilePathAndroidBitmap(imagePath));
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
          styleInformation: pic,
          largeIcon: pic?.bigPicture,
          icon: 'ic_stat_musicnote',
          subText: subText,
          tag: tag,
          showWhen: displayTime != null,
          when: displayTime?.millisecondsSinceEpoch,
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
    required String Function(String progressText) subtitle,
    required String channelName,
    required String channelDescription,
    required String payload,
    required bool isInBytes,
    String? imagePath,
    String? tag,
    required DateTime? displayTime,
  }) {
    final p = progress / maxProgress;
    final sub = isInBytes ? '${progress.fileSizeFormatted} / ${maxProgress.fileSizeFormatted}' : '${progress.formatDecimal()} / ${maxProgress.formatDecimal()}';

    final pic = imagePath == null ? null : FilePathAndroidBitmap(imagePath);

    _flutterLocalNotificationsPlugin.show(
      id,
      title,
      subtitle(sub),
      NotificationDetails(
        android: AndroidNotificationDetails(
          '$id',
          channelName,
          channelDescription: channelDescription,
          groupKey: '$id',
          category: AndroidNotificationCategory.progress,
          setAsGroupSummary: true,
          channelShowBadge: false,
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: true,
          showProgress: true,
          ongoing: true,
          visibility: NotificationVisibility.public,
          styleInformation: BigTextStyleInformation(subtitle(sub)), // this gets displayed instead of subtitle
          largeIcon: pic,
          maxProgress: maxProgress,
          icon: 'ic_stat_musicnote',
          progress: progress,
          subText: '${((p.isFinite ? p : 0) * 100).round()}%',
          showWhen: displayTime != null,
          when: displayTime?.millisecondsSinceEpoch,
          tag: tag,
        ),
      ),
      payload: payload,
    );
  }
}
