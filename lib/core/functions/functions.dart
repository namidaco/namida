//
//
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';

//
//
/// Simple method to get total album duration in seconds
// int getTotalTracksDuration({required List<Track> tracks}) {
//   int totalAlbumDuration = 0;
//   for (int j = 0; j < tracks.length; j++) {
//     totalAlbumDuration += tracks[j].duration! ~/ 1000;
//   }
//   return totalAlbumDuration;
// }

// String getTotalTracksDurationFormatted({required List<Track> tracks}) {
//   int totalTracksDuration = getTotalTracksDuration(tracks: tracks);
//   String formattedTotalTracksDuration =
//       "${Duration(seconds: totalTracksDuration).inHours == 0 ? "" : "${Duration(seconds: totalTracksDuration).inHours} h "}${Duration(seconds: totalTracksDuration).inMinutes.remainder(60) == 0 ? "" : "${Duration(seconds: totalTracksDuration).inMinutes.remainder(60) + 1} min"}";
//   return formattedTotalTracksDuration;
// }

// int getTotalTracksDurationNew({required List<Track> tracks}) {
//   int totalAlbumDuration = 0;
//   for (int j = 0; j < tracks.length; j++) {
//     totalAlbumDuration += tracks[j].duration! ~/ 1000;
//   }
//   return totalAlbumDuration;
// }

// String getTotalTracksDurationFormattedNew({required List<Track> tracks}) {
//   int totalTracksDuration = getTotalTracksDurationNew(tracks: tracks);
//   String formattedTotalTracksDuration =
//       "${Duration(seconds: totalTracksDuration).inHours == 0 ? "" : "${Duration(seconds: totalTracksDuration).inHours} h "}${Duration(seconds: totalTracksDuration).inMinutes.remainder(60) == 0 ? "" : "${Duration(seconds: totalTracksDuration).inMinutes.remainder(60) + 1} min"}";
//   return formattedTotalTracksDuration;
// }

// String lengthWithTrackKeyword(int length, {bool displayLength = true}) {
//   return '${displayLength ? '$length ' : null}Track${length == 1 ? "" : "s"}';
// }

// String getDateFormatted(String date) {
//   final formatDate = DateFormat('${SettingsController.inst.dateTimeFormat}');
//   final dateFormatted = date.length == 8 ? formatDate.format(DateTime.parse(date)) : date;

//   return dateFormatted;
// }

// Future<Metadata?> getTrackMetadata(String filePath) async {
//   final metadata = await MetadataRetriever.fromFile(File(filePath));
//   String? trackName = metadata.trackName;
//   List<String>? trackArtistNames = metadata.trackArtistNames;
//   String? albumName = metadata.albumName;
//   String? albumArtistName = metadata.albumArtistName;
//   int? trackNumber = metadata.trackNumber;
//   int? albumLength = metadata.albumLength;
//   int? year = metadata.year;
//   String? genre = metadata.genre;
//   String? authorName = metadata.authorName;
//   String? writerName = metadata.writerName;
//   int? discNumber = metadata.discNumber;
//   String? mimeType = metadata.mimeType;
//   int? trackDuration = metadata.trackDuration;
//   int? bitrate = metadata.bitrate;
//   Uint8List? albumArt = metadata.albumArt;
//   debugPrint(("yearrrr $year"));

//   return Future.value(metadata);
// }

// Future<int?> getTrackYearMetadata(String filePath) async {
//   final metadata = await MetadataRetriever.fromFile(File(filePath));
//   int? year = metadata.year;

//   return Future.value(year);
// }
