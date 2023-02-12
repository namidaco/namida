///
String kAppDirectoryPath = '';
int kAudioFilesLength = 0;
Set<String> kDirectoriesPaths = {};
List<double> kDefaultWaveFormData = List<double>.generate(500, (index) => 0.02);

/// Directories and files used by the app
final String kTracksFilePath = '$kAppDirectoryPath/tracks.json';
final String kArtworksDirPath = '$kAppDirectoryPath/Artworks/';
final String kArtworksCompDirPath = '$kAppDirectoryPath/ArtworksCompressed/';
final String kWaveformDirPath = '$kAppDirectoryPath/Waveforms/';
