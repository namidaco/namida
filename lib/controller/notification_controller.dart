import 'package:flutter/material.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/download_task_base.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> cancelAll() async {
    try {
      return _flutterLocalNotificationsPlugin.cancelAll();
    } catch (_) {}
  }

  static const _historyImportID = 1;
  static const _historyImportPayload = 'history_import';
  static const _historyImportChannelName = 'History Import';
  static const _historyImportChannelDescription = 'Imports Tracks to History from a source';

  static const _youtubeDownloadID = 2;
  static const _youtubeDownloadPayload = 'youtube_download';
  static const _youtubeDownloadChannelName = 'Downloads';
  static const _youtubeDownloadChannelDescription = 'Downlaod content from youtube';

  static Future<bool?> init() {
    return _flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_musicnote'),
      ),
      onDidReceiveBackgroundNotificationResponse: _onDidReceiveLocalNotification,
      onDidReceiveNotificationResponse: _onDidReceiveLocalNotification,
    );
  }

  static void mediaNotification({
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

  static void downloadYoutubeNotification({
    required DownloadTaskFilename filenameWrapper,
    required String title,
    required String Function(String progressText) subtitle,
    String? imagePath,
    required int progress,
    required int total,
    required DateTime displayTime,
    required bool isRunning,
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
      tag: filenameWrapper.key,
      displayTime: displayTime,
      ongoing: isRunning,
    );
  }

  static Future<void> removeDownloadingYoutubeNotification({required DownloadTaskFilename filenameWrapper}) async {
    await _flutterLocalNotificationsPlugin.cancel(_youtubeDownloadID, tag: filenameWrapper.key);
  }

  static void doneDownloadingYoutubeNotification({
    required DownloadTaskFilename filenameWrapper,
    required String videoTitle,
    required String subtitle,
    required bool failed,
    String? imagePath,
  }) async {
    final key = filenameWrapper.key;
    await _flutterLocalNotificationsPlugin.cancel(_youtubeDownloadID, tag: key);
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
      tag: key,
      displayTime: DateTime.now(),
    );
  }

  static void importHistoryNotification(int parsed, int total, DateTime displayTime) {
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

  static void doneImportingHistoryNotification(int totalParsed, int totalAdded) {
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

  static void _onDidReceiveLocalNotification(NotificationResponse details) async {
    if (details.payload == _historyImportPayload) {
      JsonToHistoryParser.inst.showParsingProgressDialog();
    }
  }

  static void _createNotification({
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

  static void _createProgressNotification({
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
    bool ongoing = true,
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
          ongoing: ongoing,
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
