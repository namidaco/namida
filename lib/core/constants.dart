import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/controller/current_color.dart';

///
String kAppDirectoryPath = '';
int kAudioFilesLength = 0;
Set<String> kDirectoriesPaths = {};
List<double> kDefaultWaveFormData = List<double>.generate(500, (index) => 0.02);

/// Main Color
Color kMainColor = const Color.fromARGB(255, 117, 128, 224);
Color kMainColorLight = const Color.fromARGB(255, 116, 126, 219);
Color kMainColorDark = const Color.fromARGB(255, 139, 149, 241);

/// Directories and files used by Namida
final String kTracksFilePath = '$kAppDirectoryPath/tracks.json';
final String kPlaylistsFilePath = '$kAppDirectoryPath/playlists.json';
final String kArtworksDirPath = '$kAppDirectoryPath/Artworks/';
final String kArtworksCompDirPath = '$kAppDirectoryPath/ArtworksCompressed/';
final String kWaveformDirPath = '$kAppDirectoryPath/Waveforms/';

/// Default values available for setting the Date Time Format.
const kDefaultDateTimeStrings = {
  'yyyyMMdd': '20220413',
  'dd/MM/yyyy': '13/04/2022',
  'MM/dd/yyyy': '04/13/2022',
  'yyyy/MM/dd': '2022/04/13',
  'yyyy/dd/MM': '2022/13/04',
  'dd-MM-yyyy': '13-04-2022',
  'MM-dd-yyyy': '04-13-2022',
  'MMMM dd, yyyy': 'April 13, 2022',
  'MMM dd, yyyy': 'Apr 13, 2022',
  '[dd | MM]': '[13 | 04]',
  '[dd.MM.yyyy]': '[13.04.2022]',
};

/// Extensions used to filter files
const List<String> kFileExtensions = [
  '.aac',
  '.ac3',
  '.aiff',
  '.amr',
  '.ape',
  '.au',
  '.dts',
  '.flac',
  '.m4a',
  '.m4b',
  '.m4p',
  '.mid',
  '.mp3',
  '.ogg',
  '.opus',
  '.ra',
  '.tak',
  '.wav',
  '.wma',
];

/// Colors
// class Namida {
//   static Color iconColor = Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(100), Get.theme.colorScheme.onBackground);
// }
